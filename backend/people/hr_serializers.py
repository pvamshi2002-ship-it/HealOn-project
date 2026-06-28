from django.contrib.auth import get_user_model
from rest_framework import serializers

from .career_serializers import build_public_job_url
from .models import (
    Candidate,
    Department,
    Designation,
    EmployeeDocument,
    ExitRequest,
    JobOpening,
    LeaveRequest,
    LeaveType,
    PerformanceReview,
    Shift,
    ShiftAssignment,
)

User = get_user_model()


class DepartmentSerializer(serializers.ModelSerializer):
    head_name = serializers.SerializerMethodField()
    employee_count = serializers.SerializerMethodField()

    class Meta:
        model = Department
        fields = [
            'id',
            'name',
            'code',
            'description',
            'head',
            'head_name',
            'employee_count',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'head_name', 'employee_count', 'created_at', 'updated_at']

    def get_head_name(self, obj):
        if not obj.head_id:
            return ''
        return obj.head.get_full_name() or obj.head.username

    def get_employee_count(self, obj):
        from .models import UserProfile

        return UserProfile.objects.filter(department=obj.name).count()

    def validate_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Department name is required.')
        return value


class DesignationSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source='department.name', read_only=True, default='')

    class Meta:
        model = Designation
        fields = [
            'id',
            'name',
            'code',
            'department',
            'department_name',
            'level',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'department_name', 'created_at', 'updated_at']

    def validate_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Designation name is required.')
        return value


class ShiftSerializer(serializers.ModelSerializer):
    class Meta:
        model = Shift
        fields = [
            'id',
            'name',
            'start_time',
            'end_time',
            'grace_minutes',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Shift name is required.')
        return value


class ShiftAssignmentSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    shift_name = serializers.CharField(source='shift.name', read_only=True)

    class Meta:
        model = ShiftAssignment
        fields = [
            'id',
            'employee',
            'employee_name',
            'shift',
            'shift_name',
            'effective_from',
            'effective_to',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'employee_name', 'shift_name', 'created_at', 'updated_at']

    def get_employee_name(self, obj):
        return obj.employee.get_full_name() or obj.employee.username

    def validate(self, attrs):
        effective_from = attrs.get('effective_from', getattr(self.instance, 'effective_from', None))
        effective_to = attrs.get('effective_to', getattr(self.instance, 'effective_to', None))
        if effective_from and effective_to and effective_to < effective_from:
            raise serializers.ValidationError(
                {'effective_to': 'End date cannot be before start date.'}
            )
        return attrs


class LeaveTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaveType
        fields = [
            'id',
            'name',
            'annual_quota',
            'is_paid',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class AdminLeaveRequestSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    total_days = serializers.IntegerField(read_only=True)

    class Meta:
        model = LeaveRequest
        fields = [
            'id',
            'employee',
            'employee_name',
            'leave_type',
            'from_date',
            'to_date',
            'reason',
            'status',
            'status_label',
            'total_days',
            'applied_at',
        ]
        read_only_fields = ['id', 'employee_name', 'status_label', 'total_days', 'applied_at']

    def get_employee_name(self, obj):
        return obj.employee.get_full_name() or obj.employee.username

    def validate(self, attrs):
        from_date = attrs.get('from_date', getattr(self.instance, 'from_date', None))
        to_date = attrs.get('to_date', getattr(self.instance, 'to_date', None))
        if from_date and to_date and to_date < from_date:
            raise serializers.ValidationError(
                {'to_date': 'To date cannot be before from date.'}
            )
        return attrs


class JobOpeningSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source='department.name', read_only=True, default='')
    designation_name = serializers.CharField(
        source='designation.name', read_only=True, default=''
    )
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    candidate_count = serializers.SerializerMethodField()
    public_url = serializers.SerializerMethodField()

    class Meta:
        model = JobOpening
        fields = [
            'id',
            'title',
            'department',
            'department_name',
            'designation',
            'designation_name',
            'openings_count',
            'description',
            'status',
            'status_label',
            'candidate_count',
            'public_slug',
            'public_url',
            'posted_at',
            'closed_at',
        ]
        read_only_fields = [
            'id',
            'department_name',
            'designation_name',
            'status_label',
            'candidate_count',
            'public_slug',
            'public_url',
            'posted_at',
            'closed_at',
        ]

    def get_public_url(self, obj):
        if not obj.public_slug:
            return ''
        return build_public_job_url(obj.public_slug)

    def get_candidate_count(self, obj):
        return obj.candidates.count()

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Job title is required.')
        return value


class CandidateSerializer(serializers.ModelSerializer):
    job_title = serializers.CharField(source='job_opening.title', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = Candidate
        fields = [
            'id',
            'job_opening',
            'job_title',
            'full_name',
            'email',
            'phone',
            'experience',
            'skills',
            'resume_file_name',
            'resume_data',
            'cover_letter',
            'status',
            'status_label',
            'notes',
            'applied_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'job_title', 'status_label', 'applied_at', 'updated_at']

    def validate_full_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Candidate name is required.')
        return value


class ExitRequestSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = ExitRequest
        fields = [
            'id',
            'employee',
            'employee_name',
            'resignation_date',
            'last_working_day',
            'reason',
            'status',
            'status_label',
            'clearance_notes',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'employee_name', 'status_label', 'created_at', 'updated_at']

    def get_employee_name(self, obj):
        return obj.employee.get_full_name() or obj.employee.username

    def validate(self, attrs):
        resignation_date = attrs.get(
            'resignation_date', getattr(self.instance, 'resignation_date', None)
        )
        last_working_day = attrs.get(
            'last_working_day', getattr(self.instance, 'last_working_day', None)
        )
        if resignation_date and last_working_day and last_working_day < resignation_date:
            raise serializers.ValidationError(
                {'last_working_day': 'Last working day cannot be before resignation date.'}
            )
        return attrs


class EmployeeDocumentSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    category_label = serializers.CharField(source='get_category_display', read_only=True)
    uploaded_by_name = serializers.SerializerMethodField()
    status_label = serializers.SerializerMethodField()

    class Meta:
        model = EmployeeDocument
        fields = [
            'id',
            'employee',
            'employee_name',
            'title',
            'category',
            'category_label',
            'file_name',
            'file_data',
            'notes',
            'is_required',
            'is_archived',
            'status_label',
            'expiry_date',
            'uploaded_by',
            'uploaded_by_name',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'employee_name',
            'category_label',
            'status_label',
            'uploaded_by_name',
            'created_at',
            'updated_at',
        ]

    def get_employee_name(self, obj):
        return obj.employee.get_full_name() or obj.employee.username

    def get_uploaded_by_name(self, obj):
        if not obj.uploaded_by_id:
            return ''
        return obj.uploaded_by.get_full_name() or obj.uploaded_by.username

    def get_status_label(self, obj):
        if obj.is_archived:
            return 'Archived'
        return 'Active'

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Document title is required.')
        return value


class EmployeeDocumentReadSerializer(serializers.ModelSerializer):
    category_label = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model = EmployeeDocument
        fields = [
            'id',
            'title',
            'category',
            'category_label',
            'file_name',
            'file_data',
            'notes',
            'is_required',
            'expiry_date',
            'created_at',
            'updated_at',
        ]
        read_only_fields = fields


class PerformanceReviewSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    reviewer_name = serializers.SerializerMethodField()
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = PerformanceReview
        fields = [
            'id',
            'employee',
            'employee_name',
            'reviewer',
            'reviewer_name',
            'period_start',
            'period_end',
            'rating',
            'goals',
            'feedback',
            'status',
            'status_label',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'employee_name',
            'reviewer_name',
            'status_label',
            'created_at',
            'updated_at',
        ]

    def get_employee_name(self, obj):
        return obj.employee.get_full_name() or obj.employee.username

    def get_reviewer_name(self, obj):
        if not obj.reviewer_id:
            return ''
        return obj.reviewer.get_full_name() or obj.reviewer.username

    def validate_rating(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError('Rating must be between 1 and 5.')
        return value

    def validate(self, attrs):
        period_start = attrs.get('period_start', getattr(self.instance, 'period_start', None))
        period_end = attrs.get('period_end', getattr(self.instance, 'period_end', None))
        if period_start and period_end and period_end < period_start:
            raise serializers.ValidationError(
                {'period_end': 'Period end cannot be before period start.'}
            )
        return attrs
