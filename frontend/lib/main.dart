import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'external_link.dart';
import 'payslip_download.dart';

// For web: use localhost, for mobile: use 10.0.2.2
final String backendUrl = () {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000'; // For web
}();

class AttendanceReport {
  AttendanceReport({
    required this.month,
    required this.presentDays,
    required this.totalHours,
    required this.lateDays,
    required this.days,
  });

  final String month;
  final int presentDays;
  final double totalHours;
  final int lateDays;
  final List<AttendanceReportDay> days;

  factory AttendanceReport.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final daysJson = json['days'] as List<dynamic>? ?? [];
    return AttendanceReport(
      month: json['month'] as String? ?? '',
      presentDays: (summary['present_days'] as num?)?.toInt() ?? 0,
      totalHours: (summary['total_hours'] as num?)?.toDouble() ?? 0,
      lateDays: (summary['late_days'] as num?)?.toInt() ?? 0,
      days: daysJson
          .whereType<Map<String, dynamic>>()
          .map(AttendanceReportDay.fromJson)
          .toList(),
    );
  }
}

class AttendanceReportDay {
  AttendanceReportDay({
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.totalHours,
  });

  final String date;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final double? totalHours;

  factory AttendanceReportDay.fromJson(Map<String, dynamic> json) {
    return AttendanceReportDay(
      date: json['date'] as String? ?? '',
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      totalHours: (json['total_hours'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'Incomplete',
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealOn Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _token;
  final _empIdCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _resetMobileCtrl = TextEditingController();
  final _resetOtpCtrl = TextEditingController();
  final _resetPassCtrl = TextEditingController();
  final _helpdeskIssueCtrl = TextEditingController();
  final _employeeFirstNameCtrl = TextEditingController();
  final _employeeLastNameCtrl = TextEditingController();
  final _employeeDobCtrl = TextEditingController();
  final _employeeEmailCtrl = TextEditingController();
  final _employeeDepartmentCtrl = TextEditingController();
  final _employeeDesignationCtrl = TextEditingController();
  final _employeeUsernameCtrl = TextEditingController();
  final _employeePasswordCtrl = TextEditingController();
  final _employeeSearchCtrl = TextEditingController();
  final _editEmployeeFirstNameCtrl = TextEditingController();
  final _editEmployeeLastNameCtrl = TextEditingController();
  final _editEmployeeDobCtrl = TextEditingController();
  final _editEmployeeEmailCtrl = TextEditingController();
  final _editEmployeeDepartmentCtrl = TextEditingController();
  final _editEmployeeDesignationCtrl = TextEditingController();
  final _editEmployeeUsernameCtrl = TextEditingController();
  final _editEmployeePasswordCtrl = TextEditingController();
  final _adminAttendanceSearchCtrl = TextEditingController();
  final _adminReportSearchCtrl = TextEditingController();
  final _locationAddressCtrl = TextEditingController();
  final _locationMapLinkCtrl = TextEditingController();
  final _locationRadiusCtrl = TextEditingController(text: '100');
  final _leaveCcCtrl = TextEditingController();
  final _leaveReasonCtrl = TextEditingController();
  final _regularizationCcCtrl = TextEditingController();
  final _regularizationCheckInCtrl = TextEditingController();
  final _regularizationCheckOutCtrl = TextEditingController();
  final _regularizationReasonCtrl = TextEditingController();
  String _status = '';
  bool _isLoading = false;
  bool _isResetLoading = false;
  bool _isEmployeeSaving = false;
  bool _isLocationSaving = false;
  bool _employeeCanAccessUser = true;
  bool _employeeCanAccessAdmin = false;
  bool _employeeCanAccessHr = false;
  bool _editEmployeeCanAccessUser = true;
  bool _editEmployeeCanAccessAdmin = false;
  bool _editEmployeeCanAccessHr = false;
  bool _showLocationAssignedPopup = false;
  bool _showPassword = false;
  bool _rememberMe = false;
  int _resetStep = 0;
  String? _resetMessage;
  String _selectedRole = 'User';
  String _selectedMenu = 'Dashboard';
  String _selectedAttendanceSection = 'Daily Attendance';
  String _selectedAdminAttendanceSection = 'Daily Attendances';
  String _selectedDailyAttendanceStatus = 'All';
  String _selectedTaskSection = 'Pending Tasks';
  String _selectedAdminTaskStatus = 'assigned';
  String _selectedPendingRequestStatus = 'pending';
  String _selectedLeaveSection = 'Apply Leave';
  String? _selectedApplyLeaveType;
  DateTime? _leaveFromDate;
  DateTime? _leaveToDate;
  String _leaveFromSession = 'Session 1';
  String _leaveToSession = 'Session 2';
  bool _showLeaveSubmitSuccess = false;
  bool _isLeaveSubmitting = false;
  Timer? _leaveSubmitSuccessTimer;
  String _selectedLeaveOverview = 'Leave History';
  String _selectedSalarySection = 'Payslips';
  String _selectedPayslipMonth = _monthName(DateTime.now().month);
  String _selectedPayslipYear = DateTime.now().year.toString();
  bool _isPayslipLoading = false;
  Map<String, dynamic>? _selectedSalaryRecord;
  bool _isSalaryDetailsLoading = false;
  String? _salaryDetailsError;
  bool _isTasksLoading = false;
  bool _isHelpdeskLoading = false;
  String _selectedHrSection = 'Staff Directory';
  DateTime _selectedReportMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime? _selectedRegularizationDate;
  bool _isRegularizationSubmitting = false;
  AttendanceReport? _attendanceReport;
  bool _isReportLoading = false;
  String? _reportError;
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _userDashboard;
  Map<String, dynamic>? _adminDashboard;
  Map<String, dynamic>? _adminAttendance;
  Map<String, dynamic>? _adminAttendanceReport;
  Map<String, dynamic>? _adminTasks;
  final Map<String, String> _pendingRequestActions = {};
  List<Map<String, dynamic>> _employeeLeaves = [];
  List<Map<String, dynamic>> _employeeTasks = [];
  List<Map<String, dynamic>> _helpdeskTickets = [];
  List<Map<String, dynamic>> _employeeDirectory = [];
  List<dynamic> _adminEmployees = [];
  int? _selectedEditEmployeeId;
  int? _selectedLocationEmployeeId;
  int? _selectedAdminAttendanceEmployeeId;
  int? _selectedAdminReportEmployeeId;
  DateTime _selectedAdminAttendanceReportMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime? _selectedAdminAttendanceReportDate;
  DateTime _selectedAdminTaskMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime? _selectedAdminTaskDate;
  bool _isDashboardLoading = false;
  String? _dashboardError;

  bool get _isAdminRole => _selectedRole.trim().toLowerCase() == 'admin';
  bool get _isHrRole => _selectedRole.trim().toLowerCase() == 'hr';

  int _readInt(Map<String, dynamic>? map, String key) {
    return (map?[key] as num?)?.toInt() ?? 0;
  }

  Map<String, dynamic>? _userSection(String key) {
    return _userDashboard?[key] as Map<String, dynamic>?;
  }

  List<Map<String, String>> _dashboardHolidayRows() {
    final holidays = _userDashboard?['holidays'] as List<dynamic>?;
    if (holidays == null || holidays.isEmpty) {
      return const [
        {'name': 'Bakrid', 'date': '17 June 2026'},
        {'name': 'Independence Day', 'date': '15 August 2026'},
        {'name': 'Ganesh Chaturthi', 'date': '27 August 2026'},
      ];
    }
    return holidays.map((raw) {
      final holiday = raw as Map<String, dynamic>;
      return {
        'name': holiday['name']?.toString() ?? 'Holiday',
        'date': _readableDate(holiday['date']?.toString() ?? ''),
      };
    }).toList();
  }

  static String _monthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return monthNames[month - 1];
  }

  @override
  void dispose() {
    _leaveSubmitSuccessTimer?.cancel();
    _empIdCtrl.dispose();
    _passCtrl.dispose();
    _resetMobileCtrl.dispose();
    _resetOtpCtrl.dispose();
    _resetPassCtrl.dispose();
    _helpdeskIssueCtrl.dispose();
    _employeeFirstNameCtrl.dispose();
    _employeeLastNameCtrl.dispose();
    _employeeDobCtrl.dispose();
    _employeeEmailCtrl.dispose();
    _employeeDepartmentCtrl.dispose();
    _employeeDesignationCtrl.dispose();
    _employeeUsernameCtrl.dispose();
    _employeePasswordCtrl.dispose();
    _employeeSearchCtrl.dispose();
    _editEmployeeFirstNameCtrl.dispose();
    _editEmployeeLastNameCtrl.dispose();
    _editEmployeeDobCtrl.dispose();
    _editEmployeeEmailCtrl.dispose();
    _editEmployeeDepartmentCtrl.dispose();
    _editEmployeeDesignationCtrl.dispose();
    _editEmployeeUsernameCtrl.dispose();
    _editEmployeePasswordCtrl.dispose();
    _adminAttendanceSearchCtrl.dispose();
    _adminReportSearchCtrl.dispose();
    _locationAddressCtrl.dispose();
    _locationMapLinkCtrl.dispose();
    _locationRadiusCtrl.dispose();
    _leaveCcCtrl.dispose();
    _leaveReasonCtrl.dispose();
    _regularizationCcCtrl.dispose();
    _regularizationCheckInCtrl.dispose();
    _regularizationCheckOutCtrl.dispose();
    _regularizationReasonCtrl.dispose();
    super.dispose();
  }

  void _showLeaveSubmittedSuccess() {
    _leaveSubmitSuccessTimer?.cancel();
    setState(() {
      _showLeaveSubmitSuccess = true;
    });
    _leaveSubmitSuccessTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showLeaveSubmitSuccess = false;
      });
    });
  }

  void _hideLeaveSubmittedSuccess() {
    _leaveSubmitSuccessTimer?.cancel();
    setState(() {
      _showLeaveSubmitSuccess = false;
    });
  }

  Future<Map<String, dynamic>?> _apiGet(String path) async {
    if (_token == null) {
      return null;
    }

    final resp = await http.get(
      Uri.parse('$backendUrl$path'),
      headers: {'Authorization': 'Token $_token'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Request failed: ${resp.statusCode}');
  }

  String _responseMessage(http.Response resp, String fallback) {
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (body.isNotEmpty) {
        final first = body.entries.first;
        final value = first.value;
        if (value is List && value.isNotEmpty) {
          return '${first.key}: ${value.first}';
        }
        if (value is String && value.isNotEmpty) {
          return '${first.key}: $value';
        }
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String? _normalizeTimeForApi(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int _monthNumber(String monthName) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final index = months.indexOf(monthName);
    return index == -1 ? DateTime.now().month : index + 1;
  }

  String _moneyLabel(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '') ?? 0;
    return 'INR ${amount.toStringAsFixed(2)}';
  }

  String _monthYearQuery(String monthName, String year) {
    return 'month=${_monthNumber(monthName)}&year=$year';
  }

  List<Map<String, dynamic>> _leaveRequests() {
    if (_employeeLeaves.isNotEmpty) return _employeeLeaves;
    final recent = _userSection('leaves')?['recent'] as List<dynamic>?;
    return recent?.whereType<Map<String, dynamic>>().toList() ?? [];
  }

  Color _leaveTypeColor(String leaveType) {
    switch (leaveType.toLowerCase()) {
      case 'sick leave':
        return Colors.red;
      case 'paid leave':
        return const Color(0xFF1ABE8E);
      case 'compensation leave':
        return const Color(0xFF7C3AED);
      case 'paternity leave':
        return Colors.indigo;
      default:
        return const Color(0xFF2B5AF0);
    }
  }

  Color _leaveStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF1ABE8E);
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return const Color(0xFF2B5AF0);
    }
  }

  Future<void> requestPasswordReset(StateSetter dialogSetState) async {
    if (_resetMobileCtrl.text.trim().isEmpty) {
      dialogSetState(() => _resetMessage = 'Please enter mobile number');
      return;
    }

    dialogSetState(() {
      _isResetLoading = true;
      _resetMessage = null;
    });

    final resp = await http.post(
      Uri.parse('$backendUrl/api/password-reset/request/'),
      body: {'mobile_number': _resetMobileCtrl.text.trim()},
    );

    dialogSetState(() {
      _isResetLoading = false;
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        _resetStep = 1;
        final devOtp = body['dev_otp'] ?? body['otp'];
        final smsDelivered = body['sms_delivered'] == true;
        if (smsDelivered) {
          _resetMessage =
              'HealOn password reset OTP sent to your mobile number.';
        } else if (devOtp != null) {
          _resetMessage =
              'SMS provider is not configured. Use dev OTP: $devOtp';
        } else {
          _resetMessage =
              'OTP generated, but SMS provider is not configured on backend.';
        }
      } else {
        _resetMessage = _responseMessage(resp, 'Unable to send OTP');
      }
    });
  }

  Future<void> verifyPasswordResetOtp(StateSetter dialogSetState) async {
    if (_resetOtpCtrl.text.trim().isEmpty) {
      dialogSetState(() => _resetMessage = 'Please enter OTP');
      return;
    }

    dialogSetState(() {
      _isResetLoading = true;
      _resetMessage = null;
    });

    final resp = await http.post(
      Uri.parse('$backendUrl/api/password-reset/verify/'),
      body: {
        'mobile_number': _resetMobileCtrl.text.trim(),
        'otp': _resetOtpCtrl.text.trim(),
      },
    );

    dialogSetState(() {
      _isResetLoading = false;
      if (resp.statusCode == 200) {
        _resetStep = 2;
        _resetMessage = 'OTP verified. Enter new password.';
      } else {
        _resetMessage = _responseMessage(resp, 'Invalid OTP');
      }
    });
  }

  Future<void> confirmPasswordReset(StateSetter dialogSetState) async {
    if (_resetPassCtrl.text.length < 6) {
      dialogSetState(
        () => _resetMessage = 'Password must be at least 6 characters',
      );
      return;
    }

    dialogSetState(() {
      _isResetLoading = true;
      _resetMessage = null;
    });

    final resp = await http.post(
      Uri.parse('$backendUrl/api/password-reset/confirm/'),
      body: {
        'mobile_number': _resetMobileCtrl.text.trim(),
        'otp': _resetOtpCtrl.text.trim(),
        'new_password': _resetPassCtrl.text,
      },
    );

    dialogSetState(() => _isResetLoading = false);
    if (resp.statusCode == 200) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _status = 'Password reset successfully. Please login.');
      }
    } else {
      dialogSetState(() {
        _resetMessage = _responseMessage(resp, 'Unable to reset password');
      });
    }
  }

  void _showForgotPasswordDialog() {
    setState(() {
      _resetStep = 0;
      _resetMessage = null;
      _resetMobileCtrl.clear();
      _resetOtpCtrl.clear();
      _resetPassCtrl.clear();
    });

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final title = _resetStep == 0
                ? 'Forgot Password'
                : _resetStep == 1
                ? 'Verify OTP'
                : 'Reset Password';
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_resetStep == 0)
                      TextField(
                        controller: _resetMobileCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Registered Mobile Number',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else if (_resetStep == 1)
                      TextField(
                        controller: _resetOtpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'OTP',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      TextField(
                        controller: _resetPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Reset New Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (_resetMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _resetMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF1F2E5A)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isResetLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isResetLoading
                      ? null
                      : () {
                          if (_resetStep == 0) {
                            requestPasswordReset(dialogSetState);
                          } else if (_resetStep == 1) {
                            verifyPasswordResetOtp(dialogSetState);
                          } else {
                            confirmPasswordReset(dialogSetState);
                          }
                        },
                  child: _isResetLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_resetStep == 2 ? 'Reset' : 'Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> loadDashboardData() async {
    if (_token == null) {
      return;
    }

    setState(() {
      _isDashboardLoading = true;
      _dashboardError = null;
    });

    try {
      if (_isAdminRole) {
        final dashboard = await _apiGet('/api/admin/dashboard/');
        final employees = await _apiGet('/api/admin/employees/');
        final attendance = await _apiGet('/api/admin/attendance/');
        if (!mounted) {
          return;
        }
        setState(() {
          _adminDashboard = dashboard;
          _adminEmployees = employees?['employees'] as List<dynamic>? ?? [];
          _adminAttendance = attendance;
        });
        await _loadAdminTasks();
      } else if (_isHrRole) {
        final dashboard = await _apiGet('/api/dashboard/');
        final leaves = await _apiGet('/api/employee/leaves/');
        final tasks = await _apiGet('/api/employee/tasks/');
        final helpdesk = await _apiGet('/api/employee/helpdesk/');
        final directory = await _apiGet('/api/employee/directory/');
        if (!mounted) {
          return;
        }
        setState(() {
          _userDashboard = dashboard;
          if (leaves?['summary'] is Map<String, dynamic>) {
            _userDashboard?['leaves'] = leaves?['summary'];
          }
          _employeeLeaves =
              leaves?['leaves']?.whereType<Map<String, dynamic>>().toList() ??
              [];
          _employeeTasks =
              tasks?['tasks']?.whereType<Map<String, dynamic>>().toList() ?? [];
          _helpdeskTickets =
              helpdesk?['tickets']
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          _employeeDirectory =
              directory?['employees']
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          _currentUser = dashboard?['user'] as Map<String, dynamic>?;
        });
      } else {
        final dashboard = await _apiGet('/api/dashboard/');
        final leaves = await _apiGet('/api/employee/leaves/');
        final tasks = await _apiGet('/api/employee/tasks/');
        final helpdesk = await _apiGet('/api/employee/helpdesk/');
        final directory = await _apiGet('/api/employee/directory/');
        if (!mounted) {
          return;
        }
        setState(() {
          _userDashboard = dashboard;
          if (leaves?['summary'] is Map<String, dynamic>) {
            _userDashboard?['leaves'] = leaves?['summary'];
          }
          _employeeLeaves =
              leaves?['leaves']?.whereType<Map<String, dynamic>>().toList() ??
              [];
          _employeeTasks =
              tasks?['tasks']?.whereType<Map<String, dynamic>>().toList() ?? [];
          _helpdeskTickets =
              helpdesk?['tickets']
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          _employeeDirectory =
              directory?['employees']
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          _currentUser = dashboard?['user'] as Map<String, dynamic>?;
        });
        await loadAttendanceReport();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dashboardError = 'Unable to load dashboard: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDashboardLoading = false);
      }
    }
  }

  Future<void> refreshDashboardData() async {
    await loadDashboardData();
    if (mounted && _dashboardError == null) {
      _showNotification('Dashboard refreshed');
    }
  }

  Future<Position?> _getAttendanceLocation(String actionLabel) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showNotification(
        'Enable location services to $actionLabel',
        isError: true,
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      _showNotification('Please allow location access to $actionLabel');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showNotification('Location permission denied', isError: true);
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showNotification(
        'Location permission permanently denied',
        isError: true,
      );
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> checkOut() async {
    final pos = await _getAttendanceLocation('check out');
    if (pos == null) {
      return;
    }

    final resp = await http.post(
      Uri.parse('$backendUrl/api/checkout/'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Token $_token',
      },
      body: jsonEncode({
        'latitude': pos.latitude.toStringAsFixed(6),
        'longitude': pos.longitude.toStringAsFixed(6),
        'accuracy': pos.accuracy,
      }),
    );
    if (resp.statusCode == 201) {
      _showNotification('Checked out successfully');
      await loadDashboardData();
      if (_selectedMenu == 'Attendance') {
        await loadAttendanceReport();
      }
    } else {
      final detail = _responseDetail(resp.body);
      _showNotification('Check-out failed: $detail', isError: true);
    }
  }

  Future<void> login() async {
    if (_empIdCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _status = 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final requestedRole = _selectedRole;
      final resp = await http.post(
        Uri.parse('$backendUrl/api/auth/'),
        body: {
          'username': _empIdCtrl.text,
          'password': _passCtrl.text,
          'role': requestedRole,
        },
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = body['user'] as Map<String, dynamic>? ?? {};
        final backendRole = user['role'] as String?;
        final permissions =
            (user['dashboard_permissions'] as List<dynamic>?)
                ?.map((item) => item.toString().toLowerCase())
                .toSet() ??
            <String>{};
        if (backendRole != null &&
            backendRole.toLowerCase() != requestedRole.toLowerCase() &&
            !permissions.contains(requestedRole.toLowerCase())) {
          setState(() => _status = '');
          _showNotification(
            'Invalid Employee ID or Password',
            isError: true,
            duration: const Duration(seconds: 5),
          );
          return;
        }
        setState(() {
          _token = body['token'] as String?;
          _currentUser = user;
          _selectedRole = requestedRole;
          _selectedMenu = 'Dashboard';
          _selectedHrSection = 'Staff Directory';
          _status = 'Logged in successfully';
        });
        await loadDashboardData();
        // Auto-clear status after 1.5 seconds
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _status = '');
          }
        });
      } else {
        String message = 'Invalid Employee ID or Password';
        try {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          message = body['detail'] as String? ?? message;
        } catch (_) {}
        setState(() => _status = '');
        _showNotification(
          message,
          isError: true,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      setState(() => _status = 'Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showNotification(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? Colors.red : const Color(0xFF1ABE8E),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(duration, () {
      entry.remove();
    });
  }

  Future<void> _submitHelpdeskIssue() async {
    final issue = _helpdeskIssueCtrl.text.trim();
    if (issue.isEmpty) {
      _showNotification('Please enter your issue', isError: true);
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('$backendUrl/api/employee/helpdesk/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode({
          'subject': 'Employee support request',
          'description': issue,
        }),
      );
      if (resp.statusCode == 201) {
        _helpdeskIssueCtrl.clear();
        _showNotification('Issue submitted successfully');
        await loadDashboardData();
      } else {
        _showNotification(
          'Issue submit failed: ${resp.statusCode}',
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Issue submit failed: $e', isError: true);
    }
  }

  Future<void> _submitLeaveRequest(String selectedLeaveType) async {
    if (_leaveFromDate == null || _leaveToDate == null) {
      _showNotification('Please select leave dates', isError: true);
      return;
    }

    if (_leaveToDate!.isBefore(_leaveFromDate!)) {
      _showNotification('To date cannot be before from date', isError: true);
      return;
    }

    final requestedDays = _requestedLeaveDays();
    if (requestedDays <= 0) {
      _showNotification(
        'Please select at least one working day',
        isError: true,
      );
      return;
    }

    final reason = _leaveReasonCtrl.text.trim();
    if (reason.isEmpty) {
      _showNotification('Please enter a leave reason', isError: true);
      return;
    }

    setState(() => _isLeaveSubmitting = true);
    try {
      final cc = _leaveCcCtrl.text.trim();
      final fullReason = cc.isEmpty ? reason : '$reason\nCC: $cc';
      final resp = await http.post(
        Uri.parse('$backendUrl/api/employee/leaves/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode({
          'leave_type': selectedLeaveType,
          'from_date': _formatDateForApi(_leaveFromDate!),
          'to_date': _formatDateForApi(_leaveToDate!),
          'reason': fullReason,
        }),
      );

      if (resp.statusCode == 201) {
        setState(() {
          _leaveFromDate = null;
          _leaveToDate = null;
          _leaveFromSession = 'Session 1';
          _leaveToSession = 'Session 2';
          _leaveCcCtrl.clear();
          _leaveReasonCtrl.clear();
        });
        _showLeaveSubmittedSuccess();
        _showNotification('Leave request submitted');
        await loadDashboardData();
      } else {
        _showNotification(
          _responseMessage(resp, 'Leave submit failed'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Leave submit failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLeaveSubmitting = false);
      }
    }
  }

  Future<void> _submitRegularizationRequest(DateTime date) async {
    final reason = _regularizationReasonCtrl.text.trim();
    if (reason.isEmpty) {
      _showNotification(
        'Please enter reason for regularization',
        isError: true,
      );
      return;
    }

    final checkIn = _normalizeTimeForApi(_regularizationCheckInCtrl.text);
    final checkOut = _normalizeTimeForApi(_regularizationCheckOutCtrl.text);
    if (checkIn == null || checkOut == null) {
      _showNotification('Enter time in HH:mm format', isError: true);
      return;
    }

    setState(() => _isRegularizationSubmitting = true);
    try {
      final resp = await http.post(
        Uri.parse('$backendUrl/api/attendance-regularizations/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode({
          'date': _formatDateForApi(date),
          'check_in_time': checkIn,
          'check_out_time': checkOut,
          'cc': _regularizationCcCtrl.text.trim(),
          'reason': reason,
        }),
      );

      if (resp.statusCode == 201) {
        setState(() {
          _selectedRegularizationDate = null;
          _regularizationCcCtrl.clear();
          _regularizationCheckInCtrl.clear();
          _regularizationCheckOutCtrl.clear();
          _regularizationReasonCtrl.clear();
        });
        _showNotification('Regularization request submitted');
      } else {
        _showNotification(
          _responseMessage(resp, 'Regularization submit failed'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Regularization submit failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRegularizationSubmitting = false);
      }
    }
  }

  Future<void> _showRegularizationCcPicker() async {
    if (_employeeDirectory.isEmpty) {
      try {
        final directory = await _apiGet('/api/employee/directory/');
        if (!mounted) return;
        setState(() {
          _employeeDirectory =
              directory?['employees']
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
        });
      } catch (e) {
        _showNotification('Unable to load employees: $e', isError: true);
        return;
      }
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select CC Employee'),
          content: SizedBox(
            width: 360,
            child: _employeeDirectory.isEmpty
                ? const Text('No other employees found.')
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _employeeDirectory.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final employee = _employeeDirectory[index];
                        final name =
                            employee['name']?.toString().trim().isNotEmpty ==
                                true
                            ? employee['name'].toString()
                            : employee['username']?.toString() ?? 'Employee';
                        final employeeId =
                            employee['employee_id']?.toString() ??
                            employee['username']?.toString() ??
                            '';
                        final role = employee['role']?.toString() ?? '';
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(name),
                          subtitle: Text(
                            [
                              if (employeeId.isNotEmpty) employeeId,
                              if (role.isNotEmpty) role,
                            ].join(' · '),
                          ),
                          onTap: () {
                            setState(() {
                              _regularizationCcCtrl.text = name;
                            });
                            Navigator.of(dialogContext).pop();
                          },
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            if (_regularizationCcCtrl.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _regularizationCcCtrl.clear();
                  });
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Clear'),
              ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchSelectedPayslip() async {
    if (_token == null) return null;
    final month = _monthNumber(_selectedPayslipMonth);
    final resp = await http.get(
      Uri.parse(
        '$backendUrl/api/employee/salary/?month=$month&year=$_selectedPayslipYear',
      ),
      headers: {'Authorization': 'Token $_token'},
    );
    if (resp.statusCode != 200) {
      _showNotification(
        _responseMessage(resp, 'Unable to load payslip'),
        isError: true,
      );
      return null;
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final records = body['salary_records'] as List<dynamic>? ?? [];
    if (records.isEmpty) {
      _showNotification(
        'No published payslip found for selected month',
        isError: true,
      );
      return null;
    }
    return records.first as Map<String, dynamic>;
  }

  Future<void> _loadSelectedTasks() async {
    setState(() => _isTasksLoading = true);
    try {
      final tasks = await _apiGet('/api/employee/tasks/');
      if (!mounted) return;
      setState(() {
        _employeeTasks =
            tasks?['tasks']?.whereType<Map<String, dynamic>>().toList() ?? [];
      });
    } catch (e) {
      _showNotification('Unable to load tasks: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isTasksLoading = false);
    }
  }

  Future<void> _loadSelectedHelpdeskTickets() async {
    setState(() => _isHelpdeskLoading = true);
    try {
      final helpdesk = await _apiGet('/api/employee/helpdesk/');
      if (!mounted) return;
      setState(() {
        _helpdeskTickets =
            helpdesk?['tickets']?.whereType<Map<String, dynamic>>().toList() ??
            [];
      });
    } catch (e) {
      _showNotification('Unable to load helpdesk tickets: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isHelpdeskLoading = false);
    }
  }

  Future<void> _viewSelectedSalaryDetails() async {
    setState(() {
      _isSalaryDetailsLoading = true;
      _salaryDetailsError = null;
    });
    try {
      final record = await _fetchSelectedPayslip();
      if (!mounted) return;
      setState(() {
        _selectedSalaryRecord = record;
        if (record == null) {
          _salaryDetailsError = 'No salary details found for this month.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedSalaryRecord = null;
        _salaryDetailsError = 'No salary details found for this month.';
      });
    } finally {
      if (mounted) setState(() => _isSalaryDetailsLoading = false);
    }
  }

  Future<void> _viewSelectedPayslip() async {
    setState(() => _isPayslipLoading = true);
    try {
      final payslip = await _fetchSelectedPayslip();
      if (payslip == null || !mounted) return;
      _showPayslipDialog(payslip);
    } finally {
      if (mounted) {
        setState(() => _isPayslipLoading = false);
      }
    }
  }

  Future<void> _downloadSelectedPayslip() async {
    if (_token == null) return;
    setState(() => _isPayslipLoading = true);
    try {
      final month = _monthNumber(_selectedPayslipMonth);
      final resp = await http.get(
        Uri.parse(
          '$backendUrl/api/employee/salary/payslip/?month=$month&year=$_selectedPayslipYear',
        ),
        headers: {'Authorization': 'Token $_token'},
      );
      if (resp.statusCode != 200) {
        _showNotification(
          _responseMessage(resp, 'Unable to download payslip'),
          isError: true,
        );
        return;
      }

      downloadPdfFile(
        resp.bodyBytes,
        'payslip-$_selectedPayslipYear-${month.toString().padLeft(2, '0')}.pdf',
      );
      _showNotification('Payslip downloaded');
    } catch (e) {
      _showNotification('Unable to download payslip: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isPayslipLoading = false);
      }
    }
  }

  void _showPayslipDialog(Map<String, dynamic> payslip) {
    final gross = _moneyLabel(payslip['gross_salary']);
    final net = _moneyLabel(payslip['net_salary']);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Payslip - $_selectedPayslipMonth $_selectedPayslipYear'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSalaryAmountRow(
                  'Basic Salary',
                  _moneyLabel(payslip['basic_salary']),
                ),
                _buildSalaryAmountRow(
                  'Allowances',
                  _moneyLabel(payslip['allowances']),
                ),
                _buildSalaryAmountRow('Bonus', _moneyLabel(payslip['bonus'])),
                _buildSalaryAmountRow(
                  'Incentives',
                  _moneyLabel(payslip['incentives']),
                ),
                _buildSalaryAmountRow('Gross Salary', gross),
                const Divider(height: 24),
                _buildSalaryAmountRow(
                  'Deductions',
                  _moneyLabel(payslip['deductions']),
                ),
                _buildSalaryAmountRow(
                  'Tax Deducted',
                  _moneyLabel(payslip['tax_deducted']),
                ),
                _buildSalaryAmountRow('Net Salary', net, isHighlighted: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: _downloadSelectedPayslip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B5AF0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Download PDF'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _registerEmployee() async {
    final firstName = _employeeFirstNameCtrl.text.trim();
    final lastName = _employeeLastNameCtrl.text.trim();
    final dateOfBirth = _employeeDobCtrl.text.trim();
    final email = _employeeEmailCtrl.text.trim();
    final username = _employeeUsernameCtrl.text.trim();
    final password = _employeePasswordCtrl.text;
    final department = _employeeDepartmentCtrl.text.trim();
    final designation = _employeeDesignationCtrl.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      _showNotification(
        'First name, last name, email, username, and password are required',
        isError: true,
      );
      return;
    }
    if (!_employeeCanAccessUser &&
        !_employeeCanAccessAdmin &&
        !_employeeCanAccessHr) {
      _showNotification(
        'Select at least one dashboard permission',
        isError: true,
      );
      return;
    }

    setState(() => _isEmployeeSaving = true);
    try {
      final resp = await http.post(
        Uri.parse('$backendUrl/api/admin/employees/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'date_of_birth': dateOfBirth,
          'email': email,
          'username': username,
          'password': password,
          'department': department,
          'designation': designation,
          'can_access_user_dashboard': _employeeCanAccessUser,
          'can_access_admin_dashboard': _employeeCanAccessAdmin,
          'can_access_hr_dashboard': _employeeCanAccessHr,
        }),
      );

      if (resp.statusCode == 201) {
        _employeeFirstNameCtrl.clear();
        _employeeLastNameCtrl.clear();
        _employeeDobCtrl.clear();
        _employeeEmailCtrl.clear();
        _employeeUsernameCtrl.clear();
        _employeePasswordCtrl.clear();
        _employeeDepartmentCtrl.clear();
        _employeeDesignationCtrl.clear();
        setState(() {
          _employeeCanAccessUser = true;
          _employeeCanAccessAdmin = false;
          _employeeCanAccessHr = false;
        });
        _showNotification('Employee added successfully');
        await loadDashboardData();
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to add employee'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to add employee: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isEmployeeSaving = false);
      }
    }
  }

  int _employeeId(Map<String, dynamic> employee) {
    return (employee['id'] as num?)?.toInt() ?? 0;
  }

  String _employeeDisplayName(Map<String, dynamic> employee) {
    final name = employee['name']?.toString() ?? '-';
    final username = employee['username']?.toString() ?? '';
    return username.isEmpty ? name : '$name ($username)';
  }

  String _pendingRequestKey(String kind, int id) => '$kind-$id';

  List<Map<String, dynamic>> _adminEmployeeMaps() {
    return _adminEmployees.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic>? _selectedEditEmployee() {
    for (final employee in _adminEmployeeMaps()) {
      if (_employeeId(employee) == _selectedEditEmployeeId) {
        return employee;
      }
    }
    return null;
  }

  void _selectEditEmployee(int? employeeId) {
    final employee = _adminEmployeeMaps().firstWhere(
      (item) => _employeeId(item) == employeeId,
      orElse: () => <String, dynamic>{},
    );
    setState(() {
      _selectedEditEmployeeId = employeeId;
      _editEmployeeFirstNameCtrl.text =
          employee['first_name']?.toString() ?? '';
      _editEmployeeLastNameCtrl.text = employee['last_name']?.toString() ?? '';
      _editEmployeeDobCtrl.text = employee['date_of_birth']?.toString() ?? '';
      _editEmployeeEmailCtrl.text = employee['email']?.toString() ?? '';
      _editEmployeeUsernameCtrl.text = employee['username']?.toString() ?? '';
      _editEmployeeDepartmentCtrl.text =
          employee['department']?.toString() ?? '';
      _editEmployeeDesignationCtrl.text =
          employee['designation']?.toString() ?? '';
      _editEmployeePasswordCtrl.clear();
      final permissions =
          (employee['dashboard_permissions'] as List<dynamic>?)
              ?.map((item) => item.toString().toLowerCase())
              .toSet() ??
          <String>{};
      _editEmployeeCanAccessUser =
          permissions.isEmpty || permissions.contains('user');
      _editEmployeeCanAccessAdmin = permissions.contains('admin');
      _editEmployeeCanAccessHr = permissions.contains('hr');
    });
  }

  Future<void> _updateEmployeeDetails() async {
    final employeeId = _selectedEditEmployeeId;
    if (employeeId == null || employeeId == 0) {
      _showNotification('Select an employee first', isError: true);
      return;
    }

    final firstName = _editEmployeeFirstNameCtrl.text.trim();
    final lastName = _editEmployeeLastNameCtrl.text.trim();
    final dateOfBirth = _editEmployeeDobCtrl.text.trim();
    final email = _editEmployeeEmailCtrl.text.trim();
    final username = _editEmployeeUsernameCtrl.text.trim();
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        username.isEmpty) {
      _showNotification(
        'First name, last name, email, and username are required',
        isError: true,
      );
      return;
    }
    if (!_editEmployeeCanAccessUser &&
        !_editEmployeeCanAccessAdmin &&
        !_editEmployeeCanAccessHr) {
      _showNotification(
        'Select at least one dashboard permission',
        isError: true,
      );
      return;
    }

    setState(() => _isEmployeeSaving = true);
    try {
      final body = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'email': email,
        'username': username,
        'department': _editEmployeeDepartmentCtrl.text.trim(),
        'designation': _editEmployeeDesignationCtrl.text.trim(),
        'can_access_user_dashboard': _editEmployeeCanAccessUser,
        'can_access_admin_dashboard': _editEmployeeCanAccessAdmin,
        'can_access_hr_dashboard': _editEmployeeCanAccessHr,
        'is_active': _selectedEditEmployee()?['is_active'] == true,
      };
      final password = _editEmployeePasswordCtrl.text;
      if (password.isNotEmpty) {
        body['password'] = password;
      }

      final resp = await http.patch(
        Uri.parse('$backendUrl/api/admin/employees/$employeeId/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        _showNotification('Employee details updated');
        await loadDashboardData();
        _selectEditEmployee(employeeId);
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to update employee'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to update employee: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isEmployeeSaving = false);
      }
    }
  }

  Future<void> _updatePendingRequestStatus(
    String kind,
    int id,
    String statusValue, {
    bool closeDialog = false,
  }) async {
    final path = switch (kind) {
      'leave' => '/api/admin/leaves/$id/status/',
      'regularization' => '/api/admin/regularizations/$id/status/',
      'ticket' => '/api/admin/helpdesk/$id/status/',
      _ => '',
    };
    if (path.isEmpty) {
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('$backendUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode({'status': statusValue}),
      );
      if (resp.statusCode == 200) {
        _showNotification('Request submitted');
        _pendingRequestActions.remove(_pendingRequestKey(kind, id));
        if (closeDialog &&
            mounted &&
            Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        await loadDashboardData();
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to update request'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to update request: $e', isError: true);
    }
  }

  Map<String, dynamic>? _selectedLocationEmployee() {
    for (final raw in _adminEmployees) {
      if (raw is Map<String, dynamic> &&
          _employeeId(raw) == _selectedLocationEmployeeId) {
        return raw;
      }
    }
    return null;
  }

  void _selectLocationEmployee(int? employeeId) {
    final employee = _adminEmployees
        .whereType<Map<String, dynamic>>()
        .firstWhere(
          (item) => _employeeId(item) == employeeId,
          orElse: () => <String, dynamic>{},
        );
    final location = employee['assigned_location'] as Map<String, dynamic>?;
    setState(() {
      _selectedLocationEmployeeId = employeeId;
      _locationAddressCtrl.text = location?['address']?.toString() ?? '';
      _locationMapLinkCtrl.text = location?['map_url']?.toString() ?? '';
      _locationRadiusCtrl.text =
          location?['radius_meters']?.toString() ?? '100';
    });
  }

  Future<void> _saveEmployeeLocation() async {
    final employeeId = _selectedLocationEmployeeId;
    final address = _locationAddressCtrl.text.trim();
    final mapLink = _locationMapLinkCtrl.text.trim();
    final radius = int.tryParse(_locationRadiusCtrl.text.trim()) ?? 100;

    if (employeeId == null || employeeId == 0) {
      _showNotification('Select an employee first', isError: true);
      return;
    }
    if (address.isEmpty) {
      _showNotification('Enter the assigned work address', isError: true);
      return;
    }
    if (radius <= 0) {
      _showNotification('Radius must be greater than 0', isError: true);
      return;
    }

    setState(() => _isLocationSaving = true);
    try {
      final resp = await http.patch(
        Uri.parse('$backendUrl/api/admin/employees/$employeeId/location/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode({
          'name': 'Work Location',
          'address': address,
          'map_url': mapLink,
          'radius_meters': radius,
          'is_active': true,
        }),
      );

      if (resp.statusCode == 200) {
        _showNotification(
          'Location assigned successfully',
          duration: const Duration(seconds: 3),
        );
        setState(() => _showLocationAssignedPopup = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showLocationAssignedPopup = false);
          }
        });
        await loadDashboardData();
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to save location'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to save location: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLocationSaving = false);
      }
    }
  }

  Future<void> checkIn() async {
    final pos = await _getAttendanceLocation('check in');
    if (pos == null) {
      return;
    }

    final resp = await http.post(
      Uri.parse('$backendUrl/api/checkin/'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Token $_token',
      },
      body: jsonEncode({
        'latitude': pos.latitude.toStringAsFixed(6),
        'longitude': pos.longitude.toStringAsFixed(6),
        'accuracy': pos.accuracy,
      }),
    );
    if (resp.statusCode == 201) {
      _showNotification('Checked in successfully');
      await loadDashboardData();
      if (_selectedMenu == 'Attendance') {
        await loadAttendanceReport();
      }
    } else {
      final detail = _responseDetail(resp.body);
      _showNotification('Check-in failed: $detail', isError: true);
    }
  }

  String _responseDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail != null && detail.toString().isNotEmpty) {
          return detail.toString();
        }
      }
    } catch (_) {}
    return 'Please try again';
  }

  Future<void> loadAttendanceReport() async {
    if (_token == null) {
      return;
    }

    setState(() {
      _isReportLoading = true;
      _reportError = null;
    });

    try {
      final resp = await http.get(
        Uri.parse(
          '$backendUrl/api/attendance-report/?month=${_formatMonth(_selectedReportMonth)}',
        ),
        headers: {'Authorization': 'Token $_token'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _attendanceReport = AttendanceReport.fromJson(body);
        });
      } else {
        setState(() {
          _reportError = 'Unable to load report: ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _reportError = 'Unable to load report: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isReportLoading = false);
      }
    }
  }

  Future<void> _loadAdminAttendanceReport() async {
    if (_token == null) return;
    final params = <String, String>{};
    if (_selectedAdminAttendanceReportDate != null) {
      params['date'] = _dateKey(_selectedAdminAttendanceReportDate)!;
    } else {
      params['year'] = _selectedAdminAttendanceReportMonth.year.toString();
      params['month'] = _selectedAdminAttendanceReportMonth.month.toString();
    }
    if (_selectedAdminReportEmployeeId != null) {
      params['employee_id'] = _selectedAdminReportEmployeeId.toString();
    }
    final uri = Uri.parse(
      '$backendUrl/api/admin/attendance/',
    ).replace(queryParameters: params);
    try {
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Token $_token'},
      );
      if (resp.statusCode == 200) {
        setState(() {
          _adminAttendanceReport =
              jsonDecode(resp.body) as Map<String, dynamic>;
        });
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to load attendance report'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to load attendance report: $e', isError: true);
    }
  }

  Future<void> _loadAdminTasks() async {
    if (_token == null) return;
    final params = <String, String>{'status': _selectedAdminTaskStatus};
    if (_selectedAdminTaskDate != null) {
      params['date'] = _dateKey(_selectedAdminTaskDate)!;
    } else {
      params['year'] = _selectedAdminTaskMonth.year.toString();
      params['month'] = _selectedAdminTaskMonth.month.toString();
    }
    final uri = Uri.parse(
      '$backendUrl/api/admin/tasks/',
    ).replace(queryParameters: params);
    try {
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Token $_token'},
      );
      if (resp.statusCode == 200) {
        setState(() {
          _adminTasks = jsonDecode(resp.body) as Map<String, dynamic>;
        });
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to load work monitoring'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to load work monitoring: $e', isError: true);
    }
  }

  void _selectMenu(String menuKey) {
    setState(() {
      _selectedMenu = menuKey;
      if (menuKey == 'Attendance') {
        _selectedAttendanceSection = 'Daily Attendance';
        _selectedAdminAttendanceSection = 'Daily Attendances';
      } else if (menuKey == 'Tasks') {
        _selectedTaskSection = 'Pending Tasks';
      } else if (menuKey == 'Leaves') {
        _selectedLeaveSection = 'Apply Leave';
      } else if (menuKey == 'Salary') {
        _selectedSalarySection = 'Payslips';
      } else if (menuKey == 'Employee Management') {
        if (_isAdminRole) {
          _selectedAttendanceSection = 'Edit Employee';
        } else {
          _selectedHrSection = 'Staff Directory';
        }
      } else if (menuKey == 'Smart Location Management') {
        _selectedAttendanceSection = 'Edit Location';
      } else if (menuKey == 'Work Monitoring') {
        _selectedAdminTaskStatus = 'assigned';
      } else if (menuKey == 'Pending Requests') {
        _selectedPendingRequestStatus = 'pending';
      } else if (menuKey == 'Helpdesk' || menuKey == 'Help Desk') {
        _selectedHrSection = 'Help Desk';
      } else if (menuKey == 'Attendance Management') {
        _selectedHrSection = 'Daily Attendance';
      } else if (menuKey == 'Recruitment') {
        _selectedHrSection = 'Job Openings';
      } else if (menuKey == 'Payroll') {
        _selectedHrSection = 'Salary Management';
      } else if (menuKey == 'Performance') {
        _selectedHrSection = 'Performance Tracker';
      }
    });
    if (menuKey == 'Attendance') {
      loadAttendanceReport();
      if (_isAdminRole && _selectedAttendanceSection == 'Attendance Reports') {
        _loadAdminAttendanceReport();
      }
    }
    if (menuKey == 'Work Monitoring') {
      _loadAdminTasks();
    }
    if (menuKey == 'Helpdesk' || menuKey == 'Help Desk') {
      _loadSelectedHelpdeskTickets();
    }
    if (menuKey == 'Dashboard' ||
        menuKey == 'Employees' ||
        menuKey == 'Attendance' ||
        menuKey == 'Pending Requests') {
      loadDashboardData();
    }
  }

  void _selectAttendanceSection(String section) {
    setState(() {
      _selectedMenu = 'Attendance';
      _selectedAttendanceSection = section;
      if (section == 'Regularization Attendance') {
        _selectedRegularizationDate = null;
      }
    });
    if (section == 'Daily Attendance' ||
        section == 'Regularization Attendance') {
      loadAttendanceReport();
    }
  }

  void _selectTaskSection(String section) {
    setState(() {
      _selectedMenu = 'Tasks';
      _selectedTaskSection = section;
    });
  }

  void _selectLeaveSection(String section) {
    setState(() {
      _selectedMenu = 'Leaves';
      _selectedLeaveSection = section;
      if (section == 'Leave Overview') {
        _selectedLeaveOverview = 'Leave History';
      }
      if (section != 'Apply Leave') {
        _selectedApplyLeaveType = null;
      }
    });
  }

  void _selectSalarySection(String section) {
    setState(() {
      _selectedMenu = 'Salary';
      _selectedSalarySection = section;
    });
  }

  void _selectHrSection(String menu, String section) {
    setState(() {
      _selectedMenu = menu;
      _selectedHrSection = section;
    });
  }

  void _changeReportMonth(int monthDelta) {
    setState(() {
      _selectedReportMonth = DateTime(
        _selectedReportMonth.year,
        _selectedReportMonth.month + monthDelta,
      );
      _selectedRegularizationDate = null;
    });
    loadAttendanceReport();
  }

  void _setReportMonth({int? month, int? year}) {
    setState(() {
      _selectedReportMonth = DateTime(
        year ?? _selectedReportMonth.year,
        month ?? _selectedReportMonth.month,
      );
      _selectedRegularizationDate = null;
    });
    loadAttendanceReport();
  }

  String _formatMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _monthLabel(DateTime date) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  String _longDateLabel(DateTime date) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _regularizationDateLabel(String rawDate) {
    final date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;
    const monthNames = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const weekdayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final day = date.day.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$day-${monthNames[date.month - 1]}-$year ${weekdayNames[date.weekday - 1]}';
  }

  String _regularizationDateOnly(String rawDate) {
    final date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;
    const monthNames = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$day-${monthNames[date.month - 1]}-$year';
  }

  String _readableDate(String rawDate) {
    final date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _hoursLabel(double hours) {
    final minutes = (hours * 60).round();
    final wholeHours = (minutes ~/ 60).toString().padLeft(2, '0');
    final remainingMinutes = (minutes % 60).toString().padLeft(2, '0');
    return '$wholeHours:$remainingMinutes';
  }

  Future<void> _pickLeaveDate({required bool isFromDate}) async {
    final selectedDate = await _showLeaveCalendarPicker(
      initialDate:
          (isFromDate ? _leaveFromDate : _leaveToDate) ??
          (isFromDate ? DateTime.now() : _leaveFromDate ?? DateTime.now()),
    );
    if (selectedDate == null) return;

    setState(() {
      if (isFromDate) {
        _leaveFromDate = selectedDate;
        if (_leaveToDate != null && _leaveToDate!.isBefore(selectedDate)) {
          _leaveToDate = selectedDate;
        }
      } else {
        _leaveToDate = selectedDate;
        if (_leaveFromDate != null && _leaveFromDate!.isAfter(selectedDate)) {
          _leaveFromDate = selectedDate;
        }
      }
    });
  }

  Future<DateTime?> _showLeaveCalendarPicker({
    required DateTime initialDate,
  }) async {
    DateTime visibleMonth = DateTime(initialDate.year, initialDate.month);
    DateTime? selectedDate = initialDate;

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              title: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () {
                      setDialogState(() {
                        visibleMonth = DateTime(
                          visibleMonth.year,
                          visibleMonth.month - 1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      _formatMonth(visibleMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1F2E5A),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () {
                      setDialogState(() {
                        visibleMonth = DateTime(
                          visibleMonth.year,
                          visibleMonth.month + 1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              content: SizedBox(
                width: 390,
                child: _buildLeaveDatePickerCalendar(
                  visibleMonth,
                  selectedDate,
                  (date) {
                    setDialogState(() {
                      selectedDate = date;
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedDate == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5AF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = _token != null;

    return Scaffold(
      body: isLoggedIn
          ? _buildLoggedInView()
          : Row(
              children: [
                // Left Side - Branding
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey[200],
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HealOn',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                color: const Color(0xFF1ABE8E),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Attendance',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                color: const Color(0xFF1ABE8E),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          '"Excellence in care begins the moment you arrive. Welcome back."',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF1ABE8E),
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Side - Login Form
                Expanded(
                  flex: 1,
                  child: Container(
                    color: const Color(0xFF1ABE8E),
                    padding: const EdgeInsets.all(48),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Avatar
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Welcome Text
                                Text(
                                  'Welcome back! Please enter your details',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                                const SizedBox(height: 32),

                                // Username Field
                                Center(
                                  child: SizedBox(
                                    width: 300,
                                    height: 44,
                                    child: TextField(
                                      controller: _empIdCtrl,
                                      enabled: !_isLoading,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'username',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Password Field
                                Center(
                                  child: SizedBox(
                                    width: 300,
                                    height: 44,
                                    child: TextField(
                                      controller: _passCtrl,
                                      enabled: !_isLoading,
                                      obscureText: !_showPassword,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'password',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () => setState(
                                            () =>
                                                _showPassword = !_showPassword,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Forgot Password Link
                                Center(
                                  child: SizedBox(
                                    width: 300,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _showForgotPasswordDialog,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: const Text(
                                          'Forgot Password',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Remember Me Checkbox
                                Center(
                                  child: SizedBox(
                                    width: 300,
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) => setState(
                                            () => _rememberMe = value ?? false,
                                          ),
                                          fillColor: WidgetStateProperty.all(
                                            Colors.white,
                                          ),
                                          checkColor: const Color(0xFF1ABE8E),
                                        ),
                                        const Expanded(
                                          child: Text(
                                            'Remember user details',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                            softWrap: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Role Dropdown - Centered and Small
                                Center(
                                  child: SizedBox(
                                    width: 150,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedRole,
                                      onChanged: (value) => setState(
                                        () => _selectedRole = value ?? 'User',
                                      ),
                                      items: ['User', 'Admin', 'HR']
                                          .map(
                                            (role) => DropdownMenuItem(
                                              value: role,
                                              child: Text(role),
                                            ),
                                          )
                                          .toList(),
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Login Button - Small and Centered
                                Center(
                                  child: SizedBox(
                                    width: 150,
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0066FF,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                // Status Message
                                if (_status.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white),
                                    ),
                                    child: Text(
                                      _status,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoggedInView() {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            color: const Color(0xFF1F2E5A),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF1F2E5A),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1ABE8E),
                        ),
                        child: Icon(
                          _isAdminRole
                              ? Icons.admin_panel_settings
                              : _isHrRole
                              ? Icons.badge
                              : Icons.person,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isAdminRole
                            ? 'Admin Panel'
                            : _isHrRole
                            ? 'HR Panel'
                            : 'Employee Panel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Menu Items
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // DASHBOARD
                        _buildMenuItem(
                          'Dashboard',
                          Icons.dashboard,
                          'Dashboard',
                        ),

                        // ================= EMPLOYEE PANEL =================
                        if (!_isAdminRole && !_isHrRole) ...[
                          // ATTENDANCE
                          _buildMenuItem(
                            'Attendance',
                            Icons.access_time,
                            'Attendance',
                          ),

                          if (_selectedMenu == 'Attendance') ...[
                            _buildSubMenuItem(
                              'Daily Attendance',
                              _selectedAttendanceSection == 'Daily Attendance',
                              () =>
                                  _selectAttendanceSection('Daily Attendance'),
                            ),

                            _buildSubMenuItem(
                              'Regularization Attendance',
                              _selectedAttendanceSection ==
                                  'Regularization Attendance',
                              () => _selectAttendanceSection(
                                'Regularization Attendance',
                              ),
                            ),
                          ],

                          // LEAVES
                          _buildMenuItem(
                            'Leaves',
                            Icons.calendar_today,
                            'Leaves',
                          ),

                          if (_selectedMenu == 'Leaves') ...[
                            _buildSubMenuItem(
                              'Apply Leave',
                              _selectedLeaveSection == 'Apply Leave',
                              () => _selectLeaveSection('Apply Leave'),
                            ),

                            _buildSubMenuItem(
                              'Leave Calendar',
                              _selectedLeaveSection == 'Leave Calendar',
                              () => _selectLeaveSection('Leave Calendar'),
                            ),

                            _buildSubMenuItem(
                              'Leave Overview',
                              _selectedLeaveSection == 'Leave Overview',
                              () => _selectLeaveSection('Leave Overview'),
                            ),
                          ],

                          // TASKS
                          _buildMenuItem('Tasks', Icons.task, 'Tasks'),

                          if (_selectedMenu == 'Tasks') ...[
                            _buildSubMenuItem(
                              'Pending Tasks',
                              _selectedTaskSection == 'Pending Tasks',
                              () => _selectTaskSection('Pending Tasks'),
                            ),

                            _buildSubMenuItem(
                              'Completed Tasks',
                              _selectedTaskSection == 'Completed Tasks',
                              () => _selectTaskSection('Completed Tasks'),
                            ),
                          ],

                          // SALARY
                          _buildMenuItem('Salary', Icons.payment, 'Salary'),

                          if (_selectedMenu == 'Salary') ...[
                            _buildSubMenuItem(
                              'Payslips',
                              _selectedSalarySection == 'Payslips',
                              () => _selectSalarySection('Payslips'),
                            ),

                            _buildSubMenuItem(
                              'Compensation & Benefits',
                              _selectedSalarySection ==
                                  'Compensation & Benefits',
                              () => _selectSalarySection(
                                'Compensation & Benefits',
                              ),
                            ),

                            _buildSubMenuItem(
                              'Bonus & Incentives',
                              _selectedSalarySection == 'Bonus & Incentives',
                              () => _selectSalarySection('Bonus & Incentives'),
                            ),

                            _buildSubMenuItem(
                              'Tax Details',
                              _selectedSalarySection == 'Tax Details',
                              () => _selectSalarySection('Tax Details'),
                            ),
                          ],

                          _buildMenuItem('Helpdesk', Icons.help, 'Helpdesk'),

                          _buildMenuItem(
                            'Reports',
                            Icons.assessment,
                            'Reports',
                          ),
                        ],

                        // ================= HR PANEL =================
                        if (_isHrRole) ...[
                          _buildMenuItem(
                            'Employee Management',
                            Icons.groups,
                            'Employee Management',
                          ),
                          if (_selectedMenu == 'Employee Management') ...[
                            _buildSubMenuItem(
                              'Staff Directory',
                              _selectedHrSection == 'Staff Directory',
                              () => _selectHrSection(
                                'Employee Management',
                                'Staff Directory',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Smart Onboarding',
                              _selectedHrSection == 'Smart Onboarding',
                              () => _selectHrSection(
                                'Employee Management',
                                'Smart Onboarding',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Employee Profile',
                              _selectedHrSection == 'Employee Profile',
                              () => _selectHrSection(
                                'Employee Management',
                                'Employee Profile',
                              ),
                            ),
                          ],
                          _buildMenuItem(
                            'Attendance Management',
                            Icons.access_time,
                            'Attendance Management',
                          ),
                          if (_selectedMenu == 'Attendance Management') ...[
                            _buildSubMenuItem(
                              'Daily Attendance',
                              _selectedHrSection == 'Daily Attendance',
                              () => _selectHrSection(
                                'Attendance Management',
                                'Daily Attendance',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Attendance Insights',
                              _selectedHrSection == 'Attendance Insights',
                              () => _selectHrSection(
                                'Attendance Management',
                                'Attendance Insights',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Attendance Reports',
                              _selectedHrSection == 'Attendance Reports',
                              () => _selectHrSection(
                                'Attendance Management',
                                'Attendance Reports',
                              ),
                            ),
                          ],
                          _buildMenuItem(
                            'Recruitment',
                            Icons.how_to_reg,
                            'Recruitment',
                          ),
                          if (_selectedMenu == 'Recruitment') ...[
                            _buildSubMenuItem(
                              'Job Openings',
                              _selectedHrSection == 'Job Openings',
                              () => _selectHrSection(
                                'Recruitment',
                                'Job Openings',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Candidate Management',
                              _selectedHrSection == 'Candidate Management',
                              () => _selectHrSection(
                                'Recruitment',
                                'Candidate Management',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Interview',
                              _selectedHrSection == 'Interview',
                              () =>
                                  _selectHrSection('Recruitment', 'Interview'),
                            ),
                          ],
                          _buildMenuItem(
                            'Payroll',
                            Icons.account_balance_wallet,
                            'Payroll',
                          ),
                          if (_selectedMenu == 'Payroll') ...[
                            _buildSubMenuItem(
                              'Salary Management',
                              _selectedHrSection == 'Salary Management',
                              () => _selectHrSection(
                                'Payroll',
                                'Salary Management',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Payslips',
                              _selectedHrSection == 'Payslips',
                              () => _selectHrSection('Payroll', 'Payslips'),
                            ),
                            _buildSubMenuItem(
                              'Payroll Reports',
                              _selectedHrSection == 'Payroll Reports',
                              () => _selectHrSection(
                                'Payroll',
                                'Payroll Reports',
                              ),
                            ),
                          ],
                          _buildMenuItem(
                            'Performance',
                            Icons.insights,
                            'Performance',
                          ),
                          if (_selectedMenu == 'Performance') ...[
                            _buildSubMenuItem(
                              'Performance Tracker',
                              _selectedHrSection == 'Performance Tracker',
                              () => _selectHrSection(
                                'Performance',
                                'Performance Tracker',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Evaluations',
                              _selectedHrSection == 'Evaluations',
                              () => _selectHrSection(
                                'Performance',
                                'Evaluations',
                              ),
                            ),
                            _buildSubMenuItem(
                              'Rewards and Recognition',
                              _selectedHrSection == 'Rewards and Recognition',
                              () => _selectHrSection(
                                'Performance',
                                'Rewards and Recognition',
                              ),
                            ),
                          ],
                          _buildMenuItem(
                            'Help Desk',
                            Icons.support_agent,
                            'Help Desk',
                          ),
                        ],

                        // ================= ADMIN PANEL =================
                        if (_isAdminRole) ...[
                          // EMPLOYEE MANAGEMENT
                          _buildMenuItem(
                            'Employee Management',
                            Icons.people,
                            'Employee Management',
                          ),

                          if (_selectedMenu == 'Employee Management') ...[
                            _buildSubMenuItem(
                              'Add Employee',
                              _selectedAttendanceSection == 'Add Employee',
                              () {
                                setState(() {
                                  _selectedMenu = 'Employee Management';
                                  _selectedAttendanceSection = 'Add Employee';
                                });
                              },
                            ),

                            _buildSubMenuItem(
                              'Edit Employee',
                              _selectedAttendanceSection == 'Edit Employee',
                              () {
                                setState(() {
                                  _selectedMenu = 'Employee Management';
                                  _selectedAttendanceSection = 'Edit Employee';
                                });
                              },
                            ),
                          ],

                          // SMART LOCATION MANAGEMENT
                          _buildMenuItem(
                            'Smart Location Management',
                            Icons.location_on,
                            'Smart Location Management',
                          ),

                          if (_selectedMenu == 'Smart Location Management') ...[
                            _buildSubMenuItem(
                              'Add Location',
                              _selectedAttendanceSection == 'Add Location',
                              () {
                                setState(() {
                                  _selectedMenu = 'Smart Location Management';
                                  _selectedAttendanceSection = 'Add Location';
                                });
                              },
                            ),
                            _buildSubMenuItem(
                              'Edit Location',
                              _selectedAttendanceSection == 'Edit Location',
                              () {
                                setState(() {
                                  _selectedMenu = 'Smart Location Management';
                                  _selectedAttendanceSection = 'Edit Location';
                                });
                              },
                            ),
                          ],

                          // ATTENDANCE
                          _buildMenuItem(
                            'Attendance',
                            Icons.access_time,
                            'Attendance',
                          ),

                          if (_selectedMenu == 'Attendance') ...[
                            _buildSubMenuItem(
                              'Daily Attendance',
                              _selectedAttendanceSection == 'Daily Attendance',
                              () {
                                setState(() {
                                  _selectedMenu = 'Attendance';
                                  _selectedAttendanceSection =
                                      'Daily Attendance';
                                });
                              },
                            ),

                            _buildSubMenuItem(
                              'Attendance Reports',
                              _selectedAttendanceSection ==
                                  'Attendance Reports',
                              () {
                                setState(() {
                                  _selectedMenu = 'Attendance';
                                  _selectedAttendanceSection =
                                      'Attendance Reports';
                                });
                                _loadAdminAttendanceReport();
                              },
                            ),
                          ],

                          // WORK MONITORING
                          _buildMenuItem(
                            'Work Monitoring',
                            Icons.work,
                            'Work Monitoring',
                          ),

                          _buildMenuItem('Helpdesk', Icons.help, 'Helpdesk'),
                        ],
                      ],
                    ),
                  ),
                ),
                // Logout
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() {
                        _token = null;
                        _empIdCtrl.clear();
                        _passCtrl.clear();
                        _status = '';
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: _isAdminRole
                ? _selectedMenu == 'Attendance'
                      ? _buildAdminAttendanceView()
                      : _selectedMenu == 'Employee Management'
                      ? _selectedAttendanceSection == 'Add Employee'
                            ? _buildEmployeeRegistrationView()
                            : _buildAdminEmployeesView()
                      : _selectedMenu == 'Smart Location Management'
                      ? _buildSmartLocationManagementView()
                      : _selectedMenu == 'Work Monitoring'
                      ? _buildWorkMonitoringDashboard()
                      : _selectedMenu == 'Pending Requests'
                      ? _buildPendingRequestsDashboard()
                      : _selectedMenu == 'Helpdesk'
                      ? _buildHelpdeskView()
                      : _buildAdminDashboard()
                : _isHrRole
                ? _selectedMenu == 'Help Desk'
                      ? _buildHelpdeskView()
                      : _selectedMenu == 'Dashboard'
                      ? _buildHrDashboardView()
                      : _buildHrSectionView()
                : _selectedMenu == 'Attendance'
                ? _buildAttendanceReportView()
                : _selectedMenu == 'Tasks'
                ? _buildTasksView()
                : _selectedMenu == 'Leaves'
                ? _buildLeavesView()
                : _selectedMenu == 'Salary'
                ? _buildSalaryView()
                : _selectedMenu == 'Helpdesk'
                ? _buildHelpdeskView()
                : _selectedMenu == 'Reports'
                ? _buildEmployeeReportsView()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome Back 👋',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'User Dashboard - ${_currentUser?['name'] ?? 'Employee'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: const Color(0xFF1F2E5A),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Track your attendance, working hours and leave requests easily.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filled(
                              tooltip: 'Refresh dashboard',
                              onPressed: _isDashboardLoading
                                  ? null
                                  : refreshDashboardData,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF2B5AF0),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              icon: _isDashboardLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        if (_isDashboardLoading)
                          const LinearProgressIndicator()
                        else if (_dashboardError != null)
                          _buildReportMessage(
                            icon: Icons.error_outline,
                            title: 'Dashboard not connected',
                            message: _dashboardError!,
                            actionLabel: 'Retry',
                            onAction: loadDashboardData,
                          ),
                        if (_isDashboardLoading || _dashboardError != null)
                          const SizedBox(height: 24),

                        // Check In/Out Buttons
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: checkIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1ABE8E),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                'Check In',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: checkOut,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                'Check Out',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: 260,
                              child: _buildSummaryTile(
                                'Present Days',
                                _readInt(
                                  _userSection('attendance'),
                                  'present_days_this_month',
                                ).toString(),
                                Icons.event_available,
                                const Color(0xFF1ABE8E),
                                isCompact: true,
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child: _buildSummaryTile(
                                'Leave Balance',
                                _readInt(
                                  _userSection('leaves'),
                                  'available',
                                ).toString(),
                                Icons.event_note,
                                Colors.orange,
                                isCompact: true,
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child: _buildSummaryTile(
                                'Leave Applied',
                                _readInt(
                                  _userSection('leaves'),
                                  'applied',
                                ).toString(),
                                Icons.pending_actions,
                                Colors.orange,
                                isCompact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Main Content Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left - Upcoming Holidays
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        size: 24,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Upcoming Holidays',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ..._dashboardHolidayRows().map(
                                    (holiday) => _buildHolidayCard(
                                      holiday['name']!,
                                      holiday['date']!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Right - Cards
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  _buildDashboardCard(
                                    'Work Assigned',
                                    '${_readInt(_userSection('tasks'), 'assigned')} Pending Tasks',
                                    Icons.work_outline,
                                    const Color(0xFF2B5AF0),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildDashboardCard(
                                    'Review Tasks',
                                    '${_readInt(_userSection('tasks'), 'review_pending')} Reviews Pending',
                                    Icons.assignment_turned_in,
                                    Colors.orange,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Status Message
                        if (_status.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  _status.contains('Check-in') ||
                                      _status.contains('Check-out')
                                  ? Colors.green[50]
                                  : Colors.red[50],
                              border: Border.all(
                                color:
                                    _status.contains('Check-in') ||
                                        _status.contains('Check-out')
                                    ? Colors.green[300]!
                                    : Colors.red[300]!,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _status,
                              style: TextStyle(
                                color:
                                    _status.contains('Check-in') ||
                                        _status.contains('Check-out')
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceReportView() {
    final report = _attendanceReport;
    final isDailyAttendance = _selectedAttendanceSection == 'Daily Attendance';
    final isInsights = _selectedAttendanceSection == 'Attendances Insights';
    final isReports = _selectedAttendanceSection == 'Attendances Reports';
    final filteredDays =
        report?.days.where((day) {
          if (_selectedDailyAttendanceStatus == 'All') return true;
          return day.status == _selectedDailyAttendanceStatus;
        }).toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: const Color(0xFF1F2E5A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Review daily attendance, precise location check-ins, and regularization requests.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              if (isDailyAttendance) ...[
                const SizedBox(height: 22),
                Center(child: _buildDailyAttendanceFilters()),
              ],
            ],
          ),
          const SizedBox(height: 28),
          if (isInsights)
            _buildAttendancesInsightsSection(report)
          else if (isReports)
            _buildAttendancesReportsSection(report)
          else if (!isDailyAttendance)
            _buildRegularizationAttendanceSection()
          else ...[
            _buildTodayAttendanceCard(),
            const SizedBox(height: 22),
            if (_isReportLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_reportError != null)
              _buildReportMessage(
                icon: Icons.error_outline,
                title: 'Could not load report',
                message: _reportError!,
                actionLabel: 'Retry',
                onAction: loadAttendanceReport,
              )
            else if (report == null)
              _buildReportMessage(
                icon: Icons.calendar_month,
                title: 'Report not loaded',
                message: 'Open Attendance again or retry to load your records.',
                actionLabel: 'Load report',
                onAction: loadAttendanceReport,
              )
            else if (filteredDays.isEmpty)
              _buildReportMessage(
                icon: Icons.inbox_outlined,
                title: 'No attendance records',
                message: 'There are no check-in records for this month yet.',
              )
            else
              _buildReportTable(filteredDays),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayAttendanceCard() {
    final attendance = _userSection('attendance');
    final checkedIn = attendance?['checked_in_today'] == true;
    final checkedOut = attendance?['checked_out_today'] == true;
    final checkInTime = attendance?['today_check_in']?.toString();
    final checkOutTime = attendance?['today_check_out']?.toString();
    final status = checkedOut
        ? 'Checked Out'
        : checkedIn
        ? 'Checked In'
        : 'Not Checked In';
    final statusColor = checkedOut
        ? Colors.red
        : checkedIn
        ? const Color(0xFF1ABE8E)
        : Colors.orange;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.today_outlined, color: Color(0xFF1F2E5A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Today's Attendance",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1F2E5A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusPill(status),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildTodayAttendanceValue(
                      'Check In',
                      checkInTime?.isNotEmpty == true ? checkInTime! : '-',
                      Icons.login,
                      const Color(0xFF1ABE8E),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTodayAttendanceValue(
                      'Check Out',
                      checkOutTime?.isNotEmpty == true ? checkOutTime! : '-',
                      Icons.logout,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTodayAttendanceValue(
                      'Status',
                      status,
                      Icons.verified_outlined,
                      statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayAttendanceValue(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2E5A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyAttendanceFilters() {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      6,
      (index) => (currentYear - 4 + index).toString(),
    );
    const statuses = ['All', 'Present', 'Absent', 'Incomplete'];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedDailyAttendanceStatus,
              decoration: _salaryInputDecoration(label: 'Status'),
              items: statuses.map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedDailyAttendanceStatus = value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedReportMonth.month,
              decoration: _salaryInputDecoration(label: 'Month'),
              items: List.generate(12, (index) {
                final month = index + 1;
                return DropdownMenuItem(
                  value: month,
                  child: Text(_monthName(month)),
                );
              }),
              onChanged: _isReportLoading
                  ? null
                  : (value) {
                      if (value == null) return;
                      _setReportMonth(month: value);
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedReportMonth.year.toString(),
              decoration: _salaryInputDecoration(label: 'Year'),
              items: years.map((year) {
                return DropdownMenuItem(value: year, child: Text(year));
              }).toList(),
              onChanged: _isReportLoading
                  ? null
                  : (value) {
                      if (value == null) return;
                      _setReportMonth(year: int.parse(value));
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularizationAttendanceSection() {
    final report = _attendanceReport;
    if (_isReportLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_reportError != null) {
      return _buildReportMessage(
        icon: Icons.error_outline,
        title: 'Could not load regularization',
        message: _reportError!,
        actionLabel: 'Retry',
        onAction: loadAttendanceReport,
      );
    }

    final days = report?.days ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance Regularization',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: Colors.grey[200]),
        const SizedBox(height: 14),
        _buildRegularizationToolbar(),
        const SizedBox(height: 18),
        _buildRegularizationCalendarWithSidePanel(days),
        const SizedBox(height: 12),
        _buildRegularizationLegend(),
      ],
    );
  }

  Widget _buildRegularizationToolbar() {
    return _buildReportMonthYearControls(maxWidth: 520);
  }

  Widget _buildReportMonthYearControls({double maxWidth = 560}) {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      6,
      (index) => (currentYear - 4 + index).toString(),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _selectedReportMonth.month,
                decoration: _salaryInputDecoration(label: 'Month'),
                items: List.generate(12, (index) {
                  final month = index + 1;
                  return DropdownMenuItem(
                    value: month,
                    child: Text(_monthName(month)),
                  );
                }),
                onChanged: _isReportLoading
                    ? null
                    : (value) {
                        if (value == null) return;
                        _setReportMonth(month: value);
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedReportMonth.year.toString(),
                decoration: _salaryInputDecoration(label: 'Year'),
                items: years.map((year) {
                  return DropdownMenuItem(value: year, child: Text(year));
                }).toList(),
                onChanged: _isReportLoading
                    ? null
                    : (value) {
                        if (value == null) return;
                        _setReportMonth(year: int.parse(value));
                      },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isReportLoading ? null : loadAttendanceReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B5AF0),
                foregroundColor: Colors.white,
                minimumSize: const Size(86, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isReportLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('View'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarBox({required Widget child}) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _buildRegularizationCalendarWithSidePanel(
    List<AttendanceReportDay> days,
  ) {
    final selectedDay = _selectedRegularizationDate == null
        ? null
        : _attendanceDayForDate(days, _selectedRegularizationDate!);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackPanel = constraints.maxWidth < 980;
        final calendar = _buildRegularizationCalendar(days);
        final panel = _selectedRegularizationDate == null
            ? null
            : _buildRegularizationQuickPanel(
                date: _selectedRegularizationDate!,
                day: selectedDay,
              );

        if (panel == null) {
          return calendar;
        }

        if (stackPanel) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              calendar,
              const SizedBox(height: 14),
              SizedBox(width: 340, child: panel),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: calendar),
            const SizedBox(width: 18),
            SizedBox(width: 340, child: panel),
          ],
        );
      },
    );
  }

  Widget _buildRegularizationQuickPanel({
    required DateTime date,
    required AttendanceReportDay? day,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _leaveDateLabel(date),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Request Type',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: 'Regularization',
            decoration: _regularizationInputDecoration(),
            items: const [
              DropdownMenuItem(
                value: 'Regularization',
                child: Text('Regularization'),
              ),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          _buildRegularizationCcBox(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRegularizationTimeField(
                  'Check In Time',
                  day?.checkIn ?? '10:00',
                  _regularizationCheckInCtrl,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRegularizationTimeField(
                  'Check Out Time',
                  day?.checkOut ?? '19:00',
                  _regularizationCheckOutCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Reason',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _regularizationReasonCtrl,
            maxLines: 3,
            decoration: _regularizationInputDecoration(
              hintText: 'Write reason for regularization',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedRegularizationDate = null;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isRegularizationSubmitting
                    ? null
                    : () => _submitRegularizationRequest(date),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D82FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isRegularizationSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegularizationCcBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CC',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _regularizationCcCtrl,
            readOnly: true,
            minLines: 1,
            maxLines: 3,
            onTap: _showRegularizationCcPicker,
            decoration: _regularizationInputDecoration(
              hintText: 'Select employee',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Select employee',
                onPressed: _showRegularizationCcPicker,
                icon: const Icon(Icons.arrow_drop_down, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularizationTimeField(
    String label,
    String hintText,
    TextEditingController controller,
  ) {
    if (controller.text.isEmpty) {
      controller.text = hintText;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: _regularizationInputDecoration(
            hintText: hintText,
            suffixIcon: const Icon(Icons.access_time, size: 17),
          ),
        ),
      ],
    );
  }

  InputDecoration _regularizationInputDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFCFCFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF0D82FF)),
      ),
    );
  }

  Widget _buildRegularizationCalendar(List<AttendanceReportDay> days) {
    final daysByDate = <String, AttendanceReportDay>{
      for (final day in days)
        if (_dateKey(DateTime.tryParse(day.date)) != null)
          _dateKey(DateTime.tryParse(day.date))!: day,
    };
    final monthStart = DateTime(
      _selectedReportMonth.year,
      _selectedReportMonth.month,
      1,
    );
    final monthEnd = DateTime(
      _selectedReportMonth.year,
      _selectedReportMonth.month + 1,
      0,
    );
    final leadingBlankDays = monthStart.weekday - 1;
    final visibleCells = ((leadingBlankDays + monthEnd.day + 6) ~/ 7) * 7;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final calendarWidth = constraints.maxWidth < 620
            ? 620.0
            : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: calendarWidth,
            constraints: const BoxConstraints(maxWidth: 820),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Row(
                  children: weekdays.map((weekday) {
                    return Expanded(
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.grey[200]!),
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Text(
                          weekday,
                          style: const TextStyle(
                            color: Color(0xFF344054),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                ...List.generate(visibleCells ~/ 7, (weekIndex) {
                  return Row(
                    children: List.generate(7, (weekdayIndex) {
                      final cellIndex = weekIndex * 7 + weekdayIndex;
                      final dayNumber = cellIndex - leadingBlankDays + 1;
                      final isCurrentMonth =
                          dayNumber >= 1 && dayNumber <= monthEnd.day;
                      final date = isCurrentMonth
                          ? DateTime(
                              _selectedReportMonth.year,
                              _selectedReportMonth.month,
                              dayNumber,
                            )
                          : null;
                      final attendanceDay = daysByDate[_dateKey(date)];
                      final status = _regularizationCalendarStatusForDate(
                        date,
                        attendanceDay,
                      );
                      final statusLabel = status == null
                          ? null
                          : _regularizationStatusLabel(status);
                      final canOpenRegularization =
                          statusLabel == 'Regularization' ||
                          statusLabel == 'Absent';
                      return Expanded(
                        child: _buildRegularizationCalendarCell(
                          date: date,
                          status: status,
                          isSelected:
                              _dateKey(date) ==
                              _dateKey(_selectedRegularizationDate),
                          onTap: canOpenRegularization
                              ? () {
                                  setState(() {
                                    _selectedRegularizationDate = date;
                                    _regularizationCcCtrl.clear();
                                    _regularizationReasonCtrl.clear();
                                    _regularizationCheckInCtrl.text =
                                        attendanceDay?.checkIn ?? '10:00';
                                    _regularizationCheckOutCtrl.text =
                                        attendanceDay?.checkOut ?? '19:00';
                                  });
                                }
                              : null,
                        ),
                      );
                    }),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegularizationCalendarCell({
    required DateTime? date,
    required String? status,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final isBlank = date == null;
    final label = isBlank ? '' : date.day.toString().padLeft(2, '0');
    final isToday =
        date != null &&
        DateTime.now().year == date.year &&
        DateTime.now().month == date.month &&
        DateTime.now().day == date.day;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isBlank
              ? const Color(0xFFFCFCFD)
              : isSelected
              ? const Color(0xFFF4F0FF)
              : Colors.white,
          border: Border(
            right: BorderSide(color: Colors.grey[200]!),
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
        child: isBlank
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isToday
                              ? const Color(0xFF2B5AF0)
                              : const Color(0xFF344054),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      if (status != null) ...[
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _regularizationStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _regularizationStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _regularizationStatusLabel(status),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _regularizationStatusColor(status),
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildRegularizationLegend() {
    final items = [
      ('Present Day', const Color(0xFF118843)),
      ('Absent', const Color(0xFFE44F42)),
      ('Half Day', const Color(0xFFF9B233)),
      ('Holiday', const Color(0xFF8EC7FF)),
      ('Weekoff', const Color(0xFF1F2E5A)),
      ('Regularization', const Color(0xFF7C3AED)),
    ];
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              item.$1,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  String? _dateKey(DateTime? date) {
    if (date == null) return null;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDate(DateTime? first, DateTime? second) {
    if (first == null || second == null) return false;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _leaveDateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$day-${_shortMonth(date)}-$year';
  }

  List<(DateTime, String)> _leaveHolidays() {
    final year = DateTime.now().year;
    return [
      (DateTime(year, 1, 26), 'Republic Day'),
      (DateTime(year, 5, 1), 'May Day'),
      (DateTime(year, 6, 17), 'Bakrid'),
      (DateTime(year, 8, 15), 'Independence Day'),
      (DateTime(year, 10, 2), 'Gandhi Jayanti'),
      (DateTime(year, 10, 20), 'Diwali'),
      (DateTime(year, 12, 25), 'Christmas'),
    ];
  }

  String? _leaveHolidayForDate(DateTime date) {
    for (final holiday in _leaveHolidays()) {
      if (_isSameDate(holiday.$1, date)) return holiday.$2;
    }
    return null;
  }

  bool _isLeaveDateInSelectedRange(DateTime date) {
    if (_leaveFromDate == null || _leaveToDate == null) return false;
    final current = _dateOnly(date);
    final start = _dateOnly(_leaveFromDate!);
    final end = _dateOnly(_leaveToDate!);
    return !current.isBefore(start) && !current.isAfter(end);
  }

  int _requestedLeaveDays() {
    if (_leaveFromDate == null || _leaveToDate == null) return 0;
    var current = _dateOnly(_leaveFromDate!);
    final end = _dateOnly(_leaveToDate!);
    var days = 0;

    while (!current.isAfter(end)) {
      final isWeekend =
          current.weekday == DateTime.saturday ||
          current.weekday == DateTime.sunday;
      final isHoliday = _leaveHolidayForDate(current) != null;
      if (!isWeekend && !isHoliday) days += 1;
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  List<(DateTime, String)> _selectedLeaveHolidays() {
    if (_leaveFromDate == null || _leaveToDate == null) return [];
    final start = _dateOnly(_leaveFromDate!);
    final end = _dateOnly(_leaveToDate!);
    return _leaveHolidays().where((holiday) {
      final date = _dateOnly(holiday.$1);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  int _selectedLeaveWeekendDays() {
    if (_leaveFromDate == null || _leaveToDate == null) return 0;
    var current = _dateOnly(_leaveFromDate!);
    final end = _dateOnly(_leaveToDate!);
    var days = 0;

    while (!current.isAfter(end)) {
      if (current.weekday == DateTime.saturday ||
          current.weekday == DateTime.sunday) {
        days += 1;
      }
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  AttendanceReportDay? _attendanceDayForDate(
    List<AttendanceReportDay> days,
    DateTime date,
  ) {
    final selectedKey = _dateKey(date);
    for (final day in days) {
      if (_dateKey(DateTime.tryParse(day.date)) == selectedKey) {
        return day;
      }
    }
    return null;
  }

  String? _regularizationCalendarStatusForDate(
    DateTime? date,
    AttendanceReportDay? day,
  ) {
    if (date == null) return null;
    if (day != null) return day.status;

    final today = DateTime.now();
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
    if (date.weekday == DateTime.sunday) return 'Weekoff';
    if (date.day == 2 || date.day == 15) return 'Holiday';
    if (date.day == 4 || date.day == 18 || date.day == 24) {
      return 'Regularization';
    }
    if (isFuture) return null;
    if (date.day % 7 == 0) return 'Absent';
    return 'Present';
  }

  Color _regularizationStatusColor(String status) {
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus.contains('present') ||
        normalizedStatus.contains('full')) {
      return const Color(0xFF118843);
    }
    if (normalizedStatus.contains('absent')) {
      return const Color(0xFFE44F42);
    }
    if (normalizedStatus.contains('partial') ||
        normalizedStatus.contains('half') ||
        normalizedStatus.contains('incomplete')) {
      return const Color(0xFFF9B233);
    }
    if (normalizedStatus.contains('holiday')) {
      return const Color(0xFF8EC7FF);
    }
    if (normalizedStatus.contains('week')) {
      return const Color(0xFF1F2E5A);
    }
    if (normalizedStatus.contains('regular') ||
        normalizedStatus.contains('approved')) {
      return const Color(0xFF7C3AED);
    }
    return const Color(0xFF7C3AED);
  }

  String _regularizationStatusLabel(String status) {
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus.contains('present') ||
        normalizedStatus.contains('full')) {
      return 'Present Day';
    }
    if (normalizedStatus.contains('absent')) return 'Absent';
    if (normalizedStatus.contains('partial') ||
        normalizedStatus.contains('half') ||
        normalizedStatus.contains('incomplete')) {
      return 'Half Day';
    }
    if (normalizedStatus.contains('holiday')) return 'Holiday';
    if (normalizedStatus.contains('week')) return 'Weekoff';
    return 'Regularization';
  }

  Widget _buildAttendancesInsightsSection(AttendanceReport? report) {
    if (report == null) {
      return _buildReportMessage(
        icon: Icons.analytics_outlined,
        title: 'No insights available',
        message: 'Load your attendance data to see insights and analytics.',
      );
    }

    final avgHoursPerDay = report.days.isNotEmpty
        ? report.totalHours / report.days.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryTile(
                'Attendance Rate',
                report.days.isNotEmpty
                    ? '${((report.presentDays / report.days.length) * 100).toStringAsFixed(1)}%'
                    : '0%',
                Icons.trending_up,
                const Color(0xFF1ABE8E),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryTile(
                'Avg Hours/Day',
                avgHoursPerDay.toStringAsFixed(2),
                Icons.schedule,
                const Color(0xFF2B5AF0),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryTile(
                'On-time Rate',
                report.days.isNotEmpty
                    ? '${(((report.days.length - report.lateDays) / report.days.length) * 100).toStringAsFixed(1)}%'
                    : '0%',
                Icons.check_circle_outline,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Insights Summary',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildInsightRow(
                'Total Days Worked',
                report.presentDays.toString(),
              ),
              _buildInsightRow(
                'Total Hours Logged',
                report.totalHours.toStringAsFixed(2),
              ),
              _buildInsightRow(
                'Days with Late Check-in',
                report.lateDays.toString(),
              ),
              _buildInsightRow(
                'Working Days in Month',
                report.days.length.toString(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendancesReportsSection(AttendanceReport? report) {
    if (report == null) {
      return _buildReportMessage(
        icon: Icons.description_outlined,
        title: 'No reports available',
        message: 'Load your attendance data to generate detailed reports.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2E5A).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F2E5A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Report',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2E5A),
                ),
              ),
              const SizedBox(height: 16),
              _buildReportRow('Month', _monthLabel(_selectedReportMonth)),
              _buildReportRow('Present Days', report.presentDays.toString()),
              _buildReportRow(
                'Total Hours',
                report.totalHours.toStringAsFixed(2),
              ),
              _buildReportRow('Late Days', report.lateDays.toString()),
              _buildReportRow('Days Recorded', report.days.length.toString()),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Daily Breakdown',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (report.days.isEmpty)
          _buildReportMessage(
            icon: Icons.inbox_outlined,
            title: 'No daily records',
            message: 'No check-in records found for this month.',
          )
        else
          _buildReportTable(report.days),
      ],
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2E5A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1ABE8E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksView() {
    final isPending = _selectedTaskSection == 'Pending Tasks';
    final pendingRows = _employeePendingTaskRows();
    final completedRows = _employeeCompletedTaskRows();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Tasks',
            isPending
                ? 'Track work assigned to you and pending task activity.'
                : 'Review completed task activity.',
          ),
          const SizedBox(height: 28),
          _buildTaskStatusDropdown(),
          const SizedBox(height: 18),
          if (_isTasksLoading)
            const LinearProgressIndicator()
          else if (isPending) ...[
            _buildEmployeeAssignedTasksTable(pendingRows),
            _buildTaskReasonSection(),
          ] else
            _buildEmployeeReviewTasksTable(completedRows),
        ],
      ),
    );
  }

  Widget _buildTaskStatusDropdown() {
    const sections = ['Pending Tasks', 'Completed Tasks'];
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: DropdownButtonFormField<String>(
          initialValue: _selectedTaskSection,
          decoration: _salaryInputDecoration(label: 'Task Status'),
          items: sections.map((section) {
            return DropdownMenuItem(value: section, child: Text(section));
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedTaskSection = value);
          },
        ),
      ),
    );
  }

  List<Map<String, String>> _employeePendingTaskRows() {
    if (_employeeTasks.isNotEmpty) {
      return _employeeTasks
          .where((task) {
            final status = task['status']?.toString() ?? '';
            return status == 'assigned' ||
                status == 'in_progress' ||
                status == 'review';
          })
          .map((task) {
            return {
              'work': task['title']?.toString() ?? 'Task',
              'from': 'Manager',
              'to': _currentUser?['name'] as String? ?? 'Employee',
              'assignedDate': _readableDate(
                task['assigned_date']?.toString() ?? '',
              ),
              'assignedTime': '-',
              'uptoDate': _readableDate(task['due_date']?.toString() ?? ''),
              'uptoTime': '-',
              'status': task['status_label']?.toString() ?? 'Assigned',
            };
          })
          .toList();
    }
    if (_token != null) return [];
    return [
      {
        'work': 'Patient follow-up report',
        'from': 'HR Manager',
        'to': _currentUser?['name'] as String? ?? 'Employee',
        'assignedDate': _regularizationDateOnly(
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        ),
        'assignedTime': '10:00 AM',
        'uptoDate': _regularizationDateOnly(DateTime.now().toIso8601String()),
        'uptoTime': '06:00 PM',
        'status': 'Assigned',
      },
      {
        'work': 'Update attendance documents',
        'from': 'Operations',
        'to': _currentUser?['name'] as String? ?? 'Employee',
        'assignedDate': _regularizationDateOnly(
          DateTime.now().toIso8601String(),
        ),
        'assignedTime': '11:30 AM',
        'uptoDate': _regularizationDateOnly(
          DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        ),
        'uptoTime': '04:30 PM',
        'status': 'In Progress',
      },
    ];
  }

  List<Map<String, String>> _employeeCompletedTaskRows() {
    if (_employeeTasks.isNotEmpty) {
      return _employeeTasks
          .where((task) => task['status']?.toString() == 'completed')
          .map((task) {
            return {
              'work': task['title']?.toString() ?? 'Task',
              'assignedDate': _readableDate(
                task['assigned_date']?.toString() ?? '',
              ),
              'completedDate': _readableDate(
                task['completed_date']?.toString() ?? '',
              ),
              'status': task['status_label']?.toString() ?? 'Completed',
            };
          })
          .toList();
    }
    if (_token != null) return [];
    return [
      {
        'work': 'Patient follow-up report',
        'assignedDate': _regularizationDateOnly(
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        ),
        'completedDate': _regularizationDateOnly(
          DateTime.now().toIso8601String(),
        ),
        'status': 'Completed',
      },
      {
        'work': 'Daily visit summary',
        'assignedDate': _regularizationDateOnly(
          DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        ),
        'completedDate': _regularizationDateOnly(
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        ),
        'status': 'Completed',
      },
    ];
  }

  Widget _buildEmployeeAssignedTasksTable(List<Map<String, String>> rows) {
    return _buildTaskTableShell(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
        headingTextStyle: const TextStyle(
          color: Color(0xFF1F2E5A),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(color: Color(0xFF344054), fontSize: 12),
        columns: const [
          DataColumn(label: Text('Work Assigned')),
          DataColumn(label: Text('From')),
          DataColumn(label: Text('To')),
          DataColumn(label: Text('Assigned Date')),
          DataColumn(label: Text('Assigned Time')),
          DataColumn(label: Text('Upto Date')),
          DataColumn(label: Text('Upto Time')),
          DataColumn(label: Text('Status')),
        ],
        rows: rows.map((task) {
          return DataRow(
            cells: [
              DataCell(Text(task['work'] ?? '-')),
              DataCell(Text(task['from'] ?? '-')),
              DataCell(Text(task['to'] ?? '-')),
              DataCell(Text(task['assignedDate'] ?? '-')),
              DataCell(Text(task['assignedTime'] ?? '-')),
              DataCell(Text(task['uptoDate'] ?? '-')),
              DataCell(Text(task['uptoTime'] ?? '-')),
              DataCell(_buildStatusPill(task['status'] ?? 'Assigned')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmployeeReviewTasksTable(List<Map<String, String>> rows) {
    return _buildTaskTableShell(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
        headingTextStyle: const TextStyle(
          color: Color(0xFF1F2E5A),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(color: Color(0xFF344054), fontSize: 12),
        columns: const [
          DataColumn(label: Text('Work Assigned')),
          DataColumn(label: Text('Assigned Date')),
          DataColumn(label: Text('Completed Date')),
          DataColumn(label: Text('Status')),
        ],
        rows: rows.map((task) {
          return DataRow(
            cells: [
              DataCell(Text(task['work'] ?? '-')),
              DataCell(Text(task['assignedDate'] ?? '-')),
              DataCell(Text(task['completedDate'] ?? '-')),
              DataCell(_buildStatusPill(task['status'] ?? 'Submitted')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskTableShell({required DataTable child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }

  Widget _buildTaskReasonSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reason About Task',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Write a short reason or update about the assigned task',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFCFCFD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF2B5AF0)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B5AF0),
                foregroundColor: Colors.white,
                minimumSize: const Size(90, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearViewControls({
    required String selectedMonth,
    required String selectedYear,
    required ValueChanged<String> onMonthChanged,
    required ValueChanged<String> onYearChanged,
    required VoidCallback? onView,
    bool isLoading = false,
  }) {
    final currentYear = DateTime.now().year;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final years = List.generate(
      6,
      (index) => (currentYear - 4 + index).toString(),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedMonth,
                decoration: _salaryInputDecoration(label: 'Month'),
                items: months.map((month) {
                  return DropdownMenuItem(value: month, child: Text(month));
                }).toList(),
                onChanged: (value) {
                  if (value != null) onMonthChanged(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedYear,
                decoration: _salaryInputDecoration(label: 'Year'),
                items: years.map((year) {
                  return DropdownMenuItem(value: year, child: Text(year));
                }).toList(),
                onChanged: (value) {
                  if (value != null) onYearChanged(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onView,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B5AF0),
                foregroundColor: Colors.white,
                minimumSize: const Size(86, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('View'),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _availableLeaveTypes() {
    final approvedLeaves = _leaveRequests().where((leave) {
      return (leave['status']?.toString().toLowerCase() ?? '') == 'approved';
    });
    int usedDays(String type) {
      return approvedLeaves
          .where((leave) => leave['leave_type']?.toString() == type)
          .fold<int>(
            0,
            (sum, leave) => sum + ((leave['total_days'] as num?)?.toInt() ?? 0),
          );
    }

    final leaveTypes = <Map<String, dynamic>>[
      {
        'name': 'Casual Leave',
        'icon': Icons.weekend_outlined,
        'color': const Color(0xFF2B5AF0),
        'used': usedDays('Casual Leave'),
        'total': 12,
      },
      {
        'name': 'Sick Leave',
        'icon': Icons.local_hospital_outlined,
        'color': Colors.red,
        'used': usedDays('Sick Leave'),
        'total': 12,
      },
      {
        'name': 'Paid Leave',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFF1ABE8E),
        'used': usedDays('Paid Leave'),
        'total': 12,
      },
      {
        'name': 'Compensation Leave',
        'icon': Icons.more_time,
        'color': const Color(0xFF7C3AED),
        'used': usedDays('Compensation Leave'),
        'total': 12,
      },
      {
        'name': 'Paternity Leave',
        'icon': Icons.family_restroom,
        'color': Colors.indigo,
        'used': usedDays('Paternity Leave'),
        'total': 12,
      },
    ];

    return leaveTypes;
  }

  Widget _buildApplyLeaveTypes() {
    final leaveTypes = _availableLeaveTypes();
    final selectedLeaveType =
        _selectedApplyLeaveType ?? leaveTypes.first['name'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 172,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: leaveTypes.length,
          itemBuilder: (context, index) {
            final leaveType = leaveTypes[index];
            final name = leaveType['name'] as String;
            final color = leaveType['color'] as Color;
            final used = leaveType['used'] as int;
            final total = leaveType['total'] as int;
            final displayUsed = used == 0 ? 1 : used.clamp(0, total);
            final available = (total - displayUsed).clamp(0, total);
            final isSelected = name == selectedLeaveType;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedApplyLeaveType = name;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey[200]!,
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        leaveType['icon'] as IconData,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$available available',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1F2E5A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$displayUsed/$total',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1F2E5A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        _buildApplyLeaveForm(leaveTypes, selectedLeaveType),
      ],
    );
  }

  Widget _buildApplyLeaveForm(
    List<Map<String, dynamic>> leaveTypes,
    String selectedLeaveType,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 920,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apply Leave',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF1F2E5A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useStackedLayout = constraints.maxWidth < 760;
                  final formFields = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLeaveDropdownField(leaveTypes, selectedLeaveType),
                      const SizedBox(height: 12),
                      _buildLeaveDateSessionRow(
                        dateLabel: 'From Date',
                        selectedDate: _leaveFromDate,
                        onDateTap: () => _pickLeaveDate(isFromDate: true),
                        sessionLabel: 'Session 1',
                        selectedSession: _leaveFromSession,
                        onSessionChanged: (value) {
                          setState(() {
                            _leaveFromSession = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildLeaveDateSessionRow(
                        dateLabel: 'To Date',
                        selectedDate: _leaveToDate,
                        onDateTap: () => _pickLeaveDate(isFromDate: false),
                        sessionLabel: 'Session 2',
                        selectedSession: _leaveToSession,
                        onSessionChanged: (value) {
                          setState(() {
                            _leaveToSession = value;
                          });
                        },
                      ),
                    ],
                  );
                  final calculator = _buildLeaveCalculator(
                    leaveTypes,
                    selectedLeaveType,
                  );

                  if (useStackedLayout) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        formFields,
                        const SizedBox(height: 12),
                        calculator,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: formFields),
                      const SizedBox(width: 16),
                      SizedBox(width: 360, child: calculator),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildLeaveCcField(),
              const SizedBox(height: 12),
              _buildLeaveReasonField(),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: _isLeaveSubmitting
                          ? null
                          : () => _submitLeaveRequest(selectedLeaveType),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5AF0),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(84, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isLeaveSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit'),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _showLeaveSubmitSuccess
                          ? Padding(
                              key: const ValueKey('leave-submit-success'),
                              padding: const EdgeInsets.only(top: 8),
                              child: InkWell(
                                onTap: _hideLeaveSubmittedSuccess,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F8F3),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF1ABE8E,
                                      ).withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        color: Color(0xFF0F9F78),
                                        size: 17,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Submitted successfully',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: const Color(0xFF0F766E),
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('leave-submit-success-empty'),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveDropdownField(
    List<Map<String, dynamic>> leaveTypes,
    String selectedLeaveType,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave Type',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedLeaveType,
          decoration: _leaveInputDecoration(),
          items: leaveTypes.map((leaveType) {
            return DropdownMenuItem<String>(
              value: leaveType['name'] as String,
              child: Text(leaveType['name'] as String),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedApplyLeaveType = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildLeaveCcField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CC',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _leaveCcCtrl,
          decoration: _leaveInputDecoration(
            hintText: 'Add contact details',
            prefixIcon: const Icon(Icons.add_circle_outline, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _leaveReasonCtrl,
          maxLines: 2,
          decoration: _leaveInputDecoration(
            hintText: 'Write a short reason for leave',
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveCalculator(
    List<Map<String, dynamic>> leaveTypes,
    String selectedLeaveType,
  ) {
    final selectedType = leaveTypes.firstWhere(
      (leaveType) => leaveType['name'] == selectedLeaveType,
      orElse: () => leaveTypes.first,
    );
    final used = selectedType['used'] as int;
    final total = selectedType['total'] as int;
    final available = (total - used).clamp(0, total);
    final requestedDays = _requestedLeaveDays();
    final holidayCount = _selectedLeaveHolidays().length;
    final weekendCount = _selectedLeaveWeekendDays();
    final exceedsBalance = requestedDays > available;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                color: Color(0xFF2B5AF0),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Leaves Calculator',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF1F2E5A),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$used/$total used',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF1F2E5A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLeaveCalculatorChip(
                'Available',
                available.toString(),
                const Color(0xFF1ABE8E),
              ),
              _buildLeaveCalculatorChip(
                'Applying',
                requestedDays.toString(),
                exceedsBalance ? Colors.red : const Color(0xFF2B5AF0),
              ),
              _buildLeaveCalculatorChip(
                'Holidays',
                holidayCount.toString(),
                const Color(0xFFB7791F),
              ),
              _buildLeaveCalculatorChip(
                'Weekends',
                weekendCount.toString(),
                Colors.grey[700]!,
              ),
            ],
          ),
          if (exceedsBalance) ...[
            const SizedBox(height: 8),
            Text(
              'Requested leave exceeds the available balance.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaveCalculatorChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveDateSessionRow({
    required String dateLabel,
    required DateTime? selectedDate,
    required VoidCallback onDateTap,
    required String sessionLabel,
    required String selectedSession,
    required ValueChanged<String> onSessionChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildLeaveDateField(dateLabel, selectedDate, onDateTap),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 132,
          child: _buildLeaveSessionField(
            sessionLabel,
            selectedSession,
            onSessionChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveSessionField(
    String label,
    String selectedSession,
    ValueChanged<String> onChanged,
  ) {
    const sessions = ['Session 1', 'Session 2'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedSession,
          decoration: _leaveInputDecoration(),
          items: sessions.map((session) {
            return DropdownMenuItem<String>(
              value: session,
              child: Text(session),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
        ),
      ],
    );
  }

  Widget _buildLeaveDateField(
    String label,
    DateTime? selectedDate,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: InputDecorator(
            decoration: _leaveInputDecoration(
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(
              selectedDate == null
                  ? 'DD-MMM-YY'
                  : _leaveDateLabel(selectedDate),
              style: TextStyle(
                color: selectedDate == null
                    ? Colors.grey[500]
                    : const Color(0xFF1F2E5A),
                fontWeight: selectedDate == null
                    ? FontWeight.w400
                    : FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _leaveInputDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFCFCFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF2B5AF0)),
      ),
    );
  }

  Widget _buildLeavesView() {
    final section = _selectedLeaveSection;
    IconData icon = Icons.event_available;
    String description = 'Submit and track your leave requests.';
    String title = 'No leave requests';
    String message = 'Leave requests will appear here once submitted.';

    if (section == 'Leave Calendar') {
      icon = Icons.calendar_month;
      description = 'View planned holidays and approved leave days.';
      title = 'No leave calendar entries';
      message = 'Approved leave and calendar entries will appear here.';
    } else if (section == 'Leave Overview') {
      icon = Icons.analytics_outlined;
      description = 'Review leave balances, approvals, and request history.';
      title = 'No leave overview data';
      message = 'Leave balance and history will appear here when available.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Leaves', description),
          const SizedBox(height: 28),
          if (section == 'Apply Leave')
            _buildApplyLeaveTypes()
          else if (section == 'Leave Calendar')
            _buildLeaveCalendarSection()
          else if (section == 'Leave Overview')
            _buildLeaveOverviewSection()
          else
            _buildReportMessage(icon: icon, title: title, message: message),
        ],
      ),
    );
  }

  Widget _buildLeaveDatePickerCalendar(
    DateTime visibleMonth,
    DateTime? selectedDate,
    ValueChanged<DateTime> onSelectDate,
  ) {
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final monthEnd = DateTime(visibleMonth.year, visibleMonth.month + 1, 0);
    final leadingBlankDays = monthStart.weekday - 1;
    final visibleCells = ((leadingBlankDays + monthEnd.day + 6) ~/ 7) * 7;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: weekdays.map((weekday) {
            return Expanded(
              child: Center(
                child: Text(
                  weekday,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate(visibleCells ~/ 7, (weekIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: List.generate(7, (weekdayIndex) {
                final cellIndex = weekIndex * 7 + weekdayIndex;
                final dayNumber = cellIndex - leadingBlankDays + 1;
                final isCurrentMonth =
                    dayNumber >= 1 && dayNumber <= monthEnd.day;
                final date = isCurrentMonth
                    ? DateTime(visibleMonth.year, visibleMonth.month, dayNumber)
                    : null;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _buildLeaveDatePickerCell(
                      date,
                      selectedDate,
                      onSelectDate,
                    ),
                  ),
                );
              }),
            ),
          );
        }),
        const SizedBox(height: 6),
        _buildLeavePickerLegend(),
        const SizedBox(height: 10),
        _buildLeaveHolidayNotes(visibleMonth),
      ],
    );
  }

  Widget _buildLeaveDatePickerCell(
    DateTime? date,
    DateTime? selectedDate,
    ValueChanged<DateTime> onSelectDate,
  ) {
    if (date == null) {
      return const SizedBox(height: 42);
    }

    final holiday = _leaveHolidayForDate(date);
    final isHoliday = holiday != null;
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isSelected = _isSameDate(date, selectedDate);
    final isInRange = _isLeaveDateInSelectedRange(date);
    final Color markerColor = isHoliday
        ? const Color(0xFFB7791F)
        : isWeekend
        ? Colors.grey
        : const Color(0xFF2B5AF0);

    return InkWell(
      onTap: () => onSelectDate(date),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2B5AF0)
              : isInRange
              ? const Color(0xFFEAF0FF)
              : isHoliday
              ? const Color(0xFFFFF7E6)
              : isWeekend
              ? const Color(0xFFF2F4F7)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2B5AF0)
                : isHoliday
                ? const Color(0xFFF6C453)
                : Colors.grey[200]!,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1F2E5A),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : markerColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeavePickerLegend() {
    final items = [
      ('Selected range', const Color(0xFF2B5AF0)),
      ('Holiday', const Color(0xFFB7791F)),
      ('Weekend', Colors.grey),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              item.$1,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLeaveHolidayNotes(DateTime visibleMonth) {
    final holidays = _leaveHolidays()
        .where(
          (holiday) =>
              holiday.$1.year == visibleMonth.year &&
              holiday.$1.month == visibleMonth.month,
        )
        .toList();

    if (holidays.isEmpty) {
      return Text(
        'No listed holidays this month. Weekends are excluded from the leave count.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: holidays.map((holiday) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(
                Icons.celebration_outlined,
                size: 15,
                color: Color(0xFFB7791F),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_leaveDateLabel(holiday.$1)} - ${holiday.$2}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF1F2E5A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveCalendarSection() {
    final leaveEntries = _leaveCalendarEntries();
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthEnd = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    final leadingBlankDays = monthStart.weekday - 1;
    final visibleCells = ((leadingBlankDays + monthEnd.day + 6) ~/ 7) * 7;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLeaveCalendarLegend(),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: 720,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: weekdays.map((weekday) {
                              return Expanded(
                                child: Container(
                                  height: 30,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    border: Border(
                                      right: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    weekday,
                                    style: const TextStyle(
                                      color: Color(0xFF1F2E5A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          ...List.generate(visibleCells ~/ 7, (weekIndex) {
                            return Row(
                              children: List.generate(7, (weekdayIndex) {
                                final cellIndex = weekIndex * 7 + weekdayIndex;
                                final dayNumber =
                                    cellIndex - leadingBlankDays + 1;
                                final isCurrentMonth =
                                    dayNumber >= 1 && dayNumber <= monthEnd.day;
                                final date = isCurrentMonth
                                    ? DateTime(
                                        DateTime.now().year,
                                        DateTime.now().month,
                                        dayNumber,
                                      )
                                    : null;
                                final entries =
                                    leaveEntries[_dateKey(date)] ?? [];
                                return Expanded(
                                  child: _buildLeaveCalendarCell(date, entries),
                                );
                              }),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Flexible(
              flex: 2,
              child: _buildCompletedLeaveHolidayDashboardSection(),
            ),
          ],
        ),
      ],
    );
  }

  Map<String, List<Map<String, dynamic>>> _leaveCalendarEntries() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final leave in _leaveRequests()) {
      if (leave['status']?.toString().toLowerCase() != 'approved') continue;
      final fromDate = DateTime.tryParse(leave['from_date']?.toString() ?? '');
      final toDate = DateTime.tryParse(leave['to_date']?.toString() ?? '');
      if (fromDate == null || toDate == null) continue;

      var current = _dateOnly(fromDate);
      final end = _dateOnly(toDate);
      while (!current.isAfter(end)) {
        final key = _dateKey(current)!;
        grouped.putIfAbsent(key, () => []).add({
          'date': current,
          'label': leave['leave_type']?.toString() ?? 'Leave',
          'color': _leaveTypeColor(leave['leave_type']?.toString() ?? ''),
        });
        current = current.add(const Duration(days: 1));
      }
    }
    return grouped;
  }

  Widget _buildLeaveCalendarCell(
    DateTime? date,
    List<Map<String, dynamic>> entries,
  ) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: date == null ? const Color(0xFFFCFCFD) : Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[200]!),
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: date == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                ...entries.take(2).map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: entry['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            entry['label'] as String,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: entry['color'] as Color,
                              fontWeight: FontWeight.w700,
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildLeaveCalendarLegend() {
    final items = [
      ('Casual Leave', const Color(0xFF2B5AF0)),
      ('Sick Leave', Colors.red),
      ('Paid Leave', const Color(0xFF1ABE8E)),
      ('Compensation', const Color(0xFF7C3AED)),
      ('Paternity', Colors.indigo),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              item.$1,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLeaveOverviewSection() {
    final leaveTypes = _availableLeaveTypes();
    final remainingLeaves = leaveTypes.map((leaveType) {
      final used = leaveType['used'] as int;
      final total = leaveType['total'] as int;
      return {
        'title': leaveType['name'] as String,
        'date': '${(total - used).clamp(0, total)} remaining of $total',
        'status': 'Available',
        'color': leaveType['color'] as Color,
      };
    }).toList();
    final remainingTotal = leaveTypes.fold<int>(
      0,
      (sum, leaveType) =>
          sum +
          ((leaveType['total'] as int) - (leaveType['used'] as int)).clamp(
            0,
            leaveType['total'] as int,
          ),
    );
    Map<String, dynamic> leaveRow(Map<String, dynamic> leave) {
      final status =
          leave['status_label']?.toString() ??
          leave['status']?.toString() ??
          'Pending';
      final fromDate = _readableDate(leave['from_date']?.toString() ?? '');
      final toDate = _readableDate(leave['to_date']?.toString() ?? '');
      final totalDays = (leave['total_days'] as num?)?.toInt() ?? 0;
      final dateLabel = fromDate == toDate
          ? '$fromDate ($totalDays day${totalDays == 1 ? '' : 's'})'
          : '$fromDate - $toDate ($totalDays day${totalDays == 1 ? '' : 's'})';
      return {
        'title': leave['leave_type']?.toString() ?? 'Leave',
        'date': dateLabel,
        'status': status,
        'color': _leaveStatusColor(leave['status']?.toString() ?? status),
      };
    }

    final leaveHistory = _leaveRequests().map(leaveRow).toList();
    final pendingLeaves = _leaveRequests()
        .where(
          (leave) => leave['status']?.toString().toLowerCase() == 'pending',
        )
        .map(leaveRow)
        .toList();
    final approvedLeaves = _leaveRequests()
        .where(
          (leave) => leave['status']?.toString().toLowerCase() == 'approved',
        )
        .map(leaveRow)
        .toList();
    final lossOfPayLeaves = _leaveRequests()
        .where(
          (leave) => leave['status']?.toString().toLowerCase() == 'rejected',
        )
        .map(leaveRow)
        .toList();
    final overviewDetails = {
      'Leave History': leaveHistory,
      'Remaining Leaves': remainingLeaves,
      'Pending Requests': pendingLeaves,
      'Approved Leaves': approvedLeaves,
      'Loss of Pay': lossOfPayLeaves,
    };
    final selectedDetails =
        overviewDetails[_selectedLeaveOverview] ?? leaveHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLeaveOverviewCard(
                'Remaining Leaves',
                remainingTotal.toString(),
                Icons.event_available,
                const Color(0xFF1ABE8E),
                isSelected: _selectedLeaveOverview == 'Remaining Leaves',
                onTap: () {
                  setState(() {
                    _selectedLeaveOverview = 'Remaining Leaves';
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLeaveOverviewCard(
                'Pending Requests',
                pendingLeaves.length.toString(),
                Icons.pending_actions,
                Colors.orange,
                isSelected: _selectedLeaveOverview == 'Pending Requests',
                onTap: () {
                  setState(() {
                    _selectedLeaveOverview = 'Pending Requests';
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildLeaveOverviewCard(
                    'Approved Leaves',
                    approvedLeaves.length.toString(),
                    Icons.verified_outlined,
                    const Color(0xFF2B5AF0),
                    isSelected: _selectedLeaveOverview == 'Approved Leaves',
                    onTap: () {
                      setState(() {
                        _selectedLeaveOverview = 'Approved Leaves';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildLeaveOverviewCard(
                    'Loss of Pay',
                    lossOfPayLeaves.length.toString(),
                    Icons.money_off_csred_outlined,
                    Colors.red,
                    isSelected: _selectedLeaveOverview == 'Loss of Pay',
                    onTap: () {
                      setState(() {
                        _selectedLeaveOverview = 'Loss of Pay';
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 560,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedLeaveOverview,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF1F2E5A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedDetails.isEmpty)
                    Text(
                      'No leave records found.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    ...selectedDetails.map((item) {
                      final color = item['color'] as Color;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: color.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_note, color: color, size: 15),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['title'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1F2E5A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  item['date'] as String,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusPill(item['status'] as String),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1F2E5A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isSelected ? color : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _shortMonth(DateTime date) {
    const monthNames = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return monthNames[date.month - 1];
  }

  Widget _buildSalaryView() {
    final section = _selectedSalarySection;
    String description = 'View salary information and monthly pay details.';

    if (section == 'Compensation & Benefits') {
      description = 'Review salary components, allowances, and benefits.';
    } else if (section == 'Bonus & Incentives') {
      description = 'Review bonus payments, incentives, and payout history.';
    } else if (section == 'Tax Details') {
      description = 'Review tax declarations, deductions, and annual tax data.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Salary', description),
          const SizedBox(height: 28),
          if (section == 'Payslips')
            _buildPayslipsSection()
          else if (section == 'Compensation & Benefits')
            _buildCompensationBenefitsSection()
          else if (section == 'Bonus & Incentives')
            _buildBonusIncentivesSection()
          else
            _buildTaxDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildPayslipsSection() {
    final currentYear = DateTime.now().year;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final years = List.generate(
      6,
      (index) => (currentYear - 4 + index).toString(),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 560,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payslip',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1F2E5A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPayslipMonth,
                      decoration: _salaryInputDecoration(label: 'Month'),
                      items: months.map((month) {
                        return DropdownMenuItem(
                          value: month,
                          child: Text(month),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedPayslipMonth = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPayslipYear,
                      decoration: _salaryInputDecoration(label: 'Year'),
                      items: years.map((year) {
                        return DropdownMenuItem(value: year, child: Text(year));
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedPayslipYear = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton(
                      onPressed: _isPayslipLoading
                          ? null
                          : _downloadSelectedPayslip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5AF0),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(112, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isPayslipLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Download'),
                    ),
                    OutlinedButton(
                      onPressed: _isPayslipLoading
                          ? null
                          : _viewSelectedPayslip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2B5AF0),
                        side: const BorderSide(color: Color(0xFF2B5AF0)),
                        minimumSize: const Size(80, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompensationBenefitsSection() {
    final latestRecord =
        _userSection('salary')?['latest'] as Map<String, dynamic>?;
    final selectedRecord = _salaryDetailsError == null
        ? (_selectedSalaryRecord ?? latestRecord)
        : null;
    final salaryRows = selectedRecord == null
        ? <(String, String)>[]
        : [
            ('Basic Salary', _moneyLabel(selectedRecord['basic_salary'])),
            ('Allowances', _moneyLabel(selectedRecord['allowances'])),
            ('Bonus', _moneyLabel(selectedRecord['bonus'])),
            ('Incentives', _moneyLabel(selectedRecord['incentives'])),
            ('Deductions', _moneyLabel(selectedRecord['deductions'])),
            ('Net Salary', _moneyLabel(selectedRecord['net_salary'])),
          ];

    return _buildSalaryCard(
      title: 'Compensation & Benefits',
      icon: Icons.account_balance_wallet_outlined,
      color: const Color(0xFF1ABE8E),
      children: [
        if (selectedRecord != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${_monthName((selectedRecord['month'] as num?)?.toInt() ?? _monthNumber(_selectedPayslipMonth))} ${selectedRecord['year'] ?? _selectedPayslipYear}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        if (_salaryDetailsError != null)
          _buildEmptyStateMessage(_salaryDetailsError!)
        else
          ...salaryRows.map((row) {
            final isNet = row.$1 == 'Net Salary';
            return _buildSalaryAmountRow(row.$1, row.$2, isHighlighted: isNet);
          }),
        const Divider(height: 26),
        _buildMonthYearViewControls(
          selectedMonth: _selectedPayslipMonth,
          selectedYear: _selectedPayslipYear,
          onMonthChanged: (value) =>
              setState(() => _selectedPayslipMonth = value),
          onYearChanged: (value) =>
              setState(() => _selectedPayslipYear = value),
          onView: _isSalaryDetailsLoading ? null : _viewSelectedSalaryDetails,
          isLoading: _isSalaryDetailsLoading,
        ),
      ],
    );

    final rows = [
      ('Basic Salary', '₹45,000'),
      ('Allowances', '₹12,000'),
      ('Deductions', '₹3,500'),
      ('Medical Allowance', '₹2,500'),
      ('Travel Allowance', '₹4,000'),
      ('Net Salary', '₹53,500'),
    ];

    return _buildSalaryCard(
      title: 'Compensation & Benefits',
      icon: Icons.account_balance_wallet_outlined,
      color: const Color(0xFF1ABE8E),
      children: rows.map((row) {
        final isNet = row.$1 == 'Net Salary';
        return _buildSalaryAmountRow(row.$1, row.$2, isHighlighted: isNet);
      }).toList(),
    );
  }

  Widget _buildBonusIncentivesSection() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 520,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No bonus earned yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1F2E5A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bonus and incentive rewards will appear here once assigned.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxDetailsSection() {
    final latestRecord =
        _userSection('salary')?['latest'] as Map<String, dynamic>?;
    final selectedRecord = _salaryDetailsError == null
        ? (_selectedSalaryRecord ?? latestRecord)
        : null;
    final taxDeducted =
        double.tryParse(selectedRecord?['tax_deducted']?.toString() ?? '') ?? 0;
    final deductions =
        double.tryParse(selectedRecord?['deductions']?.toString() ?? '') ?? 0;

    return _buildSalaryCard(
      title: 'Tax Details',
      icon: Icons.account_balance,
      color: const Color(0xFF2B5AF0),
      children: [
        if (selectedRecord != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${_monthName((selectedRecord['month'] as num?)?.toInt() ?? _monthNumber(_selectedPayslipMonth))} ${selectedRecord['year'] ?? _selectedPayslipYear}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        if (_salaryDetailsError != null)
          _buildEmptyStateMessage(_salaryDetailsError!)
        else ...[
          _buildSalaryAmountRow('Income Tax (TDS)', _moneyLabel(taxDeducted)),
          _buildSalaryAmountRow('Other Deductions', _moneyLabel(deductions)),
          const Divider(height: 26),
          _buildSalaryAmountRow(
            'Total Tax Deduction',
            _moneyLabel(taxDeducted + deductions),
            isHighlighted: true,
          ),
        ],
        const Divider(height: 26),
        _buildMonthYearViewControls(
          selectedMonth: _selectedPayslipMonth,
          selectedYear: _selectedPayslipYear,
          onMonthChanged: (value) =>
              setState(() => _selectedPayslipMonth = value),
          onYearChanged: (value) =>
              setState(() => _selectedPayslipYear = value),
          onView: _isSalaryDetailsLoading ? null : _viewSelectedSalaryDetails,
          isLoading: _isSalaryDetailsLoading,
        ),
      ],
    );

    return _buildSalaryCard(
      title: 'Tax Details',
      icon: Icons.account_balance,
      color: const Color(0xFF2B5AF0),
      children: [
        _buildSalaryAmountRow('Professional Tax', '₹200'),
        _buildSalaryAmountRow('Income Tax (TDS)', '₹1,500'),
        _buildSalaryAmountRow('PF Contribution', '₹1,200'),
        const Divider(height: 26),
        _buildSalaryAmountRow(
          'Total Tax Deduction',
          '₹2,900',
          isHighlighted: true,
        ),
      ],
    );
  }

  Widget _buildSalaryCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 560,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1F2E5A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryAmountRow(
    String label,
    String amount, {
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFF1ABE8E).withValues(alpha: 0.1)
            : const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF1ABE8E).withValues(alpha: 0.25)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF1F2E5A),
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: const Color(0xFF1F2E5A),
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey[600])),
    );
  }

  InputDecoration _salaryInputDecoration({
    String? label,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFCFCFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF2B5AF0)),
      ),
    );
  }

  InputDecoration _helpdeskIssueInputDecoration() {
    return InputDecoration(
      hintText: 'Describe your issue',
      prefixIcon: const Icon(Icons.report_problem_outlined),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFCFCFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF2B5AF0)),
      ),
    );
  }

  Widget _buildHelpdeskView() {
    final issueDate = _readableDate(DateTime.now().toIso8601String());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Helpdesk',
            'Contact support for attendance, leave, salary, and account help.',
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _buildContactTile(
                  'Email ID',
                  'pvamshi2002@gmail.com',
                  Icons.email_outlined,
                  const Color(0xFF2B5AF0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildContactTile(
                  'Contact Number',
                  '7867895432',
                  Icons.phone_outlined,
                  const Color(0xFF1ABE8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 560,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Issue',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FixedColumnWidth(120),
                    1: FlexColumnWidth(),
                  },
                  border: TableBorder.all(color: Color(0xFFE5E7EB)),
                  children: [
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Issue Date',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(issueDate),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Issue Reason',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: TextField(
                            controller: _helpdeskIssueCtrl,
                            maxLines: 2,
                            decoration: _helpdeskIssueInputDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _submitHelpdeskIssue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B5AF0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 13,
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildHelpdeskTicketsTable(),
        ],
      ),
    );
  }

  Widget _buildHelpdeskTicketsTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          headingTextStyle: const TextStyle(
            color: Color(0xFF1F2E5A),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          dataTextStyle: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 12,
          ),
          columns: const [
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Issue')),
            DataColumn(label: Text('Created Date')),
            DataColumn(label: Text('Resolved Date')),
            DataColumn(label: Text('Status')),
          ],
          rows: _helpdeskTickets.map((ticket) {
            return DataRow(
              cells: [
                DataCell(Text(ticket['subject']?.toString() ?? '-')),
                DataCell(Text(ticket['description']?.toString() ?? '-')),
                DataCell(
                  Text(_readableDate(ticket['created_at']?.toString() ?? '')),
                ),
                DataCell(
                  Text(_readableDate(ticket['resolved_at']?.toString() ?? '')),
                ),
                DataCell(
                  _buildStatusPill(
                    ticket['status_label']?.toString() ?? 'Open',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmployeeReportsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Reports',
            'Review your attendance, leave, salary, and helpdesk summaries.',
          ),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.4,
            children: [
              _buildEmployeeReportCard(
                'Attendance Report',
                'Daily attendance and precise location check-in summary',
                Icons.fact_check_outlined,
                const Color(0xFF1ABE8E),
              ),
              _buildEmployeeReportCard(
                'Leave Report',
                'Applied, approved, and remaining leave summary',
                Icons.event_note,
                const Color(0xFF2B5AF0),
              ),
              _buildEmployeeReportCard(
                'Salary Report',
                'Payslips, allowances, deductions, and tax details',
                Icons.receipt_long,
                Colors.orange,
              ),
              _buildEmployeeReportCard(
                'Helpdesk Report',
                'Support request and issue resolution summary',
                Icons.support_agent,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHrDashboardView() {
    final tasks = _userSection('tasks');
    final leaves = _userSection('leaves');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'HR Dashboard - ${_currentUser?['name'] ?? 'HR'}',
            'Manage people operations, attendance, recruitment, payroll, and performance.',
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  'Open Roles',
                  '0',
                  Icons.work_outline,
                  const Color(0xFF2B5AF0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryTile(
                  'Pending Onboarding',
                  _readInt(tasks, 'assigned').toString(),
                  Icons.person_add_alt,
                  const Color(0xFF1ABE8E),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryTile(
                  'Leave Requests',
                  _readInt(leaves, 'applied').toString(),
                  Icons.event_note,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.6,
            children: [
              _buildEmployeeReportCard(
                'Employee Management',
                'Staff directory, onboarding, and employee profiles',
                Icons.groups,
                const Color(0xFF1ABE8E),
              ),
              _buildEmployeeReportCard(
                'Attendance Management',
                'Daily attendance, insights, and attendance reports',
                Icons.access_time,
                const Color(0xFF2B5AF0),
              ),
              _buildEmployeeReportCard(
                'Recruitment',
                'Job openings, candidates, and interviews',
                Icons.how_to_reg,
                Colors.orange,
              ),
              _buildEmployeeReportCard(
                'Payroll',
                'Salary management, payslips, and payroll reports',
                Icons.account_balance_wallet,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHrSectionView() {
    final section = _selectedHrSection;
    final config = _hrSectionConfig(_selectedMenu, section);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(_selectedMenu, config['description'] as String),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  config['primaryLabel'] as String,
                  '0',
                  config['icon'] as IconData,
                  config['color'] as Color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryTile(
                  'Pending',
                  '0',
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryTile(
                  'Completed',
                  '0',
                  Icons.verified_outlined,
                  const Color(0xFF1ABE8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildReportMessage(
            icon: config['icon'] as IconData,
            title: section,
            message: config['message'] as String,
          ),
        ],
      ),
    );
  }

  Map<String, Object> _hrSectionConfig(String menu, String section) {
    IconData icon = Icons.dashboard_customize;
    Color color = const Color(0xFF2B5AF0);
    String primaryLabel = section;
    String description = 'Manage $section from the HR dashboard.';
    String message = '$section data will appear here when records are added.';

    if (menu == 'Employee Management') {
      icon = section == 'Smart Onboarding'
          ? Icons.person_add_alt
          : section == 'Employee Profile'
          ? Icons.badge_outlined
          : Icons.groups;
      color = const Color(0xFF1ABE8E);
      description =
          'Manage staff directory, onboarding, and employee profiles.';
    } else if (menu == 'Attendance Management') {
      icon = section == 'Attendance Insights'
          ? Icons.analytics_outlined
          : section == 'Attendance Reports'
          ? Icons.description_outlined
          : Icons.access_time;
      description = 'Monitor attendance activity, trends, and reports.';
    } else if (menu == 'Recruitment') {
      icon = section == 'Candidate Management'
          ? Icons.people_alt_outlined
          : section == 'Interview'
          ? Icons.event_available
          : Icons.work_outline;
      color = Colors.orange;
      description = 'Track job openings, candidates, and interviews.';
    } else if (menu == 'Payroll') {
      icon = section == 'Payslips'
          ? Icons.receipt_long
          : section == 'Payroll Reports'
          ? Icons.assessment
          : Icons.account_balance_wallet;
      color = Colors.purple;
      description = 'Manage salary, payslips, and payroll reporting.';
    } else if (menu == 'Performance') {
      icon = section == 'Evaluations'
          ? Icons.fact_check_outlined
          : section == 'Rewards and Recognition'
          ? Icons.emoji_events_outlined
          : Icons.insights;
      color = Colors.teal;
      description = 'Track performance, evaluations, rewards, and recognition.';
    }

    return {
      'icon': icon,
      'color': color,
      'primaryLabel': primaryLabel,
      'description': description,
      'message': message,
    };
  }

  Widget _buildEmployeeReportCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1F2E5A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1F2E5A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSummaryTile(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isCompact ? 24 : 32),
          SizedBox(width: isCompact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style:
                      (isCompact
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.headlineSmall)
                          ?.copyWith(
                            color: const Color(0xFF1F2E5A),
                            fontWeight: FontWeight.bold,
                          ),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(List<AttendanceReportDay> days) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 818,
              child: DataTable(
                columnSpacing: 34,
                horizontalMargin: 30,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFFCFCFD),
                ),
                headingTextStyle: const TextStyle(
                  color: Color(0xFF1F2E5A),
                  fontWeight: FontWeight.bold,
                ),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Check In')),
                  DataColumn(label: Text('Check Out')),
                  DataColumn(label: Text('Total Hours')),
                  DataColumn(label: Text('Status')),
                ],
                rows: days.map((day) {
                  return DataRow(
                    cells: [
                      DataCell(Text(day.date)),
                      DataCell(Text(day.checkIn ?? '-')),
                      DataCell(Text(day.checkOut ?? '-')),
                      DataCell(Text(day.totalHours?.toStringAsFixed(2) ?? '-')),
                      DataCell(_buildStatusPill(day.status)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final positiveStatuses = ['Present', 'Active', 'Approved'];
    final negativeStatuses = ['Absent', 'Inactive', 'Rejected'];
    final color = positiveStatuses.contains(status)
        ? const Color(0xFF1ABE8E)
        : negativeStatuses.contains(status)
        ? Colors.red
        : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Admin Dashboard Views
  Widget _buildAdminDashboard() {
    final summary = _adminDashboard?['summary'] as Map<String, dynamic>?;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back 👋',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Admin Dashboard - ${_currentUser?['name'] ?? 'Admin'}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: const Color(0xFF1F2E5A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage employees, monitor attendance, and view analytics.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABE8E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: Color(0xFF1ABE8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          if (_isDashboardLoading)
            const LinearProgressIndicator()
          else if (_dashboardError != null)
            _buildReportMessage(
              icon: Icons.error_outline,
              title: 'Dashboard not connected',
              message: _dashboardError!,
              actionLabel: 'Retry',
              onAction: loadDashboardData,
            ),
          if (_isDashboardLoading || _dashboardError != null)
            const SizedBox(height: 24),

          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            children: [
              _buildAdminStatCard(
                'Total Employees',
                _readInt(summary, 'total_employees').toString(),
                Icons.people,
                const Color(0xFF2B5AF0),
                onTap: _showTotalEmployeesDialog,
              ),
              _buildAdminStatCard(
                'Total Requests',
                _readInt(summary, 'total_requests').toString(),
                Icons.pending_actions,
                Colors.purple,
                onTap: () {
                  setState(() {
                    _selectedMenu = 'Pending Requests';
                    _selectedPendingRequestStatus = 'all';
                  });
                  loadDashboardData();
                },
              ),
            ],
          ),
          const SizedBox(height: 48),
          _buildAdminPendingWorksSection(),
        ],
      ),
    );
  }

  void _showTotalEmployeesDialog() {
    final employees = _adminEmployeeMaps();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Total Employees (${employees.length})'),
          content: SizedBox(
            width: 520,
            child: employees.isEmpty
                ? const Text('No employees found.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: employees.map((employee) {
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(employee['name']?.toString() ?? '-'),
                          subtitle: Text(
                            'Username: ${employee['username']?.toString() ?? '-'}',
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _adminPendingWorkItems() {
    final pending =
        _adminDashboard?['pending_requests'] as Map<String, dynamic>? ?? {};
    final leaves = pending['leaves'] as List<dynamic>? ?? [];
    final regularizations = pending['regularizations'] as List<dynamic>? ?? [];
    final tickets = pending['tickets'] as List<dynamic>? ?? [];

    return [
      ...leaves.whereType<Map<String, dynamic>>().map((item) {
        return {
          'kind': 'leave',
          'id': (item['id'] as num?)?.toInt() ?? 0,
          'type': 'Leave Request',
          'employee': item['employee']?.toString() ?? '-',
          'title': item['type']?.toString() ?? 'Leave',
          'meta':
              '${_readableDate(item['from_date']?.toString() ?? '')} - ${_readableDate(item['to_date']?.toString() ?? '')}',
          'status_value': item['status']?.toString() ?? 'pending',
          'status': item['status_label']?.toString() ?? 'Pending',
        };
      }),
      ...regularizations.whereType<Map<String, dynamic>>().map((item) {
        return {
          'kind': 'regularization',
          'id': (item['id'] as num?)?.toInt() ?? 0,
          'type': 'Regularization',
          'employee': item['employee']?.toString() ?? '-',
          'title': _readableDate(item['date']?.toString() ?? ''),
          'meta': item['reason']?.toString() ?? '-',
          'status_value': item['status']?.toString() ?? 'pending',
          'status': item['status_label']?.toString() ?? 'Pending',
        };
      }),
      ...tickets.whereType<Map<String, dynamic>>().map((item) {
        return {
          'kind': 'ticket',
          'id': (item['id'] as num?)?.toInt() ?? 0,
          'type': 'Helpdesk',
          'employee': item['employee']?.toString() ?? '-',
          'title': item['subject']?.toString() ?? 'Support request',
          'meta': item['description']?.toString() ?? '-',
          'status_value': item['status']?.toString() ?? 'open',
          'status': item['status_label']?.toString() ?? 'Open',
        };
      }),
    ];
  }

  Widget _buildAdminPendingWorksSection() {
    final items = _adminPendingWorkItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Requests From Users',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          _buildReportMessage(
            icon: Icons.task_alt,
            title: 'No requests',
            message: 'User requests will appear here after employees submit.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 184,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['type']?.toString() ?? 'Pending Work',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2E5A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _buildStatusPill(
                          item['status']?.toString() ?? 'Pending',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['employee']?.toString() ?? '-',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['title']?.toString() ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2E5A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['meta']?.toString() ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedMenu = 'Pending Requests';
                          _selectedPendingRequestStatus = 'all';
                        });
                      },
                      child: const Text('View request'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showAllPendingRequestsDialog() async {
    await loadDashboardData();
    if (!mounted) return;
    final items = _adminPendingWorkItems();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('All Pending Requests'),
          content: SizedBox(
            width: 760,
            child: items.isEmpty
                ? const Text('No pending requests from users right now.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items
                          .map((item) => _buildPendingRequestTile(item))
                          .toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingRequestTile(Map<String, dynamic> item) {
    final kind = item['kind']?.toString() ?? '';
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final isTicket = kind == 'ticket';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['type']} - ${item['employee']}',
                  style: const TextStyle(
                    color: Color(0xFF1F2E5A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildStatusPill(item['status']?.toString() ?? 'Pending'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['title']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            item['meta']?.toString() ?? '-',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: id == 0
                    ? null
                    : () => _updatePendingRequestStatus(
                        kind,
                        id,
                        isTicket ? 'resolved' : 'approved',
                        closeDialog: true,
                      ),
                icon: Icon(isTicket ? Icons.task_alt : Icons.check),
                label: Text(isTicket ? 'Resolve' : 'Approve'),
              ),
              OutlinedButton.icon(
                onPressed: id == 0
                    ? null
                    : () => _updatePendingRequestStatus(
                        kind,
                        id,
                        isTicket ? 'in_progress' : 'rejected',
                        closeDialog: true,
                      ),
                icon: Icon(isTicket ? Icons.pending_actions : Icons.close),
                label: Text(isTicket ? 'In Progress' : 'Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsDashboard() {
    final items = _adminPendingWorkItems();
    final filtered = items.where((item) {
      final status = (item['status_value']?.toString() ?? '').toLowerCase();
      if (_selectedPendingRequestStatus == 'all') return true;
      if (_selectedPendingRequestStatus == 'pending') {
        return status == 'pending' ||
            status == 'open' ||
            status == 'in_progress';
      }
      if (_selectedPendingRequestStatus == 'approved') {
        return status == 'approved' || status == 'resolved';
      }
      return status == 'rejected' || status == 'closed';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Total Requests Dashboard',
            'Review approved, rejected, and pending user requests.',
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedPendingRequestStatus,
              decoration: const InputDecoration(
                labelText: 'Request Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedPendingRequestStatus = value);
              },
            ),
          ),
          const SizedBox(height: 18),
          if (filtered.isEmpty)
            _buildReportMessage(
              icon: Icons.pending_actions,
              title: 'No requests found',
              message: 'Requests matching this status will appear here.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Employee')),
                    DataColumn(label: Text('Details')),
                    DataColumn(label: Text('Current')),
                    DataColumn(label: Text('Change Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: filtered.map((item) {
                    final kind = item['kind']?.toString() ?? '';
                    final id = (item['id'] as num?)?.toInt() ?? 0;
                    final requestKey = _pendingRequestKey(kind, id);
                    final action =
                        _pendingRequestActions[requestKey] ??
                        _pendingRequestActionFromStatus(
                          item['status']?.toString() ?? 'Pending',
                        );
                    return DataRow(
                      cells: [
                        DataCell(Text(item['type']?.toString() ?? '-')),
                        DataCell(Text(item['employee']?.toString() ?? '-')),
                        DataCell(
                          SizedBox(
                            width: 300,
                            child: Text(
                              '${item['title'] ?? '-'}\n${item['meta'] ?? '-'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          _buildStatusPill(
                            item['status']?.toString() ?? 'Pending',
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              initialValue: action,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Pending'),
                                ),
                                DropdownMenuItem(
                                  value: 'approve',
                                  child: Text('Approve'),
                                ),
                                DropdownMenuItem(
                                  value: 'reject',
                                  child: Text('Reject'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _pendingRequestActions[requestKey] = value;
                                });
                              },
                            ),
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () => _updatePendingRequestStatus(
                              kind,
                              id,
                              _statusValueForPendingAction(kind, action),
                            ),
                            child: const Text('Submit'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _pendingRequestActionFromStatus(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'approved' || normalized == 'resolved') return 'approve';
    if (normalized == 'rejected' || normalized == 'closed') return 'reject';
    return 'pending';
  }

  String _statusValueForPendingAction(String kind, String action) {
    if (kind == 'ticket') {
      return switch (action) {
        'approve' => 'resolved',
        'reject' => 'closed',
        _ => 'open',
      };
    }
    return switch (action) {
      'approve' => 'approved',
      'reject' => 'rejected',
      _ => 'pending',
    };
  }

  Widget _buildAdminStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return card;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }

  Widget _buildAdminEmployeesView() {
    final query = _employeeSearchCtrl.text.trim().toLowerCase();
    final employees = _adminEmployeeMaps().where((employee) {
      if (query.isEmpty) return true;
      return [
        employee['name'],
        employee['username'],
        employee['email'],
        employee['department'],
        employee['designation'],
      ].any((value) => value?.toString().toLowerCase().contains(query) == true);
    }).toList();
    final selectedEmployee = _selectedEditEmployee();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Management',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: const Color(0xFF1F2E5A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage all employees in your organization',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedMenu = 'Employee Management';
                    _selectedAttendanceSection = 'Add Employee';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1ABE8E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  '+ Add Employee',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _employeeSearchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search Employee',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 360,
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        employees.any(
                          (employee) =>
                              _employeeId(employee) == _selectedEditEmployeeId,
                        )
                        ? _selectedEditEmployeeId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Select Employee',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: employees.map((employee) {
                      return DropdownMenuItem<int>(
                        value: _employeeId(employee),
                        child: Text(
                          _employeeDisplayName(employee),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _selectEditEmployee,
                  ),
                ),
              ],
            ),
          ),
          if (selectedEmployee != null) ...[
            const SizedBox(height: 20),
            _buildEmployeeEditDetailsCard(selectedEmployee),
          ],
          const SizedBox(height: 28),

          // Employee List Table
          if (employees.isEmpty)
            _buildReportMessage(
              icon: Icons.people_outline,
              title: 'No employees found',
              message: query.isEmpty
                  ? 'Employees created in Django will appear here.'
                  : 'No employee matches your search.',
              actionLabel: 'Refresh',
              onAction: loadDashboardData,
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Employee ID')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Assigned Location')),
                    DataColumn(label: Text('Radius')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Check-ins')),
                  ],
                  rows: employees.map<DataRow>((employee) {
                    final location =
                        employee['assigned_location'] as Map<String, dynamic>?;
                    return DataRow(
                      selected:
                          _employeeId(employee) == _selectedEditEmployeeId,
                      onSelectChanged: (_) =>
                          _selectEditEmployee(_employeeId(employee)),
                      cells: [
                        DataCell(Text('EMP${employee['id']}')),
                        DataCell(Text(employee['name'] as String? ?? '-')),
                        DataCell(Text(employee['email'] as String? ?? '-')),
                        DataCell(
                          SizedBox(
                            width: 260,
                            child: Text(
                              location?['address'] as String? ??
                                  'No location assigned',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            location == null
                                ? '-'
                                : '${location['radius_meters']}m',
                          ),
                        ),
                        DataCell(
                          _buildStatusPill(
                            employee['is_active'] == true
                                ? 'Active'
                                : 'Inactive',
                          ),
                        ),
                        DataCell(
                          Text(
                            ((employee['total_checkins'] as num?)?.toInt() ?? 0)
                                .toString(),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmployeeEditDetailsCard(Map<String, dynamic> employee) {
    final location = employee['assigned_location'] as Map<String, dynamic>?;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit ${employee['name'] ?? 'Employee'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1F2E5A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _buildStatusPill(
                  employee['is_active'] == true ? 'Active' : 'Inactive',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildCompactEditField(
                  'First Name',
                  _editEmployeeFirstNameCtrl,
                ),
                _buildCompactEditField('Last Name', _editEmployeeLastNameCtrl),
                _buildCompactEditField(
                  'Date of Birth (YYYY-MM-DD)',
                  _editEmployeeDobCtrl,
                  keyboardType: TextInputType.datetime,
                ),
                _buildCompactEditField(
                  'Employee Email',
                  _editEmployeeEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildCompactEditField(
                  'Login Username',
                  _editEmployeeUsernameCtrl,
                ),
                _buildCompactEditField(
                  'New Password',
                  _editEmployeePasswordCtrl,
                  obscureText: true,
                ),
                _buildCompactEditField(
                  'Department',
                  _editEmployeeDepartmentCtrl,
                ),
                _buildCompactEditField(
                  'Designation',
                  _editEmployeeDesignationCtrl,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildDashboardPermissionBoxes(
              canUser: _editEmployeeCanAccessUser,
              canAdmin: _editEmployeeCanAccessAdmin,
              canHr: _editEmployeeCanAccessHr,
              onUserChanged: (value) =>
                  setState(() => _editEmployeeCanAccessUser = value ?? false),
              onAdminChanged: (value) =>
                  setState(() => _editEmployeeCanAccessAdmin = value ?? false),
              onHrChanged: (value) =>
                  setState(() => _editEmployeeCanAccessHr = value ?? false),
            ),
            const SizedBox(height: 14),
            Text(
              'Assigned Location: ${location?['address']?.toString() ?? 'No location assigned'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isEmployeeSaving ? null : _updateEmployeeDetails,
              icon: _isEmployeeSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Update Employee'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactEditField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return SizedBox(
      width: 290,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardPermissionBoxes({
    required bool canUser,
    required bool canAdmin,
    required bool canHr,
    required ValueChanged<bool?> onUserChanged,
    required ValueChanged<bool?> onAdminChanged,
    required ValueChanged<bool?> onHrChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard Permissions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF1F2E5A),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildPermissionCheckBox('User', canUser, onUserChanged),
            _buildPermissionCheckBox('Admin', canAdmin, onAdminChanged),
            _buildPermissionCheckBox('HR', canHr, onHrChanged),
          ],
        ),
      ],
    );
  }

  Widget _buildPermissionCheckBox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return SizedBox(
      width: 118,
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        dense: true,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
      ),
    );
  }

  Widget _buildSmartLocationManagementView() {
    final isAdd = _selectedAttendanceSection == 'Add Location';
    final employeeOptions = _adminEmployeeMaps();
    final selectedEmployee = _selectedLocationEmployee();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Location Management',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAdd
                ? 'Assign a check-in location to an employee.'
                : 'Edit employee locations used for check-in and check-out.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue:
                        employeeOptions.any(
                          (employee) =>
                              _employeeId(employee) ==
                              _selectedLocationEmployeeId,
                        )
                        ? _selectedLocationEmployeeId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: employeeOptions.map((employee) {
                      final id = _employeeId(employee);
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          _employeeDisplayName(employee),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _selectLocationEmployee,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _locationAddressCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Work Address',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _locationMapLinkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Google Maps Link',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _locationRadiusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Allowed Radius (meters)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLocationSaving
                            ? null
                            : _saveEmployeeLocation,
                        icon: _isLocationSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.location_on),
                        label: Text(
                          isAdd ? 'Assign Location' : 'Update Location',
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_showLocationAssignedPopup)
                        _buildStatusPill('Location Assigned'),
                    ],
                  ),
                  if (!isAdd &&
                      selectedEmployee?['assigned_location'] != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Current location details loaded for ${selectedEmployee?['name'] ?? 'employee'}.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isAdd) ...[
            const SizedBox(height: 28),
            _buildLocationAssignmentsTable(),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationAssignmentsTable() {
    if (_adminEmployees.isEmpty) {
      return _buildReportMessage(
        icon: Icons.location_off,
        title: 'No employee locations',
        message: 'Employee locations will appear here after assignment.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Employee')),
            DataColumn(label: Text('Assigned Address')),
            DataColumn(label: Text('Radius')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: _adminEmployees.whereType<Map<String, dynamic>>().map((
            employee,
          ) {
            final location =
                employee['assigned_location'] as Map<String, dynamic>?;
            return DataRow(
              cells: [
                DataCell(Text(employee['name']?.toString() ?? '-')),
                DataCell(
                  SizedBox(
                    width: 320,
                    child: Text(
                      location?['address']?.toString() ?? 'Not assigned',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    location == null ? '-' : '${location['radius_meters']}m',
                  ),
                ),
                DataCell(
                  _buildStatusPill(
                    location == null ? 'Pending' : 'Location Assigned',
                  ),
                ),
                DataCell(
                  TextButton.icon(
                    onPressed: () =>
                        _selectLocationEmployee(_employeeId(employee)),
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAdminAttendanceView() {
    final isDailyAttendances =
        _selectedAdminAttendanceSection == 'Daily Attendances' ||
        _selectedAttendanceSection == 'Daily Attendance';
    final isInsights =
        _selectedAdminAttendanceSection == 'Attendances Insights';
    final isReports =
        _selectedAdminAttendanceSection == 'Attendances Reports' ||
        _selectedAttendanceSection == 'Attendance Reports';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Management',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isInsights
                ? 'View attendance insights and analytics across the organization'
                : isReports
                ? 'Generate and download detailed attendance reports'
                : 'Monitor real-time attendance of all employees',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          if (isDailyAttendances)
            _buildAdminDailyAttendancesSection()
          else if (isInsights)
            _buildAdminAttendancesInsightsSection()
          else if (isReports)
            _buildAdminAttendancesReportsSection(),
        ],
      ),
    );
  }

  Widget _buildAdminDailyAttendancesSection() {
    final summary = _adminAttendance?['summary'] as Map<String, dynamic>?;
    final allRows = _adminAttendance?['rows'] as List<dynamic>? ?? [];
    final query = _adminAttendanceSearchCtrl.text.trim().toLowerCase();
    final rows = allRows.whereType<Map<String, dynamic>>().where((row) {
      final rowEmployeeId = (row['employee_id'] as num?)?.toInt();
      if (_selectedAdminAttendanceEmployeeId != null &&
          rowEmployeeId != _selectedAdminAttendanceEmployeeId) {
        return false;
      }
      if (query.isEmpty) return true;
      final location = row['assigned_location'] as Map<String, dynamic>?;
      return [
        row['employee'],
        row['username'],
        row['check_in_location'],
        row['check_out_location'],
        location?['address'],
      ].any((value) => value?.toString().toLowerCase().contains(query) == true);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Row(
              children: [
                Expanded(
                  child: _buildAdminStatCard(
                    'Total Present',
                    '${_readInt(summary, 'present')}/${_readInt(summary, 'total_employees')}',
                    Icons.check_circle,
                    const Color(0xFF1ABE8E),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAdminStatCard(
                    'Total Absent',
                    _readInt(summary, 'absent').toString(),
                    Icons.cancel,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        Center(
          child: Text(
            "Today's Attendance",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedAdminAttendanceEmployeeId,
                  decoration: const InputDecoration(
                    labelText: 'Employee',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Employees'),
                    ),
                    ..._adminEmployeeMaps().map((employee) {
                      return DropdownMenuItem<int?>(
                        value: _employeeId(employee),
                        child: Text(
                          _employeeDisplayName(employee),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedAdminAttendanceEmployeeId = value);
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _adminAttendanceSearchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search attendance',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (rows.isEmpty)
          _buildReportMessage(
            icon: Icons.event_busy,
            title: 'No attendance rows',
            message: 'No attendance rows match the selected employee/search.',
            actionLabel: 'Refresh',
            onAction: loadDashboardData,
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Assigned Location')),
                  DataColumn(label: Text('Radius')),
                  DataColumn(label: Text('Check In')),
                  DataColumn(label: Text('Check Out')),
                  DataColumn(label: Text('Check-in Address')),
                  DataColumn(label: Text('Check-out Address')),
                  DataColumn(label: Text('Status')),
                ],
                rows: rows.map<DataRow>((row) {
                  final location =
                      row['assigned_location'] as Map<String, dynamic>?;
                  return DataRow(
                    onSelectChanged: (_) => _showAdminAttendanceDetails(row),
                    cells: [
                      DataCell(
                        Text(_readableDate(row['date']?.toString() ?? '')),
                      ),
                      DataCell(
                        TextButton(
                          onPressed: () => _showAdminAttendanceDetails(row),
                          child: Text(row['employee'] as String? ?? '-'),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Text(
                            location?['address'] as String? ??
                                'No location assigned',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          location == null
                              ? '-'
                              : '${location['radius_meters']}m',
                        ),
                      ),
                      DataCell(Text(row['check_in'] as String? ?? '-')),
                      DataCell(Text(row['check_out'] as String? ?? '-')),
                      DataCell(
                        SizedBox(
                          width: 240,
                          child: Text(
                            row['check_in_location']?.toString().isNotEmpty ==
                                    true
                                ? row['check_in_location'].toString()
                                : '-',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 240,
                          child: Text(
                            row['check_out_location']?.toString().isNotEmpty ==
                                    true
                                ? row['check_out_location'].toString()
                                : '-',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        _buildStatusPill(row['status'] as String? ?? 'Absent'),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  void _showAdminAttendanceDetails(Map<String, dynamic> row) {
    final location = row['assigned_location'] as Map<String, dynamic>?;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(row['employee']?.toString() ?? 'Attendance details'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAttendanceDetailRow(
                    'Date',
                    _readableDate(row['date']?.toString() ?? ''),
                  ),
                  _buildAttendanceDetailRow(
                    'Username',
                    row['username']?.toString() ?? '-',
                  ),
                  _buildAttendanceDetailRow(
                    'Status',
                    row['status']?.toString() ?? '-',
                  ),
                  const Divider(height: 26),
                  _buildAttendanceDetailRow(
                    'Assigned location',
                    location?['address']?.toString() ?? 'No location assigned',
                  ),
                  _buildAttendanceDetailRow(
                    'Allowed radius',
                    location == null ? '-' : '${location['radius_meters']}m',
                  ),
                  const Divider(height: 26),
                  _buildAttendanceDetailRow(
                    'Check-in time',
                    row['check_in']?.toString() ?? '-',
                  ),
                  _buildAttendanceDetailRow(
                    'Check-in address',
                    row['check_in_location']?.toString().isNotEmpty == true
                        ? row['check_in_location'].toString()
                        : '-',
                  ),
                  _buildAttendanceDetailRow(
                    'Check-in distance',
                    _distanceLabel(row['check_in_distance_meters']),
                  ),
                  _buildAttendanceMapButton(
                    'Open check-in map',
                    row['check_in_map_url']?.toString() ?? '',
                  ),
                  const Divider(height: 26),
                  _buildAttendanceDetailRow(
                    'Check-out time',
                    row['check_out']?.toString() ?? '-',
                  ),
                  _buildAttendanceDetailRow(
                    'Check-out address',
                    row['check_out_location']?.toString().isNotEmpty == true
                        ? row['check_out_location'].toString()
                        : '-',
                  ),
                  _buildAttendanceDetailRow(
                    'Check-out distance',
                    _distanceLabel(row['check_out_distance_meters']),
                  ),
                  _buildAttendanceMapButton(
                    'Open check-out map',
                    row['check_out_map_url']?.toString() ?? '',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttendanceDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: Color(0xFF1F2E5A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceMapButton(String label, String url) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: url.isEmpty ? null : () => openExternalLink(url),
        icon: const Icon(Icons.map_outlined),
        label: Text(label),
      ),
    );
  }

  String _distanceLabel(dynamic value) {
    final distance = (value as num?)?.toDouble();
    if (distance == null) return '-';
    return '${distance.toStringAsFixed(1)}m';
  }

  Widget _buildAdminAttendancesInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAdminStatCard(
                'Avg Attendance Rate',
                '85.3%',
                Icons.trending_up,
                const Color(0xFF1ABE8E),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildAdminStatCard(
                'Employees On-time',
                '215/245',
                Icons.schedule,
                const Color(0xFF2B5AF0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildAdminStatCard(
                'Late Check-ins',
                '30',
                Icons.warning_amber,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildAdminStatCard(
                'Absences',
                '47',
                Icons.cancel,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organization Insights',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildInsightRow('Total Employees', '245'),
              _buildInsightRow('Daily Avg Attendance', '198'),
              _buildInsightRow('Compliance Rate', '96.5%'),
              _buildInsightRow('Trend', 'Improving ↑'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminAttendancesReportsSection() {
    final report = _adminAttendanceReport ?? _adminAttendance;
    final summary = report?['summary'] as Map<String, dynamic>?;
    final query = _adminReportSearchCtrl.text.trim().toLowerCase();
    final rows = (report?['rows'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((row) {
          if (query.isEmpty) return true;
          final location = row['assigned_location'] as Map<String, dynamic>?;
          return [
            row['date'],
            row['employee'],
            row['username'],
            row['check_in_location'],
            row['check_out_location'],
            location?['address'],
          ].any(
            (value) => value?.toString().toLowerCase().contains(query) == true,
          );
        })
        .toList();
    final years = List<int>.generate(6, (index) => DateTime.now().year - index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance Reports',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedAdminAttendanceReportMonth.year,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: years
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedAdminAttendanceReportDate = null;
                      _selectedAdminAttendanceReportMonth = DateTime(
                        value,
                        _selectedAdminAttendanceReportMonth.month,
                      );
                    });
                    _loadAdminAttendanceReport();
                  },
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedAdminAttendanceReportMonth.month,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: List<int>.generate(12, (index) => index + 1)
                      .map(
                        (month) => DropdownMenuItem(
                          value: month,
                          child: Text(_monthName(month)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedAdminAttendanceReportDate = null;
                      _selectedAdminAttendanceReportMonth = DateTime(
                        _selectedAdminAttendanceReportMonth.year,
                        value,
                      );
                    });
                    _loadAdminAttendanceReport();
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _selectedAdminAttendanceReportDate ?? DateTime.now(),
                      firstDate: DateTime(DateTime.now().year - 5),
                      lastDate: DateTime(DateTime.now().year + 1),
                    );
                    if (picked != null) {
                      setState(
                        () => _selectedAdminAttendanceReportDate = picked,
                      );
                      _loadAdminAttendanceReport();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _selectedAdminAttendanceReportDate == null
                        ? 'Select Date'
                        : _readableDate(
                            _selectedAdminAttendanceReportDate!
                                .toIso8601String(),
                          ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedAdminReportEmployeeId,
                  decoration: const InputDecoration(
                    labelText: 'Employee',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Employees'),
                    ),
                    ..._adminEmployeeMaps().map((employee) {
                      return DropdownMenuItem<int?>(
                        value: _employeeId(employee),
                        child: Text(
                          _employeeDisplayName(employee),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedAdminReportEmployeeId = value);
                    _loadAdminAttendanceReport();
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _adminReportSearchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadAdminAttendanceReport,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Row(
              children: [
                Expanded(
                  child: _buildAdminStatCard(
                    'Present',
                    _readInt(summary, 'present').toString(),
                    Icons.check_circle,
                    const Color(0xFF1ABE8E),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAdminStatCard(
                    'Absent',
                    _readInt(summary, 'absent').toString(),
                    Icons.cancel,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Employee')),
                DataColumn(label: Text('Check In')),
                DataColumn(label: Text('Check Out')),
                DataColumn(label: Text('Check-in Address')),
                DataColumn(label: Text('Check-out Address')),
                DataColumn(label: Text('Status')),
              ],
              rows: rows.map((row) {
                return DataRow(
                  onSelectChanged: (_) => _showAdminAttendanceDetails(row),
                  cells: [
                    DataCell(Text(row['date']?.toString() ?? '-')),
                    DataCell(
                      TextButton(
                        onPressed: () => _showAdminAttendanceDetails(row),
                        child: Text(row['employee']?.toString() ?? '-'),
                      ),
                    ),
                    DataCell(Text(row['check_in']?.toString() ?? '-')),
                    DataCell(Text(row['check_out']?.toString() ?? '-')),
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: Text(
                          row['check_in_location']?.toString().isNotEmpty ==
                                  true
                              ? row['check_in_location'].toString()
                              : '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: Text(
                          row['check_out_location']?.toString().isNotEmpty ==
                                  true
                              ? row['check_out_location'].toString()
                              : '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      _buildStatusPill(row['status']?.toString() ?? '-'),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminReportsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports & Analytics',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View comprehensive reports and analytics',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // Report Options Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            children: [
              _buildReportCard(
                'Attendance Report',
                'View monthly attendance statistics',
                Icons.bar_chart,
                const Color(0xFF2B5AF0),
              ),
              _buildReportCard(
                'Leave Report',
                'Analyze leave patterns and usage',
                Icons.calendar_today,
                const Color(0xFF1ABE8E),
              ),
              _buildReportCard(
                'Task Report',
                'Track task completion and performance',
                Icons.task,
                Colors.orange,
              ),
              _buildReportCard(
                'Salary Report',
                'View payroll and compensation data',
                Icons.attach_money,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text(
              'View Report',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRegistrationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Employee Registration',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2E5A),
            ),
          ),
          const SizedBox(height: 20),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                TextField(
                  controller: _employeeFirstNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _employeeLastNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _employeeDobCtrl,
                  keyboardType: TextInputType.datetime,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _employeeEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Employee Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _employeeUsernameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Login Username',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _employeePasswordCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Login Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _employeeDepartmentCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _employeeDesignationCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Designation',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildDashboardPermissionBoxes(
                  canUser: _employeeCanAccessUser,
                  canAdmin: _employeeCanAccessAdmin,
                  canHr: _employeeCanAccessHr,
                  onUserChanged: (value) =>
                      setState(() => _employeeCanAccessUser = value ?? false),
                  onAdminChanged: (value) =>
                      setState(() => _employeeCanAccessAdmin = value ?? false),
                  onHrChanged: (value) =>
                      setState(() => _employeeCanAccessHr = value ?? false),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _isEmployeeSaving ? null : _registerEmployee,
                    child: _isEmployeeSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register Employee'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeProfileManagementView() {
    return Center(
      child: Text(
        'Employee Profile Management',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildWorkMonitoringDashboard() {
    final summary = _adminTasks?['summary'] as Map<String, dynamic>?;
    final tasks = (_adminTasks?['tasks'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final years = List<int>.generate(6, (index) => DateTime.now().year - index);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Work Monitoring',
            'Track assigned, in-progress, and completed work by date.',
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 300,
                child: _buildAdminStatCard(
                  'Work Assigned',
                  _readInt(summary, 'assigned').toString(),
                  Icons.assignment,
                  const Color(0xFF2B5AF0),
                ),
              ),
              SizedBox(
                width: 300,
                child: _buildAdminStatCard(
                  'Work In Progress',
                  _readInt(summary, 'in_progress').toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              SizedBox(
                width: 300,
                child: _buildAdminStatCard(
                  'Work Completed',
                  _readInt(summary, 'completed').toString(),
                  Icons.task_alt,
                  const Color(0xFF1ABE8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedAdminTaskStatus,
                    decoration: const InputDecoration(
                      labelText: 'Task Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'assigned',
                        child: Text('Assigned'),
                      ),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(value: 'all', child: Text('All')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedAdminTaskStatus = value);
                      _loadAdminTasks();
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedAdminTaskMonth.year,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: years
                        .map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedAdminTaskDate = null;
                        _selectedAdminTaskMonth = DateTime(
                          value,
                          _selectedAdminTaskMonth.month,
                        );
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 185,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedAdminTaskMonth.month,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List<int>.generate(12, (index) => index + 1)
                        .map(
                          (month) => DropdownMenuItem(
                            value: month,
                            child: Text(_monthName(month)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedAdminTaskDate = null;
                        _selectedAdminTaskMonth = DateTime(
                          _selectedAdminTaskMonth.year,
                          value,
                        );
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedAdminTaskDate ?? DateTime.now(),
                        firstDate: DateTime(DateTime.now().year - 5),
                        lastDate: DateTime(DateTime.now().year + 1),
                      );
                      if (picked != null) {
                        setState(() => _selectedAdminTaskDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedAdminTaskDate == null
                          ? 'Select Date'
                          : _readableDate(
                              _selectedAdminTaskDate!.toIso8601String(),
                            ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadAdminTasks,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (tasks.isEmpty)
            _buildReportMessage(
              icon: Icons.work_outline,
              title: 'No work found',
              message: 'Tasks matching the selected filters will appear here.',
              actionLabel: 'Refresh',
              onAction: _loadAdminTasks,
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Employee')),
                    DataColumn(label: Text('Task')),
                    DataColumn(label: Text('Assigned Date')),
                    DataColumn(label: Text('Due Date')),
                    DataColumn(label: Text('Completed Date')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: tasks.map((task) {
                    return DataRow(
                      cells: [
                        DataCell(Text(task['employee']?.toString() ?? '-')),
                        DataCell(
                          SizedBox(
                            width: 280,
                            child: Text(
                              task['title']?.toString() ?? '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _readableDate(
                              task['assigned_date']?.toString() ?? '',
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _readableDate(task['due_date']?.toString() ?? ''),
                          ),
                        ),
                        DataCell(
                          Text(
                            _readableDate(
                              task['completed_date']?.toString() ?? '',
                            ),
                          ),
                        ),
                        DataCell(
                          _buildStatusPill(
                            task['status_label']?.toString() ?? '-',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskAssignmentView() {
    return Center(
      child: Text(
        'Task Assignment Dashboard',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInProgressTasksView() {
    return Center(
      child: Text(
        'InProgress Tasks Dashboard',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCompletedTasksView() {
    return Center(
      child: Text(
        'Completed Tasks Dashboard',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmployeePaymentsView() {
    return Center(
      child: Text(
        'Employee Payments Dashboard',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmployeeIncentivesView() {
    return Center(
      child: Text(
        'Employee Incentives Dashboard',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAdminSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Settings',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: const Color(0xFF1F2E5A),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure system settings and preferences',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // Settings Sections
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSettingRow('Organization Name', 'HealOn Inc.'),
                const SizedBox(height: 16),
                _buildSettingRow('Working Hours', '9:00 AM - 6:00 PM'),
                const SizedBox(height: 16),
                _buildSettingRow('Weekend Days', 'Saturday - Sunday'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1ABE8E),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Settings
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security & Notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildToggleRow('Email Notifications', true),
                const SizedBox(height: 16),
                _buildToggleRow('SMS Alerts', false),
                const SizedBox(height: 16),
                _buildToggleRow('Daily Reports', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        TextButton(
          onPressed: () {},
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1ABE8E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(String label, bool value) {
    bool toggleValue = value;
    return StatefulBuilder(
      builder: (context, setState) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Switch(
            value: toggleValue,
            onChanged: (newValue) {
              setState(() {
                toggleValue = newValue;
              });
            },
            activeThumbColor: const Color(0xFF1ABE8E),
          ),
        ],
      ),
    );
  }

  Widget _buildReportMessage({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[500]),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(String label, IconData icon, String menuKey) {
    bool isActive = _selectedMenu == menuKey;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1ABE8E) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: () => _selectMenu(menuKey),
      ),
    );
  }

  Widget _buildSubMenuItem(String label, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 36, right: 8, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        minLeadingWidth: 8,
        leading: Icon(
          Icons.circle,
          size: 8,
          color: isActive ? const Color(0xFF1ABE8E) : Colors.white70,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildHolidayCard(String name, String date) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            date,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedLeaveHolidayDashboardSection() {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final completedItems =
        <Map<String, dynamic>>[
            ..._leaveRequests()
                .where((leave) {
                  final status = leave['status']?.toString().toLowerCase();
                  final toDate = DateTime.tryParse(
                    leave['to_date']?.toString() ?? '',
                  );
                  return status == 'approved' &&
                      toDate != null &&
                      _dateOnly(toDate).isBefore(today);
                })
                .map((leave) {
                  final leaveType = leave['leave_type']?.toString() ?? 'Leave';
                  return {
                    'title': leaveType,
                    'date': DateTime.parse(leave['to_date']?.toString() ?? ''),
                    'type': 'Leave',
                    'color': _leaveTypeColor(leaveType),
                  };
                }),
            ..._leaveHolidays().map((holiday) {
              return {
                'title': holiday.$2,
                'date': holiday.$1,
                'type': 'Holiday',
                'color': const Color(0xFFB7791F),
              };
            }),
          ].where((item) {
            final date = _dateOnly(item['date'] as DateTime);
            return date.isBefore(today);
          }).toList()
          ..sort((a, b) {
            return (b['date'] as DateTime).compareTo(a['date'] as DateTime);
          });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_toggle_off,
                size: 22,
                color: Color(0xFF1F2E5A),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Completed Leaves & Holidays',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1F2E5A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (completedItems.isEmpty)
            Text(
              'No completed leave or holiday entries yet.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            )
          else
            ...completedItems.take(5).map((item) {
              final color = item['color'] as Color;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['type'] == 'Holiday'
                          ? Icons.celebration_outlined
                          : Icons.event_note_outlined,
                      color: color,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['title'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2E5A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _leaveDateLabel(item['date'] as DateTime),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
