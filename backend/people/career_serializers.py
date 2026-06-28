from django.conf import settings
from rest_framework import serializers

from .models import Candidate, ExitRequest, JobOpening, LeaveType


def build_public_job_url(slug):
    base = getattr(settings, 'FRONTEND_PUBLIC_BASE_URL', 'http://localhost:8080').rstrip('/')
    return f'{base}/#/careers/{slug}'


class PublicJobOpeningSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source='department.name', read_only=True, default='')
    designation_name = serializers.CharField(source='designation.name', read_only=True, default='')
    public_url = serializers.SerializerMethodField()

    class Meta:
        model = JobOpening
        fields = [
            'id',
            'title',
            'department_name',
            'designation_name',
            'openings_count',
            'description',
            'status',
            'public_slug',
            'public_url',
            'posted_at',
        ]
        read_only_fields = fields

    def get_public_url(self, obj):
        if not obj.public_slug:
            return ''
        return build_public_job_url(obj.public_slug)


class PublicJobApplySerializer(serializers.ModelSerializer):
    class Meta:
        model = Candidate
        fields = [
            'full_name',
            'email',
            'phone',
            'experience',
            'skills',
            'resume_file_name',
            'resume_data',
            'cover_letter',
        ]

    def validate_full_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Full name is required.')
        return value

    def validate_email(self, value):
        return value.strip().lower()

    def validate(self, attrs):
        resume_data = (attrs.get('resume_data') or '').strip()
        resume_file_name = (attrs.get('resume_file_name') or '').strip()
        if not resume_data:
            raise serializers.ValidationError(
                {'resume_data': 'Resume upload is required.'}
            )
        if not resume_file_name:
            raise serializers.ValidationError(
                {'resume_file_name': 'Resume file name is required.'}
            )
        return attrs


class EmployeeExitRequestSerializer(serializers.ModelSerializer):
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = ExitRequest
        fields = [
            'id',
            'resignation_date',
            'last_working_day',
            'reason',
            'status',
            'status_label',
            'clearance_notes',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'status',
            'status_label',
            'clearance_notes',
            'created_at',
            'updated_at',
        ]

    def validate(self, attrs):
        resignation_date = attrs.get('resignation_date')
        last_working_day = attrs.get('last_working_day')
        if resignation_date and last_working_day and last_working_day < resignation_date:
            raise serializers.ValidationError(
                {'last_working_day': 'Last working day cannot be before resignation date.'}
            )
        return attrs


class EmployeeLeaveTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaveType
        fields = ['id', 'name', 'annual_quota', 'is_paid', 'is_active']
