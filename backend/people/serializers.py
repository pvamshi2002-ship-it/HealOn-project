from rest_framework import serializers

from .models import (
    AssignedLocation,
    Attendance,
    AttendanceRegularization,
    EmployeeTask,
    HelpdeskTicket,
    Holiday,
    LeaveRequest,
    SalaryRecord,
)


class AssignedLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = AssignedLocation
        fields = [
            'id',
            'name',
            'address',
            'map_url',
            'coordinates_resolved',
            'radius_meters',
            'is_active',
            'updated_at',
        ]
        read_only_fields = ['id', 'updated_at']


class AttendanceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Attendance
        fields = [
            'id',
            'user',
            'event_type',
            'assigned_location',
            'location_address',
            'distance_meters',
            'latitude',
            'longitude',
            'accuracy',
            'timestamp',
        ]
        read_only_fields = [
            'id',
            'user',
            'event_type',
            'assigned_location',
            'location_address',
            'distance_meters',
            'timestamp',
        ]


class AttendanceRegularizationSerializer(serializers.ModelSerializer):
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = AttendanceRegularization
        fields = [
            'id',
            'date',
            'check_in_time',
            'check_out_time',
            'cc',
            'reason',
            'status',
            'status_label',
            'applied_at',
        ]
        read_only_fields = ['id', 'status', 'status_label', 'applied_at']


class EmployeeTaskSerializer(serializers.ModelSerializer):
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = EmployeeTask
        fields = [
            'id',
            'title',
            'description',
            'assigned_date',
            'due_date',
            'completed_date',
            'status',
            'status_label',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'assigned_date', 'created_at', 'updated_at']


class LeaveRequestSerializer(serializers.ModelSerializer):
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    total_days = serializers.IntegerField(read_only=True)

    class Meta:
        model = LeaveRequest
        fields = [
            'id',
            'leave_type',
            'from_date',
            'to_date',
            'reason',
            'status',
            'status_label',
            'total_days',
            'applied_at',
        ]
        read_only_fields = ['id', 'status', 'status_label', 'total_days', 'applied_at']


class SalaryRecordSerializer(serializers.ModelSerializer):
    gross_salary = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    net_salary = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)

    class Meta:
        model = SalaryRecord
        fields = [
            'id',
            'year',
            'month',
            'basic_salary',
            'allowances',
            'deductions',
            'bonus',
            'incentives',
            'tax_deducted',
            'gross_salary',
            'net_salary',
            'is_published',
        ]
        read_only_fields = fields


class HelpdeskTicketSerializer(serializers.ModelSerializer):
    status_label = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = HelpdeskTicket
        fields = ['id', 'subject', 'description', 'status', 'status_label', 'created_at', 'resolved_at']
        read_only_fields = ['id', 'status', 'status_label', 'created_at', 'resolved_at']


class HolidaySerializer(serializers.ModelSerializer):
    class Meta:
        model = Holiday
        fields = ['id', 'name', 'date', 'is_optional']
