import re
import json
import csv
from decimal import Decimal
from urllib.error import URLError
from urllib.parse import parse_qs, quote_plus, unquote, urlparse
from urllib.request import Request, urlopen

from django import forms
from django.contrib import admin
from django.contrib.auth.models import Group
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.auth.forms import UserCreationForm
from django.db.models import Count, Sum
from django.http import HttpResponse
from django.urls import reverse
from django.utils import timezone
from django.utils.html import format_html
from django.utils.text import capfirst

try:
    from rest_framework.authtoken.models import TokenProxy
except ImportError:
    TokenProxy = None

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
from .password_rules import validate_password_rules


User = get_user_model()

try:
    admin.site.unregister(Group)
except admin.sites.NotRegistered:
    pass

if TokenProxy:
    try:
        admin.site.unregister(TokenProxy)
    except admin.sites.NotRegistered:
        pass


admin.site.site_header = 'HealOn HR Management System'
admin.site.site_title = 'HealOn HR Management System'
admin.site.index_title = 'Welcome Admin'
admin.site.index_template = 'admin/index.html'


def status_badge(value, label=None):
    palette = {
        'approved': ('#dcfce7', '#166534', '#86efac'),
        'pending': ('#ffedd5', '#9a3412', '#fdba74'),
        'rejected': ('#fee2e2', '#991b1b', '#fca5a5'),
        'open': ('#dbeafe', '#1d4ed8', '#93c5fd'),
        'in_progress': ('#e0f2fe', '#0369a1', '#7dd3fc'),
        'resolved': ('#dcfce7', '#166534', '#86efac'),
        'closed': ('#f1f5f9', '#475569', '#cbd5e1'),
        'assigned': ('#e0f2fe', '#075985', '#7dd3fc'),
        'review': ('#fef3c7', '#92400e', '#fcd34d'),
        'completed': ('#dcfce7', '#166534', '#86efac'),
    }
    background, color, border = palette.get(value, ('#f1f5f9', '#334155', '#cbd5e1'))
    text = label or capfirst(str(value).replace('_', ' '))
    return format_html(
        '<span class="healon-status-badge" style="background:{};color:{};border-color:{}">{}</span>',
        background,
        color,
        border,
        text,
    )


def compact_decimal(value):
    decimal_value = Decimal(str(value or 0))
    return format(decimal_value.normalize(), 'f')


def biometric_image_preview(value, width=120, height=90):
    if not value:
        return '-'
    return format_html(
        '<img src="{}" style="width:{}px;height:{}px;object-fit:cover;border-radius:8px;border:1px solid #d1d5db" />',
        value,
        width,
        height,
    )


class PhotoBiometricCaptureWidget(forms.Textarea):
    class Media:
        js = ('people/admin_photo_capture.js',)

    def __init__(self, attrs=None):
        default_attrs = {
            'class': 'healon-photo-capture',
            'rows': 3,
        }
        if attrs:
            default_attrs.update(attrs)
        super().__init__(default_attrs)


class HealOnUserCreationForm(UserCreationForm):
    first_name = forms.CharField(max_length=150, required=False)
    last_name = forms.CharField(max_length=150, required=False)
    display_name = forms.CharField(max_length=300)
    email = forms.EmailField()
    employee_code = forms.CharField(max_length=30, required=False)
    mobile_number = forms.CharField(max_length=20, required=False)
    profile_photo_biometric = forms.CharField(
        label='Employee verification photo',
        required=True,
        widget=PhotoBiometricCaptureWidget(),
        help_text='Required for check-in/check-out photo verification. Capture or upload the employee photo before saving.',
    )
    gender = forms.ChoiceField(
        choices=(('', '---------'), *UserProfile.GENDER_CHOICES),
        required=False,
    )
    date_of_birth = forms.DateField(required=False, widget=forms.DateInput(attrs={'type': 'date'}))
    department = forms.CharField(max_length=80, required=False)
    designation = forms.CharField(max_length=80, required=False)
    can_access_user_dashboard = forms.BooleanField(required=False, initial=True)
    can_access_admin_dashboard = forms.BooleanField(required=False)
    can_access_hr_dashboard = forms.BooleanField(required=False)

    class Meta(UserCreationForm.Meta):
        model = User
        fields = (
            'first_name',
            'last_name',
            'display_name',
            'username',
            'email',
            'employee_code',
            'mobile_number',
            'profile_photo_biometric',
            'gender',
            'date_of_birth',
            'password1',
            'password2',
            'department',
            'designation',
            'can_access_user_dashboard',
            'can_access_admin_dashboard',
            'can_access_hr_dashboard',
        )

    def clean_password2(self):
        password = self.cleaned_data.get('password2')
        validate_password_rules(password)
        return password

    def clean_profile_photo_biometric(self):
        value = (self.cleaned_data.get('profile_photo_biometric') or '').strip()
        if not value.startswith('data:image/') or ',' not in value:
            raise forms.ValidationError(
                'Employee verification photo must be a captured image data URL.'
            )
        return value

    def save(self, commit=True):
        user = super().save(commit=False)
        first_name = self.cleaned_data['first_name']
        last_name = self.cleaned_data['last_name']
        display_name = self.cleaned_data.get('display_name') or ''
        if display_name and (not first_name or not last_name):
            display_first_name, _, display_last_name = display_name.partition(' ')
            first_name = first_name or display_first_name
            last_name = last_name or display_last_name
        user.first_name = first_name
        user.last_name = last_name
        user.email = self.cleaned_data['email']
        user.is_staff = self.cleaned_data['can_access_admin_dashboard']
        if commit:
            user.save()
            UserProfile.objects.update_or_create(
                user=user,
                defaults={
                    'employee_code': self.cleaned_data.get('employee_code') or user.username.upper(),
                    'mobile_number': self.cleaned_data.get('mobile_number') or '',
                    'profile_photo_biometric': self.cleaned_data.get('profile_photo_biometric') or '',
                    'gender': self.cleaned_data.get('gender') or '',
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

    class Media:
        js = ('people/admin_employee_form.js',)


class HealOnUserChangeForm(forms.ModelForm):
    display_name = forms.CharField(max_length=300)
    employee_code = forms.CharField(max_length=30, required=False)
    mobile_number = forms.CharField(max_length=20, required=False)
    profile_photo_biometric = forms.CharField(
        label='Employee verification photo',
        required=True,
        widget=PhotoBiometricCaptureWidget(),
        help_text='Required for check-in/check-out photo verification. Capture, recapture, or upload the employee photo before saving.',
    )
    gender = forms.ChoiceField(
        choices=(('', '---------'), *UserProfile.GENDER_CHOICES),
        required=False,
    )
    date_of_birth = forms.DateField(required=False, widget=forms.DateInput(attrs={'type': 'date'}))
    department = forms.CharField(max_length=80, required=False)
    designation = forms.CharField(max_length=80, required=False)
    can_access_user_dashboard = forms.BooleanField(required=False, initial=True)
    can_access_admin_dashboard = forms.BooleanField(required=False)
    can_access_hr_dashboard = forms.BooleanField(required=False)

    class Meta:
        model = User
        fields = (
            'first_name',
            'last_name',
            'display_name',
            'username',
            'email',
            'employee_code',
            'mobile_number',
            'profile_photo_biometric',
            'gender',
            'date_of_birth',
            'department',
            'designation',
            'can_access_user_dashboard',
            'can_access_admin_dashboard',
            'can_access_hr_dashboard',
        )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        profile = getattr(self.instance, 'userprofile', None)
        if self.instance and self.instance.pk:
            self.fields['display_name'].initial = self.instance.get_full_name() or self.instance.username
        if profile:
            self.fields['employee_code'].initial = profile.employee_code
            self.fields['mobile_number'].initial = profile.mobile_number
            self.fields['profile_photo_biometric'].initial = profile.profile_photo_biometric
            self.fields['gender'].initial = profile.gender
            self.fields['date_of_birth'].initial = profile.date_of_birth
            self.fields['department'].initial = profile.department
            self.fields['designation'].initial = profile.designation
            self.fields['can_access_user_dashboard'].initial = profile.can_access_user_dashboard
            self.fields['can_access_admin_dashboard'].initial = profile.can_access_admin_dashboard
            self.fields['can_access_hr_dashboard'].initial = profile.can_access_hr_dashboard

    def clean_profile_photo_biometric(self):
        value = (self.cleaned_data.get('profile_photo_biometric') or '').strip()
        if not value.startswith('data:image/') or ',' not in value:
            raise forms.ValidationError(
                'Employee verification photo must be a captured image data URL.'
            )
        return value

    def clean(self):
        cleaned_data = super().clean()
        if not any([
            cleaned_data.get('can_access_user_dashboard'),
            cleaned_data.get('can_access_admin_dashboard'),
            cleaned_data.get('can_access_hr_dashboard'),
        ]):
            raise forms.ValidationError('Select at least one dashboard permission.')
        return cleaned_data

    class Media:
        js = ('people/admin_employee_form.js',)



class AssignedLocationAdminForm(forms.ModelForm):
    face_verification_enabled = forms.BooleanField(
        label='Enable Face Verification for This Location',
        required=False,
        initial=True,
        help_text=(
            'When global face verification is required, this controls whether '
            'employees at this assigned location must match their registered photo.'
        ),
    )
    is_active = forms.TypedChoiceField(
        label='Location attendance',
        choices=((True, 'Enable Location'), (False, 'Disable Location')),
        coerce=lambda value: value in (True, 'True', 'true', '1', 1),
        widget=forms.RadioSelect,
        help_text=(
            'Enable Location requires GPS radius validation for check-in and '
            'check-out. Disable Location allows attendance with photo only.'
        ),
    )
    map_location = forms.CharField(
        label='Google Maps link',
        required=False,
        help_text='Optional. Paste the exact Google Maps place link for more accurate check-in distance.',
        widget=forms.TextInput(attrs={'style': 'width: 520px; max-width: 100%;'}),
    )
    latitude_longitude = forms.CharField(
        label='Latitude/Longitude',
        required=False,
        help_text=(
            'Required when Location attendance is enabled. Search the map, drag '
            'the pin, use current location, or enter coordinates as latitude,longitude.'
        ),
        widget=forms.TextInput(
            attrs={
                'class': 'healon-location-coordinate-input',
                'placeholder': '13.05580947189991,77.54149038010287',
                'style': 'width: 520px; max-width: 100%;',
            },
        ),
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
        self.fields['radius_meters'].help_text = (
            'Allowed GPS radius in meters. Must be greater than 0 when saved.'
        )
        self.fields['radius_meters'].widget.attrs.update({'min': '1', 'step': '1'})
        if self.instance and self.instance.pk:
            self.fields['map_location'].initial = self.instance.map_url
            if not (
                self.instance.latitude == 0 and self.instance.longitude == 0
            ):
                self.fields['latitude_longitude'].initial = (
                    f'{self.instance.latitude},{self.instance.longitude}'
                )

    def _field_value(self, field_name):
        if not self.is_bound:
            return self.initial.get(field_name)
        return self.data.get(self.add_prefix(field_name))

    def _is_empty_attached_inline(self):
        if self.instance and self.instance.pk:
            return False
        return not any(
            (self._field_value(field_name) or '').strip()
            for field_name in (
                'address',
                'latitude_longitude',
                'map_location',
                'map_url',
                'latitude',
                'longitude',
            )
        )

    def has_changed(self):
        if self._is_empty_attached_inline():
            return False
        return super().has_changed()

    def clean(self):
        cleaned_data = super().clean()
        if self._is_empty_attached_inline():
            cleaned_data['address'] = cleaned_data.get('address') or ''
            cleaned_data['latitude'] = 0
            cleaned_data['longitude'] = 0
            cleaned_data['coordinates_resolved'] = False
            return cleaned_data
        address = (cleaned_data.get('address') or '').strip()
        map_location = (cleaned_data.get('map_location') or '').strip()
        coordinate_text = (cleaned_data.get('latitude_longitude') or '').strip()
        location_enabled = cleaned_data.get('is_active')
        radius_meters = cleaned_data.get('radius_meters')
        hidden_coordinate_text = '{},{}'.format(
            cleaned_data.get('latitude') or '',
            cleaned_data.get('longitude') or '',
        )
        coordinates = parse_coordinate_pair(coordinate_text) if coordinate_text else None
        if coordinate_text and coordinates is None:
            self.add_error(
                'latitude_longitude',
                'Enter coordinates as latitude,longitude with latitude between -90 and 90 and longitude between -180 and 180.',
            )
            return cleaned_data
        if not coordinates:
            coordinates = parse_coordinate_pair(hidden_coordinate_text)
        if not coordinates:
            map_coordinates = extract_coordinates_from_map_url(map_location)
            if map_coordinates:
                coordinates = parse_coordinate_pair(','.join(map_coordinates))
        if radius_meters is None or radius_meters <= 0:
            self.add_error('radius_meters', 'Allowed radius must be greater than 0 meters.')
        coordinates_are_zero = bool(
            coordinates
            and Decimal(str(coordinates[0])) == 0
            and Decimal(str(coordinates[1])) == 0
        )
        if location_enabled and (not coordinates or coordinates_are_zero):
            self.add_error(
                'latitude_longitude',
                'Select a valid map pin or enter valid latitude/longitude before enabling location attendance.',
            )
            return cleaned_data
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

    class Media:
        css = {
            'all': (
                'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
                'people/admin_location_map.css',
            )
        }
        js = (
            'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
            'people/admin_location_map.js',
        )


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
                    'profile_photo_preview',
                    'profile_photo_biometric',
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
    readonly_fields = ('profile_photo_preview',)

    def profile_photo_preview(self, obj):
        return biometric_image_preview(
            getattr(obj, 'profile_photo_biometric', ''),
        )

    profile_photo_preview.short_description = 'Verification photo'


class AssignedLocationInline(admin.StackedInline):
    model = AssignedLocation
    form = AssignedLocationAdminForm
    can_delete = False
    extra = 0
    fields = (
        'name',
        'address',
        'latitude_longitude',
        'map_location',
        'map_url',
        'latitude',
        'longitude',
        'coordinates_resolved',
        'radius_meters',
        'effective_from',
        'effective_to',
        'is_active',
        'face_verification_enabled',
        'map_link',
        'directions_link',
        'updated_at',
    )
    readonly_fields = ('map_link', 'directions_link', 'updated_at')

    def map_link(self, obj):
        if not obj or obj.pk is None:
            return '-'
        url = obj.map_url or (
            'https://www.google.com/maps?q='
            f'{compact_decimal(obj.latitude)},{compact_decimal(obj.longitude)}'
        )
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
            compact_decimal(obj.latitude),
            compact_decimal(obj.longitude),
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
        'effective_from',
        'effective_to',
        'is_active',
        'face_verification_enabled',
        'map_status',
        'updated_at',
    )
    list_filter = (
        'is_active',
        'face_verification_enabled',
        'radius_meters',
        'coordinates_resolved',
        'effective_from',
        'effective_to',
    )
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
        'latitude_longitude',
        'map_location',
        'map_url',
        'latitude',
        'longitude',
        'coordinates_resolved',
        'radius_meters',
        'effective_from',
        'effective_to',
        'is_active',
        'face_verification_enabled',
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
            compact_decimal(obj.latitude),
            compact_decimal(obj.longitude),
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
        'photo_biometric_preview',
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
            compact_decimal(obj.latitude),
            compact_decimal(obj.longitude),
        )

    location_link.short_description = 'Location'

    def photo_biometric_preview(self, obj):
        return biometric_image_preview(obj.photo_biometric, width=96, height=72)

    photo_biometric_preview.short_description = 'Photo biometric'


admin.site.unregister(User)


USER_ADMIN_PROFILE_FIELDS = (
    'first_name',
    'last_name',
    'display_name',
    'username',
    'email',
    'employee_code',
    'mobile_number',
    'profile_photo_biometric',
    'gender',
    'date_of_birth',
    'department',
    'designation',
    'can_access_user_dashboard',
    'can_access_admin_dashboard',
    'can_access_hr_dashboard',
)


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    form = HealOnUserChangeForm
    add_form = HealOnUserCreationForm
    inlines = [AssignedLocationInline, AttendanceInline]
    fieldsets = (
        (
            None,
            {
                'classes': ('wide',),
                'fields': USER_ADMIN_PROFILE_FIELDS,
            },
        ),
    )
    add_fieldsets = (
        (
            None,
            {
                'classes': ('wide',),
                'fields': USER_ADMIN_PROFILE_FIELDS[:10]
                + (
                    'password1',
                    'password2',
                )
                + USER_ADMIN_PROFILE_FIELDS[10:],
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
    list_filter = ('is_active', 'is_staff', 'userprofile__department')
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

    def save_model(self, request, obj, form, change):
        if change and hasattr(form, 'cleaned_data'):
            display_name = form.cleaned_data.get('display_name') or ''
            first_name = form.cleaned_data.get('first_name') or ''
            last_name = form.cleaned_data.get('last_name') or ''
            if display_name and (not first_name or not last_name):
                display_first_name, _, display_last_name = display_name.partition(' ')
                first_name = first_name or display_first_name
                last_name = last_name or display_last_name
            obj.first_name = first_name
            obj.last_name = last_name
            obj.is_staff = bool(form.cleaned_data.get('can_access_admin_dashboard'))
        super().save_model(request, obj, form, change)
        if change and hasattr(form, 'cleaned_data'):
            UserProfile.objects.update_or_create(
                user=obj,
                defaults={
                    'employee_code': form.cleaned_data.get('employee_code') or obj.username.upper(),
                    'mobile_number': form.cleaned_data.get('mobile_number') or '',
                    'profile_photo_biometric': form.cleaned_data.get('profile_photo_biometric') or '',
                    'gender': form.cleaned_data.get('gender') or '',
                    'date_of_birth': form.cleaned_data.get('date_of_birth'),
                    'department': form.cleaned_data.get('department') or '',
                    'designation': form.cleaned_data.get('designation') or 'Employee',
                    'can_access_user_dashboard': form.cleaned_data.get(
                        'can_access_user_dashboard',
                        True,
                    ),
                    'can_access_admin_dashboard': form.cleaned_data.get(
                        'can_access_admin_dashboard',
                        False,
                    ),
                    'can_access_hr_dashboard': form.cleaned_data.get(
                        'can_access_hr_dashboard',
                        False,
                    ),
                },
            )

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
        'profile_photo_preview',
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
    readonly_fields = ('profile_photo_preview',)

    def profile_photo_preview(self, obj):
        return biometric_image_preview(obj.profile_photo_biometric)

    profile_photo_preview.short_description = 'Verification photo'


@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = (
        'user',
        'event_badge',
        'timestamp',
        'location_address',
        'distance_label',
        'accuracy',
        'photo_biometric_preview',
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
        'photo_biometric_preview',
        'photo_biometric',
    )
    actions = ('mark_selected_check_in', 'mark_selected_check_out')
    list_per_page = 25

    @admin.action(description='Mark Attendance as Check In')
    def mark_selected_check_in(self, request, queryset):
        queryset.update(event_type=Attendance.CHECK_IN)

    @admin.action(description='Mark Attendance as Check Out')
    def mark_selected_check_out(self, request, queryset):
        queryset.update(event_type=Attendance.CHECK_OUT)

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
            compact_decimal(obj.latitude),
            compact_decimal(obj.longitude),
        )

    def photo_biometric_preview(self, obj):
        return biometric_image_preview(obj.photo_biometric)

    photo_biometric_preview.short_description = 'Photo biometric'


@admin.register(AttendanceSettings)
class AttendanceSettingsAdmin(admin.ModelAdmin):
    list_display = ('name', 'require_face_verification', 'updated_at')
    fields = ('name', 'face_recognition_enabled', 'updated_at')
    readonly_fields = ('updated_at',)

    def formfield_for_dbfield(self, db_field, request, **kwargs):
        formfield = super().formfield_for_dbfield(db_field, request, **kwargs)
        if db_field.name == 'face_recognition_enabled':
            formfield.label = 'Require Face Verification'
            formfield.help_text = (
                'Enable biometric face matching during check-in/check-out. '
                'Disable to keep normal photo capture only.'
            )
        return formfield

    def require_face_verification(self, obj):
        return obj.face_recognition_enabled

    require_face_verification.boolean = True
    require_face_verification.short_description = 'Require Face Verification'

    def has_add_permission(self, request):
        return not AttendanceSettings.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(AttendanceRegularization)
class AttendanceRegularizationAdmin(admin.ModelAdmin):
    list_display = (
        'employee',
        'date',
        'check_in_time',
        'check_out_time',
        'status_label',
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

    list_per_page = 25

    def status_label(self, obj):
        return status_badge(obj.status, obj.get_status_display())

    status_label.short_description = 'Status'
    status_label.admin_order_field = 'status'

    @admin.action(description='Approve Attendance Requests')
    def approve_requests(self, request, queryset):
        queryset.update(status=AttendanceRegularization.STATUS_APPROVED)

    @admin.action(description='Reject Attendance Requests')
    def reject_requests(self, request, queryset):
        queryset.update(status=AttendanceRegularization.STATUS_REJECTED)


@admin.register(EmployeeTask)
class EmployeeTaskAdmin(admin.ModelAdmin):
    list_display = ('employee', 'title', 'status_label', 'assigned_date', 'due_date', 'completed_date')
    list_filter = ('status', 'assigned_date', 'due_date')
    search_fields = ('employee__username', 'employee__first_name', 'employee__last_name', 'title')
    list_per_page = 25

    def status_label(self, obj):
        return status_badge(obj.status, obj.get_status_display())

    status_label.short_description = 'Status'
    status_label.admin_order_field = 'status'


@admin.register(LeaveRequest)
class LeaveRequestAdmin(admin.ModelAdmin):
    list_display = ('employee', 'leave_type', 'from_date', 'to_date', 'total_days', 'status_label')
    list_filter = ('status', 'leave_type', 'from_date')
    search_fields = ('employee__username', 'employee__first_name', 'employee__last_name', 'reason')
    actions = ('approve_requests', 'reject_requests')
    date_hierarchy = 'from_date'
    list_per_page = 25

    def status_label(self, obj):
        return status_badge(obj.status, obj.get_status_display())

    status_label.short_description = 'Status'
    status_label.admin_order_field = 'status'

    @admin.action(description='Approve Leave')
    def approve_requests(self, request, queryset):
        queryset.update(status=LeaveRequest.STATUS_APPROVED)

    @admin.action(description='Reject Leave')
    def reject_requests(self, request, queryset):
        queryset.update(status=LeaveRequest.STATUS_REJECTED)


@admin.register(SalaryRecord)
class SalaryRecordAdmin(admin.ModelAdmin):
    list_display = ('employee', 'month', 'year', 'gross_salary', 'net_salary', 'is_published')
    list_filter = ('is_published', 'year', 'month')
    search_fields = ('employee__username', 'employee__first_name', 'employee__last_name')
    actions = ('export_payroll',)
    list_per_page = 25

    @admin.action(description='Export Payroll')
    def export_payroll(self, request, queryset):
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="healon-payroll.csv"'
        writer = csv.writer(response)
        writer.writerow([
            'Employee',
            'Month',
            'Year',
            'Basic Salary',
            'Allowances',
            'Deductions',
            'Bonus',
            'Incentives',
            'Tax Deducted',
            'Gross Salary',
            'Net Salary',
            'Published',
        ])
        for record in queryset.select_related('employee'):
            writer.writerow([
                record.employee.get_full_name() or record.employee.username,
                record.month,
                record.year,
                record.basic_salary,
                record.allowances,
                record.deductions,
                record.bonus,
                record.incentives,
                record.tax_deducted,
                record.gross_salary,
                record.net_salary,
                'Yes' if record.is_published else 'No',
            ])
        return response


@admin.register(ReimbursementRequest)
class ReimbursementRequestAdmin(admin.ModelAdmin):
    list_display = ('employee', 'expense_date', 'file_name', 'submitted_at')
    list_filter = ('expense_date', 'submitted_at')
    search_fields = (
        'employee__username',
        'employee__first_name',
        'employee__last_name',
        'reason',
        'file_name',
    )
    readonly_fields = ('submitted_at', 'pdf_link')
    fields = ('employee', 'expense_date', 'reason', 'file_name', 'pdf_link', 'submitted_at')
    list_per_page = 25

    def pdf_link(self, obj):
        if not obj or not obj.pdf_data:
            return '-'
        return format_html(
            '<a href="{}" target="_blank" rel="noopener">Open uploaded PDF</a>',
            obj.pdf_data,
        )

    pdf_link.short_description = 'PDF'


@admin.register(HelpdeskTicket)
class HelpdeskTicketAdmin(admin.ModelAdmin):
    list_display = ('employee', 'subject', 'status_label', 'created_at', 'resolved_at')
    list_filter = ('status', 'created_at')
    search_fields = ('employee__username', 'employee__first_name', 'employee__last_name', 'subject')
    actions = ('resolve_tickets',)
    list_per_page = 25

    def status_label(self, obj):
        return status_badge(obj.status, obj.get_status_display())

    status_label.short_description = 'Status'
    status_label.admin_order_field = 'status'

    @admin.action(description='Resolve Ticket')
    def resolve_tickets(self, request, queryset):
        queryset.update(status=HelpdeskTicket.STATUS_RESOLVED, resolved_at=timezone.now())


@admin.register(Holiday)
class HolidayAdmin(admin.ModelAdmin):
    list_display = ('name', 'date', 'is_optional')
    list_filter = ('is_optional', 'date')
    search_fields = ('name',)
    list_per_page = 25


@admin.register(PasswordResetOTP)
class PasswordResetOTPAdmin(admin.ModelAdmin):
    list_display = ('user', 'mobile_number', 'created_at', 'expires_at', 'verified_at', 'used_at', 'attempts')
    list_filter = ('created_at', 'expires_at', 'verified_at', 'used_at')
    search_fields = ('user__username', 'user__first_name', 'user__last_name', 'mobile_number')
    readonly_fields = ('user', 'mobile_number', 'otp_hash', 'created_at', 'expires_at', 'verified_at', 'used_at', 'attempts')
    list_per_page = 25


def admin_url(model, action='changelist'):
    return reverse(f'admin:{model._meta.app_label}_{model._meta.model_name}_{action}')


def monthly_labels(reference_date, months=6):
    labels = []
    year = reference_date.year
    month = reference_date.month
    for offset in range(months - 1, -1, -1):
        candidate_month = month - offset
        candidate_year = year
        while candidate_month <= 0:
            candidate_month += 12
            candidate_year -= 1
        labels.append((candidate_year, candidate_month, f'{candidate_month:02d}/{candidate_year}'))
    return labels


def build_healon_dashboard_context():
    today = timezone.localdate()
    month_windows = monthly_labels(today)
    users = User.objects.filter(is_active=True)
    active_employee_count = users.count()
    present_today_count = (
        Attendance.objects.filter(timestamp__date=today)
        .values('user')
        .distinct()
        .count()
    )
    absent_today_count = max(active_employee_count - present_today_count, 0)
    pending_leave_count = LeaveRequest.objects.filter(status=LeaveRequest.STATUS_PENDING).count()
    open_ticket_count = HelpdeskTicket.objects.filter(
        status__in=[HelpdeskTicket.STATUS_OPEN, HelpdeskTicket.STATUS_IN_PROGRESS]
    ).count()
    payroll_processed_count = SalaryRecord.objects.filter(is_published=True).count()

    attendance_series = []
    growth_series = []
    payroll_series = []
    for year, month, _label in month_windows:
        attendance_series.append(
            Attendance.objects.filter(timestamp__year=year, timestamp__month=month)
            .values('timestamp__date', 'user')
            .distinct()
            .count()
        )
        growth_series.append(User.objects.filter(date_joined__year=year, date_joined__month=month).count())
        payroll_total = (
            SalaryRecord.objects.filter(year=year, month=month)
            .aggregate(total=Sum('basic_salary') + Sum('allowances') + Sum('bonus') + Sum('incentives'))
            .get('total')
            or 0
        )
        payroll_series.append(float(payroll_total))

    leave_statuses = LeaveRequest.objects.values('status').annotate(total=Count('id'))
    leave_map = {item['status']: item['total'] for item in leave_statuses}

    return {
        'metrics': [
            {
                'label': 'Total Employees',
                'value': active_employee_count,
                'icon': 'fas fa-users',
                'tone': 'navy',
                'url': admin_url(User),
            },
            {
                'label': 'Present Today',
                'value': present_today_count,
                'icon': 'fas fa-user-check',
                'tone': 'emerald',
                'url': admin_url(Attendance),
            },
            {
                'label': 'Absent Today',
                'value': absent_today_count,
                'icon': 'fas fa-user-clock',
                'tone': 'orange',
                'url': admin_url(Attendance),
            },
            {
                'label': 'Pending Leaves',
                'value': pending_leave_count,
                'icon': 'fas fa-calendar-minus',
                'tone': 'amber',
                'url': f'{admin_url(LeaveRequest)}?status__exact={LeaveRequest.STATUS_PENDING}',
            },
            {
                'label': 'Payroll Processed',
                'value': payroll_processed_count,
                'icon': 'fas fa-wallet',
                'tone': 'slate',
                'url': f'{admin_url(SalaryRecord)}?is_published__exact=1',
            },
            {
                'label': 'Open Tickets',
                'value': open_ticket_count,
                'icon': 'fas fa-headset',
                'tone': 'blue',
                'url': admin_url(HelpdeskTicket),
            },
        ],
        'chart_data': {
            'labels': [label for _year, _month, label in month_windows],
            'attendance': attendance_series,
            'employee_growth': growth_series,
            'payroll': payroll_series,
            'leave_labels': ['Approved', 'Pending', 'Rejected'],
            'leave_values': [
                leave_map.get(LeaveRequest.STATUS_APPROVED, 0),
                leave_map.get(LeaveRequest.STATUS_PENDING, 0),
                leave_map.get(LeaveRequest.STATUS_REJECTED, 0),
            ],
        },
        'recent_activities': Attendance.objects.select_related('user').order_by('-timestamp')[:6],
        'pending_approvals': LeaveRequest.objects.select_related('employee').filter(
            status=LeaveRequest.STATUS_PENDING
        ).order_by('-applied_at')[:6],
        'open_tickets': HelpdeskTicket.objects.select_related('employee').filter(
            status__in=[HelpdeskTicket.STATUS_OPEN, HelpdeskTicket.STATUS_IN_PROGRESS]
        ).order_by('-created_at')[:6],
        'attendance_summary': {
            'present': present_today_count,
            'absent': absent_today_count,
            'total': active_employee_count,
        },
        'quick_actions': [
            {'label': 'Approve Leave', 'url': f'{admin_url(LeaveRequest)}?status__exact=pending', 'icon': 'fas fa-check'},
            {'label': 'Mark Attendance', 'url': admin_url(Attendance), 'icon': 'fas fa-calendar-plus'},
            {'label': 'Export Payroll', 'url': admin_url(SalaryRecord), 'icon': 'fas fa-file-export'},
            {'label': 'Helpdesk Support', 'url': f'{admin_url(HelpdeskTicket)}?status__exact=open', 'icon': 'fas fa-headset'},
        ],
    }


original_each_context = admin.site.each_context


def healon_each_context(request):
    context = original_each_context(request)
    if request.path.rstrip('/') == reverse('admin:index').rstrip('/'):
        context['healon_dashboard'] = build_healon_dashboard_context()
    return context


admin.site.each_context = healon_each_context
