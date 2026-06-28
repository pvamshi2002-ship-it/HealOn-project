import 'dart:convert';

String jsonResponse(Map<String, dynamic> body) => jsonEncode(body);

final authUserResponse = jsonResponse({
  'token': 'test-token-user',
  'user': {
    'id': 2,
    'username': 'employee',
    'name': 'Test Employee',
    'role': 'User',
    'employee_id': 'EMP-TEST',
    'department': 'Engineering',
    'designation': 'Developer',
    'dashboard_permissions': ['User'],
  },
});

final authAdminResponse = jsonResponse({
  'token': 'test-token-admin',
  'user': {
    'id': 1,
    'username': 'admin',
    'name': 'Test Admin',
    'role': 'Admin',
    'employee_id': 'EMP-ADMIN',
    'department': 'HR',
    'designation': 'Administrator',
    'dashboard_permissions': ['Admin'],
  },
});

final authHrResponse = jsonResponse({
  'token': 'test-token-hr',
  'user': {
    'id': 3,
    'username': 'hr',
    'name': 'Test HR',
    'role': 'HR',
    'employee_id': 'EMP-HR',
    'department': 'HR',
    'designation': 'HR Manager',
    'dashboard_permissions': ['HR', 'User'],
  },
});

final userDashboardResponse = jsonResponse({
  'user': {
    'id': 2,
    'username': 'employee',
    'name': 'Test Employee',
    'role': 'User',
    'employee_id': 'EMP-TEST',
    'department': 'Engineering',
    'designation': 'Developer',
  },
  'attendance_summary': {
    'present_days': 12,
    'leave_balance': 8,
    'pending_tasks': 2,
    'published_payslips': 1,
  },
  'holidays': [
    {'name': 'Republic Day', 'date': '2026-01-26'},
  ],
  'attendance_settings': {
    'face_recognition_enabled': false,
    'face_match_threshold': 0.86,
  },
});

final adminDashboardResponse = jsonResponse({
  'summary': {
    'total_employees': 10,
    'present_today': 7,
    'pending_leaves': 2,
    'open_tickets': 1,
  },
  'recent_leaves': [],
  'recent_attendance': [],
});

final employeesListResponse = jsonResponse({
  'employees': [
    {
      'id': 2,
      'username': 'employee',
      'name': 'Test Employee',
      'first_name': 'Test',
      'last_name': 'Employee',
      'employee_code': 'EMP-TEST',
      'department': 'Engineering',
      'designation': 'Developer',
      'role': 'User',
      'dashboard_permissions': ['User'],
    },
    {
      'id': 4,
      'username': 'jane',
      'name': 'Jane Doe',
      'first_name': 'Jane',
      'last_name': 'Doe',
      'employee_code': 'EMP-JANE',
      'department': 'Support',
      'designation': 'Agent',
      'role': 'User',
      'dashboard_permissions': ['User'],
    },
  ],
});

final attendanceListResponse = jsonResponse({
  'attendance': [
    {
      'id': 1,
      'username': 'employee',
      'event_type': 'check_in',
      'timestamp': '2026-06-09T09:00:00Z',
      'location_address': 'Office',
    },
  ],
});

final attendanceSettingsResponse = jsonResponse({
  'face_recognition_enabled': false,
  'require_face_verification': false,
  'face_match_threshold': 0.86,
});

final leavesResponse = jsonResponse({
  'summary': {
    'approved': 1,
    'pending': 1,
    'rejected': 0,
    'balance': 8,
  },
  'leaves': [
    {
      'id': 1,
      'leave_type': 'Paid Leave',
      'from_date': '2026-06-10',
      'to_date': '2026-06-10',
      'total_days': 1,
      'status': 'pending',
      'reason': 'Personal',
    },
  ],
});

final tasksResponse = jsonResponse({
  'tasks': [
    {
      'id': 1,
      'title': 'Complete report',
      'status': 'assigned',
      'due_date': '2026-06-12',
    },
  ],
});

final helpdeskResponse = jsonResponse({
  'tickets': [
    {
      'id': 1,
      'subject': 'Laptop issue',
      'status': 'open',
      'priority': 'medium',
    },
  ],
});

final directoryResponse = jsonResponse({
  'employees': [
    {
      'id': 2,
      'name': 'Test Employee',
      'username': 'employee',
      'employee_id': 'EMP-TEST',
      'department': 'Engineering',
      'role': 'User',
    },
    {
      'id': 4,
      'name': 'Jane Doe',
      'username': 'jane',
      'employee_id': 'EMP-JANE',
      'department': 'Support',
      'role': 'User',
    },
  ],
});

final attendanceReportResponse = jsonResponse({
  'month': '2026-06',
  'summary': {
    'present_days': 10,
    'total_hours': 80,
    'late_days': 1,
  },
  'days': [
    {
      'date': '2026-06-01',
      'status': 'Present',
      'check_in': '09:00',
      'check_out': '18:00',
      'total_hours': 8,
    },
  ],
});

final salaryResponse = jsonResponse({
  'records': [
    {
      'month': 6,
      'year': 2026,
      'basic_salary': 45000,
      'allowances': 12000,
      'deductions': 3500,
      'net_salary': 53500,
      'is_published': true,
    },
  ],
});

final adminTasksResponse = jsonResponse({
  'tasks': [
    {
      'id': 1,
      'title': 'Onboarding',
      'employee': 'employee',
      'status': 'assigned',
    },
  ],
});

final adminSalaryRecordsResponse = jsonResponse({
  'records': [
    {
      'id': 1,
      'employee_id': 2,
      'employee_name': 'Test Employee',
      'month': 6,
      'year': 2026,
      'net_salary': 53500,
      'is_published': true,
    },
  ],
});

final reimbursementsResponse = jsonResponse({
  'reimbursements': [
    {
      'id': 1,
      'title': 'Travel',
      'amount': 1200,
      'status': 'pending',
    },
  ],
});
