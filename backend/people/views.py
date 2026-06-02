from datetime import datetime, timedelta
from decimal import Decimal
import base64
import hashlib
import logging
import struct
import zlib
from math import atan2, cos, radians, sin, sqrt
from smtplib import SMTPException
from urllib import parse
from urllib.parse import urlparse

from django.conf import settings
from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.admin.views.decorators import staff_member_required
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.mail import send_mail
from django.core.validators import validate_email
from django.http import HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.utils.dateparse import parse_date
from django.utils.crypto import constant_time_compare, get_random_string, salted_hmac
from django.utils import timezone
from django.views.decorators.http import require_POST
from rest_framework import status
from rest_framework.authentication import TokenAuthentication
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    AssignedLocation,
    Attendance,
    AttendanceSettings,
    AttendanceRegularization,
    EmployeeTask,
    HelpdeskTicket,
    Holiday,
    LeaveRequest,
    PasswordResetOTP,
    ReimbursementRequest,
    SalaryRecord,
    UserProfile,
)
from .location_utils import (
    extract_coordinates_from_map_url,
    geocode_location_text,
    parse_coordinate_pair,
)
from .password_rules import password_rule_error
from .serializers import (
    AssignedLocationSerializer,
    AttendanceRegularizationSerializer,
    AttendanceSerializer,
    EmployeeTaskSerializer,
    HelpdeskTicketSerializer,
    HolidaySerializer,
    LeaveRequestSerializer,
    ReimbursementRequestSerializer,
    SalaryRecordSerializer,
)


logger = logging.getLogger(__name__)

EARTH_RADIUS_METERS = 6371000
MAX_ATTENDANCE_LOCATION_AGE_SECONDS = 120
MAX_ATTENDANCE_LOCATION_FUTURE_SECONDS = 30


def role_for_user(user):
    profile = getattr(user, 'userprofile', None)
    role_markers = [
        user.username,
        user.email,
        profile.department if profile else '',
        profile.designation if profile else '',
    ]
    has_hr_marker = any('hr' in (marker or '').lower() for marker in role_markers)
    if profile:
        if profile.can_access_admin_dashboard or user.is_staff:
            return 'Admin'
        if profile.can_access_hr_dashboard or has_hr_marker:
            return 'HR'
        if profile.can_access_user_dashboard:
            return 'User'
    if user.is_staff:
        return 'Admin'
    if has_hr_marker:
        return 'HR'
    return 'User'


def dashboard_permissions_for_user(user):
    profile = getattr(user, 'userprofile', None)
    if not profile:
        return ['Admin'] if user.is_staff else ['User']
    permissions = []
    if profile.can_access_user_dashboard:
        permissions.append('User')
    if profile.can_access_admin_dashboard or user.is_staff:
        permissions.append('Admin')
    role_markers = [
        user.username,
        user.email,
        profile.department,
        profile.designation,
    ]
    if profile.can_access_hr_dashboard or any(
        'hr' in (marker or '').lower() for marker in role_markers
    ):
        permissions.append('HR')
    return permissions or [role_for_user(user)]


def user_can_access_dashboard(user, role):
    return role.lower() in {
        permission.lower() for permission in dashboard_permissions_for_user(user)
    }


def user_can_manage_people(user):
    return user_can_access_dashboard(user, 'Admin') or user_can_access_dashboard(
        user,
        'HR',
    )


def looks_like_url(value):
    parsed = urlparse((value or '').strip())
    return bool(parsed.scheme and parsed.netloc)


def admin_managed_users():
    return get_user_model().objects.filter(is_superuser=False)


def map_url_for_attendance(attendance):
    if attendance is None:
        return ''
    if not attendance.location_address and attendance.distance_meters is None:
        return ''
    return (
        'https://www.google.com/maps?q='
        f'{compact_decimal(attendance.latitude)},{compact_decimal(attendance.longitude)}'
    )


def photo_biometric_details(photo_biometric):
    if not photo_biometric:
        return {
            'verified': False,
            'message': 'Photo biometric missing.',
            'mime_type': '',
            'size_bytes': 0,
        }
    if not photo_biometric.startswith('data:image/'):
        return {
            'verified': False,
            'message': 'Photo biometric must be an image.',
            'mime_type': '',
            'size_bytes': 0,
        }
    header, _, payload = photo_biometric.partition(',')
    mime_type = header.removeprefix('data:').split(';')[0]
    try:
        size_bytes = len(base64.b64decode(payload, validate=True))
    except Exception:
        return {
            'verified': False,
            'message': 'Photo biometric image data is invalid.',
            'mime_type': mime_type,
            'size_bytes': 0,
        }
    return {
        'verified': size_bytes > 0,
        'message': 'Photo biometric verified.',
        'mime_type': mime_type,
        'size_bytes': size_bytes,
    }


def validate_photo_biometric(value, label='Photo biometric'):
    details = photo_biometric_details(value)
    if not details['verified']:
        return details, f"{label} is required." if not value else details['message']
    return details, ''


def normalized_photo_payload(value):
    text = (value or '').strip()
    if not text.startswith('data:image/') or ',' not in text:
        return ''
    payload = text.partition(',')[2].strip()
    try:
        return base64.b64encode(base64.b64decode(payload, validate=True)).decode('ascii')
    except Exception:
        return ''


def photo_biometric_hash(value):
    payload = normalized_photo_payload(value)
    if not payload:
        return ''
    return hashlib.sha256(payload.encode('ascii')).hexdigest()


def decode_png_pixels(value):
    text = (value or '').strip()
    if not text.startswith('data:image/png;base64,'):
        return None
    try:
        raw = base64.b64decode(text.partition(',')[2], validate=True)
    except Exception:
        return None
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        return None

    offset = 8
    width = height = color_type = None
    compressed = bytearray()
    while offset + 8 <= len(raw):
        length = struct.unpack('>I', raw[offset:offset + 4])[0]
        chunk_type = raw[offset + 4:offset + 8]
        chunk_data = raw[offset + 8:offset + 8 + length]
        offset += 12 + length
        if chunk_type == b'IHDR':
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(
                '>IIBBBBB',
                chunk_data,
            )
            if bit_depth != 8 or interlace != 0 or color_type not in {2, 6}:
                return None
        elif chunk_type == b'IDAT':
            compressed.extend(chunk_data)
        elif chunk_type == b'IEND':
            break

    if not width or not height or color_type is None or not compressed:
        return None

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    try:
        inflated = zlib.decompress(bytes(compressed))
    except Exception:
        return None
    expected = height * (stride + 1)
    if len(inflated) < expected:
        return None

    rows = []
    previous = [0] * stride
    cursor = 0
    for _row_index in range(height):
        filter_type = inflated[cursor]
        cursor += 1
        scanline = list(inflated[cursor:cursor + stride])
        cursor += stride
        recon = [0] * stride
        for index, value_byte in enumerate(scanline):
            left = recon[index - channels] if index >= channels else 0
            up = previous[index]
            up_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                recon[index] = value_byte
            elif filter_type == 1:
                recon[index] = (value_byte + left) & 0xFF
            elif filter_type == 2:
                recon[index] = (value_byte + up) & 0xFF
            elif filter_type == 3:
                recon[index] = (value_byte + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                predictor = left + up - up_left
                distances = (
                    abs(predictor - left),
                    abs(predictor - up),
                    abs(predictor - up_left),
                )
                paeth = (left, up, up_left)[distances.index(min(distances))]
                recon[index] = (value_byte + paeth) & 0xFF
            else:
                return None
        rows.append(recon)
        previous = recon

    return {'width': width, 'height': height, 'channels': channels, 'rows': rows}


def center_grayscale_signature(image, size=16):
    if not image:
        return None
    width = image['width']
    height = image['height']
    channels = image['channels']
    rows = image['rows']
    crop_size = int(min(width, height) * 0.72)
    if crop_size < size:
        return None
    start_x = (width - crop_size) // 2
    start_y = (height - crop_size) // 2
    values = []
    for cell_y in range(size):
        for cell_x in range(size):
            x0 = start_x + (cell_x * crop_size) // size
            x1 = start_x + ((cell_x + 1) * crop_size) // size
            y0 = start_y + (cell_y * crop_size) // size
            y1 = start_y + ((cell_y + 1) * crop_size) // size
            total = count = 0
            for y in range(y0, max(y1, y0 + 1)):
                row = rows[y]
                for x in range(x0, max(x1, x0 + 1)):
                    offset = x * channels
                    red, green, blue = row[offset], row[offset + 1], row[offset + 2]
                    total += int((red * 299 + green * 587 + blue * 114) / 1000)
                    count += 1
            values.append(total / max(count, 1))
    return values


def photo_similarity_score(profile_photo, captured_photo):
    profile_signature = center_grayscale_signature(decode_png_pixels(profile_photo))
    captured_signature = center_grayscale_signature(decode_png_pixels(captured_photo))
    if not profile_signature or not captured_signature:
        return None
    profile_mean = sum(profile_signature) / len(profile_signature)
    captured_mean = sum(captured_signature) / len(captured_signature)
    profile_normalized = [value - profile_mean for value in profile_signature]
    captured_normalized = [value - captured_mean for value in captured_signature]
    numerator = sum(a * b for a, b in zip(profile_normalized, captured_normalized))
    profile_energy = sqrt(sum(value * value for value in profile_normalized))
    captured_energy = sqrt(sum(value * value for value in captured_normalized))
    if profile_energy == 0 or captured_energy == 0:
        return 0
    correlation = numerator / (profile_energy * captured_energy)
    return max(0, min(1, (correlation + 1) / 2))


def face_match_details(profile_photo, captured_photo):
    profile_hash = photo_biometric_hash(profile_photo)
    captured_hash = photo_biometric_hash(captured_photo)
    exact_match = bool(profile_hash and captured_hash and profile_hash == captured_hash)
    similarity_score = photo_similarity_score(profile_photo, captured_photo)
    matched = exact_match or (
        similarity_score is not None and similarity_score >= 0.86
    )
    if similarity_score is None and not exact_match:
        message = (
            'Face verification requires PNG camera captures. Recapture the '
            'employee registered photo and try again.'
        )
    elif matched:
        message = 'Face matched'
    else:
        message = 'Face not matched'
    return {
        'enabled': True,
        'matched': matched,
        'message': message,
        'similarity_score': similarity_score,
    }


def face_verification_required_for(assigned_location):
    settings_obj = AttendanceSettings.current()
    location_enabled = (
        True
        if assigned_location is None
        else assigned_location.face_verification_enabled
    )
    return settings_obj.face_recognition_enabled and location_enabled


def face_verification_settings_payload(assigned_location=None):
    settings_obj = AttendanceSettings.current()
    location_enabled = (
        True
        if assigned_location is None
        else assigned_location.face_verification_enabled
    )
    required = settings_obj.face_recognition_enabled and location_enabled
    return {
        'face_recognition_enabled': required,
        'require_face_verification': settings_obj.face_recognition_enabled,
        'face_verification_required': required,
        'global_face_verification_enabled': settings_obj.face_recognition_enabled,
        'location_face_verification_enabled': location_enabled,
        'updated_at': settings_obj.updated_at,
    }


def attendance_settings_payload():
    settings_obj = AttendanceSettings.current()
    return {
        'face_recognition_enabled': settings_obj.face_recognition_enabled,
        'require_face_verification': settings_obj.face_recognition_enabled,
        'global_face_verification_enabled': settings_obj.face_recognition_enabled,
        'updated_at': settings_obj.updated_at,
    }


def request_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {'1', 'true', 'yes', 'on', 'enabled'}
    return bool(value)


def verification_attachment_details(value):
    text = (value or '').strip()
    if not text:
        return {
            'verified': False,
            'message': 'Verification attachment missing.',
            'mime_type': '',
            'size_bytes': 0,
        }
    if text.startswith('data:image/'):
        return photo_biometric_details(text)
    allowed_mime_types = {
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    }
    if not text.startswith('data:') or ',' not in text:
        return {
            'verified': False,
            'message': 'Upload a photo, PDF, DOC, or DOCX verification file.',
            'mime_type': '',
            'size_bytes': 0,
        }
    header, _, payload = text.partition(',')
    mime_type = header.removeprefix('data:').split(';')[0]
    if mime_type not in allowed_mime_types:
        return {
            'verified': False,
            'message': 'Upload a photo, PDF, DOC, or DOCX verification file.',
            'mime_type': mime_type,
            'size_bytes': 0,
        }
    try:
        size_bytes = len(base64.b64decode(payload, validate=True))
    except Exception:
        return {
            'verified': False,
            'message': 'Verification file data is invalid.',
            'mime_type': mime_type,
            'size_bytes': 0,
        }
    return {
        'verified': size_bytes > 0,
        'message': 'Verification file uploaded.',
        'mime_type': mime_type,
        'size_bytes': size_bytes,
    }


def validate_verification_attachment(value, label='Employee verification file'):
    details = verification_attachment_details(value)
    if not details['verified']:
        return details, f"{label} is required." if not value else details['message']
    return details, ''


def validate_pdf_data(value):
    text = (value or '').strip()
    if not text.startswith('data:application/pdf;base64,'):
        return 'Upload a PDF file.'
    payload = text.partition(',')[2]
    try:
        size_bytes = len(base64.b64decode(payload, validate=True))
    except Exception:
        return 'Uploaded PDF data is invalid.'
    if size_bytes <= 0:
        return 'Uploaded PDF is empty.'
    return ''


def approved_regularization_exists(employee, day):
    return AttendanceRegularization.objects.filter(
        employee=employee,
        date=day,
        status=AttendanceRegularization.STATUS_APPROVED,
    ).exists()


def attendance_hours(check_in, check_out):
    if not check_in or not check_out or check_out.timestamp < check_in.timestamp:
        return None
    return round((check_out.timestamp - check_in.timestamp).total_seconds() / 3600, 2)


def attendance_status_for_day(employee, day, check_in, check_out):
    if approved_regularization_exists(employee, day):
        return 'Present'
    hours = attendance_hours(check_in, check_out)
    if hours is None:
        if check_out:
            return 'Regularization'
        return 'Absent'
    if hours > 11:
        return 'Regularization'
    if hours >= 9:
        return 'Present'
    if hours >= 4.5:
        return 'Half Day'
    return 'Regularization'


def serialize_attendance_admin_row(employee, day, check_in, check_out):
    assigned_location = getattr(employee, 'assigned_location', None)
    hours = attendance_hours(check_in, check_out)
    return {
        'date': day.isoformat(),
        'employee_id': employee.id,
        'employee': employee.get_full_name() or employee.username,
        'username': employee.username,
        'check_in': timezone.localtime(check_in.timestamp).strftime('%I:%M %p') if check_in else '-',
        'check_out': timezone.localtime(check_out.timestamp).strftime('%I:%M %p') if check_out else '-',
        'total_hours': hours,
        'status': attendance_status_for_day(employee, day, check_in, check_out),
        'assigned_location': (
            AssignedLocationSerializer(assigned_location).data
            if assigned_location
            else None
        ),
        'check_in_location': check_in.location_address if check_in else '',
        'check_out_location': check_out.location_address if check_out else '',
        'check_in_distance_meters': check_in.distance_meters if check_in else None,
        'check_out_distance_meters': check_out.distance_meters if check_out else None,
        'check_in_latitude': str(check_in.latitude) if check_in else '',
        'check_in_longitude': str(check_in.longitude) if check_in else '',
        'check_out_latitude': str(check_out.latitude) if check_out else '',
        'check_out_longitude': str(check_out.longitude) if check_out else '',
        'check_in_map_url': map_url_for_attendance(check_in),
        'check_out_map_url': map_url_for_attendance(check_out),
        'check_in_photo_biometric': check_in.photo_biometric if check_in else '',
        'check_out_photo_biometric': check_out.photo_biometric if check_out else '',
        'check_in_biometric_details': photo_biometric_details(
            check_in.photo_biometric if check_in else ''
        ),
        'check_out_biometric_details': photo_biometric_details(
            check_out.photo_biometric if check_out else ''
        ),
    }


def serialize_user(user):
    profile = getattr(user, 'userprofile', None)
    assigned_location = getattr(user, 'assigned_location', None)
    return {
        'id': user.id,
        'username': user.username,
        'employee_id': profile.employee_code if profile and profile.employee_code else user.username,
        'first_name': user.first_name,
        'last_name': user.last_name,
        'name': user.get_full_name() or user.username,
        'email': user.email,
        'mobile_number': profile.mobile_number if profile else '',
        'profile_photo_biometric': profile.profile_photo_biometric if profile else '',
        'profile_photo_biometric_details': photo_biometric_details(
            profile.profile_photo_biometric if profile else ''
        ),
        'gender': profile.gender if profile else '',
        'date_of_birth': profile.date_of_birth.isoformat() if profile and profile.date_of_birth else '',
        'department': profile.department if profile else '',
        'designation': profile.designation if profile else '',
        'role': role_for_user(user),
        'dashboard_permissions': dashboard_permissions_for_user(user),
        'is_staff': user.is_staff,
        'is_active': user.is_active,
        'assigned_location': (
            AssignedLocationSerializer(assigned_location).data
            if assigned_location
            else None
        ),
    }


def haversine_distance_meters(lat1, lon1, lat2, lon2):
    lat1_rad = radians(float(lat1))
    lon1_rad = radians(float(lon1))
    lat2_rad = radians(float(lat2))
    lon2_rad = radians(float(lon2))
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    a = sin(dlat / 2) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon / 2) ** 2
    return EARTH_RADIUS_METERS * (2 * atan2(sqrt(a), sqrt(1 - a)))


def attendance_radius_validation(live_latitude, live_longitude, assigned_location):
    office_latitude = assigned_location.latitude
    office_longitude = assigned_location.longitude
    if not coordinates_in_valid_range(office_latitude, office_longitude):
        return None, False

    distance_meters = haversine_distance_meters(
        live_latitude,
        live_longitude,
        office_latitude,
        office_longitude,
    )
    return distance_meters, distance_meters <= assigned_location.radius_meters


def log_attendance_radius_validation(
    *,
    user,
    event_type,
    employee_latitude,
    employee_longitude,
    assigned_location,
    distance_meters,
    within_allowed_radius,
):
    logger.info(
        (
            'Attendance GPS validation: user_id=%s event_type=%s '
            'office_latitude=%s office_longitude=%s '
            'employee_latitude=%s employee_longitude=%s '
            'distance_meters=%s allowed_radius_meters=%s allowed=%s'
        ),
        user.id,
        event_type,
        assigned_location.latitude,
        assigned_location.longitude,
        employee_latitude,
        employee_longitude,
        None if distance_meters is None else round(distance_meters, 2),
        assigned_location.radius_meters,
        within_allowed_radius,
    )


def coordinates_are_zero(latitude, longitude):
    return Decimal(str(latitude)) == Decimal('0') and Decimal(str(longitude)) == Decimal('0')


def coordinates_in_valid_range(latitude, longitude):
    lat = Decimal(str(latitude))
    lon = Decimal(str(longitude))
    return Decimal('-90') <= lat <= Decimal('90') and Decimal('-180') <= lon <= Decimal('180')


def attendance_location_freshness_error(position_timestamp, captured_at=None):
    if position_timestamp is None:
        return ''
    now = timezone.now()
    if position_timestamp > now + timezone.timedelta(
        seconds=MAX_ATTENDANCE_LOCATION_FUTURE_SECONDS
    ):
        return 'Live GPS timestamp is invalid. Please refresh your location and try again.'
    if now - position_timestamp > timezone.timedelta(
        seconds=MAX_ATTENDANCE_LOCATION_AGE_SECONDS
    ):
        return 'Live GPS coordinates are stale. Please refresh your location and try again.'
    if (
        captured_at
        and abs((captured_at - position_timestamp).total_seconds())
        > MAX_ATTENDANCE_LOCATION_AGE_SECONDS
    ):
        return 'Live GPS capture time is stale. Please refresh your location and try again.'
    return ''


def ensure_assigned_location_coordinates(assigned_location):
    if (
        assigned_location.coordinates_resolved
        and coordinates_in_valid_range(
            assigned_location.latitude,
            assigned_location.longitude,
        )
        and not coordinates_are_zero(
            assigned_location.latitude,
            assigned_location.longitude,
        )
    ):
        return True

    coordinates = None
    if assigned_location.map_url:
        coordinates = extract_coordinates_from_map_url(assigned_location.map_url)

    if coordinates is None:
        coordinates = extract_coordinates_from_map_url(assigned_location.address)

    if coordinates is None and assigned_location.coordinates_resolved:
        return True

    if coordinates is None:
        coordinates = geocode_location_text(assigned_location.address)

    if coordinates is None:
        return False

    assigned_location.latitude = coordinates[0]
    assigned_location.longitude = coordinates[1]
    assigned_location.coordinates_resolved = True
    assigned_location.save(update_fields=['latitude', 'longitude', 'coordinates_resolved'])
    return True


def money(value):
    return float(value or Decimal('0'))


def decimal_label(value):
    return f'{Decimal(value or 0):,.2f}'


def compact_decimal(value):
    decimal_value = Decimal(str(value or 0))
    return format(decimal_value.normalize(), 'f')


def pdf_escape(value):
    return str(value).replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')


def simple_pdf(lines):
    content_lines = ['BT', '/F1 18 Tf', '72 760 Td']
    first = True
    for text, size in lines:
        if first:
            first = False
        else:
            content_lines.append('0 -24 Td')
        content_lines.append(f'/F1 {size} Tf')
        content_lines.append(f'({pdf_escape(text)}) Tj')
    content_lines.append('ET')
    stream = '\n'.join(content_lines).encode('utf-8')

    objects = [
        b'<< /Type /Catalog /Pages 2 0 R >>',
        b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        b'<< /Length ' + str(len(stream)).encode('ascii') + b' >>\nstream\n' + stream + b'\nendstream',
    ]

    pdf = bytearray(b'%PDF-1.4\n')
    offsets = [0]
    for index, obj in enumerate(objects, start=1):
        offsets.append(len(pdf))
        pdf.extend(f'{index} 0 obj\n'.encode('ascii'))
        pdf.extend(obj)
        pdf.extend(b'\nendobj\n')
    xref = len(pdf)
    pdf.extend(f'xref\n0 {len(objects) + 1}\n'.encode('ascii'))
    pdf.extend(b'0000000000 65535 f \n')
    for offset in offsets[1:]:
        pdf.extend(f'{offset:010d} 00000 n \n'.encode('ascii'))
    pdf.extend(
        f'trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF'.encode(
            'ascii'
        )
    )
    return bytes(pdf)


def attendance_dashboard(user):
    today = timezone.localdate()
    month_start = today.replace(day=1)
    records = Attendance.objects.filter(user=user)
    today_records = records.filter(timestamp__date=today)
    month_records = records.filter(timestamp__date__gte=month_start, timestamp__date__lte=today)
    check_in = today_records.filter(event_type=Attendance.CHECK_IN).order_by('timestamp').first()
    check_out = today_records.filter(event_type=Attendance.CHECK_OUT).order_by('-timestamp').first()
    present_days = 0
    for day in month_records.dates('timestamp', 'day'):
        day_records = month_records.filter(timestamp__date=day)
        check_in_for_day = day_records.filter(event_type=Attendance.CHECK_IN).order_by('timestamp').first()
        check_out_for_day = day_records.filter(event_type=Attendance.CHECK_OUT).order_by('-timestamp').first()
        if attendance_status_for_day(user, day, check_in_for_day, check_out_for_day) == 'Present':
            present_days += 1

    return {
        'checked_in_today': check_in is not None,
        'checked_out_today': check_out is not None,
        'today_check_in': timezone.localtime(check_in.timestamp).strftime('%H:%M') if check_in else None,
        'today_check_out': timezone.localtime(check_out.timestamp).strftime('%H:%M') if check_out else None,
        'check_in_location': check_in.location_address if check_in else '',
        'check_out_location': check_out.location_address if check_out else '',
        'check_in_distance_meters': check_in.distance_meters if check_in else None,
        'check_out_distance_meters': check_out.distance_meters if check_out else None,
        'check_in_accuracy': check_in.accuracy if check_in else None,
        'check_out_accuracy': check_out.accuracy if check_out else None,
        'check_in_latitude': str(check_in.latitude) if check_in else '',
        'check_in_longitude': str(check_in.longitude) if check_in else '',
        'check_out_latitude': str(check_out.latitude) if check_out else '',
        'check_out_longitude': str(check_out.longitude) if check_out else '',
        'check_in_map_url': map_url_for_attendance(check_in),
        'check_out_map_url': map_url_for_attendance(check_out),
        'present_days_this_month': present_days,
        'month_check_ins': month_records.filter(event_type=Attendance.CHECK_IN).count(),
        'month_check_outs': month_records.filter(event_type=Attendance.CHECK_OUT).count(),
    }


def tasks_dashboard(user):
    tasks = EmployeeTask.objects.filter(employee=user)
    return {
        'assigned': tasks.filter(status__in=[EmployeeTask.STATUS_ASSIGNED, EmployeeTask.STATUS_IN_PROGRESS]).count(),
        'review_pending': tasks.filter(status=EmployeeTask.STATUS_REVIEW).count(),
        'completed': tasks.filter(status=EmployeeTask.STATUS_COMPLETED).count(),
        'recent': EmployeeTaskSerializer(tasks[:5], many=True).data,
    }


def leaves_dashboard(user):
    leaves = LeaveRequest.objects.filter(employee=user)
    approved_days = sum(leave.total_days for leave in leaves.filter(status=LeaveRequest.STATUS_APPROVED))
    return {
        'available': max(24 - approved_days, 0),
        'applied': leaves.count(),
        'approved': leaves.filter(status=LeaveRequest.STATUS_APPROVED).count(),
        'pending': leaves.filter(status=LeaveRequest.STATUS_PENDING).count(),
        'rejected': leaves.filter(status=LeaveRequest.STATUS_REJECTED).count(),
        'recent': LeaveRequestSerializer(leaves[:5], many=True).data,
    }


def salary_dashboard(user):
    published = SalaryRecord.objects.filter(employee=user, is_published=True)
    latest = published.first()
    return {
        'payslips': published.count(),
        'allowances': money(latest.allowances) if latest else 0,
        'deductions': money(latest.deductions) if latest else 0,
        'bonus': money(latest.bonus) if latest else 0,
        'incentives': money(latest.incentives) if latest else 0,
        'tax_details': money(latest.tax_deducted) if latest else 0,
        'latest': SalaryRecordSerializer(latest).data if latest else None,
        'recent': SalaryRecordSerializer(published[:5], many=True).data,
    }


def helpdesk_dashboard(user):
    tickets = HelpdeskTicket.objects.filter(employee=user)
    return {
        'open_tickets': tickets.filter(status__in=[HelpdeskTicket.STATUS_OPEN, HelpdeskTicket.STATUS_IN_PROGRESS]).count(),
        'resolved_tickets': tickets.filter(status__in=[HelpdeskTicket.STATUS_RESOLVED, HelpdeskTicket.STATUS_CLOSED]).count(),
        'recent': HelpdeskTicketSerializer(tickets[:5], many=True).data,
    }


def reports_dashboard(user):
    attendance = attendance_dashboard(user)
    leaves = leaves_dashboard(user)
    salary = salary_dashboard(user)
    helpdesk = helpdesk_dashboard(user)
    return {
        'attendance_report': attendance['present_days_this_month'],
        'leave_report': leaves['applied'],
        'salary_report': salary['payslips'],
        'helpdesk_report': helpdesk['open_tickets'] + helpdesk['resolved_tickets'],
    }


def normalize_mobile_number(value):
    return ''.join(ch for ch in (value or '') if ch.isdigit() or ch == '+')


def e164_mobile_number(mobile_number):
    if mobile_number.startswith('+'):
        return mobile_number
    if len(mobile_number) == 10:
        return f'+91{mobile_number}'
    if len(mobile_number) == 12 and mobile_number.startswith('91'):
        return f'+{mobile_number}'
    return mobile_number


PASSWORD_RESET_OTP_SALT = 'people.password-reset.email-otp'


def find_profile_by_mobile_number(mobile_number):
    candidates = {mobile_number, e164_mobile_number(mobile_number)}
    if mobile_number.startswith('+91'):
        candidates.add(mobile_number[3:])
        candidates.add(mobile_number[1:])
    elif mobile_number.startswith('91') and len(mobile_number) == 12:
        candidates.add(mobile_number[2:])
    for profile in UserProfile.objects.select_related('user').filter(user__is_active=True):
        saved_mobile = normalize_mobile_number(profile.mobile_number)
        saved_candidates = {saved_mobile, e164_mobile_number(saved_mobile)}
        if saved_mobile.startswith('+91'):
            saved_candidates.add(saved_mobile[3:])
            saved_candidates.add(saved_mobile[1:])
        elif saved_mobile.startswith('91') and len(saved_mobile) == 12:
            saved_candidates.add(saved_mobile[2:])
        if candidates.intersection(saved_candidates):
            return profile
    return None


def normalize_email_address(email):
    return (email or '').strip().lower()


def find_user_by_email(email):
    normalized_email = normalize_email_address(email)
    if not normalized_email:
        return None
    return (
        get_user_model()
        .objects.filter(email__iexact=normalized_email, is_active=True)
        .first()
    )


def hash_password_reset_otp(otp):
    return salted_hmac(
        PASSWORD_RESET_OTP_SALT,
        otp,
        secret=settings.SECRET_KEY,
        algorithm='sha256',
    ).hexdigest()


def latest_email_reset_request(email):
    normalized_email = normalize_email_address(email)
    return (
        PasswordResetOTP.objects.select_related('user')
        .filter(
            mobile_number=normalized_email,
            used_at__isnull=True,
        )
        .order_by('-created_at')
        .first()
    )


def otp_expiry_time():
    return timezone.now() + timedelta(minutes=getattr(settings, 'EMAIL_OTP_EXPIRY_MINUTES', 10))


def send_password_reset_otp_email(user, otp, expires_at):
    email_user = getattr(settings, 'EMAIL_HOST_USER', '').strip()
    email_password = getattr(settings, 'EMAIL_HOST_PASSWORD', '').strip()
    if (
        not email_user
        or not email_password
        or email_user == 'your-gmail-address@gmail.com'
        or email_password == 'your-16-character-app-password'
    ):
        raise SMTPException(
            'Gmail SMTP is not configured. Set EMAIL_HOST_USER and EMAIL_HOST_PASSWORD to a Gmail address and App Password.',
        )

    expiry_minutes = getattr(settings, 'EMAIL_OTP_EXPIRY_MINUTES', 10)
    subject = 'HealOn password reset OTP'
    message = (
        f'Hello {user.get_full_name() or user.username},\n\n'
        f'Your HealOn password reset OTP is {otp}.\n'
        f'This OTP expires in {expiry_minutes} minutes.\n\n'
        'If you did not request a password reset, ignore this email.'
    )
    send_mail(
        subject,
        message,
        getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@healon.local'),
        [user.email],
        fail_silently=False,
    )


class AuthTokenView(ObtainAuthToken):
    authentication_classes = []
    permission_classes = []

    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        token = Token.objects.select_related('user').get(key=response.data['token'])
        requested_role = (request.data.get('role') or '').lower()

        if requested_role and not user_can_access_dashboard(token.user, requested_role):
            return Response(
                {'detail': 'Invalid Employee ID or Password'},
                status=status.HTTP_403_FORBIDDEN,
            )

        return Response({'token': token.key, 'user': serialize_user(token.user)})


class MeView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({'user': serialize_user(request.user)})


class UserDashboardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        assigned_location = getattr(request.user, 'assigned_location', None)
        return Response({
            'user': serialize_user(request.user),
            'attendance': attendance_dashboard(request.user),
            'attendance_settings': face_verification_settings_payload(
                assigned_location,
            ),
            'tasks': tasks_dashboard(request.user),
            'leaves': leaves_dashboard(request.user),
            'salary': salary_dashboard(request.user),
            'helpdesk': helpdesk_dashboard(request.user),
            'reports': reports_dashboard(request.user),
            'holidays': HolidaySerializer(
                Holiday.objects.filter(date__gte=timezone.localdate())[:10],
                many=True,
            ).data,
            'timestamp': timezone.now().isoformat(),
        })


@staff_member_required
def admin_dashboard_panel(request):
    User = get_user_model()
    employees = User.objects.filter(is_staff=False)
    today = timezone.localdate()
    today_records = Attendance.objects.filter(timestamp__date=today)
    present_today = today_records.filter(event_type=Attendance.CHECK_IN).values('user').distinct().count()
    pending_leaves = LeaveRequest.objects.filter(status=LeaveRequest.STATUS_PENDING).count()
    pending_regularizations = AttendanceRegularization.objects.filter(
        status=AttendanceRegularization.STATUS_PENDING
    ).count()
    open_tickets = HelpdeskTicket.objects.filter(
        status__in=[HelpdeskTicket.STATUS_OPEN, HelpdeskTicket.STATUS_IN_PROGRESS]
    ).count()
    pending_leave_items = LeaveRequest.objects.select_related('employee').filter(
        status=LeaveRequest.STATUS_PENDING
    )[:10]
    pending_regularization_items = AttendanceRegularization.objects.select_related('employee').filter(
        status=AttendanceRegularization.STATUS_PENDING
    )[:10]
    pending_ticket_items = HelpdeskTicket.objects.select_related('employee').filter(
        status__in=[HelpdeskTicket.STATUS_OPEN, HelpdeskTicket.STATUS_IN_PROGRESS]
    )[:10]
    pending_work_items = [
        {
            'type': 'Leave Request',
            'employee': item.employee,
            'title': item.leave_type,
            'details': f'{item.from_date} to {item.to_date} ({item.total_days} days)',
            'status': item.status,
            'status_label': item.get_status_display(),
        }
        for item in pending_leave_items
    ] + [
        {
            'type': 'Regularization',
            'employee': item.employee,
            'title': item.date,
            'details': item.reason,
            'status': item.status,
            'status_label': item.get_status_display(),
        }
        for item in pending_regularization_items
    ] + [
        {
            'type': 'Helpdesk',
            'employee': item.employee,
            'title': item.subject,
            'details': item.description,
            'status': item.status,
            'status_label': item.get_status_display(),
        }
        for item in pending_ticket_items
    ]
    context = {
        'summary': {
            'total_employees': employees.count(),
            'active_employees': employees.filter(is_active=True).count(),
            'present_today': present_today,
            'absent_today': max(employees.count() - present_today, 0),
            'total_requests': pending_leaves + pending_regularizations + open_tickets,
            'pending_leaves': pending_leaves,
            'pending_regularizations': pending_regularizations,
            'published_payslips': SalaryRecord.objects.filter(is_published=True).count(),
            'tasks_in_progress': EmployeeTask.objects.filter(status=EmployeeTask.STATUS_IN_PROGRESS).count(),
            'open_tickets': open_tickets,
        },
        'employees': employees.select_related('userprofile').order_by('username'),
        'recent_attendance': Attendance.objects.select_related('user')[:10],
        'recent_regularizations': AttendanceRegularization.objects.select_related('employee')[:10],
        'pending_regularizations': pending_regularization_items,
        'recent_tasks': EmployeeTask.objects.select_related('employee')[:10],
        'recent_leaves': LeaveRequest.objects.select_related('employee')[:10],
        'pending_leaves': pending_leave_items,
        'pending_work_items': pending_work_items[:12],
        'recent_tickets': HelpdeskTicket.objects.select_related('employee')[:10],
    }
    return render(request, 'people/admin_dashboard.html', context)


@staff_member_required
@require_POST
def update_leave_request_status(request, leave_id, new_status):
    if new_status not in {
        LeaveRequest.STATUS_APPROVED,
        LeaveRequest.STATUS_REJECTED,
        LeaveRequest.STATUS_PENDING,
    }:
        messages.error(request, 'Invalid leave status.')
        return redirect('admin-dashboard-panel')

    leave = get_object_or_404(LeaveRequest, pk=leave_id)
    leave.status = new_status
    leave.save(update_fields=['status'])
    messages.success(
        request,
        f'{leave.employee} {leave.leave_type} marked as {leave.get_status_display()}.',
    )
    return redirect('admin-dashboard-panel')


@staff_member_required
@require_POST
def update_regularization_status(request, regularization_id, new_status):
    if new_status not in {
        AttendanceRegularization.STATUS_APPROVED,
        AttendanceRegularization.STATUS_REJECTED,
        AttendanceRegularization.STATUS_PENDING,
    }:
        messages.error(request, 'Invalid regularization status.')
        return redirect('admin-dashboard-panel')

    regularization = get_object_or_404(AttendanceRegularization, pk=regularization_id)
    regularization.status = new_status
    regularization.save(update_fields=['status'])
    messages.success(
        request,
        f'{regularization.employee} regularization for {regularization.date} marked as {regularization.get_status_display()}.',
    )
    return redirect('admin-dashboard-panel')


class AttendanceEventView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]
    event_type = Attendance.CHECK_IN

    def post(self, request):
        assigned_location = getattr(request.user, 'assigned_location', None)
        location_restricted = assigned_location is not None and assigned_location.is_active
        face_recognition_enabled = face_verification_required_for(assigned_location)
        face_settings = face_verification_settings_payload(assigned_location)
        data = request.data.copy()
        if not location_restricted:
            data.setdefault('latitude', '0')
            data.setdefault('longitude', '0')
        serializer = AttendanceSerializer(data=data)
        if serializer.is_valid():
            profile = getattr(request.user, 'userprofile', None)
            profile_photo = profile.profile_photo_biometric if profile else ''
            photo_biometric = (
                serializer.validated_data.get('photo_biometric') or ''
            ).strip()
            biometric_details, biometric_error = validate_photo_biometric(
                photo_biometric,
                'Captured attendance photo',
            )
            if biometric_error:
                return Response(
                    {'detail': biometric_error},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            face_details = {'enabled': False, 'matched': None, 'message': 'Face recognition disabled'}
            if face_recognition_enabled:
                _, profile_photo_error = validate_photo_biometric(
                    profile_photo,
                    'Registered employee photo',
                )
                if profile_photo_error:
                    return Response(
                        {
                            'detail': (
                                'Registered employee photo is required before '
                                'check-in or check-out. Please contact admin.'
                            ),
                            'face_recognition_enabled': True,
                            'face_verification_required': True,
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                face_details = face_match_details(profile_photo, photo_biometric)
                if not face_details['matched']:
                    return Response(
                        {
                            'detail': 'Face not matched',
                            'face_recognition_enabled': True,
                            'face_verification_required': True,
                            'face_match_details': face_details,
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

            if not location_restricted:
                serializer.save(
                    user=request.user,
                    event_type=self.event_type,
                    assigned_location=assigned_location,
                    location_address='',
                    distance_meters=None,
                )
                data = serializer.data
                data['biometric_details'] = {
                    **biometric_details,
                    'registered_photo_verified': face_recognition_enabled,
                    'face_recognition_enabled': face_recognition_enabled,
                    'face_verification_required': face_recognition_enabled,
                    'face_verification_settings': face_settings,
                    'face_match_details': face_details,
                    'location_restriction_enabled': False,
                    'message': (
                        'Photo biometric captured. Location restriction is disabled '
                        'for this employee.'
                    ),
                }
                return Response(data, status=status.HTTP_201_CREATED)

            today = timezone.localdate()
            if assigned_location.effective_from and today < assigned_location.effective_from:
                return Response(
                    {
                        'detail': (
                            'Your assigned attendance location is not active yet. '
                            f'It starts on {assigned_location.effective_from.isoformat()}.'
                        ),
                        'assigned_location': AssignedLocationSerializer(assigned_location).data,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if assigned_location.effective_to and today > assigned_location.effective_to:
                return Response(
                    {
                        'detail': (
                            'Your assigned attendance location has expired. '
                            f'It ended on {assigned_location.effective_to.isoformat()}.'
                        ),
                        'assigned_location': AssignedLocationSerializer(assigned_location).data,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if not ensure_assigned_location_coordinates(assigned_location):
                return Response(
                    {
                        'detail': (
                            'Assigned attendance location could not be found on the map. '
                            'Please ask admin to update the full workplace address.'
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            latitude = serializer.validated_data['latitude']
            longitude = serializer.validated_data['longitude']
            if coordinates_are_zero(latitude, longitude):
                return Response(
                    {'detail': 'Live GPS coordinates are required for attendance.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if not coordinates_in_valid_range(latitude, longitude):
                return Response(
                    {'detail': 'Live GPS coordinates are invalid.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if serializer.validated_data.get('position_timestamp') is None:
                return Response(
                    {'detail': 'Fresh live GPS timestamp is required for attendance.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            freshness_error = attendance_location_freshness_error(
                serializer.validated_data.get('position_timestamp'),
                serializer.validated_data.get('location_captured_at'),
            )
            if freshness_error:
                return Response(
                    {'detail': freshness_error},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            distance_meters, within_allowed_radius = attendance_radius_validation(
                latitude,
                longitude,
                assigned_location,
            )
            log_attendance_radius_validation(
                user=request.user,
                event_type=self.event_type,
                employee_latitude=latitude,
                employee_longitude=longitude,
                assigned_location=assigned_location,
                distance_meters=distance_meters,
                within_allowed_radius=within_allowed_radius,
            )
            if distance_meters is None:
                return Response(
                    {
                        'detail': (
                            'Assigned attendance location coordinates are invalid. '
                            'Please ask admin to update the office location.'
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if not within_allowed_radius:
                return Response(
                    {
                        'detail': (
                            'You are outside the allowed office location radius. '
                            f'You are {distance_meters:.1f} meters away from the office location.'
                        ),
                        'assigned_location': AssignedLocationSerializer(assigned_location).data,
                        'distance_meters': round(distance_meters, 1),
                        'allowed_radius_meters': assigned_location.radius_meters,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            serializer.save(
                user=request.user,
                event_type=self.event_type,
                assigned_location=assigned_location,
                location_address=assigned_location.address,
                distance_meters=round(distance_meters, 2),
            )
            data = serializer.data
            data['biometric_details'] = {
                **biometric_details,
                'registered_photo_verified': face_recognition_enabled,
                'face_recognition_enabled': face_recognition_enabled,
                'face_verification_required': face_recognition_enabled,
                'face_verification_settings': face_settings,
                'face_match_details': face_details,
                'message': 'Photo biometric captured.',
            }
            return Response(data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CheckInView(AttendanceEventView):
    event_type = Attendance.CHECK_IN


class CheckOutView(AttendanceEventView):
    event_type = Attendance.CHECK_OUT


class AttendanceReportView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        month = request.query_params.get('month') or timezone.localdate().strftime('%Y-%m')
        try:
            month_start = datetime.strptime(month, '%Y-%m').date().replace(day=1)
        except ValueError:
            return Response({'month': ['Use YYYY-MM format.']}, status=status.HTTP_400_BAD_REQUEST)

        next_month = month_start.replace(year=month_start.year + 1, month=1) if month_start.month == 12 else month_start.replace(month=month_start.month + 1)
        start_at = timezone.make_aware(datetime.combine(month_start, datetime.min.time()))
        end_at = timezone.make_aware(datetime.combine(next_month, datetime.min.time()))
        records = Attendance.objects.filter(user=request.user, timestamp__gte=start_at, timestamp__lt=end_at).order_by('timestamp')

        grouped = {}
        for record in records:
            day = timezone.localtime(record.timestamp).date().isoformat()
            grouped.setdefault(day, []).append(record)

        days = []
        total_hours = 0.0
        for day, day_records in grouped.items():
            check_ins = [item for item in day_records if item.event_type == Attendance.CHECK_IN]
            check_outs = [item for item in day_records if item.event_type == Attendance.CHECK_OUT]
            check_in = check_ins[0] if check_ins else None
            check_out = check_outs[-1] if check_outs else None
            day_date = datetime.strptime(day, '%Y-%m-%d').date()
            hours = attendance_hours(check_in, check_out)
            status_label = attendance_status_for_day(request.user, day_date, check_in, check_out)
            if hours is not None:
                total_hours += hours
            days.append({
                'date': day,
                'check_in': timezone.localtime(check_in.timestamp).strftime('%H:%M') if check_in else None,
                'check_out': timezone.localtime(check_out.timestamp).strftime('%H:%M') if check_out else None,
                'total_hours': hours,
                'status': status_label,
            })

        return Response({
            'month': month,
            'summary': {
                'present_days': len([day for day in days if day['status'] == 'Present']),
                'total_hours': round(total_hours, 2),
                'late_days': 0,
            },
            'days': days,
        })


class EmployeeAttendanceRegularizationView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        requests = AttendanceRegularization.objects.filter(employee=request.user)
        return Response({
            'regularizations': AttendanceRegularizationSerializer(requests, many=True).data,
        })

    def post(self, request):
        serializer = AttendanceRegularizationSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(employee=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class EmployeeTasksView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        tasks = EmployeeTask.objects.filter(employee=request.user)
        if request.query_params.get('year'):
            tasks = tasks.filter(assigned_date__year=request.query_params['year'])
        if request.query_params.get('month'):
            tasks = tasks.filter(assigned_date__month=request.query_params['month'])
        return Response({'summary': tasks_dashboard(request.user), 'tasks': EmployeeTaskSerializer(tasks, many=True).data})

    def post(self, request):
        task_id = request.data.get('task_id')
        reason = (request.data.get('reason') or '').strip()
        if not task_id:
            return Response({'detail': 'Task is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if not reason:
            return Response({'detail': 'Reason is required.'}, status=status.HTTP_400_BAD_REQUEST)

        task = get_object_or_404(EmployeeTask, pk=task_id, employee=request.user)
        if task.status == EmployeeTask.STATUS_COMPLETED:
            return Response(
                {'detail': 'Completed tasks cannot be submitted again.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        task.description = reason
        task.status = EmployeeTask.STATUS_REVIEW
        task.save(update_fields=['description', 'status', 'updated_at'])
        return Response({
            'detail': 'Task submitted to admin.',
            'task': EmployeeTaskSerializer(task).data,
        })


class EmployeeLeaveRequestsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        leaves = LeaveRequest.objects.filter(employee=request.user)
        return Response({'summary': leaves_dashboard(request.user), 'leaves': LeaveRequestSerializer(leaves, many=True).data})

    def post(self, request):
        serializer = LeaveRequestSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(employee=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class EmployeeSalaryView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        records = SalaryRecord.objects.filter(employee=request.user, is_published=True)
        if request.query_params.get('year'):
            records = records.filter(year=request.query_params['year'])
        if request.query_params.get('month'):
            records = records.filter(month=request.query_params['month'])
        return Response({'summary': salary_dashboard(request.user), 'salary_records': SalaryRecordSerializer(records, many=True).data})


class EmployeeReimbursementRequestsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        requests = ReimbursementRequest.objects.filter(employee=request.user)
        if request.query_params.get('date'):
            requests = requests.filter(expense_date=request.query_params['date'])
        return Response({
            'reimbursements': ReimbursementRequestSerializer(requests, many=True).data,
        })

    def post(self, request):
        expense_date_raw = (request.data.get('expense_date') or '').strip()
        reason = (request.data.get('reason') or '').strip()
        file_name = (request.data.get('file_name') or '').strip()
        pdf_data = (request.data.get('pdf_data') or '').strip()

        expense_date = parse_date(expense_date_raw) if expense_date_raw else None
        if expense_date is None:
            return Response(
                {'detail': 'Select a valid reimbursement date.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not reason:
            return Response(
                {'detail': 'Reason is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not file_name:
            return Response(
                {'detail': 'Upload a PDF file.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        pdf_error = validate_pdf_data(pdf_data)
        if pdf_error:
            return Response({'detail': pdf_error}, status=status.HTTP_400_BAD_REQUEST)

        reimbursement = ReimbursementRequest.objects.create(
            employee=request.user,
            expense_date=expense_date,
            reason=reason,
            file_name=file_name,
            pdf_data=pdf_data,
        )
        return Response(
            {'reimbursement': ReimbursementRequestSerializer(reimbursement).data},
            status=status.HTTP_201_CREATED,
        )


class EmployeePayslipPdfView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        year = request.query_params.get('year')
        month = request.query_params.get('month')
        if not year or not month:
            return Response(
                {'detail': 'Month and year are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        record = SalaryRecord.objects.filter(
            employee=request.user,
            is_published=True,
            year=year,
            month=month,
        ).first()
        if record is None:
            return Response(
                {'detail': 'No published payslip found for this month.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        employee = request.user.get_full_name() or request.user.username
        month_label = datetime(int(record.year), int(record.month), 1).strftime('%B %Y')
        lines = [
            ('HealOn Payslip', 20),
            (f'Employee: {employee}', 12),
            (f'Employee ID: {request.user.username}', 12),
            (f'Pay Period: {month_label}', 12),
            ('', 12),
            ('Earnings', 14),
            (f'Basic Salary: INR {decimal_label(record.basic_salary)}', 12),
            (f'Allowances: INR {decimal_label(record.allowances)}', 12),
            (f'Bonus: INR {decimal_label(record.bonus)}', 12),
            (f'Incentives: INR {decimal_label(record.incentives)}', 12),
            (f'Gross Salary: INR {decimal_label(record.gross_salary)}', 12),
            ('', 12),
            ('Deductions', 14),
            (f'Deductions: INR {decimal_label(record.deductions)}', 12),
            (f'Tax Deducted: INR {decimal_label(record.tax_deducted)}', 12),
            ('', 12),
            (f'Net Salary: INR {decimal_label(record.net_salary)}', 16),
        ]
        pdf = simple_pdf(lines)
        filename = f'payslip-{record.year}-{record.month:02d}.pdf'
        response = HttpResponse(pdf, content_type='application/pdf')
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response


class EmployeeHelpdeskTicketsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        tickets = HelpdeskTicket.objects.filter(employee=request.user)
        if request.query_params.get('year'):
            tickets = tickets.filter(created_at__year=request.query_params['year'])
        if request.query_params.get('month'):
            tickets = tickets.filter(created_at__month=request.query_params['month'])
        return Response({'summary': helpdesk_dashboard(request.user), 'tickets': HelpdeskTicketSerializer(tickets, many=True).data})

    def post(self, request):
        serializer = HelpdeskTicketSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(employee=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class EmployeeHolidaysView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({'holidays': HolidaySerializer(Holiday.objects.filter(date__gte=timezone.localdate()), many=True).data})


class EmployeeReportsSummaryView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({'reports': reports_dashboard(request.user)})


class EmployeeDirectoryView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        User = get_user_model()
        employees = User.objects.select_related('userprofile').filter(
            is_active=True,
            is_staff=False,
        )
        employees = employees.exclude(id=request.user.id).order_by('first_name', 'username')
        return Response({
            'employees': [
                serialize_user(employee)
                for employee in employees
            ],
        })


class AdminDashboardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        User = get_user_model()
        employees = User.objects.filter(is_superuser=False)
        today = timezone.localdate()
        today_records = Attendance.objects.filter(timestamp__date=today)
        present_today = 0
        for employee in employees:
            user_records = today_records.filter(user=employee)
            check_in = user_records.filter(event_type=Attendance.CHECK_IN).order_by('timestamp').first()
            check_out = user_records.filter(event_type=Attendance.CHECK_OUT).order_by('-timestamp').first()
            if attendance_status_for_day(employee, today, check_in, check_out) == 'Present':
                present_today += 1
        pending_leave_requests = LeaveRequest.objects.filter(status=LeaveRequest.STATUS_PENDING).count()
        pending_regularization_requests = AttendanceRegularization.objects.filter(
            status=AttendanceRegularization.STATUS_PENDING
        ).count()
        open_tickets = HelpdeskTicket.objects.filter(
            status__in=[HelpdeskTicket.STATUS_OPEN, HelpdeskTicket.STATUS_IN_PROGRESS]
        ).count()
        total_requests = (
            LeaveRequest.objects.count()
            + AttendanceRegularization.objects.count()
            + HelpdeskTicket.objects.count()
        )
        return Response({
            'summary': {
                'total_employees': employees.count(),
                'present_today': present_today,
                'absent_today': max(employees.count() - present_today, 0),
                'total_requests': total_requests,
                'leave_requests': pending_leave_requests,
                'regularization_requests': pending_regularization_requests,
                'pending_approvals': (
                    pending_leave_requests
                    + pending_regularization_requests
                    + open_tickets
                ),
                'tasks_in_progress': EmployeeTask.objects.filter(status=EmployeeTask.STATUS_IN_PROGRESS).count(),
                'active_employees': employees.filter(is_active=True).count(),
                'today_check_outs': today_records.filter(event_type=Attendance.CHECK_OUT).count(),
            },
            'pending_requests': {
                'leaves': [
                    {
                        'id': item.id,
                        'employee': item.employee.get_full_name() or item.employee.username,
                        'type': item.leave_type,
                        'from_date': item.from_date.isoformat(),
                        'to_date': item.to_date.isoformat(),
                        'days': item.total_days,
                        'reason': item.reason,
                        'status': item.status,
                        'status_label': item.get_status_display(),
                    }
                    for item in LeaveRequest.objects.select_related('employee').all()[:100]
                ],
                'regularizations': [
                    {
                        'id': item.id,
                        'employee': item.employee.get_full_name() or item.employee.username,
                        'date': item.date.isoformat(),
                        'check_in_time': item.check_in_time.strftime('%H:%M') if item.check_in_time else '',
                        'check_out_time': item.check_out_time.strftime('%H:%M') if item.check_out_time else '',
                        'cc': item.cc,
                        'reason': item.reason,
                        'status': item.status,
                        'status_label': item.get_status_display(),
                    }
                    for item in AttendanceRegularization.objects.select_related('employee').all()[:100]
                ],
                'tickets': [
                    {
                        'id': item.id,
                        'employee': item.employee.get_full_name() or item.employee.username,
                        'subject': item.subject,
                        'description': item.description,
                        'status': item.status,
                        'status_label': item.get_status_display(),
                        'created_at': item.created_at.isoformat(),
                    }
                    for item in HelpdeskTicket.objects.select_related('employee').all()[:100]
                ],
                'reimbursements': ReimbursementRequestSerializer(
                    ReimbursementRequest.objects.select_related('employee')[:100],
                    many=True,
                ).data,
            },
            'timestamp': timezone.now().isoformat(),
        })


class AdminDashboardStatsView(AdminDashboardView):
    pass


class AdminReimbursementRequestsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        requests = ReimbursementRequest.objects.select_related('employee')
        if request.query_params.get('date'):
            requests = requests.filter(expense_date=request.query_params['date'])
        return Response({
            'reimbursements': ReimbursementRequestSerializer(requests[:200], many=True).data,
        })


class AdminSalaryRecordsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        records = SalaryRecord.objects.select_related('employee')
        if request.query_params.get('employee_id'):
            records = records.filter(employee_id=request.query_params['employee_id'])
        if request.query_params.get('year'):
            records = records.filter(year=request.query_params['year'])
        if request.query_params.get('month'):
            records = records.filter(month=request.query_params['month'])
        return Response({
            'salary_records': SalaryRecordSerializer(records[:200], many=True).data,
        })

    def post(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied

        User = get_user_model()
        employee = get_object_or_404(
            User,
            pk=request.data.get('employee_id'),
            is_superuser=False,
        )
        try:
            year = int(request.data.get('year'))
            month = int(request.data.get('month'))
        except (TypeError, ValueError):
            return Response(
                {'detail': 'Select a valid salary month and year.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if month < 1 or month > 12:
            return Response(
                {'detail': 'Select a valid salary month.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        decimal_fields = [
            'basic_salary',
            'allowances',
            'deductions',
            'bonus',
            'incentives',
            'tax_deducted',
        ]
        values = {}
        for field in decimal_fields:
            raw_value = request.data.get(field, 0) or 0
            try:
                values[field] = Decimal(str(raw_value))
            except Exception:
                return Response(
                    {'detail': f'{field.replace("_", " ").title()} must be a valid amount.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if values[field] < 0:
                return Response(
                    {'detail': f'{field.replace("_", " ").title()} cannot be negative.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        record, _ = SalaryRecord.objects.update_or_create(
            employee=employee,
            year=year,
            month=month,
            defaults={
                **values,
                'is_published': bool(request.data.get('is_published', True)),
            },
        )
        return Response(
            {'salary_record': SalaryRecordSerializer(record).data},
            status=status.HTTP_201_CREATED,
        )


class AdminLeaveStatusApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, leave_id):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        new_status = request.data.get('status')
        if new_status not in {
            LeaveRequest.STATUS_APPROVED,
            LeaveRequest.STATUS_REJECTED,
            LeaveRequest.STATUS_PENDING,
        }:
            return Response({'detail': 'Invalid leave status.'}, status=status.HTTP_400_BAD_REQUEST)
        leave = get_object_or_404(LeaveRequest, pk=leave_id)
        leave.status = new_status
        leave.save(update_fields=['status'])
        return Response({'detail': f'Leave request marked as {leave.get_status_display()}.'})


class AdminRegularizationStatusApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, regularization_id):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        new_status = request.data.get('status')
        if new_status not in {
            AttendanceRegularization.STATUS_APPROVED,
            AttendanceRegularization.STATUS_REJECTED,
            AttendanceRegularization.STATUS_PENDING,
        }:
            return Response({'detail': 'Invalid regularization status.'}, status=status.HTTP_400_BAD_REQUEST)
        regularization = get_object_or_404(AttendanceRegularization, pk=regularization_id)
        regularization.status = new_status
        regularization.save(update_fields=['status'])
        return Response({'detail': f'Regularization marked as {regularization.get_status_display()}.'})


class AdminHelpdeskStatusApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, ticket_id):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        new_status = request.data.get('status')
        if new_status not in {
            HelpdeskTicket.STATUS_OPEN,
            HelpdeskTicket.STATUS_IN_PROGRESS,
            HelpdeskTicket.STATUS_RESOLVED,
            HelpdeskTicket.STATUS_CLOSED,
        }:
            return Response({'detail': 'Invalid helpdesk status.'}, status=status.HTTP_400_BAD_REQUEST)
        ticket = get_object_or_404(HelpdeskTicket, pk=ticket_id)
        ticket.status = new_status
        update_fields = ['status']
        if new_status in {HelpdeskTicket.STATUS_RESOLVED, HelpdeskTicket.STATUS_CLOSED}:
            ticket.resolved_at = timezone.now()
            update_fields.append('resolved_at')
        ticket.save(update_fields=update_fields)
        return Response({'detail': f'Helpdesk ticket marked as {ticket.get_status_display()}.'})


class AdminEmployeesApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        employees = admin_managed_users().order_by('username')
        return Response({'employees': [serialize_user(employee) | {'total_checkins': Attendance.objects.filter(user=employee, event_type=Attendance.CHECK_IN).count()} for employee in employees]})

    def post(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied

        first_name = (request.data.get('first_name') or '').strip()
        last_name = (request.data.get('last_name') or '').strip()
        name = (request.data.get('name') or '').strip()
        email = (request.data.get('email') or '').strip()
        mobile_number = normalize_mobile_number(request.data.get('mobile_number'))
        profile_photo_biometric = (
            request.data.get('profile_photo_biometric') or ''
        ).strip()
        username = (request.data.get('username') or '').strip()
        password = request.data.get('password') or ''
        date_of_birth_raw = (request.data.get('date_of_birth') or '').strip()
        department = (request.data.get('department') or '').strip()
        designation = (request.data.get('designation') or '').strip()
        can_access_user_dashboard = request.data.get('can_access_user_dashboard', True)
        can_access_admin_dashboard = request.data.get('can_access_admin_dashboard', False)
        can_access_hr_dashboard = request.data.get('can_access_hr_dashboard', False)
        location_name = (request.data.get('location_name') or 'Work Location').strip()
        location_address = (request.data.get('location_address') or '').strip()
        location_coordinate_pair = (
            request.data.get('location_latitude_longitude')
            or request.data.get('latitude_longitude')
            or ''
        ).strip()
        location_latitude = request.data.get('location_latitude')
        location_longitude = request.data.get('location_longitude')
        location_radius_meters = request.data.get('location_radius_meters') or 100
        if location_coordinate_pair:
            coordinates = parse_coordinate_pair(location_coordinate_pair)
            if coordinates is None:
                return Response(
                    {
                        'detail': (
                            'Latitude/Longitude must use latitude,longitude format '
                            'with latitude between -90 and 90 and longitude between -180 and 180.'
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            location_latitude, location_longitude = coordinates

        if name and (not first_name or not last_name):
            name_first, _, name_last = name.partition(' ')
            first_name = first_name or name_first
            last_name = last_name or name_last
        if not first_name or not email or not username or not password:
            return Response(
                {'detail': 'Display name, email, username, and password are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        _, profile_photo_error = validate_verification_attachment(
            profile_photo_biometric,
            'Employee verification file',
        )
        if profile_photo_error:
            return Response(
                {'detail': profile_photo_error},
                status=status.HTTP_400_BAD_REQUEST,
            )
        date_of_birth = parse_date(date_of_birth_raw) if date_of_birth_raw else None
        if date_of_birth_raw and date_of_birth is None:
            return Response(
                {'detail': 'Date of birth must be in YYYY-MM-DD format.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not any([
            can_access_user_dashboard,
            can_access_admin_dashboard,
            can_access_hr_dashboard,
        ]):
            return Response(
                {'detail': 'Select at least one dashboard permission.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        password_error = password_rule_error(password)
        if password_error:
            return Response(
                {'detail': password_error},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if any([location_address, location_latitude, location_longitude]) and not all(
            [location_address, location_latitude, location_longitude]
        ):
            return Response(
                {
                    'detail': (
                        'Location address, latitude, and longitude are required '
                        'when assigning an attendance location.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        User = get_user_model()
        if User.objects.filter(username__iexact=username).exists():
            return Response(
                {'detail': 'Username already exists.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if User.objects.filter(email__iexact=email).exists():
            return Response(
                {'detail': 'Email already exists.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        employee = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
            is_staff=bool(can_access_admin_dashboard),
            is_active=True,
        )
        UserProfile.objects.update_or_create(
            user=employee,
            defaults={
                'employee_code': username.upper(),
                'mobile_number': mobile_number,
                'profile_photo_biometric': profile_photo_biometric,
                'date_of_birth': date_of_birth,
                'department': department,
                'designation': designation or 'Employee',
                'can_access_user_dashboard': bool(can_access_user_dashboard),
                'can_access_admin_dashboard': bool(can_access_admin_dashboard),
                'can_access_hr_dashboard': bool(can_access_hr_dashboard),
            },
        )
        employee.refresh_from_db()
        if location_address and location_latitude and location_longitude:
            location_serializer = AssignedLocationSerializer(
                data={
                    'name': location_name,
                    'address': location_address,
                    'map_url': f'https://www.google.com/maps/search/?api=1&query={parse.quote_plus(location_address)}',
                    'latitude': location_latitude,
                    'longitude': location_longitude,
                    'coordinates_resolved': True,
                    'radius_meters': location_radius_meters,
                    'is_active': True,
                }
            )
            if location_serializer.is_valid():
                location_serializer.save(user=employee)
            else:
                employee.delete()
                return Response(location_serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        return Response(
            {'employee': serialize_user(employee) | {'total_checkins': 0}},
            status=status.HTTP_201_CREATED,
        )


class AdminEmployeeDetailApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def delete(self, request, employee_id):
        if not user_can_manage_people(request.user):
            raise PermissionDenied

        employee = get_object_or_404(admin_managed_users(), pk=employee_id)
        if employee.pk == request.user.pk:
            return Response(
                {'detail': 'You cannot delete your own employee account.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        employee.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    def patch(self, request, employee_id):
        if not user_can_manage_people(request.user):
            raise PermissionDenied

        employee = get_object_or_404(admin_managed_users(), pk=employee_id)
        data = request.data
        first_name = (data.get('first_name') or '').strip()
        last_name = (data.get('last_name') or '').strip()
        name = (data.get('name') or '').strip()
        email = (data.get('email') or '').strip()
        mobile_number = normalize_mobile_number(data.get('mobile_number'))
        profile_photo_biometric = (
            data.get('profile_photo_biometric') or ''
        ).strip()
        username = (data.get('username') or '').strip()
        date_of_birth_raw = (data.get('date_of_birth') or '').strip()
        department = (data.get('department') or '').strip()
        designation = (data.get('designation') or '').strip()
        can_access_user_dashboard = data.get('can_access_user_dashboard', True)
        can_access_admin_dashboard = data.get('can_access_admin_dashboard', False)
        can_access_hr_dashboard = data.get('can_access_hr_dashboard', False)
        password = data.get('password') or ''
        is_active = data.get('is_active')

        if name and (not first_name or not last_name):
            name_first, _, name_last = name.partition(' ')
            first_name = first_name or name_first
            last_name = last_name or name_last
        if not first_name or not email or not username:
            return Response(
                {'detail': 'Display name, email, and username are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        date_of_birth = parse_date(date_of_birth_raw) if date_of_birth_raw else None
        if date_of_birth_raw and date_of_birth is None:
            return Response(
                {'detail': 'Date of birth must be in YYYY-MM-DD format.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not any([
            can_access_user_dashboard,
            can_access_admin_dashboard,
            can_access_hr_dashboard,
        ]):
            return Response(
                {'detail': 'Select at least one dashboard permission.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        User = get_user_model()
        if User.objects.filter(username__iexact=username).exclude(pk=employee.pk).exists():
            return Response({'detail': 'Username already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        if User.objects.filter(email__iexact=email).exclude(pk=employee.pk).exists():
            return Response({'detail': 'Email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        password_error = password_rule_error(password) if password else ''
        if password_error:
            return Response(
                {'detail': password_error},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if profile_photo_biometric:
            _, profile_photo_error = validate_verification_attachment(
                profile_photo_biometric,
                'Employee verification file',
            )
            if profile_photo_error:
                return Response(
                    {'detail': profile_photo_error},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        employee.username = username
        employee.email = email
        employee.first_name = first_name
        employee.last_name = last_name
        employee.is_staff = bool(can_access_admin_dashboard)
        if isinstance(is_active, bool):
            employee.is_active = is_active
        if password:
            employee.set_password(password)
        employee.save()
        profile_defaults = {
            'employee_code': username.upper(),
            'mobile_number': mobile_number,
            'date_of_birth': date_of_birth,
            'department': department,
            'designation': designation or 'Employee',
            'can_access_user_dashboard': bool(can_access_user_dashboard),
            'can_access_admin_dashboard': bool(can_access_admin_dashboard),
            'can_access_hr_dashboard': bool(can_access_hr_dashboard),
        }
        if profile_photo_biometric:
            profile_defaults['profile_photo_biometric'] = profile_photo_biometric
        UserProfile.objects.update_or_create(
            user=employee,
            defaults=profile_defaults,
        )
        employee.refresh_from_db()
        return Response({
            'employee': serialize_user(employee) | {
                'total_checkins': Attendance.objects.filter(
                    user=employee,
                    event_type=Attendance.CHECK_IN,
                ).count()
            }
        })


class AdminEmployeeLocationApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def put(self, request, employee_id):
        return self.save_location(request, employee_id)

    def patch(self, request, employee_id):
        return self.save_location(request, employee_id, partial=True)

    def save_location(self, request, employee_id, partial=False):
        if not user_can_manage_people(request.user):
            raise PermissionDenied

        employee = get_object_or_404(admin_managed_users(), pk=employee_id)
        assigned_location = getattr(employee, 'assigned_location', None)
        data = request.data.copy()
        address = (data.get('address') or '').strip()
        map_url = (data.get('map_url') or '').strip()
        extra_location_text = (data.get('extra_location_text') or '').strip()
        coordinate_pair = (
            data.get('latitude_longitude')
            or data.get('location_latitude_longitude')
            or ''
        ).strip()
        effective_from = parse_date(data.get('effective_from') or '') if data.get('effective_from') else None
        effective_to = parse_date(data.get('effective_to') or '') if data.get('effective_to') else None
        if data.get('effective_from') and effective_from is None:
            return Response(
                {'detail': 'Location start date must be in YYYY-MM-DD format.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if data.get('effective_to') and effective_to is None:
            return Response(
                {'detail': 'Location end date must be in YYYY-MM-DD format.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if effective_from and effective_to and effective_to < effective_from:
            return Response(
                {'detail': 'Location end date cannot be before start date.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if map_url and not looks_like_url(map_url):
            extra_location_text = f'{extra_location_text} {map_url}'.strip()
            map_url = ''
            data['map_url'] = ''
        lookup_text = ' '.join(
            part for part in [address, extra_location_text] if part
        ).strip()
        coordinates = parse_coordinate_pair(coordinate_pair) if coordinate_pair else None
        if coordinate_pair and coordinates is None:
            return Response(
                {
                    'detail': (
                        'Latitude/Longitude must use latitude,longitude format '
                        'with latitude between -90 and 90 and longitude between -180 and 180.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        if coordinates is None and map_url:
            coordinates = extract_coordinates_from_map_url(map_url)
        if coordinates is None and lookup_text:
            coordinates = extract_coordinates_from_map_url(lookup_text)
        if coordinates is None and lookup_text:
            coordinates = geocode_location_text(lookup_text)
        if coordinates is None:
            return Response(
                {
                    'detail': (
                        'Select a valid office map pin or enter latitude,longitude '
                        'before saving the employee location.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        if coordinates_are_zero(coordinates[0], coordinates[1]):
            return Response(
                {
                    'detail': (
                        'Office location coordinates cannot be 0,0. Select the '
                        'actual office map pin before saving.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        if coordinates:
            data['latitude'] = coordinates[0]
            data['longitude'] = coordinates[1]
            data['coordinates_resolved'] = True
        elif assigned_location is None:
            data['latitude'] = 0
            data['longitude'] = 0
            data['coordinates_resolved'] = False

        serializer = AssignedLocationSerializer(
            assigned_location,
            data=data,
            partial=partial,
        )
        if serializer.is_valid():
            save_kwargs = {'user': employee}
            if coordinates:
                save_kwargs['latitude'] = coordinates[0]
                save_kwargs['longitude'] = coordinates[1]
                save_kwargs['coordinates_resolved'] = True
            location = serializer.save(**save_kwargs)
            return Response({
                'employee': serialize_user(employee) | {
                    'total_checkins': Attendance.objects.filter(
                        user=employee,
                        event_type=Attendance.CHECK_IN,
                    ).count()
                },
                'assigned_location': AssignedLocationSerializer(location).data,
            })
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminAttendanceApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        User = get_user_model()
        employees = User.objects.filter(is_superuser=False)
        employee_id = request.query_params.get('employee_id')
        if employee_id:
            employees = employees.filter(id=employee_id)

        year = request.query_params.get('year')
        month = request.query_params.get('month')
        selected_date = request.query_params.get('date')
        if year and month:
            period_start = datetime(int(year), int(month), 1).date()
            if int(month) == 12:
                period_end = datetime(int(year) + 1, 1, 1).date() - timedelta(days=1)
            else:
                period_end = datetime(int(year), int(month) + 1, 1).date() - timedelta(days=1)
            records = Attendance.objects.filter(
                timestamp__date__gte=period_start,
                timestamp__date__lte=period_end,
            ).select_related('user')
            if employee_id:
                records = records.filter(user_id=employee_id)
            rows = []
            report_end = min(period_end, timezone.localdate())
            if report_end < period_start:
                report_days = []
            else:
                report_days = [
                    period_start + timedelta(days=offset)
                    for offset in range((report_end - period_start).days + 1)
                ]
            for day in report_days:
                for employee in employees.order_by('username'):
                    user_records = records.filter(user=employee, timestamp__date=day)
                    check_in = user_records.filter(event_type=Attendance.CHECK_IN).order_by('timestamp').first()
                    check_out = user_records.filter(event_type=Attendance.CHECK_OUT).order_by('-timestamp').first()
                    rows.append(
                        serialize_attendance_admin_row(
                            employee,
                            day,
                            check_in,
                            check_out,
                        )
                    )
            present_count = len([row for row in rows if row['status'] == 'Present'])
            return Response({
                'summary': {
                    'total_employees': employees.count(),
                    'present': present_count,
                    'absent': max(len(rows) - present_count, 0),
                },
                'rows': rows,
            })

        today = (
            datetime.strptime(selected_date, '%Y-%m-%d').date()
            if selected_date
            else timezone.localdate()
        )
        today_records = Attendance.objects.filter(timestamp__date=today).select_related('user')
        if employee_id:
            today_records = today_records.filter(user_id=employee_id)
        rows = []
        for employee in employees.order_by('username'):
            user_records = today_records.filter(user=employee)
            check_in = user_records.filter(event_type=Attendance.CHECK_IN).order_by('timestamp').first()
            check_out = user_records.filter(event_type=Attendance.CHECK_OUT).order_by('-timestamp').first()
            row = serialize_attendance_admin_row(employee, today, check_in, check_out)
            rows.append(row)
        present_count = len([row for row in rows if row['status'] == 'Present'])
        return Response({
            'summary': {
                'total_employees': employees.count(),
                'present': present_count,
                'absent': max(employees.count() - present_count, 0),
            },
            'rows': rows,
        })


class AdminTasksApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        tasks = EmployeeTask.objects.select_related('employee')
        status_filter = request.query_params.get('status')
        year = request.query_params.get('year')
        month = request.query_params.get('month')
        date = request.query_params.get('date')
        if status_filter and status_filter != 'all':
            tasks = tasks.filter(status=status_filter)
        if date:
            tasks = tasks.filter(created_at__date=date)
        elif year and month:
            tasks = tasks.filter(created_at__year=year, created_at__month=month)
        elif year:
            tasks = tasks.filter(created_at__year=year)
        summary = {
            'assigned': tasks.filter(status=EmployeeTask.STATUS_ASSIGNED).count(),
            'in_progress': tasks.filter(status=EmployeeTask.STATUS_IN_PROGRESS).count(),
            'completed': tasks.filter(status=EmployeeTask.STATUS_COMPLETED).count(),
        }
        return Response({
            'summary': summary,
            'tasks': [
                {
                    **EmployeeTaskSerializer(task).data,
                    'employee_id': task.employee_id,
                    'employee': task.employee.get_full_name() or task.employee.username,
                    'username': task.employee.username,
                }
                for task in tasks.order_by('-created_at')[:200]
            ],
        })


class AdminAttendanceSettingsApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        return Response(attendance_settings_payload())

    def patch(self, request):
        if not user_can_manage_people(request.user):
            raise PermissionDenied
        settings_obj = AttendanceSettings.current()
        setting_key = (
            'face_recognition_enabled'
            if 'face_recognition_enabled' in request.data
            else 'require_face_verification'
            if 'require_face_verification' in request.data
            else None
        )
        if setting_key is None:
            return Response(
                {'detail': 'require_face_verification is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        settings_obj.face_recognition_enabled = request_bool(
            request.data.get(setting_key)
        )
        settings_obj.save(update_fields=['face_recognition_enabled', 'updated_at'])
        return Response(attendance_settings_payload())


class PasswordResetRequestView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        email = normalize_email_address(request.data.get('email'))
        if not email:
            return Response(
                {'detail': 'Please enter registered email address.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            validate_email(email)
        except ValidationError:
            return Response(
                {'detail': 'Please enter a valid email address.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = find_user_by_email(email)
        if user is None:
            return Response({
                'detail': 'If an active HealOn account exists for this email, an OTP has been sent.',
                'otp_provider': 'email',
                'expires_in_minutes': getattr(settings, 'EMAIL_OTP_EXPIRY_MINUTES', 10),
            })

        otp = get_random_string(6, allowed_chars='0123456789')
        expires_at = otp_expiry_time()

        PasswordResetOTP.objects.filter(
            user=user,
            mobile_number=email,
            used_at__isnull=True,
        ).update(used_at=timezone.now())

        PasswordResetOTP.objects.create(
            user=user,
            mobile_number=email,
            otp_hash=hash_password_reset_otp(otp),
            expires_at=expires_at,
        )
        try:
            send_password_reset_otp_email(user, otp, expires_at)
        except SMTPException as exc:
            PasswordResetOTP.objects.filter(
                user=user,
                mobile_number=email,
                used_at__isnull=True,
            ).update(used_at=timezone.now())
            return Response(
                {
                    'detail': (
                        'Unable to send OTP email. Configure Gmail SMTP with '
                        'EMAIL_HOST_USER and EMAIL_HOST_PASSWORD App Password.'
                    ),
                    'error': str(exc),
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response({
            'detail': 'If an active HealOn account exists for this email, an OTP has been sent.',
            'otp_provider': 'email',
            'expires_in_minutes': getattr(settings, 'EMAIL_OTP_EXPIRY_MINUTES', 10),
        })


class PasswordResetVerifyView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        email = normalize_email_address(request.data.get('email'))
        otp = (request.data.get('otp') or '').strip()
        if not email or not otp:
            return Response(
                {'detail': 'Please enter email and OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reset_otp = latest_email_reset_request(email)
        if reset_otp is None:
            return Response(
                {'detail': 'Please request a new OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if reset_otp.expires_at <= timezone.now():
            return Response(
                {'detail': 'OTP has expired. Please request a new OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if reset_otp.attempts >= 5:
            return Response(
                {'detail': 'Too many OTP attempts. Please request a new OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reset_otp.attempts += 1
        if not constant_time_compare(reset_otp.otp_hash, hash_password_reset_otp(otp)):
            reset_otp.save(update_fields=['attempts'])
            return Response(
                {'detail': 'Invalid OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        reset_otp.verified_at = timezone.now()
        reset_otp.save(update_fields=['attempts', 'verified_at'])
        return Response({'detail': 'OTP verified. Enter new password.'})


class PasswordResetConfirmView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        email = normalize_email_address(request.data.get('email'))
        new_password = request.data.get('new_password') or ''

        password_error = password_rule_error(new_password)
        if password_error:
            return Response(
                {'detail': password_error},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reset_otp = latest_email_reset_request(email)
        if reset_otp is None:
            return Response(
                {'detail': 'Please request a new OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if reset_otp.expires_at <= timezone.now():
            return Response(
                {'detail': 'OTP has expired. Please request a new OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if reset_otp.verified_at is None:
            return Response(
                {'detail': 'Please verify OTP before resetting password.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reset_otp.user.set_password(new_password)
        reset_otp.user.save(update_fields=['password'])
        reset_otp.used_at = timezone.now()
        reset_otp.save(update_fields=['used_at'])
        return Response({'detail': 'Password reset successfully. Please login.'})
