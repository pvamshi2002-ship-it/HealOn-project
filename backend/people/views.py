from datetime import datetime, timedelta
from decimal import Decimal
import base64
import hashlib
import json
from math import atan2, cos, radians, sin, sqrt
import secrets
from urllib import parse, request as urlrequest
from urllib.error import HTTPError, URLError

from django.conf import settings
from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.admin.views.decorators import staff_member_required
from django.core.exceptions import PermissionDenied
from django.http import HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.utils.dateparse import parse_date
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
    AttendanceRegularization,
    EmployeeTask,
    HelpdeskTicket,
    Holiday,
    LeaveRequest,
    PasswordResetOTP,
    SalaryRecord,
    UserProfile,
)
from .location_utils import extract_coordinates_from_map_url, geocode_location_text
from .serializers import (
    AssignedLocationSerializer,
    AttendanceRegularizationSerializer,
    AttendanceSerializer,
    EmployeeTaskSerializer,
    HelpdeskTicketSerializer,
    HolidaySerializer,
    LeaveRequestSerializer,
    SalaryRecordSerializer,
)


EARTH_RADIUS_METERS = 6371000


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


def admin_managed_users():
    return get_user_model().objects.filter(is_superuser=False)


def map_url_for_attendance(attendance):
    if attendance is None:
        return ''
    return f'https://www.google.com/maps?q={attendance.latitude},{attendance.longitude}'


def serialize_attendance_admin_row(employee, day, check_in, check_out):
    assigned_location = getattr(employee, 'assigned_location', None)
    return {
        'date': day.isoformat(),
        'employee_id': employee.id,
        'employee': employee.get_full_name() or employee.username,
        'username': employee.username,
        'check_in': timezone.localtime(check_in.timestamp).strftime('%I:%M %p') if check_in else '-',
        'check_out': timezone.localtime(check_out.timestamp).strftime('%I:%M %p') if check_out else '-',
        'status': 'Present' if check_in else 'Absent',
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


def distance_between_meters(lat1, lon1, lat2, lon2):
    return haversine_distance_meters(lat1, lon1, lat2, lon2)


def ensure_assigned_location_coordinates(assigned_location):
    coordinates = None
    if assigned_location.map_url:
        coordinates = extract_coordinates_from_map_url(assigned_location.map_url)

    if coordinates is None and assigned_location.coordinates_resolved:
        return True

    if coordinates is None:
        coordinates = extract_coordinates_from_map_url(assigned_location.address)
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
    present_days = month_records.filter(event_type=Attendance.CHECK_IN).dates('timestamp', 'day').count()

    return {
        'checked_in_today': check_in is not None,
        'checked_out_today': check_out is not None,
        'today_check_in': timezone.localtime(check_in.timestamp).strftime('%H:%M') if check_in else None,
        'today_check_out': timezone.localtime(check_out.timestamp).strftime('%H:%M') if check_out else None,
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


def twilio_mobile_number(mobile_number):
    if mobile_number.startswith('+'):
        return mobile_number
    if len(mobile_number) == 10:
        return f'+91{mobile_number}'
    if len(mobile_number) == 12 and mobile_number.startswith('91'):
        return f'+{mobile_number}'
    return mobile_number


def hash_reset_otp(mobile_number, otp):
    payload = f'{settings.SECRET_KEY}:{mobile_number}:{otp}'
    return hashlib.sha256(payload.encode('utf-8')).hexdigest()


def find_profile_by_mobile_number(mobile_number):
    candidates = {mobile_number, twilio_mobile_number(mobile_number)}
    if mobile_number.startswith('+91'):
        candidates.add(mobile_number[3:])
        candidates.add(mobile_number[1:])
    elif mobile_number.startswith('91') and len(mobile_number) == 12:
        candidates.add(mobile_number[2:])
    for profile in UserProfile.objects.select_related('user').filter(user__is_active=True):
        saved_mobile = normalize_mobile_number(profile.mobile_number)
        saved_candidates = {saved_mobile, twilio_mobile_number(saved_mobile)}
        if saved_mobile.startswith('+91'):
            saved_candidates.add(saved_mobile[3:])
            saved_candidates.add(saved_mobile[1:])
        elif saved_mobile.startswith('91') and len(saved_mobile) == 12:
            saved_candidates.add(saved_mobile[2:])
        if candidates.intersection(saved_candidates):
            return profile
    return None


def latest_reset_otp(mobile_number, otp):
    return (
        PasswordResetOTP.objects.select_related('user')
        .filter(
            mobile_number=mobile_number,
            otp_hash=hash_reset_otp(mobile_number, otp),
            used_at__isnull=True,
        )
        .order_by('-created_at')
        .first()
    )


def latest_twilio_reset_otp(mobile_number):
    return (
        PasswordResetOTP.objects.select_related('user')
        .filter(
            mobile_number=mobile_number,
            otp_hash='twilio-verify',
            used_at__isnull=True,
        )
        .order_by('-created_at')
        .first()
    )


def twilio_verify_enabled():
    return (
        settings.SMS_PROVIDER == 'twilio'
        and settings.TWILIO_ACCOUNT_SID
        and settings.TWILIO_AUTH_TOKEN
        and settings.TWILIO_VERIFY_SERVICE_SID
    )


def post_twilio_form(url, data):
    req = urlrequest.Request(url, data=parse.urlencode(data).encode('utf-8'))
    credentials = f'{settings.TWILIO_ACCOUNT_SID}:{settings.TWILIO_AUTH_TOKEN}'.encode('utf-8')
    req.add_header('Authorization', f'Basic {base64.b64encode(credentials).decode("ascii")}')
    try:
        with urlrequest.urlopen(req, timeout=10) as resp:
            body = resp.read().decode('utf-8') or '{}'
            parsed = json.loads(body)
            return 200 <= resp.status < 300, parsed, None
    except HTTPError as exc:
        body = exc.read().decode('utf-8') or '{}'
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {}
        message = parsed.get('message') or f'HTTP Error {exc.code}: {exc.reason}'
        if exc.code == 401:
            message = (
                'Twilio authorization failed. Check TWILIO_ACCOUNT_SID, '
                'TWILIO_AUTH_TOKEN, and TWILIO_VERIFY_SERVICE_SID.'
            )
        return False, parsed, message
    except (URLError, json.JSONDecodeError) as exc:
        return False, {}, str(exc)


def send_twilio_verify_otp(mobile_number):
    url = (
        'https://verify.twilio.com/v2/Services/'
        f'{settings.TWILIO_VERIFY_SERVICE_SID}/Verifications'
    )
    ok, body, error = post_twilio_form(url, {'To': mobile_number, 'Channel': 'sms'})
    if not ok:
        return False, error or body.get('message') or 'Twilio Verify request failed.'
    if body.get('status') not in {'pending', 'approved'}:
        return False, body.get('message') or 'Twilio Verify did not start.'
    return True, None


def check_twilio_verify_otp(mobile_number, otp):
    url = (
        'https://verify.twilio.com/v2/Services/'
        f'{settings.TWILIO_VERIFY_SERVICE_SID}/VerificationCheck'
    )
    ok, body, error = post_twilio_form(url, {'To': mobile_number, 'Code': otp})
    if not ok:
        return False, error or body.get('message') or 'Twilio Verify check failed.'
    return body.get('status') == 'approved', body.get('message')


def send_password_reset_sms(mobile_number, otp):
    message = f'HealOn password reset OTP is {otp}. It is valid for 10 minutes.'
    if (
        settings.SMS_PROVIDER == 'twilio'
        and settings.TWILIO_ACCOUNT_SID
        and settings.TWILIO_AUTH_TOKEN
        and settings.TWILIO_FROM_NUMBER
    ):
        data = parse.urlencode({
            'To': mobile_number,
            'From': settings.TWILIO_FROM_NUMBER,
            'Body': message,
        }).encode('utf-8')
        url = f'https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Messages.json'
        req = urlrequest.Request(url, data=data)
        credentials = f'{settings.TWILIO_ACCOUNT_SID}:{settings.TWILIO_AUTH_TOKEN}'.encode('utf-8')
        req.add_header('Authorization', f'Basic {base64.b64encode(credentials).decode("ascii")}')
        try:
            with urlrequest.urlopen(req, timeout=10) as resp:
                return 200 <= resp.status < 300, None
        except URLError as exc:
            return False, str(exc)

    print(f'SMS to {mobile_number}: {message}')
    return True, None


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
        return Response({
            'user': serialize_user(request.user),
            'attendance': attendance_dashboard(request.user),
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
            'open_tickets': open_tickets,
            'published_payslips': SalaryRecord.objects.filter(is_published=True).count(),
            'tasks_in_progress': EmployeeTask.objects.filter(status=EmployeeTask.STATUS_IN_PROGRESS).count(),
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
        serializer = AttendanceSerializer(data=request.data.copy())
        if serializer.is_valid():
            assigned_location = getattr(request.user, 'assigned_location', None)
            if assigned_location is None or not assigned_location.is_active:
                return Response(
                    {
                        'detail': (
                            'No active assigned attendance location is configured for this user. '
                            'Please contact admin.'
                        )
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
            distance_meters = distance_between_meters(
                latitude,
                longitude,
                assigned_location.latitude,
                assigned_location.longitude,
            )
            if distance_meters > assigned_location.radius_meters:
                return Response(
                    {
                        'detail': (
                            'You are outside the assigned attendance location '
                            f'({distance_meters:.1f}m away; allowed radius is '
                            f'{assigned_location.radius_meters}m).'
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
            return Response(serializer.data, status=status.HTTP_201_CREATED)
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
            hours = None
            status_label = 'Incomplete'
            if check_in and check_out and check_out.timestamp >= check_in.timestamp:
                hours = round((check_out.timestamp - check_in.timestamp).total_seconds() / 3600, 2)
                total_hours += hours
                status_label = 'Present'
            elif check_out:
                status_label = 'Missing check-in'
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
                'present_days': len([day for day in days if day['check_in'] is not None]),
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
        if not user_can_access_dashboard(request.user, 'Admin'):
            raise PermissionDenied
        User = get_user_model()
        employees = User.objects.filter(is_superuser=False)
        today = timezone.localdate()
        today_records = Attendance.objects.filter(timestamp__date=today)
        present_today = today_records.filter(event_type=Attendance.CHECK_IN).values('user').distinct().count()
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
            },
            'timestamp': timezone.now().isoformat(),
        })


class AdminDashboardStatsView(AdminDashboardView):
    pass


class AdminLeaveStatusApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, leave_id):
        if not user_can_access_dashboard(request.user, 'Admin'):
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
        if not user_can_access_dashboard(request.user, 'Admin'):
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
        if not user_can_access_dashboard(request.user, 'Admin'):
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
        if not user_can_access_dashboard(request.user, 'Admin'):
            raise PermissionDenied
        employees = admin_managed_users().order_by('username')
        return Response({'employees': [serialize_user(employee) | {'total_checkins': Attendance.objects.filter(user=employee, event_type=Attendance.CHECK_IN).count()} for employee in employees]})

    def post(self, request):
        if not user_can_access_dashboard(request.user, 'Admin'):
            raise PermissionDenied

        first_name = (request.data.get('first_name') or '').strip()
        last_name = (request.data.get('last_name') or '').strip()
        name = (request.data.get('name') or '').strip()
        email = (request.data.get('email') or '').strip()
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
        location_latitude = request.data.get('location_latitude')
        location_longitude = request.data.get('location_longitude')
        location_radius_meters = request.data.get('location_radius_meters') or 100

        if not first_name and name:
            first_name, _, last_name = name.partition(' ')
        if not first_name or not last_name or not email or not username or not password:
            return Response(
                {'detail': 'First name, last name, email, username, and password are required.'},
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
        if len(password) < 6:
            return Response(
                {'detail': 'Password must be at least 6 characters.'},
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

    def patch(self, request, employee_id):
        if not user_can_access_dashboard(request.user, 'Admin'):
            raise PermissionDenied

        employee = get_object_or_404(admin_managed_users(), pk=employee_id)
        data = request.data
        first_name = (data.get('first_name') or '').strip()
        last_name = (data.get('last_name') or '').strip()
        name = (data.get('name') or '').strip()
        email = (data.get('email') or '').strip()
        username = (data.get('username') or '').strip()
        date_of_birth_raw = (data.get('date_of_birth') or '').strip()
        department = (data.get('department') or '').strip()
        designation = (data.get('designation') or '').strip()
        can_access_user_dashboard = data.get('can_access_user_dashboard', True)
        can_access_admin_dashboard = data.get('can_access_admin_dashboard', False)
        can_access_hr_dashboard = data.get('can_access_hr_dashboard', False)
        password = data.get('password') or ''
        is_active = data.get('is_active')

        if not first_name and name:
            first_name, _, last_name = name.partition(' ')
        if not first_name or not last_name or not email or not username:
            return Response(
                {'detail': 'First name, last name, email, and username are required.'},
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
        if password and len(password) < 6:
            return Response(
                {'detail': 'Password must be at least 6 characters.'},
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
        UserProfile.objects.update_or_create(
            user=employee,
            defaults={
                'employee_code': username.upper(),
                'date_of_birth': date_of_birth,
                'department': department,
                'designation': designation or 'Employee',
                'can_access_user_dashboard': bool(can_access_user_dashboard),
                'can_access_admin_dashboard': bool(can_access_admin_dashboard),
                'can_access_hr_dashboard': bool(can_access_hr_dashboard),
            },
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
        if not user_can_access_dashboard(request.user, 'Admin'):
            raise PermissionDenied

        employee = get_object_or_404(admin_managed_users(), pk=employee_id)
        assigned_location = getattr(employee, 'assigned_location', None)
        data = request.data.copy()
        address = (data.get('address') or '').strip()
        map_url = (data.get('map_url') or '').strip()
        coordinates = None
        if map_url:
            coordinates = extract_coordinates_from_map_url(map_url)
        if coordinates is None and address:
            coordinates = extract_coordinates_from_map_url(address)
        if coordinates is None and address:
            coordinates = geocode_location_text(address)
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
        if not user_can_access_dashboard(request.user, 'Admin'):
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
            present_user_ids = set(records.filter(event_type=Attendance.CHECK_IN).values_list('user_id', flat=True))
            return Response({
                'summary': {
                    'total_employees': employees.count(),
                    'present': len(present_user_ids),
                    'absent': max(employees.count() - len(present_user_ids), 0),
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
        present_user_ids = set(today_records.filter(event_type=Attendance.CHECK_IN).values_list('user_id', flat=True))
        rows = []
        for employee in employees.order_by('username'):
            user_records = today_records.filter(user=employee)
            check_in = user_records.filter(event_type=Attendance.CHECK_IN).order_by('timestamp').first()
            check_out = user_records.filter(event_type=Attendance.CHECK_OUT).order_by('-timestamp').first()
            row = serialize_attendance_admin_row(employee, today, check_in, check_out)
            row['status'] = 'Present' if employee.id in present_user_ids else 'Absent'
            rows.append(row)
        return Response({
            'summary': {
                'total_employees': employees.count(),
                'present': len(present_user_ids),
                'absent': max(employees.count() - len(present_user_ids), 0),
            },
            'rows': rows,
        })


class AdminTasksApiView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not user_can_access_dashboard(request.user, 'Admin'):
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


class PasswordResetRequestView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        mobile_number = normalize_mobile_number(request.data.get('mobile_number'))
        if not mobile_number:
            return Response(
                {'detail': 'Please enter mobile number.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile = find_profile_by_mobile_number(mobile_number)
        if profile is None:
            return Response(
                {'detail': 'No active user found with this mobile number.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        sms_mobile_number = twilio_mobile_number(mobile_number)

        PasswordResetOTP.objects.filter(
            user=profile.user,
            mobile_number=mobile_number,
            used_at__isnull=True,
        ).update(used_at=timezone.now())

        if twilio_verify_enabled():
            sms_sent, sms_error = send_twilio_verify_otp(sms_mobile_number)
            if not sms_sent:
                return Response(
                    {'detail': f'Unable to send OTP notification: {sms_error}'},
                    status=status.HTTP_502_BAD_GATEWAY,
                )

            PasswordResetOTP.objects.create(
                user=profile.user,
                mobile_number=mobile_number,
                otp_hash='twilio-verify',
                expires_at=timezone.now() + timedelta(minutes=10),
            )
            return Response({
                'detail': 'HealOn password reset OTP sent to the registered mobile number.',
                'sms_provider': 'twilio_verify',
                'sms_delivered': True,
            })

        otp = f'{secrets.randbelow(1000000):06d}'
        PasswordResetOTP.objects.create(
            user=profile.user,
            mobile_number=mobile_number,
            otp_hash=hash_reset_otp(mobile_number, otp),
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        sms_sent, sms_error = send_password_reset_sms(mobile_number, otp)
        if not sms_sent:
            return Response(
                {'detail': f'Unable to send OTP notification: {sms_error}'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        data = {
            'detail': 'HealOn password reset OTP sent to the registered mobile number.',
            'sms_provider': settings.SMS_PROVIDER,
            'sms_delivered': settings.SMS_PROVIDER == 'twilio',
        }
        if settings.DEBUG or settings.SMS_PROVIDER == 'console':
            data['dev_otp'] = otp
        return Response(data)


class PasswordResetVerifyView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        mobile_number = normalize_mobile_number(request.data.get('mobile_number'))
        otp = (request.data.get('otp') or '').strip()
        if twilio_verify_enabled():
            reset_otp = latest_twilio_reset_otp(mobile_number)
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

            approved, error = check_twilio_verify_otp(mobile_number, otp)
            reset_otp.attempts += 1
            if not approved:
                reset_otp.save(update_fields=['attempts'])
                return Response(
                    {'detail': error or 'Invalid OTP.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            reset_otp.verified_at = timezone.now()
            reset_otp.save(update_fields=['attempts', 'verified_at'])
            return Response({'detail': 'OTP verified. Enter new password.'})

        reset_otp = latest_reset_otp(mobile_number, otp)
        if reset_otp is None:
            return Response(
                {'detail': 'Invalid OTP.'},
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
        reset_otp.verified_at = timezone.now()
        reset_otp.save(update_fields=['attempts', 'verified_at'])
        return Response({'detail': 'OTP verified. Enter new password.'})


class PasswordResetConfirmView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        mobile_number = normalize_mobile_number(request.data.get('mobile_number'))
        otp = (request.data.get('otp') or '').strip()
        new_password = request.data.get('new_password') or ''

        if len(new_password) < 6:
            return Response(
                {'detail': 'Password must be at least 6 characters.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reset_otp = latest_twilio_reset_otp(mobile_number) if twilio_verify_enabled() else latest_reset_otp(mobile_number, otp)
        if reset_otp is None:
            return Response(
                {'detail': 'Invalid OTP.'},
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
