import re
import json
from urllib.error import URLError
from urllib.parse import parse_qs, quote_plus, unquote, urlparse
from urllib.request import Request, urlopen

from django import forms
from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.auth.forms import UserCreationForm
from django.utils.html import format_html

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


User = get_user_model()


class HealOnUserCreationForm(UserCreationForm):
    first_name = forms.CharField(max_length=150)
    last_name = forms.CharField(max_length=150)
    email = forms.EmailField()
    date_of_birth = forms.DateField(required=False, widget=forms.DateInput(attrs={'type': 'date'}))
    department = forms.CharField(max_length=80, required=False)
    designation = forms.CharField(max_length=80, required=False)
    can_access_user_dashboard = forms.BooleanField(required=False, initial=True)
    can_access_admin_dashboard = forms.BooleanField(required=False)
    can_access_hr_dashboard = forms.BooleanField(required=False)

    class Meta(UserCreationForm.Meta):
        model = User
        fields = (
            'username',
            'first_name',
            'last_name',
            'email',
            'date_of_birth',
            'password1',
            'password2',
            'department',
            'designation',
            'can_access_user_dashboard',
            'can_access_admin_dashboard',
            'can_access_hr_dashboard',
        )

    def save(self, commit=True):
        user = super().save(commit=False)
        user.first_name = self.cleaned_data['first_name']
        user.last_name = self.cleaned_data['last_name']
        user.email = self.cleaned_data['email']
        user.is_staff = self.cleaned_data['can_access_admin_dashboard']
        if commit:
            user.save()
            UserProfile.objects.update_or_create(
                user=user,
                defaults={
                    'employee_code': user.username.upper(),
                    'date_of_birth': self.cleaned_data.get('date_of_birth'),
                    'department': self.cleaned_data.get('department') or '',
                    'designation': self.cleaned_data.get('designation') or 'Employee',
                    'can_access_user_dashboard': self.cleaned_data[
                        'can_access_user_dashboard'
                    ],
                    'can_access_admin_dashboard': self.cleaned_data[
                        'can_access_admin_dashboard'
                    ],
                    'can_access_hr_dashboard': self.cleaned_data[
                        'can_access_hr_dashboard'
                    ],
                },
            )
        return user


def extract_coordinates_from_map_url(value):
    text = (value or '').strip()
    if not text:
        return None

    decoded = unquote(resolve_map_url(text))
    patterns = [
        r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
        r'[?&](?:q|query|ll)=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
        r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
        r'^(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)$',
    ]
    for pattern in patterns:
        match = re.search(pattern, decoded)
        if match:
            return match.group(1), match.group(2)

    parsed = urlparse(decoded)
    query = parse_qs(parsed.query)
    for key in ('q', 'query', 'll'):
        raw = query.get(key, [''])[0]
        match = re.search(r'(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)', raw)
        if match:
            return match.group(1), match.group(2)

    return None


def geocode_location_text(value):
    text = (value or '').strip()
    if not text:
        return None

    for candidate in location_lookup_candidates(text):
        coordinates = geocode_single_location_text(candidate)
        if coordinates:
            return coordinates
    return None


def location_lookup_candidates(text):
    normalized = re.sub(r'\bRd\b', 'Road', text, flags=re.IGNORECASE)
    normalized = re.sub(
        r'Kammagondahalli',
        'Kammagondanahalli',
        normalized,
        flags=re.IGNORECASE,
    )
    candidates = []
    for candidate in (text, normalized):
        if candidate and candidate not in candidates:
            candidates.append(candidate)

    if re.fullmatch(r'\s*k\.?\s*g\.?\s*halli\s*', text, flags=re.IGNORECASE):
        candidates.extend([
            'Kammagondanahalli, Jalahalli West, Bengaluru, Karnataka 560015',
            'Jalahalli West, Bengaluru, Karnataka 560015',
        ])

    parts = [part.strip() for part in normalized.split(',') if part.strip()]
    for index in range(1, max(len(parts) - 1, 1)):
        candidate = ', '.join(parts[index:])
        if candidate and candidate not in candidates:
            candidates.append(candidate)

    return candidates


def geocode_single_location_text(text):
    url = f'https://nominatim.openstreetmap.org/search?q={quote_plus(text)}&format=json&limit=1'
    try:
        request = Request(
            url,
            headers={
                'User-Agent': 'HealOnAdminLocation/1.0',
                'Accept': 'application/json',
            },
        )
        with urlopen(request, timeout=8) as response:
            results = json.loads(response.read().decode('utf-8') or '[]')
    except (ValueError, URLError, json.JSONDecodeError):
        return None

    if not results:
        return None

    result = results[0]
    latitude = result.get('lat')
    longitude = result.get('lon')
    if latitude and longitude:
        return latitude, longitude
    return None


def resolve_map_url(value):
    text = (value or '').strip()
    parsed = urlparse(text)
    if parsed.netloc not in {'maps.app.goo.gl', 'goo.gl'}:
        return text

    try:
        request = Request(
            text,
            headers={
                'User-Agent': (
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36'
                )
            },
        )
        with urlopen(request, timeout=8) as response:
            return response.geturl()
    except (ValueError, URLError):
        return text


class AssignedLocationAdminForm(forms.ModelForm):
    map_location = forms.CharField(
        label='Google Maps link',
        required=False,
        help_text='Optional. Paste the exact Google Maps place link for more accurate check-in distance.',
        widget=forms.TextInput(attrs={'style': 'width: 520px; max-width: 100%;'}),
    )

    class Meta:
        model = AssignedLocation
        fields = '__all__'
        widgets = {
            'map_url': forms.HiddenInput(),
            'latitude': forms.HiddenInput(),
            'longitude': forms.HiddenInput(),
            'coordinates_resolved': forms.HiddenInput(),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if 'latitude' in self.fields:
            self.fields['latitude'].required = False
        if 'longitude' in self.fields:
            self.fields['longitude'].required = False
        if 'map_url' in self.fields:
            self.fields['map_url'].required = False
        if 'coordinates_resolved' in self.fields:
            self.fields['coordinates_resolved'].required = False
        if self.instance and self.instance.pk:
            self.fields['map_location'].initial = self.instance.map_url

    def clean(self):
        cleaned_data = super().clean()
        address = (cleaned_data.get('address') or '').strip()
        map_location = (cleaned_data.get('map_location') or '').strip()
        coordinates = extract_coordinates_from_map_url(map_location)
        if not coordinates:
            coordinates = extract_coordinates_from_map_url(address)
        if not coordinates:
            coordinates = geocode_location_text(address)
        if coordinates:
            cleaned_data['latitude'], cleaned_data['longitude'] = coordinates
            cleaned_data['coordinates_resolved'] = True
        else:
            cleaned_data['latitude'] = cleaned_data.get('latitude') or 0
            cleaned_data['longitude'] = cleaned_data.get('longitude') or 0
            cleaned_data['coordinates_resolved'] = False

        if map_location:
            cleaned_data['map_url'] = map_location
        elif address:
            cleaned_data['map_url'] = f'https://www.google.com/maps/search/?api=1&query={quote_plus(address)}'

        return cleaned_data


class UserProfileInline(admin.StackedInline):
    model = UserProfile
    can_delete = False
    extra = 0
    fieldsets = (
        (
            'Personal details',
            {
                'fields': (
                    'employee_code',
                    'mobile_number',
                    'gender',
                    'date_of_birth',
                    'department',
                    'designation',
                )
            },
        ),
        (
            'Dashboard permissions',
            {
                'fields': (
                    'can_access_user_dashboard',
                    'can_access_admin_dashboard',
                    'can_access_hr_dashboard',
                )
            },
        ),
    )


class AssignedLocationInline(admin.StackedInline):
    model = AssignedLocation
    form = AssignedLocationAdminForm
    can_delete = False
    extra = 0
    fields = (
        'name',
        'address',
        'map_location',
        'radius_meters',
        'is_active',
        'map_link',
        'directions_link',
        'updated_at',
    )
    readonly_fields = ('map_link', 'directions_link', 'updated_at')

    def map_link(self, obj):
        if not obj or obj.pk is None:
            return '-'
        url = obj.map_url or f'https://www.google.com/maps?q={obj.latitude},{obj.longitude}'
        return format_html(
            '<a href="{}" target="_blank" rel="noopener">Open assigned location</a>',
            url,
        )

    map_link.short_description = 'Map'

    def directions_link(self, obj):
        if not obj or obj.pk is None:
            return '-'
        if not obj.coordinates_resolved:
            return 'Map position pending'
        return format_html(
            '<a href="https://www.google.com/maps/dir/?api=1&destination={},{}" target="_blank" rel="noopener">Open directions</a>',
            obj.latitude,
            obj.longitude,
        )

    directions_link.short_description = 'Directions'


@admin.register(AssignedLocation)
class AssignedLocationAdmin(admin.ModelAdmin):
    form = AssignedLocationAdminForm
    list_display = (
        'user',
        'name',
        'address_preview',
        'restriction',
        'is_active',
        'map_status',
        'updated_at',
    )
    list_filter = ('is_active', 'radius_meters', 'coordinates_resolved')
    search_fields = (
        'user__username',
        'user__first_name',
        'user__last_name',
        'user__email',
        'name',
        'address',
    )
    fields = (
        'user',
        'name',
        'address',
        'map_location',
        'radius_meters',
        'is_active',
        'map_link',
        'directions_link',
        'updated_at',
    )
    readonly_fields = ('map_link', 'directions_link', 'updated_at')

    def address_preview(self, obj):
        return obj.address

    address_preview.short_description = 'Assigned address'

    def restriction(self, obj):
        return f'{obj.radius_meters}m radius'

    def map_status(self, obj):
        return 'Ready' if obj.coordinates_resolved else 'Pending'

    map_status.short_description = 'Map position'

    def map_link(self, obj):
        if not obj or obj.pk is None:
            return '-'
        url = obj.map_url or f'https://www.google.com/maps/search/?api=1&query={quote_plus(obj.address)}'
        return format_html(
            '<a href="{}" target="_blank" rel="noopener">Open assigned location</a>',
            url,
        )

    map_link.short_description = 'Map'

    def directions_link(self, obj):
        if not obj or obj.pk is None:
            return '-'
        if not obj.coordinates_resolved:
            return 'Map position pending'
        return format_html(
            '<a href="https://www.google.com/maps/dir/?api=1&destination={},{}" target="_blank" rel="noopener">Open directions</a>',
            obj.latitude,
            obj.longitude,
        )

    directions_link.short_description = 'Directions'


class AttendanceInline(admin.TabularInline):
    model = Attendance
    extra = 0
    can_delete = False
    show_change_link = True
    fields = (
        'event_badge',
        'timestamp',
        'location_address',
        'distance_meters',
        'accuracy',
        'location_link',
    )
    readonly_fields = fields
    ordering = ('-timestamp',)

    def has_add_permission(self, request, obj=None):
        return False

    def event_badge(self, obj):
        color = '#16a34a' if obj.event_type == Attendance.CHECK_IN else '#dc2626'
        return format_html(
            '<span style="background:{};color:white;padding:3px 8px;border-radius:999px">{}</span>',
            color,
            obj.get_event_type_display(),
        )

    event_badge.short_description = 'Event'

    def location_link(self, obj):
        return format_html(
            '<a href="https://www.google.com/maps?q={},{}" target="_blank" rel="noopener">Open map</a>',
            obj.latitude,
            obj.longitude,
        )

    location_link.short_description = 'Location'


admin.site.unregister(User)


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    add_form = HealOnUserCreationForm
    inlines = [UserProfileInline, AssignedLocationInline, AttendanceInline]
    add_fieldsets = (
        (
            None,
            {
                'classes': ('wide',),
                'fields': (
                    'username',
                    'first_name',
                    'last_name',
                    'email',
                    'date_of_birth',
                    'password1',
                    'password2',
                    'department',
                    'designation',
                    'can_access_user_dashboard',
                    'can_access_admin_dashboard',
                    'can_access_hr_dashboard',
                ),
            },
        ),
    )
    list_display = (
        'username',
        'full_name',
        'email',
        'employee_code',
        'department',
        'designation',
        'dashboard_permissions',
        'role',
        'is_active',
        'is_staff',
    )
    list_filter = ('is_active', 'is_staff', 'groups', 'userprofile__department')
    search_fields = (
        'username',
        'first_name',
        'last_name',
        'email',
        'userprofile__employee_code',
        'userprofile__department',
        'userprofile__designation',
    )

    def full_name(self, obj):
        return obj.get_full_name() or obj.username

    def employee_code(self, obj):
        profile = getattr(obj, 'userprofile', None)
        return profile.employee_code if profile and profile.employee_code else obj.username

    def department(self, obj):
        profile = getattr(obj, 'userprofile', None)
        return profile.department if profile else ''

    def designation(self, obj):
        profile = getattr(obj, 'userprofile', None)
        return profile.designation if profile else ''

    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)
        profile = getattr(form.instance, 'userprofile', None)
        if (
            profile
            and not form.instance.is_superuser
            and form.instance.is_staff != profile.can_access_admin_dashboard
        ):
            form.instance.is_staff = profile.can_access_admin_dashboard
            form.instance.save(update_fields=['is_staff'])

    def dashboard_permissions(self, obj):
        profile = getattr(obj, 'userprofile', None)
        if not profile:
            return 'Admin' if obj.is_staff else 'User'
        permissions = []
        if profile.can_access_user_dashboard:
            permissions.append('User')
        if profile.can_access_admin_dashboard or obj.is_staff:
            permissions.append('Admin')
        if profile.can_access_hr_dashboard:
            permissions.append('HR')
        return ', '.join(permissions) or '-'

    def role(self, obj):
        profile = getattr(obj, 'userprofile', None)
        if profile and profile.can_access_admin_dashboard:
            return 'Admin'
        if obj.is_staff:
            return 'Admin'
        if profile and profile.can_access_hr_dashboard:
            return 'HR'
        if profile and profile.can_access_user_dashboard:
            return 'User'
        role_markers = [
            obj.username,
            obj.email,
            profile.department if profile else '',
            profile.designation if profile else '',
        ]
        if any('hr' in (marker or '').lower() for marker in role_markers):
            return 'HR'
        return 'User'


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = (
        'user',
        'employee_code',
        'department',
        'designation',
        'date_of_birth',
        'mobile_number',
        'gender',
        'can_access_user_dashboard',
        'can_access_admin_dashboard',
        'can_access_hr_dashboard',
    )
    list_filter = (
        'department',
        'designation',
        'gender',
        'can_access_user_dashboard',
        'can_access_admin_dashboard',
        'can_access_hr_dashboard',
    )
    search_fields = (
        'user__username',
        'user__first_name',
        'user__last_name',
        'user__email',
        'employee_code',
        'department',
        'designation',
        'mobile_number',
    )


@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = (
        'user',
        'event_badge',
        'timestamp',
        'location_address',
        'distance_label',
        'accuracy',
    )
    list_filter = ('event_type', 'timestamp', 'user', 'assigned_location')
    search_fields = (
        'user__username',
        'user__first_name',
        'user__last_name',
        'user__email',
        'location_address',
        'assigned_location__address',
    )
    date_hierarchy = 'timestamp'
    readonly_fields = (
        'user',
        'event_type',
        'assigned_location',
        'location_address',
        'distance_meters',
        'accuracy',
        'timestamp',
        'location_link',
    )

    def event_badge(self, obj):
        color = '#16a34a' if obj.event_type == Attendance.CHECK_IN else '#dc2626'
        return format_html(
            '<span style="background:{};color:white;padding:3px 8px;border-radius:999px">{}</span>',
            color,
            obj.get_event_type_display(),
        )

    def distance_label(self, obj):
        if obj.distance_meters is None:
            return '-'
        return f'{obj.distance_meters:.1f}m'

    distance_label.short_description = 'Distance from assigned location'

    def location_link(self, obj):
        return format_html(
            '<a href="https://www.google.com/maps?q={},{}" target="_blank" rel="noopener">Open map</a>',
            obj.latitude,
            obj.longitude,
        )


@admin.register(AttendanceRegularization)
class AttendanceRegularizationAdmin(admin.ModelAdmin):
    list_display = (
        'employee',
        'date',
        'check_in_time',
        'check_out_time',
        'status',
        'applied_at',
    )
    list_filter = ('status', 'date', 'applied_at')
    search_fields = (
        'employee__username',
        'employee__first_name',
        'employee__last_name',
        'reason',
        'cc',
    )
    actions = ('approve_requests', 'reject_requests')

    @admin.action(description='Approve selected regularization requests')
    def approve_requests(self, request, queryset):
        queryset.update(status=AttendanceRegularization.STATUS_APPROVED)

    @admin.action(description='Reject selected regularization requests')
    def reject_requests(self, request, queryset):
        queryset.update(status=AttendanceRegularization.STATUS_REJECTED)


@admin.register(EmployeeTask)
class EmployeeTaskAdmin(admin.ModelAdmin):
    list_display = ('employee', 'title', 'status', 'assigned_date', 'due_date', 'completed_date')
    list_filter = ('status', 'assigned_date', 'due_date')
    search_fields = ('employee__username', 'employee__first_name', 'employee__last_name', 'title')


@admin.register(LeaveRequest)
class LeaveRequestAdmin(admin.ModelAdmin):
    list_display = ('employee', 'leave_type', 'from_date', 'to_date', 'total_days', 'status')
    list_filter = ('status', 'leave_type', 'from_date')
    search_fields = ('employee__username', 'employee__first_name', 'employee__last_name', 'reason')
    actions = ('approve_requests', 'reject_requests')

    @admin.action(description='Approve selected leave requests')
    def approve_requests(self, request, queryset):
        queryset.update(status=LeaveRequest.STATUS_APPROVED)

    @admin.action(description='Reject selected leave requests')
    def reject_requests(self, request, queryset):
        queryset.update(status=LeaveRequest.STATUS_REJECTED)


@admin.register(SalaryRecord)
class SalaryRecordAdmin(admin.ModelAdmin):
    list_display = ('employee', 'month', 'year', 'gross_salary', 'net_salary', 'is_published')
    list_filter = ('is_published', 'year', 'month')
    search_fields = ('employee__username', 'employee__first_name', 'employee__last_name')


@admin.register(HelpdeskTicket)
class HelpdeskTicketAdmin(admin.ModelAdmin):
    list_display = ('employee', 'subject', 'status', 'created_at', 'resolved_at')
    list_filter = ('status', 'created_at')
    search_fields = ('employee__username', 'employee__first_name', 'employee__last_name', 'subject')


@admin.register(Holiday)
class HolidayAdmin(admin.ModelAdmin):
    list_display = ('name', 'date', 'is_optional')
    list_filter = ('is_optional', 'date')
    search_fields = ('name',)


@admin.register(PasswordResetOTP)
class PasswordResetOTPAdmin(admin.ModelAdmin):
    list_display = ('user', 'mobile_number', 'created_at', 'expires_at', 'verified_at', 'used_at', 'attempts')
    list_filter = ('created_at', 'expires_at', 'verified_at', 'used_at')
    search_fields = ('user__username', 'user__first_name', 'user__last_name', 'mobile_number')
    readonly_fields = ('user', 'mobile_number', 'otp_hash', 'created_at', 'expires_at', 'verified_at', 'used_at', 'attempts')
