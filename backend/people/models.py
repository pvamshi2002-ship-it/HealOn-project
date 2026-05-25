from django.conf import settings
from django.db import models


DEFAULT_ATTENDANCE_RADIUS_METERS = 100


class UserProfile(models.Model):
    GENDER_CHOICES = [
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
    ]

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    employee_code = models.CharField(max_length=30, blank=True)
    mobile_number = models.CharField(max_length=20, blank=True)
    profile_photo_biometric = models.TextField(blank=True)
    gender = models.CharField(max_length=16, choices=GENDER_CHOICES, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    department = models.CharField(max_length=80, blank=True)
    designation = models.CharField(max_length=80, blank=True)
    can_access_user_dashboard = models.BooleanField(default=True)
    can_access_admin_dashboard = models.BooleanField(default=False)
    can_access_hr_dashboard = models.BooleanField(default=False)

    def __str__(self):
        return self.user.get_full_name() or self.user.username


class AssignedLocation(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='assigned_location',
    )
    name = models.CharField(max_length=120, default='Work Location')
    address = models.TextField(help_text='Complete location address shown to admins and employees.')
    map_url = models.URLField(max_length=500, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, default=0)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, default=0)
    coordinates_resolved = models.BooleanField(default=False)
    radius_meters = models.PositiveIntegerField(default=DEFAULT_ATTENDANCE_RADIUS_METERS)
    effective_from = models.DateField(null=True, blank=True)
    effective_to = models.DateField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['user__username']

    def __str__(self):
        return f'{self.user.username} - {self.name} ({self.radius_meters}m)'


class PasswordResetOTP(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    mobile_number = models.CharField(max_length=20)
    otp_hash = models.CharField(max_length=64)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    verified_at = models.DateTimeField(null=True, blank=True)
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.mobile_number} reset OTP'


class Attendance(models.Model):
    CHECK_IN = 'check_in'
    CHECK_OUT = 'check_out'
    EVENT_TYPES = [
        (CHECK_IN, 'Check In'),
        (CHECK_OUT, 'Check Out'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    event_type = models.CharField(max_length=16, choices=EVENT_TYPES)
    assigned_location = models.ForeignKey(
        AssignedLocation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    location_address = models.TextField(blank=True)
    distance_meters = models.FloatField(null=True, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    accuracy = models.FloatField(null=True, blank=True)
    photo_biometric = models.TextField(blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f'{self.user.username} {self.event_type} {self.timestamp:%Y-%m-%d %H:%M}'


class AttendanceRegularization(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_APPROVED = 'approved'
    STATUS_REJECTED = 'rejected'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_APPROVED, 'Approved'),
        (STATUS_REJECTED, 'Rejected'),
    ]

    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='attendance_regularizations',
    )
    date = models.DateField()
    check_in_time = models.TimeField(null=True, blank=True)
    check_out_time = models.TimeField(null=True, blank=True)
    cc = models.CharField(max_length=255, blank=True)
    reason = models.TextField()
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_PENDING)
    applied_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-applied_at']

    def __str__(self):
        return f'{self.employee.username} regularization {self.date}'


class EmployeeTask(models.Model):
    STATUS_ASSIGNED = 'assigned'
    STATUS_IN_PROGRESS = 'in_progress'
    STATUS_REVIEW = 'review'
    STATUS_COMPLETED = 'completed'
    STATUS_CHOICES = [
        (STATUS_ASSIGNED, 'Assigned'),
        (STATUS_IN_PROGRESS, 'In Progress'),
        (STATUS_REVIEW, 'Review'),
        (STATUS_COMPLETED, 'Completed'),
    ]

    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='tasks',
    )
    title = models.CharField(max_length=160)
    description = models.TextField(blank=True)
    assigned_date = models.DateField(auto_now_add=True)
    due_date = models.DateField(null=True, blank=True)
    completed_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=24, choices=STATUS_CHOICES, default=STATUS_ASSIGNED)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.title


class LeaveRequest(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_APPROVED = 'approved'
    STATUS_REJECTED = 'rejected'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_APPROVED, 'Approved'),
        (STATUS_REJECTED, 'Rejected'),
    ]

    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='leave_requests',
    )
    leave_type = models.CharField(max_length=80, default='Casual Leave')
    from_date = models.DateField()
    to_date = models.DateField()
    reason = models.TextField(blank=True)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_PENDING)
    applied_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-applied_at']

    @property
    def total_days(self):
        return (self.to_date - self.from_date).days + 1

    def __str__(self):
        return f'{self.employee.username} {self.leave_type}'


class SalaryRecord(models.Model):
    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='salary_records',
    )
    year = models.PositiveIntegerField()
    month = models.PositiveSmallIntegerField()
    basic_salary = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    allowances = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    deductions = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    bonus = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    incentives = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    tax_deducted = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_published = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-year', '-month']
        unique_together = ('employee', 'year', 'month')

    @property
    def gross_salary(self):
        return self.basic_salary + self.allowances + self.bonus + self.incentives

    @property
    def net_salary(self):
        return self.gross_salary - self.deductions - self.tax_deducted

    def __str__(self):
        return f'{self.employee.username} {self.month:02d}/{self.year}'


class ReimbursementRequest(models.Model):
    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='reimbursement_requests',
    )
    expense_date = models.DateField()
    reason = models.TextField()
    file_name = models.CharField(max_length=255)
    pdf_data = models.TextField()
    submitted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-expense_date', '-submitted_at']

    def __str__(self):
        return f'{self.employee.username} reimbursement {self.expense_date}'


class HelpdeskTicket(models.Model):
    STATUS_OPEN = 'open'
    STATUS_IN_PROGRESS = 'in_progress'
    STATUS_RESOLVED = 'resolved'
    STATUS_CLOSED = 'closed'
    STATUS_CHOICES = [
        (STATUS_OPEN, 'Open'),
        (STATUS_IN_PROGRESS, 'In Progress'),
        (STATUS_RESOLVED, 'Resolved'),
        (STATUS_CLOSED, 'Closed'),
    ]

    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='helpdesk_tickets',
    )
    subject = models.CharField(max_length=160, default='Employee support request')
    description = models.TextField()
    status = models.CharField(max_length=24, choices=STATUS_CHOICES, default=STATUS_OPEN)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.subject


class Holiday(models.Model):
    name = models.CharField(max_length=120)
    date = models.DateField(unique=True)
    is_optional = models.BooleanField(default=False)

    class Meta:
        ordering = ['date']

    def __str__(self):
        return f'{self.name} - {self.date}'
