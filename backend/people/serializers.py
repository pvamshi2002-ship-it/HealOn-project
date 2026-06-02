from rest_framework import serializers

from .models import (
    AssignedLocation,
    Attendance,
    AttendanceRegularization,
    EmployeeTask,
    HelpdeskTicket,
    Holiday,
    LeaveRequest,
    ReimbursementRequest,
    SalaryRecord,
)


class CompactDecimalField(serializers.DecimalField):
    def to_representation(self, value):
        representation = super().to_representation(value)
        if representation is None:
            return representation
        return representation.rstrip('0').rstrip('.') if '.' in representation else representation


class AssignedLocationSerializer(serializers.ModelSerializer):
    latitude = CompactDecimalField(max_digits=18, decimal_places=15)
    longitude = CompactDecimalField(max_digits=18, decimal_places=15)

    def validate(self, attrs):
        attrs = super().validate(attrs)
        latitude = attrs.get('latitude', getattr(self.instance, 'latitude', None))
        longitude = attrs.get('longitude', getattr(self.instance, 'longitude', None))
        is_active = attrs.get('is_active', getattr(self.instance, 'is_active', True))
        if latitude is not None and longitude is not None:
            if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
                raise serializers.ValidationError(
                    {
                        'latitude': (
                            'Latitude/Longitude must use latitude,longitude format '
                            'with latitude between -90 and 90 and longitude between -180 and 180.'
                        )
                    }
                )
            if is_active and latitude == 0 and longitude == 0:
                raise serializers.ValidationError(
                    {
                        'latitude': (
                            'Select a valid map pin or enter valid latitude/longitude '
                            'before enabling location attendance.'
                        )
                    }
                )
        radius = attrs.get('radius_meters', getattr(self.instance, 'radius_meters', None))
        if radius is not None and radius <= 0:
            raise serializers.ValidationError(
                {'radius_meters': 'Radius must be greater than 0.'}
            )
        return attrs

    class Meta:
        model = AssignedLocation
        fields = [
            'id',
            'name',
            'address',
            'map_url',
            'coordinates_resolved',
            'latitude',
            'longitude',
            'radius_meters',
            'effective_from',
            'effective_to',
            'is_active',
            'face_verification_enabled',
            'updated_at',
        ]
        read_only_fields = ['id', 'updated_at']


class AttendanceSerializer(serializers.ModelSerializer):
    latitude = CompactDecimalField(max_digits=18, decimal_places=15)
    longitude = CompactDecimalField(max_digits=18, decimal_places=15)
    position_timestamp = serializers.DateTimeField(write_only=True, required=False)
    location_captured_at = serializers.DateTimeField(write_only=True, required=False)

    def create(self, validated_data):
        validated_data.pop('position_timestamp', None)
        validated_data.pop('location_captured_at', None)
        return super().create(validated_data)

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
            'position_timestamp',
            'location_captured_at',
            'photo_biometric',
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
    employee_name = serializers.SerializerMethodField()
    gross_salary = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    net_salary = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)

    class Meta:
        model = SalaryRecord
        fields = [
            'id',
            'employee',
            'employee_name',
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

    def get_employee_name(self, obj):
        return obj.employee.get_full_name() or obj.employee.username


class ReimbursementRequestSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()

    class Meta:
        model = ReimbursementRequest
        fields = [
            'id',
            'employee',
            'employee_name',
            'expense_date',
            'reason',
            'file_name',
            'pdf_data',
            'submitted_at',
        ]
        read_only_fields = [
            'id',
            'employee',
            'employee_name',
            'submitted_at',
        ]

    def get_employee_name(self, obj):
        return obj.employee.get_full_name() or obj.employee.username


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
