import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'external_link.dart';
import 'login_storage_stub.dart'
    if (dart.library.html) 'login_storage_web.dart'
    as login_storage;
import 'photo_biometric_stub.dart'
    if (dart.library.html) 'photo_biometric_web.dart'
    as photo_biometric;
import 'payslip_download.dart';
import 'reimbursement_upload_stub.dart'
    if (dart.library.html) 'reimbursement_upload_web.dart'
    as reimbursement_upload;

// For web: use localhost, for mobile: use 10.0.2.2
final String backendUrl = () {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000'; // For web
}();

const Color _inkBlue = Color(0xFF172554);
const Color _brandBlue = Color(0xFF2563EB);
const Color _brandTeal = Color(0xFF10B981);
const Color _softSurface = Color(0xFFF8FAFC);
const Color _lineColor = Color(0xFFE2E8F0);

List<BoxShadow> _softShadow([double alpha = 0.08]) {
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: alpha),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
}

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
  final _loginHelpdeskIssueCtrl = TextEditingController();
  final _employeeDisplayNameCtrl = TextEditingController();
  final _employeeFirstNameCtrl = TextEditingController();
  final _employeeLastNameCtrl = TextEditingController();
  final _employeeDobCtrl = TextEditingController();
  final _employeeEmailCtrl = TextEditingController();
  final _employeePhoneCtrl = TextEditingController();
  final _employeeDepartmentCtrl = TextEditingController();
  final _employeeDesignationCtrl = TextEditingController();
  final _employeeUsernameCtrl = TextEditingController();
  final _employeePasswordCtrl = TextEditingController();
  final _employeeSearchCtrl = TextEditingController();
  final _reimbursementReasonCtrl = TextEditingController();
  final _editEmployeeDisplayNameCtrl = TextEditingController();
  final _editEmployeeFirstNameCtrl = TextEditingController();
  final _editEmployeeLastNameCtrl = TextEditingController();
  final _editEmployeeDobCtrl = TextEditingController();
  final _editEmployeeEmailCtrl = TextEditingController();
  final _editEmployeePhoneCtrl = TextEditingController();
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
  final _taskReasonCtrl = TextEditingController();
  final _salaryBasicCtrl = TextEditingController();
  final _salaryAllowancesCtrl = TextEditingController();
  final _salaryDeductionsCtrl = TextEditingController();
  final _salaryTaxCtrl = TextEditingController();
  final _salaryBonusCtrl = TextEditingController(text: '0');
  final _salaryIncentivesCtrl = TextEditingController(text: '0');
  final _bonusAmountCtrl = TextEditingController();
  final _incentiveAmountCtrl = TextEditingController();
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
  bool _showLoginHelpdesk = false;
  bool _isApplyingSavedLogin = false;
  String? _employeeProfilePhotoBiometric;
  String? _editEmployeeProfilePhotoBiometric;
  String? _lastAttendancePhotoBiometric;
  String? _lastAttendanceBiometricMessage;
  String? _passwordRefillUsername;
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
  DateTime _selectedReimbursementDate = DateTime.now();
  String? _reimbursementFileName;
  String? _reimbursementPdfData;
  bool _isReimbursementLoading = false;
  List<Map<String, dynamic>> _reimbursements = [];
  DateTime _selectedAdminReimbursementDate = DateTime.now();
  bool _isAdminReimbursementLoading = false;
  List<Map<String, dynamic>> _adminReimbursements = [];
  String _selectedHrPayrollSection = 'Reimbursement';
  String _selectedPayrollMonth = _monthName(DateTime.now().month);
  String _selectedPayrollYear = DateTime.now().year.toString();
  int? _selectedPayrollEmployeeId;
  int? _selectedBonusEmployeeId;
  bool _isPayrollSaving = false;
  bool _isSalaryRecordsLoading = false;
  List<Map<String, dynamic>> _adminSalaryRecords = [];
  bool _isTasksLoading = false;
  bool _isTaskSubmitting = false;
  bool _isHelpdeskLoading = false;
  String _selectedHrSection = 'Staff Directory';
  String _selectedHrDashboardDetail = '';
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
  Map<String, dynamic>? _selectedAdminAttendanceDetail;
  final Map<String, String> _pendingRequestActions = {};
  List<Map<String, dynamic>> _employeeLeaves = [];
  List<Map<String, dynamic>> _employeeTasks = [];
  List<Map<String, dynamic>> _helpdeskTickets = [];
  List<Map<String, dynamic>> _employeeDirectory = [];
  List<dynamic> _adminEmployees = [];
  int? _selectedEditEmployeeId;
  int? _selectedLocationEmployeeId;
  int? _selectedHrDashboardEmployeeId;
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
  DateTime? _selectedLocationDate;
  DateTime? _locationEffectiveFrom;
  DateTime? _locationEffectiveTo;
  DateTime _selectedHrDashboardDate = DateTime.now();
  bool _isDashboardLoading = false;
  String? _dashboardError;
  Map<String, Map<String, String>> _savedLoginDetails = {};

  static const _savedLoginDetailsKey = 'healon_saved_login_details';
  static const _lastLoginUsernameKey = 'healon_last_login_username';
  static const _loginHelpdeskIssuesKey = 'healon_login_helpdesk_issues';

  bool get _isAdminRole => _selectedRole.trim().toLowerCase() == 'admin';
  bool get _isHrRole => _selectedRole.trim().toLowerCase() == 'hr';

  @override
  void initState() {
    super.initState();
    _loadSavedLoginDetails();
    _empIdCtrl.addListener(_handleLoginUsernameChanged);
  }

  int _readInt(Map<String, dynamic>? map, String key) {
    return (map?[key] as num?)?.toInt() ?? 0;
  }

  String _currentDisplayName(String fallback) {
    final name = _currentUser?['name']?.toString().trim() ?? '';
    if (name.isNotEmpty && name != '-') return name;
    final username = _currentUser?['username']?.toString().trim() ?? '';
    return username.isNotEmpty ? username : fallback;
  }

  String _dailyPositiveQuote() {
    const quotes = [
      'Small steps done well become strong progress.',
      'Good work today makes tomorrow easier to build.',
      'Clarity, kindness, and consistency move teams forward.',
      'Every thoughtful action adds trust to the workplace.',
      'Progress grows when people feel seen and supported.',
      'A steady day can still be a powerful day.',
      'Lead with care, decide with clarity, and keep moving.',
    ];
    return quotes[DateTime.now().weekday - 1];
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

  void _loadSavedLoginDetails() {
    final rawDetails = login_storage.readString(_savedLoginDetailsKey);
    if (rawDetails != null && rawDetails.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDetails) as Map<String, dynamic>;
        _savedLoginDetails = decoded.map((username, value) {
          final details = value as Map<String, dynamic>;
          return MapEntry(
            username,
            details.map((key, item) => MapEntry(key, item.toString())),
          );
        });
      } catch (_) {
        _savedLoginDetails = {};
      }
    }

    final lastUsername = login_storage.readString(_lastLoginUsernameKey);
    if (lastUsername == null || lastUsername.isEmpty) {
      return;
    }
    final details = _savedLoginDetails[lastUsername];
    if (details == null) {
      return;
    }

    _isApplyingSavedLogin = true;
    _empIdCtrl.text = lastUsername;
    _selectedRole = details['role'] ?? _selectedRole;
    _rememberMe = true;
    _passwordRefillUsername = lastUsername;
    _isApplyingSavedLogin = false;
  }

  void _handleLoginUsernameChanged() {
    if (_isApplyingSavedLogin) return;

    final username = _empIdCtrl.text.trim();
    final details = _savedLoginDetails[username];
    final nextRefillUsername = details == null ? null : username;
    if (_passwordRefillUsername == nextRefillUsername) return;

    setState(() {
      _passwordRefillUsername = nextRefillUsername;
      if (details != null) {
        _selectedRole = details['role'] ?? _selectedRole;
        _rememberMe = true;
      }
    });
  }

  void _refillSavedPassword() {
    final username = _passwordRefillUsername;
    if (username == null) return;
    final details = _savedLoginDetails[username];
    if (details == null) return;

    _isApplyingSavedLogin = true;
    setState(() {
      _passCtrl.text = details['password'] ?? '';
      _selectedRole = details['role'] ?? _selectedRole;
      _rememberMe = true;
      _passwordRefillUsername = null;
    });
    _isApplyingSavedLogin = false;
  }

  void _saveCurrentLoginDetails() {
    final username = _empIdCtrl.text.trim();
    if (username.isEmpty) return;

    if (_rememberMe) {
      _savedLoginDetails[username] = {
        'password': _passCtrl.text,
        'role': _selectedRole,
      };
      login_storage.writeString(
        _savedLoginDetailsKey,
        jsonEncode(_savedLoginDetails),
      );
      login_storage.writeString(_lastLoginUsernameKey, username);
    } else {
      _savedLoginDetails.remove(username);
      login_storage.writeString(
        _savedLoginDetailsKey,
        jsonEncode(_savedLoginDetails),
      );
      if (login_storage.readString(_lastLoginUsernameKey) == username) {
        login_storage.removeString(_lastLoginUsernameKey);
      }
    }
  }

  void _submitLoginHelpdeskIssue() {
    final issue = _loginHelpdeskIssueCtrl.text.trim();
    if (issue.isEmpty) {
      _showNotification('Please enter your issue', isError: true);
      return;
    }

    final rawIssues = login_storage.readString(_loginHelpdeskIssuesKey);
    List<dynamic> issues = [];
    if (rawIssues != null && rawIssues.isNotEmpty) {
      try {
        issues = jsonDecode(rawIssues) as List<dynamic>;
      } catch (_) {
        issues = [];
      }
    }
    issues.add({
      'username': _empIdCtrl.text.trim(),
      'issue': issue,
      'created_at': DateTime.now().toIso8601String(),
    });
    login_storage.writeString(_loginHelpdeskIssuesKey, jsonEncode(issues));

    setState(() {
      _loginHelpdeskIssueCtrl.clear();
      _showLoginHelpdesk = false;
    });
    _showNotification('Issue submitted successfully');
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
    _empIdCtrl.removeListener(_handleLoginUsernameChanged);
    _empIdCtrl.dispose();
    _passCtrl.dispose();
    _resetMobileCtrl.dispose();
    _resetOtpCtrl.dispose();
    _resetPassCtrl.dispose();
    _helpdeskIssueCtrl.dispose();
    _loginHelpdeskIssueCtrl.dispose();
    _employeeDisplayNameCtrl.dispose();
    _employeeFirstNameCtrl.dispose();
    _employeeLastNameCtrl.dispose();
    _employeeDobCtrl.dispose();
    _employeeEmailCtrl.dispose();
    _employeePhoneCtrl.dispose();
    _employeeDepartmentCtrl.dispose();
    _employeeDesignationCtrl.dispose();
    _employeeUsernameCtrl.dispose();
    _employeePasswordCtrl.dispose();
    _employeeSearchCtrl.dispose();
    _reimbursementReasonCtrl.dispose();
    _editEmployeeDisplayNameCtrl.dispose();
    _editEmployeeFirstNameCtrl.dispose();
    _editEmployeeLastNameCtrl.dispose();
    _editEmployeeDobCtrl.dispose();
    _editEmployeeEmailCtrl.dispose();
    _editEmployeePhoneCtrl.dispose();
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
    _taskReasonCtrl.dispose();
    _salaryBasicCtrl.dispose();
    _salaryAllowancesCtrl.dispose();
    _salaryDeductionsCtrl.dispose();
    _salaryTaxCtrl.dispose();
    _salaryBonusCtrl.dispose();
    _salaryIncentivesCtrl.dispose();
    _bonusAmountCtrl.dispose();
    _incentiveAmountCtrl.dispose();
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

  bool _looksLikeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
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
    final passwordError = _passwordRuleError(_resetPassCtrl.text);
    if (passwordError != null) {
      dialogSetState(() => _resetMessage = passwordError);
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

  String? _passwordRuleError(String password) {
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    if (password.length < 6 || !hasUppercase || !hasLowercase || !hasNumber) {
      return 'Password must be at least 6 characters and include 1 uppercase letter, 1 lowercase letter, and 1 number.';
    }
    return null;
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
        final dashboard = await _apiGet('/api/admin/dashboard/');
        final employees = await _apiGet('/api/admin/employees/');
        final attendance = await _apiGet('/api/admin/attendance/');
        final userDashboard = await _apiGet('/api/dashboard/');
        final leaves = await _apiGet('/api/employee/leaves/');
        final tasks = await _apiGet('/api/employee/tasks/');
        final helpdesk = await _apiGet('/api/employee/helpdesk/');
        final directory = await _apiGet('/api/employee/directory/');
        if (!mounted) {
          return;
        }
        setState(() {
          _adminDashboard = dashboard;
          _adminEmployees = employees?['employees'] as List<dynamic>? ?? [];
          _adminAttendance = attendance;
          _userDashboard = userDashboard;
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
          _currentUser = userDashboard?['user'] as Map<String, dynamic>?;
        });
        await _loadAdminTasks();
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

  Future<String?> _captureAttendancePhoto(String actionLabel) async {
    _showNotification('Capture your photo biometric to $actionLabel');
    final photo = await photo_biometric.pickPhotoBiometric();
    if (photo == null || photo.isEmpty) {
      _showNotification(
        'Photo biometric is required to $actionLabel',
        isError: true,
      );
      return null;
    }
    return photo;
  }

  Future<void> _captureEmployeeProfilePhoto({bool isEdit = false}) async {
    final photo = await photo_biometric.pickPhotoBiometric();
    if (photo == null || photo.isEmpty) {
      _showNotification(
        'Employee verification photo is required',
        isError: true,
      );
      return;
    }
    setState(() {
      if (isEdit) {
        _editEmployeeProfilePhotoBiometric = photo;
      } else {
        _employeeProfilePhotoBiometric = photo;
      }
    });
    _showNotification('Employee verification photo captured');
  }

  Future<void> checkOut() async {
    final photo = await _captureAttendancePhoto('check out');
    if (photo == null) {
      return;
    }

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
        'photo_biometric': photo,
      }),
    );
    if (resp.statusCode == 201) {
      final details = _attendanceBiometricDetails(resp.body);
      setState(() {
        _lastAttendancePhotoBiometric = photo;
        _lastAttendanceBiometricMessage = details.isEmpty
            ? 'Check-out photo biometric captured'
            : 'Check-out $details';
      });
      _showNotification(
        details.isEmpty
            ? 'Checked out successfully'
            : 'Checked out successfully - $details',
      );
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
          _selectedHrDashboardDetail = '';
          _selectedAttendanceSection = 'Add Employee';
          _selectedHrSection = 'Add Employee';
          _status = 'Logged in successfully';
        });
        _saveCurrentLoginDetails();
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
    final loaded = await _ensureEmployeeDirectoryLoaded();
    if (!loaded) return;
    if (!mounted) return;
    var query = '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select CC Employee'),
          content: SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final filteredEmployees = _employeeDirectory.where((employee) {
                  final name =
                      employee['name']?.toString().trim().isNotEmpty == true
                      ? employee['name'].toString()
                      : employee['username']?.toString() ?? 'Employee';
                  final username = employee['username']?.toString() ?? '';
                  final employeeId = employee['employee_id']?.toString() ?? '';
                  final role = employee['role']?.toString() ?? '';
                  final haystack = '$name $username $employeeId $role'
                      .toLowerCase();
                  return haystack.contains(query.toLowerCase().trim());
                }).toList();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search employees',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    if (_employeeDirectory.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No other employees found.'),
                      )
                    else if (filteredEmployees.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No employees match your search.'),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredEmployees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final employee = filteredEmployees[index];
                            final name =
                                employee['name']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true
                                ? employee['name'].toString()
                                : employee['username']?.toString() ??
                                      'Employee';
                            final employeeId =
                                employee['employee_id']?.toString() ??
                                employee['username']?.toString() ??
                                '';
                            final role = employee['role']?.toString() ?? '';
                            return ListTile(
                              dense: true,
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
                  ],
                );
              },
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

  Future<bool> _ensureEmployeeDirectoryLoaded() async {
    if (_employeeDirectory.isNotEmpty) return true;
    try {
      final directory = await _apiGet('/api/employee/directory/');
      if (!mounted) return false;
      setState(() {
        _employeeDirectory =
            directory?['employees']
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
      });
      return true;
    } catch (e) {
      _showNotification('Unable to load employees: $e', isError: true);
      return false;
    }
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

  Future<void> _pickReimbursementPdf() async {
    final upload = await reimbursement_upload.pickReimbursementPdf();
    if (upload == null) {
      _showNotification('Select a PDF reimbursement file', isError: true);
      return;
    }
    setState(() {
      _reimbursementFileName = upload.fileName;
      _reimbursementPdfData = upload.dataUrl;
    });
  }

  Future<void> _pickReimbursementDate({bool admin = false}) async {
    final current = admin
        ? _selectedAdminReimbursementDate
        : _selectedReimbursementDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (admin) {
        _selectedAdminReimbursementDate = picked;
      } else {
        _selectedReimbursementDate = picked;
      }
    });
    if (admin) {
      await _loadAdminReimbursements();
    } else {
      await _loadReimbursements();
    }
  }

  Future<void> _loadReimbursements() async {
    if (_token == null) return;
    setState(() => _isReimbursementLoading = true);
    try {
      final resp = await http.get(
        Uri.parse(
          '$backendUrl/api/employee/reimbursements/?date=${_dateQuery(_selectedReimbursementDate)}',
        ),
        headers: {'Authorization': 'Token $_token'},
      );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _reimbursements = (decoded['reimbursements'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
        });
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to load reimbursements'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to load reimbursements: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isReimbursementLoading = false);
    }
  }

  Future<void> _submitReimbursement() async {
    final reason = _reimbursementReasonCtrl.text.trim();
    if (_reimbursementPdfData == null || _reimbursementFileName == null) {
      _showNotification('Upload a PDF file', isError: true);
      return;
    }
    if (reason.isEmpty) {
      _showNotification('Enter reimbursement reason', isError: true);
      return;
    }

    setState(() => _isReimbursementLoading = true);
    try {
      final resp = await http.post(
        Uri.parse('$backendUrl/api/employee/reimbursements/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode({
          'expense_date': _dateQuery(_selectedReimbursementDate),
          'reason': reason,
          'file_name': _reimbursementFileName,
          'pdf_data': _reimbursementPdfData,
        }),
      );
      if (resp.statusCode == 201) {
        _showNotification('Reimbursement submitted');
        _reimbursementReasonCtrl.clear();
        setState(() {
          _reimbursementFileName = null;
          _reimbursementPdfData = null;
        });
        await _loadReimbursements();
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to submit reimbursement'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to submit reimbursement: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isReimbursementLoading = false);
    }
  }

  Future<void> _loadAdminReimbursements() async {
    if (_token == null) return;
    setState(() => _isAdminReimbursementLoading = true);
    try {
      final resp = await http.get(
        Uri.parse(
          '$backendUrl/api/admin/reimbursements/?date=${_dateQuery(_selectedAdminReimbursementDate)}',
        ),
        headers: {'Authorization': 'Token $_token'},
      );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _adminReimbursements =
              (decoded['reimbursements'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
        });
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to load reimbursements'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to load reimbursements: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isAdminReimbursementLoading = false);
    }
  }

  Future<void> _loadAdminSalaryRecords() async {
    if (_token == null) return;
    setState(() => _isSalaryRecordsLoading = true);
    try {
      final query = StringBuffer(
        '?month=${_monthNumber(_selectedPayrollMonth)}&year=$_selectedPayrollYear',
      );
      final resp = await http.get(
        Uri.parse('$backendUrl/api/admin/salary-records/$query'),
        headers: {'Authorization': 'Token $_token'},
      );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _adminSalaryRecords =
              (decoded['salary_records'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
        });
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to load salary records'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to load salary records: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSalaryRecordsLoading = false);
    }
  }

  Future<void> _saveSalaryRecord({bool bonusOnly = false}) async {
    final employeeId = bonusOnly
        ? _selectedBonusEmployeeId
        : _selectedPayrollEmployeeId;
    if (_token == null || employeeId == null) {
      _showNotification('Select an employee', isError: true);
      return;
    }
    final existing = _salaryRecordForEmployee(employeeId);
    if (bonusOnly && existing == null) {
      _showNotification(
        'Create salary structure for this employee first',
        isError: true,
      );
      return;
    }

    setState(() => _isPayrollSaving = true);
    try {
      final body = bonusOnly
          ? {
              ...?existing,
              'employee_id': employeeId,
              'year': _selectedPayrollYear,
              'month': _monthNumber(_selectedPayrollMonth),
              'bonus': _bonusAmountCtrl.text.trim(),
              'incentives': _incentiveAmountCtrl.text.trim(),
              'is_published': true,
            }
          : {
              'employee_id': employeeId,
              'year': _selectedPayrollYear,
              'month': _monthNumber(_selectedPayrollMonth),
              'basic_salary': _salaryBasicCtrl.text.trim(),
              'allowances': _salaryAllowancesCtrl.text.trim(),
              'deductions': _salaryDeductionsCtrl.text.trim(),
              'tax_deducted': _salaryTaxCtrl.text.trim(),
              'bonus': _salaryBonusCtrl.text.trim(),
              'incentives': _salaryIncentivesCtrl.text.trim(),
              'is_published': true,
            };
      final resp = await http.post(
        Uri.parse('$backendUrl/api/admin/salary-records/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode == 201) {
        _showNotification(
          bonusOnly
              ? 'Bonus and incentives updated'
              : 'Salary structure saved and payslip generated',
        );
        if (!bonusOnly) {
          _salaryBasicCtrl.clear();
          _salaryAllowancesCtrl.clear();
          _salaryDeductionsCtrl.clear();
          _salaryTaxCtrl.clear();
          _salaryBonusCtrl.text = '0';
          _salaryIncentivesCtrl.text = '0';
        } else {
          _bonusAmountCtrl.clear();
          _incentiveAmountCtrl.clear();
        }
        await _loadAdminSalaryRecords();
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to save salary record'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to save salary record: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPayrollSaving = false);
    }
  }

  Map<String, dynamic>? _salaryRecordForEmployee(int employeeId) {
    for (final record in _adminSalaryRecords) {
      final recordEmployeeId = (record['employee'] as num?)?.toInt();
      if (recordEmployeeId == employeeId) return record;
    }
    return null;
  }

  void _downloadReimbursementPdf(Map<String, dynamic> reimbursement) {
    final pdfData = reimbursement['pdf_data']?.toString() ?? '';
    final fileName =
        reimbursement['file_name']?.toString().trim().isNotEmpty == true
        ? reimbursement['file_name'].toString().trim()
        : 'reimbursement.pdf';
    final payload = pdfData.startsWith('data:application/pdf;base64,')
        ? pdfData.substring(pdfData.indexOf(',') + 1)
        : '';

    if (payload.isEmpty) {
      _showNotification('No reimbursement document found', isError: true);
      return;
    }

    try {
      downloadPdfFile(base64Decode(payload), fileName);
      _showNotification('Reimbursement document downloaded');
    } catch (e) {
      _showNotification('Unable to download reimbursement: $e', isError: true);
    }
  }

  Future<void> _registerEmployee() async {
    var displayName = _employeeDisplayNameCtrl.text.trim();
    var firstName = _employeeFirstNameCtrl.text.trim();
    var lastName = _employeeLastNameCtrl.text.trim();
    final dateOfBirth = _employeeDobCtrl.text.trim();
    final email = _employeeEmailCtrl.text.trim();
    final phone = _employeePhoneCtrl.text.trim();
    final username = _employeeUsernameCtrl.text.trim();
    final password = _employeePasswordCtrl.text;
    final department = _employeeDepartmentCtrl.text.trim();
    final designation = _employeeDesignationCtrl.text.trim();

    if (displayName.isEmpty && firstName.isNotEmpty) {
      displayName = [
        firstName,
        lastName,
      ].where((part) => part.isNotEmpty).join(' ');
    }
    if ((firstName.isEmpty || lastName.isEmpty) && displayName.isNotEmpty) {
      final parts = displayName.split(RegExp(r'\s+'));
      firstName = firstName.isEmpty ? parts.first : firstName;
      if (lastName.isEmpty && parts.length > 1) {
        lastName = parts.sublist(1).join(' ');
      }
    }

    if (displayName.isEmpty ||
        firstName.isEmpty ||
        email.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      _showNotification(
        'Display name, email, username, and password are required',
        isError: true,
      );
      return;
    }
    final passwordError = _passwordRuleError(password);
    if (passwordError != null) {
      _showNotification(passwordError, isError: true);
      return;
    }
    if (_employeeProfilePhotoBiometric == null ||
        _employeeProfilePhotoBiometric!.isEmpty) {
      _showNotification('Capture employee verification photo', isError: true);
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
          'name': displayName,
          'first_name': firstName,
          'last_name': lastName,
          'date_of_birth': dateOfBirth,
          'email': email,
          'mobile_number': phone,
          'profile_photo_biometric': _employeeProfilePhotoBiometric,
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
        _employeeDisplayNameCtrl.clear();
        _employeeFirstNameCtrl.clear();
        _employeeLastNameCtrl.clear();
        _employeeDobCtrl.clear();
        _employeeEmailCtrl.clear();
        _employeePhoneCtrl.clear();
        _employeeProfilePhotoBiometric = null;
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
      _editEmployeeDisplayNameCtrl.text = employee['name']?.toString() ?? '';
      _editEmployeeFirstNameCtrl.text =
          employee['first_name']?.toString() ?? '';
      _editEmployeeLastNameCtrl.text = employee['last_name']?.toString() ?? '';
      _editEmployeeDobCtrl.text = employee['date_of_birth']?.toString() ?? '';
      _editEmployeeEmailCtrl.text = employee['email']?.toString() ?? '';
      _editEmployeePhoneCtrl.text = employee['mobile_number']?.toString() ?? '';
      _editEmployeeProfilePhotoBiometric = employee['profile_photo_biometric']
          ?.toString();
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

    var displayName = _editEmployeeDisplayNameCtrl.text.trim();
    var firstName = _editEmployeeFirstNameCtrl.text.trim();
    var lastName = _editEmployeeLastNameCtrl.text.trim();
    final dateOfBirth = _editEmployeeDobCtrl.text.trim();
    final email = _editEmployeeEmailCtrl.text.trim();
    final phone = _editEmployeePhoneCtrl.text.trim();
    final username = _editEmployeeUsernameCtrl.text.trim();
    if (displayName.isEmpty && firstName.isNotEmpty) {
      displayName = [
        firstName,
        lastName,
      ].where((part) => part.isNotEmpty).join(' ');
    }
    if ((firstName.isEmpty || lastName.isEmpty) && displayName.isNotEmpty) {
      final parts = displayName.split(RegExp(r'\s+'));
      firstName = firstName.isEmpty ? parts.first : firstName;
      if (lastName.isEmpty && parts.length > 1) {
        lastName = parts.sublist(1).join(' ');
      }
    }

    if (displayName.isEmpty ||
        firstName.isEmpty ||
        email.isEmpty ||
        username.isEmpty) {
      _showNotification(
        'Display name, email, and username are required',
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
        'name': displayName,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'email': email,
        'mobile_number': phone,
        if (_editEmployeeProfilePhotoBiometric?.isNotEmpty == true)
          'profile_photo_biometric': _editEmployeeProfilePhotoBiometric,
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
        final passwordError = _passwordRuleError(password);
        if (passwordError != null) {
          _showNotification(passwordError, isError: true);
          setState(() => _isEmployeeSaving = false);
          return;
        }
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

  Future<void> _confirmDeleteEmployee(Map<String, dynamic> employee) async {
    final employeeId = _employeeId(employee);
    if (employeeId == 0) {
      _showNotification('Select an employee first', isError: true);
      return;
    }
    final employeeName = employee['name']?.toString() ?? 'this employee';
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Employee'),
          content: Text(
            'Delete $employeeName? This will remove the employee from the system.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) return;
    await _deleteEmployee(employeeId);
  }

  Future<void> _deleteEmployee(int employeeId) async {
    setState(() => _isEmployeeSaving = true);
    try {
      final resp = await http.delete(
        Uri.parse('$backendUrl/api/admin/employees/$employeeId/'),
        headers: {if (_token != null) 'Authorization': 'Token $_token'},
      );

      if (resp.statusCode == 204 || resp.statusCode == 200) {
        _showNotification('Employee deleted');
        setState(() {
          _selectedEditEmployeeId = null;
          _editEmployeeDisplayNameCtrl.clear();
          _editEmployeeFirstNameCtrl.clear();
          _editEmployeeLastNameCtrl.clear();
          _editEmployeeDobCtrl.clear();
          _editEmployeeEmailCtrl.clear();
          _editEmployeePhoneCtrl.clear();
          _editEmployeeProfilePhotoBiometric = null;
          _editEmployeeDepartmentCtrl.clear();
          _editEmployeeDesignationCtrl.clear();
          _editEmployeeUsernameCtrl.clear();
          _editEmployeePasswordCtrl.clear();
        });
        await loadDashboardData();
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to delete employee'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to delete employee: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isEmployeeSaving = false);
      }
    }
  }

  Future<void> _submitTaskReason() async {
    final task = _employeeTasks.firstWhere((item) {
      final status = item['status']?.toString() ?? '';
      return status == 'assigned' ||
          status == 'in_progress' ||
          status == 'review';
    }, orElse: () => <String, dynamic>{});
    final taskId = (task['id'] as num?)?.toInt() ?? 0;
    final reason = _taskReasonCtrl.text.trim();
    if (taskId == 0) {
      _showNotification('No pending task selected', isError: true);
      return;
    }
    if (reason.isEmpty) {
      _showNotification('Enter a reason before submitting', isError: true);
      return;
    }

    setState(() => _isTaskSubmitting = true);
    try {
      final resp = await http.post(
        Uri.parse('$backendUrl/api/employee/tasks/'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
        body: jsonEncode({'task_id': taskId, 'reason': reason}),
      );
      if (resp.statusCode == 200) {
        _showNotification('Task submitted to admin');
        _taskReasonCtrl.clear();
        await loadDashboardData();
        await _loadSelectedTasks();
      } else {
        _showNotification(
          _responseMessage(resp, 'Unable to submit task'),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification('Unable to submit task: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isTaskSubmitting = false);
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
      _locationEffectiveFrom = DateTime.tryParse(
        location?['effective_from']?.toString() ?? '',
      );
      _locationEffectiveTo = DateTime.tryParse(
        location?['effective_to']?.toString() ?? '',
      );
    });
  }

  Future<void> _saveEmployeeLocation() async {
    final employeeId = _selectedLocationEmployeeId;
    final address = _locationAddressCtrl.text.trim();
    final mapOrExtraAddress = _locationMapLinkCtrl.text.trim();
    final savedAddress = address.isNotEmpty ? address : mapOrExtraAddress;
    final mapLink = _looksLikeUrl(mapOrExtraAddress) ? mapOrExtraAddress : '';
    final radius = int.tryParse(_locationRadiusCtrl.text.trim()) ?? 100;

    if (employeeId == null || employeeId == 0) {
      _showNotification('Select an employee first', isError: true);
      return;
    }
    if (savedAddress.isEmpty) {
      _showNotification('Enter the assigned work address', isError: true);
      return;
    }
    if (radius <= 0) {
      _showNotification('Radius must be greater than 0', isError: true);
      return;
    }
    if (_locationEffectiveFrom != null &&
        _locationEffectiveTo != null &&
        _locationEffectiveTo!.isBefore(_locationEffectiveFrom!)) {
      _showNotification(
        'Location end date cannot be before start date',
        isError: true,
      );
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
          'address': savedAddress,
          'map_url': mapLink,
          'extra_location_text': mapOrExtraAddress,
          'radius_meters': radius,
          'effective_from': _locationEffectiveFrom == null
              ? null
              : _dateQuery(_locationEffectiveFrom!),
          'effective_to': _locationEffectiveTo == null
              ? null
              : _dateQuery(_locationEffectiveTo!),
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
    final photo = await _captureAttendancePhoto('check in');
    if (photo == null) {
      return;
    }

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
        'photo_biometric': photo,
      }),
    );
    if (resp.statusCode == 201) {
      final details = _attendanceBiometricDetails(resp.body);
      setState(() {
        _lastAttendancePhotoBiometric = photo;
        _lastAttendanceBiometricMessage = details.isEmpty
            ? 'Check-in photo biometric captured'
            : 'Check-in $details';
      });
      _showNotification(
        details.isEmpty
            ? 'Checked in successfully'
            : 'Checked in successfully - $details',
      );
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

  String _attendanceBiometricDetails(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final details = decoded['biometric_details'];
        if (details is Map<String, dynamic> &&
            details['verified'] == true &&
            details['size_bytes'] != null) {
          return 'photo biometric verified';
        }
      }
    } catch (_) {}
    return '';
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
        _selectedAdminAttendanceDetail = null;
        if (_isHrRole) {
          _selectedHrSection = 'Daily Attendance';
        }
        _selectedHrDashboardDetail = '';
      } else if (menuKey == 'Tasks') {
        _selectedTaskSection = 'Pending Tasks';
      } else if (menuKey == 'Leaves') {
        _selectedLeaveSection = 'Apply Leave';
        if (_isHrRole) {
          _selectedHrSection = 'Leaves';
          _selectedHrDashboardDetail = '';
        }
      } else if (menuKey == 'Salary') {
        _selectedSalarySection = 'Payslips';
      } else if (menuKey == 'Employee Management') {
        if (_isAdminRole) {
          _selectedAttendanceSection = 'Edit Employee';
        } else {
          _selectedAttendanceSection = 'Add Employee';
          _selectedHrSection = 'Add Employee';
        }
        _selectedHrDashboardDetail = '';
      } else if (menuKey == 'Employee Location') {
        _selectedAttendanceSection = 'Add Location';
        _selectedHrSection = 'Add Location';
        _selectedLocationDate = null;
        _selectedHrDashboardDetail = '';
      } else if (menuKey == 'Smart Location Management') {
        _selectedAttendanceSection = 'Edit Location';
        _selectedLocationDate = null;
      } else if (menuKey == 'Work Monitoring') {
        _selectedAdminTaskStatus = 'assigned';
      } else if (menuKey == 'Pending Requests') {
        _selectedPendingRequestStatus = 'pending';
      } else if (menuKey == 'Helpdesk' || menuKey == 'Help Desk') {
        _selectedHrSection = 'Help Desk';
        _selectedHrDashboardDetail = '';
      } else if (menuKey == 'Notifications') {
        _selectedHrSection = 'Notifications';
        _selectedHrDashboardDetail = '';
      } else if (menuKey == 'Attendance Management') {
        _selectedHrSection = 'Daily Attendance';
      } else if (menuKey == 'Recruitment') {
        _selectedHrSection = 'Job Openings';
      } else if (menuKey == 'Payroll') {
        _selectedHrSection = 'Salary Management';
      } else if (menuKey == 'Employee Payroll') {
        _selectedHrSection = 'Employee Payroll';
        _selectedHrPayrollSection = 'Reimbursement';
        _selectedHrDashboardDetail = '';
      } else if (menuKey == 'Performance') {
        _selectedHrSection = 'Performance Tracker';
      }
    });
    if (menuKey == 'Attendance') {
      loadAttendanceReport();
      if ((_isAdminRole || _isHrRole) &&
          _selectedAttendanceSection == 'Attendance Reports') {
        _loadAdminAttendanceReport();
      }
    }
    if (menuKey == 'Work Monitoring') {
      _loadAdminTasks();
    }
    if (menuKey == 'Employee Payroll') {
      _loadAdminReimbursements();
      _loadAdminSalaryRecords();
    }
    if (menuKey == 'Helpdesk' || menuKey == 'Help Desk') {
      _loadSelectedHelpdeskTickets();
    }
    if (menuKey == 'Dashboard' ||
        menuKey == 'Employees' ||
        menuKey == 'Attendance' ||
        menuKey == 'Pending Requests' ||
        menuKey == 'Employee Management' ||
        menuKey == 'Employee Location' ||
        menuKey == 'Notifications' ||
        menuKey == 'Leaves') {
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
    if (section == 'Reimbursement') {
      _loadReimbursements();
    }
  }

  void _selectHrPayrollSection(String section) {
    setState(() {
      _selectedMenu = 'Employee Payroll';
      _selectedHrSection = 'Employee Payroll';
      _selectedHrPayrollSection = section;
    });
    if (section == 'Reimbursement') {
      _loadAdminReimbursements();
    } else {
      _loadAdminSalaryRecords();
    }
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

  String _dateQuery(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
          : Stack(
              children: [
                Row(
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
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                                () => _showPassword =
                                                    !_showPassword,
                                              ),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    if (_passwordRefillUsername != null) ...[
                                      Center(
                                        child: SizedBox(
                                          width: 300,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.18,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.55,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.lock_reset,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                const Expanded(
                                                  child: Text(
                                                    'Saved password found',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: _isLoading
                                                      ? null
                                                      : _refillSavedPassword,
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                  ),
                                                  child: const Text('Refill'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],

                                    // Forgot Password Link
                                    Center(
                                      child: SizedBox(
                                        width: 300,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed:
                                                _showForgotPasswordDialog,
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
                                                () => _rememberMe =
                                                    value ?? false,
                                              ),
                                              fillColor:
                                                  WidgetStateProperty.all(
                                                    Colors.white,
                                                  ),
                                              checkColor: const Color(
                                                0xFF1ABE8E,
                                              ),
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
                                            () =>
                                                _selectedRole = value ?? 'User',
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                              borderRadius:
                                                  BorderRadius.circular(24),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                          ),
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
                _buildLoginHelpdesk(),
              ],
            ),
    );
  }

  Widget _buildLoginHelpdesk() {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 20,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showLoginHelpdesk) ...[
              Container(
                width: 340,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.support_agent,
                          color: Color(0xFF1ABE8E),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Help Desk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2E5A),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () =>
                              setState(() => _showLoginHelpdesk = false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _loginHelpdeskIssueCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Small issue section',
                        filled: true,
                        fillColor: const Color(0xFFFCFCFD),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFF1ABE8E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _submitLoginHelpdeskIssue,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Submit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B5AF0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            ElevatedButton.icon(
              onPressed: () =>
                  setState(() => _showLoginHelpdesk = !_showLoginHelpdesk),
              icon: const Icon(Icons.help_outline),
              label: const Text('Help Desk'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F2E5A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInView() {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 292,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10204A), Color(0xFF172554)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 24,
                  offset: Offset(8, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [_brandTeal, Color(0xFF34D399)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _brandTeal.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isAdminRole
                              ? Icons.admin_panel_settings
                              : _isHrRole
                              ? Icons.badge
                              : Icons.person,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'HealOn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isAdminRole
                                  ? 'Admin Panel'
                                  : _isHrRole
                                  ? 'HR Panel'
                                  : 'Employee Panel',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

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
                            _buildSubMenuItem(
                              'Reimbursement',
                              _selectedSalarySection == 'Reimbursement',
                              () => _selectSalarySection('Reimbursement'),
                            ),
                          ],

                          _buildMenuItem('Helpdesk', Icons.help, 'Helpdesk'),
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
                              'Add Employee',
                              _selectedAttendanceSection == 'Add Employee',
                              () {
                                setState(() {
                                  _selectedMenu = 'Employee Management';
                                  _selectedAttendanceSection = 'Add Employee';
                                  _selectedHrSection = 'Add Employee';
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
                                  _selectedHrSection = 'Edit Employee';
                                });
                              },
                            ),
                          ],
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
                                  _selectedHrSection = 'Daily Attendance';
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
                                  _selectedHrSection = 'Attendance Reports';
                                });
                                _loadAdminAttendanceReport();
                              },
                            ),
                          ],
                          _buildMenuItem(
                            'Employee Location',
                            Icons.location_on,
                            'Employee Location',
                          ),
                          if (_selectedMenu == 'Employee Location') ...[
                            _buildSubMenuItem(
                              'Add Location',
                              _selectedAttendanceSection == 'Add Location',
                              () {
                                setState(() {
                                  _selectedMenu = 'Employee Location';
                                  _selectedAttendanceSection = 'Add Location';
                                  _selectedHrSection = 'Add Location';
                                });
                              },
                            ),
                            _buildSubMenuItem(
                              'Edit Location',
                              _selectedAttendanceSection == 'Edit Location',
                              () {
                                setState(() {
                                  _selectedMenu = 'Employee Location';
                                  _selectedAttendanceSection = 'Edit Location';
                                  _selectedHrSection = 'Edit Location';
                                });
                              },
                            ),
                          ],
                          _buildMenuItem(
                            'Employee Payroll',
                            Icons.account_balance_wallet,
                            'Employee Payroll',
                          ),
                          if (_selectedMenu == 'Employee Payroll') ...[
                            _buildSubMenuItem(
                              'Reimbursement',
                              _selectedHrPayrollSection == 'Reimbursement',
                              () => _selectHrPayrollSection('Reimbursement'),
                            ),
                            _buildSubMenuItem(
                              'Salary Structure',
                              _selectedHrPayrollSection == 'Salary Structure',
                              () => _selectHrPayrollSection('Salary Structure'),
                            ),
                            _buildSubMenuItem(
                              'Bonus & Incentives',
                              _selectedHrPayrollSection == 'Bonus & Incentives',
                              () =>
                                  _selectHrPayrollSection('Bonus & Incentives'),
                            ),
                          ],
                          _buildMenuItem(
                            'Leaves',
                            Icons.calendar_today,
                            'Leaves',
                          ),
                          _buildMenuItem(
                            'Notifications',
                            Icons.notifications_active_outlined,
                            'Notifications',
                          ),
                          _buildMenuItem('Helpdesk', Icons.help, 'Helpdesk'),
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
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 18),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
                ),
              ),
              child: DataTableTheme(
                data: DataTableThemeData(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF1F5F9),
                  ),
                  headingTextStyle: const TextStyle(
                    color: _inkBlue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                  dataTextStyle: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                  ),
                  dividerThickness: 0.6,
                ),
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
                          : _selectedMenu == 'Total Employees'
                          ? _buildTotalEmployeesDashboard()
                          : _selectedMenu == 'Pending Requests'
                          ? _buildPendingRequestsDashboard()
                          : _selectedMenu == 'Helpdesk'
                          ? _buildHelpdeskView()
                          : _buildAdminDashboard()
                    : _isHrRole
                    ? _selectedMenu == 'Employee Management'
                          ? _selectedAttendanceSection == 'Add Employee'
                                ? _buildEmployeeRegistrationView()
                                : _buildAdminEmployeesView()
                          : _selectedMenu == 'Attendance'
                          ? _buildAdminAttendanceView()
                          : _selectedMenu == 'Employee Location'
                          ? _buildSmartLocationManagementView()
                          : _selectedMenu == 'Employee Payroll'
                          ? _buildAdminReimbursementsView()
                          : _selectedMenu == 'Leaves'
                          ? _buildHrLeavesView()
                          : _selectedMenu == 'Notifications'
                          ? _buildHrNotificationsView()
                          : _selectedMenu == 'Helpdesk'
                          ? _buildHrHelpdeskDetail()
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
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF7FB),
                              Color(0xFFF8FCFF),
                              Color(0xFFCFF8F0),
                              Color(0xFFEFF9FF),
                              Color(0xFFFFFBFD),
                            ],
                            stops: [0.0, 0.24, 0.54, 0.78, 1.0],
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome Section
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome Back 👋',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
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
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
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
                              const SizedBox(height: 20),
                              _buildWelcomeQuoteBanner(
                                _currentDisplayName('Employee'),
                                'User',
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
                              if (_isDashboardLoading ||
                                  _dashboardError != null)
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
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Check In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
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
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Check Out',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_lastAttendancePhotoBiometric != null) ...[
                                const SizedBox(height: 18),
                                _buildPhotoBiometricPreview(
                                  'Latest captured biometric',
                                  _lastAttendancePhotoBiometric!,
                                  message: _lastAttendanceBiometricMessage,
                                ),
                              ],
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
                              _buildDashboardAnalyticsPanel(
                                'User Dashboard - ${_currentUser?['name'] ?? 'Employee'}',
                                [
                                  {
                                    'label': 'Present Days',
                                    'value': _readInt(
                                      _userSection('attendance'),
                                      'present_days_this_month',
                                    ),
                                    'color': const Color(0xFF1ABE8E),
                                  },
                                  {
                                    'label': 'Leave Balance',
                                    'value': _readInt(
                                      _userSection('leaves'),
                                      'available',
                                    ),
                                    'color': Colors.orange,
                                  },
                                  {
                                    'label': 'Leave Applied',
                                    'value': _readInt(
                                      _userSection('leaves'),
                                      'applied',
                                    ),
                                    'color': Colors.orange,
                                  },
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
    return _buildReportMonthYearControls(maxWidth: 520, showViewButton: false);
  }

  Widget _buildReportMonthYearControls({
    double maxWidth = 560,
    bool showViewButton = true,
  }) {
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
            if (showViewButton) ...[
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
          InkWell(
            onTap: _showRegularizationCcPicker,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFF3F63FF), width: 1.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF334155),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _regularizationCcCtrl.text.isEmpty
                          ? 'Add contact details'
                          : _regularizationCcCtrl.text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _regularizationCcCtrl.text.isEmpty
                            ? const Color(0xFF4B5563)
                            : const Color(0xFF1F2E5A),
                        fontSize: 16,
                        fontWeight: _regularizationCcCtrl.text.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
          readOnly: true,
          onTap: () => _pickRegularizationTime(controller),
          decoration: _regularizationInputDecoration(
            hintText: hintText,
            suffixIcon: IconButton(
              tooltip: 'Set time',
              onPressed: () => _pickRegularizationTime(controller),
              icon: const Icon(Icons.access_time, size: 17),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickRegularizationTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 10 : 10;
    final initialMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialHour.clamp(0, 23).toInt(),
        minute: initialMinute.clamp(0, 59).toInt(),
      ),
    );
    if (picked == null) return;
    setState(() {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
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
            controller: _taskReasonCtrl,
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
              onPressed: _isTaskSubmitting ? null : _submitTaskReason,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B5AF0),
                foregroundColor: Colors.white,
                minimumSize: const Size(90, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isTaskSubmitting
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
            final displayUsed = used.clamp(0, total);
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
                    Row(
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
                        const Spacer(),
                        Text(
                          '$available available',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
    } else if (section == 'Reimbursement') {
      description = 'Submit reimbursement PDFs and review requests by date.';
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
          else if (section == 'Reimbursement')
            _buildReimbursementSection()
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

  Widget _buildReimbursementSection() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                    'Reimbursement',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1F2E5A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isReimbursementLoading
                            ? null
                            : () => _pickReimbursementDate(),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _readableDate(
                            _selectedReimbursementDate.toIso8601String(),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isReimbursementLoading
                            ? null
                            : _pickReimbursementPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _reimbursementFileName == null
                              ? 'Upload PDF'
                              : _reimbursementFileName!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 460,
                    child: TextField(
                      controller: _reimbursementReasonCtrl,
                      maxLines: 3,
                      decoration: _salaryInputDecoration(label: 'Reason'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _isReimbursementLoading
                        ? null
                        : _submitReimbursement,
                    icon: _isReimbursementLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Upload'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _buildReimbursementTable(
              rows: _reimbursements,
              isLoading: _isReimbursementLoading,
              showEmployee: false,
              emptyMessage: 'No reimbursements submitted for this date.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminReimbursementsView() {
    final section = _selectedHrPayrollSection;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Employee Payroll',
            section == 'Reimbursement'
                ? 'Review employee reimbursement submissions by date.'
                : section == 'Salary Structure'
                ? 'Create monthly salary structures and publish payslips.'
                : 'Add bonus and incentives for an employee pay period.',
          ),
          const SizedBox(height: 24),
          _buildHrPayrollTabs(),
          const SizedBox(height: 22),
          if (section == 'Reimbursement')
            _buildHrReimbursementPanel()
          else if (section == 'Salary Structure')
            _buildHrSalaryStructurePanel()
          else
            _buildHrBonusIncentivesPanel(),
        ],
      ),
    );
  }

  Widget _buildHrPayrollTabs() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final section in const [
          'Reimbursement',
          'Salary Structure',
          'Bonus & Incentives',
        ])
          ChoiceChip(
            label: Text(section),
            selected: _selectedHrPayrollSection == section,
            onSelected: (_) => _selectHrPayrollSection(section),
          ),
      ],
    );
  }

  Widget _buildHrReimbursementPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _isAdminReimbursementLoading
                  ? null
                  : () => _pickReimbursementDate(admin: true),
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _readableDate(
                  _selectedAdminReimbursementDate.toIso8601String(),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isAdminReimbursementLoading
                  ? null
                  : _loadAdminReimbursements,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _buildReimbursementTable(
          rows: _adminReimbursements,
          isLoading: _isAdminReimbursementLoading,
          showEmployee: true,
          emptyMessage: 'No reimbursements submitted for this date.',
        ),
      ],
    );
  }

  Widget _buildHrSalaryStructurePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPayrollPeriodControls(),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
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
                  'Salary Structure',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1F2E5A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildEmployeeDropdown(
                      selectedId: _selectedPayrollEmployeeId,
                      label: 'Employee',
                      onChanged: (value) =>
                          setState(() => _selectedPayrollEmployeeId = value),
                    ),
                    _buildPayrollAmountField('Basic Salary', _salaryBasicCtrl),
                    _buildPayrollAmountField(
                      'Allowances',
                      _salaryAllowancesCtrl,
                    ),
                    _buildPayrollAmountField(
                      'Deductions',
                      _salaryDeductionsCtrl,
                    ),
                    _buildPayrollAmountField('Tax Deducted', _salaryTaxCtrl),
                    _buildPayrollAmountField('Bonus', _salaryBonusCtrl),
                    _buildPayrollAmountField(
                      'Incentives',
                      _salaryIncentivesCtrl,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isPayrollSaving
                      ? null
                      : () => _saveSalaryRecord(),
                  icon: _isPayrollSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long),
                  label: const Text('Generate Payslip'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _buildSalaryRecordsTable(),
      ],
    );
  }

  Widget _buildHrBonusIncentivesPanel() {
    final existing = _selectedBonusEmployeeId == null
        ? null
        : _salaryRecordForEmployee(_selectedBonusEmployeeId!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPayrollPeriodControls(),
        const SizedBox(height: 16),
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
                Text(
                  'Bonus & Incentives',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1F2E5A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildEmployeeDropdown(
                      selectedId: _selectedBonusEmployeeId,
                      label: 'Employee',
                      onChanged: (value) =>
                          setState(() => _selectedBonusEmployeeId = value),
                    ),
                    _buildPayrollAmountField('Bonus', _bonusAmountCtrl),
                    _buildPayrollAmountField(
                      'Incentives',
                      _incentiveAmountCtrl,
                    ),
                  ],
                ),
                if (_selectedBonusEmployeeId != null && existing == null) ...[
                  const SizedBox(height: 12),
                  _buildEmptyStateMessage(
                    'Create this employee salary structure before adding bonus.',
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isPayrollSaving
                      ? null
                      : () => _saveSalaryRecord(bonusOnly: true),
                  icon: _isPayrollSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_card),
                  label: const Text('Save Bonus'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _buildSalaryRecordsTable(),
      ],
    );
  }

  Widget _buildPayrollPeriodControls() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedPayrollMonth,
            decoration: _salaryInputDecoration(label: 'Month'),
            items: [
              for (var i = 1; i <= 12; i++)
                DropdownMenuItem(
                  value: _monthName(i),
                  child: Text(_monthName(i)),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedPayrollMonth = value);
              _loadAdminSalaryRecords();
            },
          ),
        ),
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedPayrollYear,
            decoration: _salaryInputDecoration(label: 'Year'),
            items: List.generate(6, (index) {
              final year = (DateTime.now().year - 2 + index).toString();
              return DropdownMenuItem(value: year, child: Text(year));
            }),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedPayrollYear = value);
              _loadAdminSalaryRecords();
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isSalaryRecordsLoading ? null : _loadAdminSalaryRecords,
          icon: const Icon(Icons.search),
          label: const Text('Search'),
        ),
      ],
    );
  }

  Widget _buildEmployeeDropdown({
    required int? selectedId,
    required String label,
    required ValueChanged<int?> onChanged,
  }) {
    final employees = _adminEmployeeMaps();
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<int>(
        initialValue: selectedId,
        decoration: _salaryInputDecoration(label: label),
        items: employees.map((employee) {
          final id = _employeeId(employee);
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              _employeeDisplayName(employee),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPayrollAmountField(
    String label,
    TextEditingController controller,
  ) {
    return SizedBox(
      width: 190,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _salaryInputDecoration(label: label),
      ),
    );
  }

  Widget _buildSalaryRecordsTable() {
    if (_isSalaryRecordsLoading && _adminSalaryRecords.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    }
    if (_adminSalaryRecords.isEmpty) {
      return _buildReportMessage(
        icon: Icons.payments_outlined,
        title: 'No salary records',
        message: 'No salary structure has been generated for this period.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Employee')),
            DataColumn(label: Text('Month')),
            DataColumn(label: Text('Basic')),
            DataColumn(label: Text('Allowances')),
            DataColumn(label: Text('Bonus')),
            DataColumn(label: Text('Incentives')),
            DataColumn(label: Text('Deductions')),
            DataColumn(label: Text('Tax')),
            DataColumn(label: Text('Net Salary')),
          ],
          rows: _adminSalaryRecords.map((record) {
            return DataRow(
              cells: [
                DataCell(Text(record['employee_name']?.toString() ?? '-')),
                DataCell(
                  Text(
                    '${_monthName((record['month'] as num?)?.toInt() ?? 1)} ${record['year'] ?? ''}',
                  ),
                ),
                DataCell(Text(_moneyLabel(record['basic_salary']))),
                DataCell(Text(_moneyLabel(record['allowances']))),
                DataCell(Text(_moneyLabel(record['bonus']))),
                DataCell(Text(_moneyLabel(record['incentives']))),
                DataCell(Text(_moneyLabel(record['deductions']))),
                DataCell(Text(_moneyLabel(record['tax_deducted']))),
                DataCell(Text(_moneyLabel(record['net_salary']))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReimbursementTable({
    required List<Map<String, dynamic>> rows,
    required bool isLoading,
    required bool showEmployee,
    required String emptyMessage,
  }) {
    if (isLoading && rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    }
    if (rows.isEmpty) {
      return _buildReportMessage(
        icon: Icons.receipt_long,
        title: 'No reimbursement data',
        message: emptyMessage,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            if (showEmployee) const DataColumn(label: Text('Employee')),
            const DataColumn(label: Text('Date')),
            const DataColumn(label: Text('Reason')),
            const DataColumn(label: Text('PDF')),
            const DataColumn(label: Text('Submitted')),
          ],
          rows: rows.map((row) {
            final pdfData = row['pdf_data']?.toString() ?? '';
            final cells = <DataCell>[
              if (showEmployee)
                DataCell(Text(row['employee_name']?.toString() ?? '-')),
              DataCell(
                Text(_readableDate(row['expense_date']?.toString() ?? '')),
              ),
              DataCell(
                SizedBox(
                  width: 260,
                  child: Text(
                    row['reason']?.toString() ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                TextButton.icon(
                  onPressed: pdfData.isEmpty
                      ? null
                      : () => _downloadReimbursementPdf(row),
                  icon: const Icon(Icons.download),
                  label: Text(row['file_name']?.toString() ?? 'Download PDF'),
                ),
              ),
              DataCell(
                Text(_readableDate(row['submitted_at']?.toString() ?? '')),
              ),
            ];
            return DataRow(cells: cells);
          }).toList(),
        ),
      ),
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
    if (_selectedHrDashboardDetail == 'Total Employees') {
      return _buildHrTotalEmployeesDetail();
    }
    if (_selectedHrDashboardDetail == 'Present Today') {
      return _buildHrAttendanceDetail('Present Today', 'Present');
    }
    if (_selectedHrDashboardDetail == 'Absent Today') {
      return _buildHrAttendanceDetail('Absent Today', 'Absent');
    }
    if (_selectedHrDashboardDetail == 'Leaves') {
      return _buildHrLeavesDetail();
    }
    final summary = _adminDashboard?['summary'] as Map<String, dynamic>?;
    final totalEmployees = _readInt(summary, 'total_employees');
    final presentToday = _readInt(summary, 'present_today');
    final absentToday = _readInt(summary, 'absent_today');
    final todaysLeaves = _hrLeaveItemsForDate(_selectedHrDashboardDate).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeQuoteBanner(_currentDisplayName('HR'), 'HR'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSectionHeader(
                  'HR Dashboard',
                  'Review workforce status and open focused HR dashboards.',
                ),
              ),
              IconButton.filled(
                tooltip: 'Refresh dashboard',
                onPressed: _isDashboardLoading ? null : refreshDashboardData,
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
          const SizedBox(height: 24),
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
          GridView.extent(
            maxCrossAxisExtent: 280,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.9,
            children: [
              _buildSummaryTile(
                'Total Employees',
                totalEmployees.toString(),
                Icons.groups,
                const Color(0xFF2B5AF0),
                isCompact: true,
                onTap: () => setState(
                  () => _selectedHrDashboardDetail = 'Total Employees',
                ),
              ),
              _buildSummaryTile(
                'Present Today',
                presentToday.toString(),
                Icons.event_available,
                const Color(0xFF1ABE8E),
                isCompact: true,
                onTap: () => setState(
                  () => _selectedHrDashboardDetail = 'Present Today',
                ),
              ),
              _buildSummaryTile(
                'Absent Today',
                absentToday.toString(),
                Icons.event_busy,
                Colors.red,
                isCompact: true,
                onTap: () =>
                    setState(() => _selectedHrDashboardDetail = 'Absent Today'),
              ),
              _buildSummaryTile(
                'Leaves',
                todaysLeaves.toString(),
                Icons.calendar_today,
                Colors.teal,
                isCompact: true,
                onTap: () =>
                    setState(() => _selectedHrDashboardDetail = 'Leaves'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDashboardAnalyticsPanel('HR Dashboard', [
            {
              'label': 'Total Employees',
              'value': totalEmployees,
              'color': const Color(0xFF2B5AF0),
            },
            {
              'label': 'Present Today',
              'value': presentToday,
              'color': const Color(0xFF1ABE8E),
            },
            {
              'label': 'Absent Today',
              'value': absentToday,
              'color': Colors.red,
            },
            {'label': 'Leaves', 'value': todaysLeaves, 'color': Colors.teal},
          ]),
        ],
      ),
    );
  }

  Widget _buildHrNotificationsView() {
    final notifications = _adminPendingWorkItems().take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Notifications',
            'Review pending approvals, support updates, and workforce activity.',
          ),
          const SizedBox(height: 24),
          _buildHrNotificationPanel(notifications),
        ],
      ),
    );
  }

  Widget _buildHrNotificationPanel(List<Map<String, dynamic>> notifications) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor),
        boxShadow: _softShadow(0.06),
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
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _inkBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (notifications.isEmpty)
            Text(
              'No notifications available.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
            )
          else
            ...notifications.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _lineColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF2B5AF0)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['type']?.toString() ?? 'Notification',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _inkBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item['employee'] ?? '-'} - ${item['title'] ?? '-'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusPill(item['status']?.toString() ?? 'Pending'),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHrHelpdeskDetail() {
    final issueDate = _readableDate(DateTime.now().toIso8601String());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Helpdesk',
            'Submit support issues and review issue resolution activity.',
          ),
          const SizedBox(height: 24),
          Container(
            width: 620,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lineColor),
              boxShadow: _softShadow(0.06),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Issue',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _inkBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Table(
                  columnWidths: const {
                    0: FixedColumnWidth(130),
                    1: FlexColumnWidth(),
                  },
                  border: TableBorder.all(color: _lineColor),
                  children: [
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Issue Date',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(issueDate),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Issue Reason',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: _helpdeskIssueCtrl,
                            maxLines: 3,
                            decoration: _helpdeskIssueInputDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _submitHelpdeskIssue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B5AF0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isHelpdeskLoading)
            const LinearProgressIndicator()
          else
            _buildHelpdeskTicketsTable(),
        ],
      ),
    );
  }

  Widget _buildHrDetailScaffold({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () =>
                    setState(() => _selectedHrDashboardDetail = ''),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildSectionHeader(title, subtitle)),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildHrEmployeeDropdown() {
    final employees = _adminEmployeeMaps();
    final selected =
        employees.any(
          (employee) => _employeeId(employee) == _selectedHrDashboardEmployeeId,
        )
        ? _selectedHrDashboardEmployeeId
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(180.0, 320.0)
            : 320.0;
        Widget dropdownText(String value) {
          return Text(value, maxLines: 1, overflow: TextOverflow.ellipsis);
        }

        return SizedBox(
          width: width,
          child: DropdownButtonFormField<int?>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Employee',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: dropdownText('All Employees'),
              ),
              ...employees.map((employee) {
                return DropdownMenuItem<int?>(
                  value: _employeeId(employee),
                  child: dropdownText(_employeeDisplayName(employee)),
                );
              }),
            ],
            onChanged: (value) {
              setState(() => _selectedHrDashboardEmployeeId = value);
            },
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _hrFilteredEmployees() {
    final employees = _adminEmployeeMaps();
    if (_selectedHrDashboardEmployeeId == null) return employees;
    return employees
        .where(
          (employee) => _employeeId(employee) == _selectedHrDashboardEmployeeId,
        )
        .toList();
  }

  Widget _buildHrTotalEmployeesDetail() {
    final employees = _hrFilteredEmployees();
    return _buildHrDetailScaffold(
      title: 'Total Employees',
      subtitle: 'Select an employee or review the complete employee list.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHrEmployeeDropdown(),
          const SizedBox(height: 20),
          if (employees.isEmpty)
            _buildReportMessage(
              icon: Icons.people_outline,
              title: 'No employees found',
              message: 'Employees will appear here after they are added.',
            )
          else
            _buildHrEmployeesTable(employees),
        ],
      ),
    );
  }

  Widget _buildHrEmployeesTable(List<Map<String, dynamic>> employees) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Employee Name')),
            DataColumn(label: Text('Username')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Department')),
            DataColumn(label: Text('Designation')),
            DataColumn(label: Text('Status')),
          ],
          rows: employees.map((employee) {
            return DataRow(
              cells: [
                DataCell(Text(employee['name']?.toString() ?? '-')),
                DataCell(Text(employee['username']?.toString() ?? '-')),
                DataCell(Text(employee['email']?.toString() ?? '-')),
                DataCell(Text(employee['department']?.toString() ?? '-')),
                DataCell(Text(employee['designation']?.toString() ?? '-')),
                DataCell(
                  _buildStatusPill(
                    employee['is_active'] == true ? 'Active' : 'Inactive',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _hrAttendanceRowsByStatus(String status) {
    final rows = _adminAttendance?['rows'] as List<dynamic>? ?? [];
    return rows.whereType<Map<String, dynamic>>().where((row) {
      final rowEmployeeId = (row['employee_id'] as num?)?.toInt();
      if (_selectedHrDashboardEmployeeId != null &&
          rowEmployeeId != _selectedHrDashboardEmployeeId) {
        return false;
      }
      return row['status']?.toString() == status;
    }).toList();
  }

  Widget _buildHrAttendanceDetail(String title, String status) {
    final rows = _hrAttendanceRowsByStatus(status);
    return _buildHrDetailScaffold(
      title: title,
      subtitle: 'Review employees marked $status for today.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHrEmployeeDropdown(),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            _buildReportMessage(
              icon: Icons.event_note,
              title: 'No attendance rows',
              message: 'No employees match this status today.',
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
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Check In')),
                    DataColumn(label: Text('Check Out')),
                    DataColumn(label: Text('Hours')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: rows.map((row) {
                    final hours = (row['total_hours'] as num?)?.toDouble();
                    return DataRow(
                      cells: [
                        DataCell(Text(row['employee']?.toString() ?? '-')),
                        DataCell(Text(row['username']?.toString() ?? '-')),
                        DataCell(Text(row['check_in']?.toString() ?? '-')),
                        DataCell(Text(row['check_out']?.toString() ?? '-')),
                        DataCell(Text(hours?.toStringAsFixed(2) ?? '-')),
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
      ),
    );
  }

  List<Map<String, dynamic>> _hrLeaveItemsForDate(DateTime date) {
    final selected = _dateOnly(date);
    final selectedEmployee = _selectedHrDashboardEmployeeId == null
        ? null
        : _adminEmployeeMaps().firstWhere(
            (employee) =>
                _employeeId(employee) == _selectedHrDashboardEmployeeId,
            orElse: () => <String, dynamic>{},
          );
    final selectedEmployeeName = selectedEmployee == null
        ? null
        : _employeeDisplayName(selectedEmployee).toLowerCase();
    final items = _adminPendingWorkItems()
        .where((item) => item['kind']?.toString() == 'leave')
        .where((item) {
          final fromDate = DateTime.tryParse(
            item['from_date']?.toString() ?? '',
          );
          final toDate = DateTime.tryParse(item['to_date']?.toString() ?? '');
          if (fromDate == null || toDate == null) return false;
          final from = _dateOnly(fromDate);
          final to = _dateOnly(toDate);
          if (selected.isBefore(from) || selected.isAfter(to)) return false;
          if (selectedEmployeeName == null) return true;
          final employeeName = item['employee']?.toString().toLowerCase() ?? '';
          return employeeName == selectedEmployeeName ||
              employeeName.contains(selectedEmployeeName);
        })
        .toList();
    return items;
  }

  Widget _buildHrLeavesDetail() {
    final leaves = _hrLeaveItemsForDate(_selectedHrDashboardDate);
    return _buildHrDetailScaffold(
      title: 'Leaves',
      subtitle: 'Review employee leaves for a selected day.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildHrEmployeeDropdown(),
              SizedBox(
                width: 230,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedHrDashboardDate,
                      firstDate: DateTime(DateTime.now().year - 2),
                      lastDate: DateTime(DateTime.now().year + 2),
                    );
                    if (picked != null) {
                      setState(() => _selectedHrDashboardDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _readableDate(_selectedHrDashboardDate.toIso8601String()),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (leaves.isEmpty)
            _buildReportMessage(
              icon: Icons.event_busy,
              title: 'No leaves found',
              message: 'No employee leave records match this date.',
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
                    DataColumn(label: Text('Leave Type')),
                    DataColumn(label: Text('From')),
                    DataColumn(label: Text('To')),
                    DataColumn(label: Text('Days')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: leaves.map((leave) {
                    return DataRow(
                      cells: [
                        DataCell(Text(leave['employee']?.toString() ?? '-')),
                        DataCell(Text(leave['title']?.toString() ?? '-')),
                        DataCell(
                          Text(
                            _readableDate(leave['from_date']?.toString() ?? ''),
                          ),
                        ),
                        DataCell(
                          Text(
                            _readableDate(leave['to_date']?.toString() ?? ''),
                          ),
                        ),
                        DataCell(Text(leave['days']?.toString() ?? '-')),
                        DataCell(
                          _buildStatusPill(leave['status']?.toString() ?? '-'),
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

  Widget _buildHrLeavesView() {
    final requests =
        (_adminDashboard?['pending_requests'] as Map<String, dynamic>?) ?? {};
    final leaves = (requests['leaves'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final pending = leaves.where((leave) {
      return (leave['status']?.toString().toLowerCase() ?? '') == 'pending';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Leaves',
            'Review and manage employee leave requests.',
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  'Total Requests',
                  leaves.length.toString(),
                  Icons.calendar_today,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryTile(
                  'Pending',
                  pending.length.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryTile(
                  'Approved',
                  leaves
                      .where(
                        (leave) =>
                            leave['status']?.toString().toLowerCase() ==
                            'approved',
                      )
                      .length
                      .toString(),
                  Icons.verified_outlined,
                  const Color(0xFF1ABE8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (leaves.isEmpty)
            _buildReportMessage(
              icon: Icons.event_busy,
              title: 'No leave requests found',
              message: 'Employee leave requests will appear here.',
              actionLabel: 'Refresh',
              onAction: loadDashboardData,
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
                    DataColumn(label: Text('Leave Type')),
                    DataColumn(label: Text('From')),
                    DataColumn(label: Text('To')),
                    DataColumn(label: Text('Days')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: leaves.map((leave) {
                    final id = (leave['id'] as num?)?.toInt() ?? 0;
                    final status =
                        leave['status']?.toString().toLowerCase() ?? '';
                    final isPending = status == 'pending';
                    return DataRow(
                      cells: [
                        DataCell(Text(leave['employee']?.toString() ?? '-')),
                        DataCell(Text(leave['type']?.toString() ?? '-')),
                        DataCell(
                          Text(
                            _readableDate(leave['from_date']?.toString() ?? ''),
                          ),
                        ),
                        DataCell(
                          Text(
                            _readableDate(leave['to_date']?.toString() ?? ''),
                          ),
                        ),
                        DataCell(Text(leave['days']?.toString() ?? '-')),
                        DataCell(
                          _buildStatusPill(
                            leave['status_label']?.toString() ?? 'Pending',
                          ),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: isPending && id != 0
                                    ? () => _updatePendingRequestStatus(
                                        'leave',
                                        id,
                                        'approved',
                                      )
                                    : null,
                                child: const Text('Approve'),
                              ),
                              OutlinedButton(
                                onPressed: isPending && id != 0
                                    ? () => _updatePendingRequestStatus(
                                        'leave',
                                        id,
                                        'rejected',
                                      )
                                    : null,
                                child: const Text('Reject'),
                              ),
                            ],
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

  Map<String, Object> _hrSectionConfig(String menu, String section) {
    IconData icon = Icons.dashboard_customize;
    Color color = const Color(0xFF2B5AF0);
    String primaryLabel = section;
    String description = 'Manage $section from the HR dashboard.';
    String message = '$section data will appear here when records are added.';

    if (menu == 'Employee Management') {
      icon = section == 'Add Employee' ? Icons.person_add_alt : Icons.groups;
      color = const Color(0xFF1ABE8E);
      description = 'Add employees and edit employee details.';
    } else if (menu == 'Attendance' || menu == 'Attendance Management') {
      icon = section == 'Attendance Insights'
          ? Icons.analytics_outlined
          : section == 'Attendance Reports'
          ? Icons.description_outlined
          : Icons.access_time;
      description = 'Monitor attendance activity, trends, and reports.';
    } else if (menu == 'Employee Location') {
      icon = section == 'Add Location'
          ? Icons.add_location_alt_outlined
          : Icons.edit_location_alt_outlined;
      color = Colors.orange;
      description = 'Add and edit employee attendance locations.';
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
    } else if (menu == 'Employee Payroll') {
      icon = Icons.account_balance_wallet;
      color = Colors.purple;
      primaryLabel = 'Payroll';
      description = 'Manage employee payroll operations.';
      message =
          'Employee payroll data will appear here when records are added.';
    } else if (menu == 'Leaves') {
      icon = Icons.calendar_today;
      color = Colors.teal;
      primaryLabel = 'Leaves';
      description = 'Manage employee leave operations.';
      message = 'Employee leave data will appear here when records are added.';
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: [_brandTeal, _brandBlue]),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: _inkBlue,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeQuoteBanner(String name, String roleLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lineColor),
        boxShadow: _softShadow(0.05),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1ABE8E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.format_quote, color: Color(0xFF1ABE8E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $name',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF1F2E5A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$roleLabel quote of the day: "${_dailyPositiveQuote()}"',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isCompact = false,
    VoidCallback? onTap,
  }) {
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineColor),
        boxShadow: _softShadow(0.06),
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 38 : 46,
            height: isCompact ? 38 : 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isCompact ? 21 : 25),
          ),
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
                            color: _inkBlue,
                            fontWeight: FontWeight.bold,
                          ),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: tile,
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

  Widget _buildStatusPill(String status, {Color? color}) {
    final positiveStatuses = ['Present', 'Active', 'Approved'];
    final negativeStatuses = ['Absent', 'Inactive', 'Rejected'];
    final pillColor =
        color ??
        (positiveStatuses.contains(status)
            ? const Color(0xFF1ABE8E)
            : negativeStatuses.contains(status)
            ? Colors.red
            : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pillColor.withValues(alpha: 0.22)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: pillColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDashboardAnalyticsPanel(
    String title,
    List<Map<String, Object>> items,
  ) {
    final maxValue = items.fold<int>(1, (current, item) {
      final value = item['value'] as int? ?? 0;
      return value > current ? value : current;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor),
        boxShadow: _softShadow(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _inkBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          ...items.map((item) {
            final label = item['label'] as String? ?? '';
            final value = item['value'] as int? ?? 0;
            final color = item['color'] as Color? ?? _brandBlue;
            final ratio = maxValue == 0 ? 0.0 : value / maxValue;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Text(
                        value.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _inkBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: ratio.clamp(0.0, 1.0),
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.12),
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
          const SizedBox(height: 20),
          _buildWelcomeQuoteBanner(_currentDisplayName('Admin'), 'Admin'),
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
                onTap: () {
                  setState(() => _selectedMenu = 'Total Employees');
                  loadDashboardData();
                },
              ),
              _buildAdminStatCard(
                'Total Requests',
                _readInt(summary, 'total_requests').toString(),
                Icons.pending_actions,
                Colors.purple,
                onTap: () {
                  setState(() {
                    _selectedMenu = 'Pending Requests';
                    _selectedPendingRequestStatus = 'pending';
                  });
                  loadDashboardData();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDashboardAnalyticsPanel('Admin Dashboard', [
            {
              'label': 'Total Employees',
              'value': _readInt(summary, 'total_employees'),
              'color': const Color(0xFF2B5AF0),
            },
            {
              'label': 'Total Requests',
              'value': _readInt(summary, 'total_requests'),
              'color': Colors.purple,
            },
          ]),
        ],
      ),
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
          'from_date': item['from_date']?.toString() ?? '',
          'to_date': item['to_date']?.toString() ?? '',
          'days': item['days']?.toString() ?? '-',
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

  Widget _buildTotalEmployeesDashboard() {
    final employees = _adminEmployeeMaps();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => setState(() {
                  _selectedMenu = 'Dashboard';
                  _selectedHrDashboardDetail = '';
                }),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSectionHeader(
                  'Total Employees',
                  'View all employees and open employee management from one place.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (employees.isEmpty)
            _buildReportMessage(
              icon: Icons.people_outline,
              title: 'No employees found',
              message: 'Employees will appear here after they are added.',
              actionLabel: 'Refresh',
              onAction: loadDashboardData,
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
                    DataColumn(label: Text('Employee Name')),
                    DataColumn(label: Text('Employee Username')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Department')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: employees.map((employee) {
                    return DataRow(
                      cells: [
                        DataCell(Text(employee['name']?.toString() ?? '-')),
                        DataCell(Text(employee['username']?.toString() ?? '-')),
                        DataCell(Text(employee['email']?.toString() ?? '-')),
                        DataCell(
                          Text(employee['department']?.toString() ?? '-'),
                        ),
                        DataCell(
                          _buildStatusPill(
                            employee['is_active'] == true
                                ? 'Active'
                                : 'Inactive',
                          ),
                        ),
                        DataCell(
                          TextButton.icon(
                            onPressed: () {
                              _selectEditEmployee(_employeeId(employee));
                              setState(() {
                                _selectedMenu = 'Employee Management';
                                _selectedAttendanceSection = 'Edit Employee';
                              });
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
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
    const requestStatuses = {'pending', 'approved', 'rejected'};
    final selectedStatus =
        requestStatuses.contains(_selectedPendingRequestStatus)
        ? _selectedPendingRequestStatus
        : 'pending';
    final filtered = items.where((item) {
      final status = (item['status_value']?.toString() ?? '').toLowerCase();
      if (selectedStatus == 'pending') {
        return status == 'pending' ||
            status == 'open' ||
            status == 'in_progress';
      }
      if (selectedStatus == 'approved') {
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
            'Review user requests by pending, approved, or rejected status.',
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
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
                  columns: [
                    const DataColumn(label: Text('Type')),
                    const DataColumn(label: Text('Employee')),
                    const DataColumn(label: Text('Details')),
                    const DataColumn(label: Text('Current')),
                    if (selectedStatus == 'pending') ...const [
                      DataColumn(label: Text('Eligible')),
                      DataColumn(label: Text('Action')),
                    ],
                  ],
                  rows: filtered.map((item) {
                    final kind = item['kind']?.toString() ?? '';
                    final id = (item['id'] as num?)?.toInt() ?? 0;
                    final requestKey = _pendingRequestKey(kind, id);
                    final selectedAction = _pendingRequestActions[requestKey];
                    final action = selectedAction == 'reject'
                        ? 'reject'
                        : 'approve';
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
                        if (selectedStatus == 'pending') ...[
                          DataCell(
                            SizedBox(
                              width: 140,
                              child: DropdownButtonFormField<String>(
                                initialValue: action,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 9,
                                  ),
                                ),
                                items: const [
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
                            SizedBox(
                              height: 32,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                onPressed: id == 0
                                    ? null
                                    : () => _updatePendingRequestStatus(
                                        kind,
                                        id,
                                        _statusValueForPendingAction(
                                          kind,
                                          action,
                                        ),
                                      ),
                                child: const Text('Submit'),
                              ),
                            ),
                          ),
                        ],
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
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor),
        boxShadow: _softShadow(0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 23, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _inkBlue,
              fontWeight: FontWeight.w800,
            ),
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
      borderRadius: BorderRadius.circular(20),
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
      constraints: const BoxConstraints(maxWidth: 820),
      child: Container(
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
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildCompactEditField(
                  'Display Name',
                  _editEmployeeDisplayNameCtrl,
                ),
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
                  'Phone Number',
                  _editEmployeePhoneCtrl,
                  keyboardType: TextInputType.phone,
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
                _buildEmployeePhotoCapturePanel(
                  photo: _editEmployeeProfilePhotoBiometric,
                  onCapture: () => _captureEmployeeProfilePhoto(isEdit: true),
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
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
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
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: _isEmployeeSaving
                      ? null
                      : () => _confirmDeleteEmployee(employee),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Employee'),
                ),
              ],
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
      width: 246,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeePhotoCapturePanel({
    required String? photo,
    required VoidCallback onCapture,
  }) {
    return SizedBox(
      width: 246,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFD),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Verification Photo',
              style: TextStyle(
                color: Color(0xFF1F2E5A),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (photo?.isNotEmpty == true)
              _buildPhotoBiometricPreview(
                'Captured employee photo',
                photo!,
                compact: true,
              )
            else
              Text(
                'Capture photo before saving employee.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                photo?.isNotEmpty == true ? 'Recapture Photo' : 'Take Photo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBiometricPreview(
    String title,
    String photo, {
    String? message,
    bool compact = false,
  }) {
    return Container(
      width: compact ? double.infinity : 360,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photo,
              width: compact ? 74 : 92,
              height: compact ? 58 : 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2E5A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message, style: TextStyle(color: Colors.grey[700])),
                ],
              ],
            ),
          ),
        ],
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
                      labelText: 'Assigned Work Address / Particular Address',
                      hintText: 'Enter the complete address or landmark',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _locationMapLinkCtrl,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Map Link or Extra Address (Optional)',
                      hintText: 'Paste a map URL, or type a nearby landmark',
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
                  const SizedBox(height: 14),
                  _buildLocationEffectiveDateFields(),
                  if (!isAdd) ...[
                    const SizedBox(height: 14),
                    _buildLocationDateField(),
                  ],
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
    final selectedDateKey = _dateKey(_selectedLocationDate);
    final rows = _adminEmployeeMaps().where((employee) {
      if (selectedDateKey == null) return true;
      final location = employee['assigned_location'] as Map<String, dynamic>?;
      if (location == null) return false;
      final selectedDate = _selectedLocationDate!;
      final startsAt = DateTime.tryParse(
        location['effective_from']?.toString() ?? '',
      );
      final endsAt = DateTime.tryParse(
        location['effective_to']?.toString() ?? '',
      );
      final startsOk =
          startsAt == null ||
          !_dateOnly(selectedDate).isBefore(_dateOnly(startsAt));
      final endsOk =
          endsAt == null || !_dateOnly(selectedDate).isAfter(_dateOnly(endsAt));
      return startsOk && endsOk;
    }).toList();

    if (rows.isEmpty) {
      return _buildReportMessage(
        icon: Icons.location_off,
        title: 'No employee locations',
        message: _selectedLocationDate == null
            ? 'Employee locations will appear here after assignment.'
            : 'No employee locations match the selected date.',
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
            DataColumn(label: Text('Start Date')),
            DataColumn(label: Text('End Date')),
            DataColumn(label: Text('Updated')),
            DataColumn(label: Text('Employee Name')),
            DataColumn(label: Text('Employee Username')),
            DataColumn(label: Text('Radius')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: rows.map((employee) {
            final location =
                employee['assigned_location'] as Map<String, dynamic>?;
            final updatedAt = location?['updated_at']?.toString() ?? '';
            final effectiveFrom = location?['effective_from']?.toString() ?? '';
            final effectiveTo = location?['effective_to']?.toString() ?? '';
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    effectiveFrom.isEmpty
                        ? 'Immediate'
                        : _readableDate(effectiveFrom),
                  ),
                ),
                DataCell(
                  Text(
                    effectiveTo.isEmpty
                        ? 'Open ended'
                        : _readableDate(effectiveTo),
                  ),
                ),
                DataCell(
                  Text(updatedAt.isEmpty ? '-' : _readableDate(updatedAt)),
                ),
                DataCell(Text(employee['name']?.toString() ?? '-')),
                DataCell(Text(employee['username']?.toString() ?? '-')),
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

  Widget _buildLocationDateField() {
    return SizedBox(
      width: 360,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedLocationDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(DateTime.now().year + 2),
                );
                if (picked != null) {
                  setState(() => _selectedLocationDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedLocationDate == null
                    ? 'All Dates'
                    : _readableDate(_selectedLocationDate!.toIso8601String()),
              ),
            ),
          ),
          if (_selectedLocationDate != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Clear date',
              onPressed: () => setState(() => _selectedLocationDate = null),
              icon: const Icon(Icons.close),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationEffectiveDateFields() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildLocationEffectiveDateButton(
          label: 'Start Date',
          value: _locationEffectiveFrom,
          emptyLabel: 'Immediate',
          onPick: (date) => setState(() => _locationEffectiveFrom = date),
          onClear: () => setState(() => _locationEffectiveFrom = null),
        ),
        _buildLocationEffectiveDateButton(
          label: 'End Date',
          value: _locationEffectiveTo,
          emptyLabel: 'Open ended',
          onPick: (date) => setState(() => _locationEffectiveTo = date),
          onClear: () => setState(() => _locationEffectiveTo = null),
        ),
      ],
    );
  }

  Widget _buildLocationEffectiveDateButton({
    required String label,
    required DateTime? value,
    required String emptyLabel,
    required ValueChanged<DateTime> onPick,
    required VoidCallback onClear,
  }) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(DateTime.now().year + 3),
                );
                if (picked != null) onPick(picked);
              },
              icon: const Icon(Icons.event_available),
              label: Text(
                value == null
                    ? '$label: $emptyLabel'
                    : '$label: ${_readableDate(value.toIso8601String())}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Clear $label',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminAttendanceView() {
    final selectedDetail = _selectedAdminAttendanceDetail;
    if (selectedDetail != null) {
      return _buildAdminAttendanceDetailsDashboard(selectedDetail);
    }

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
    setState(() => _selectedAdminAttendanceDetail = row);
  }

  Widget _buildAdminAttendanceDetailsDashboard(Map<String, dynamic> row) {
    final location = row['assigned_location'] as Map<String, dynamic>?;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () =>
                    setState(() => _selectedAdminAttendanceDetail = null),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSectionHeader(
                  row['employee']?.toString() ?? 'Attendance Details',
                  'Review attendance time, location, radius, and map details.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const Divider(height: 28),
                  _buildAttendanceDetailRow(
                    'Assigned location',
                    location?['address']?.toString() ?? 'No location assigned',
                  ),
                  _buildAttendanceDetailRow(
                    'Allowed radius',
                    location == null ? '-' : '${location['radius_meters']}m',
                  ),
                  const Divider(height: 28),
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
                  _buildAttendanceBiometricPreview(
                    'Check-in biometric',
                    row['check_in_photo_biometric']?.toString() ?? '',
                    row['check_in_biometric_details'],
                  ),
                  const Divider(height: 28),
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
                  _buildAttendanceBiometricPreview(
                    'Check-out biometric',
                    row['check_out_photo_biometric']?.toString() ?? '',
                    row['check_out_biometric_details'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildAttendanceBiometricPreview(
    String label,
    String photo,
    dynamic details,
  ) {
    final detailMap = details is Map<String, dynamic> ? details : {};
    final verified = detailMap['verified'] == true;
    final sizeBytes = detailMap['size_bytes'];
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
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
            child: photo.isEmpty
                ? const Text('-', style: TextStyle(color: Color(0xFF1F2E5A)))
                : Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          photo,
                          width: 110,
                          height: 82,
                          fit: BoxFit.cover,
                        ),
                      ),
                      _buildStatusPill(
                        verified ? 'Biometric Verified' : 'Not Verified',
                        color: verified
                            ? const Color(0xFF1ABE8E)
                            : Colors.orange,
                      ),
                      if (sizeBytes != null)
                        Text(
                          '$sizeBytes bytes',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                    ],
                  ),
          ),
        ],
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
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildCompactEditField(
                        'Display Name',
                        _employeeDisplayNameCtrl,
                      ),
                      _buildCompactEditField(
                        'First Name',
                        _employeeFirstNameCtrl,
                      ),
                      _buildCompactEditField(
                        'Last Name',
                        _employeeLastNameCtrl,
                      ),
                      _buildCompactEditField(
                        'Date of Birth (YYYY-MM-DD)',
                        _employeeDobCtrl,
                        keyboardType: TextInputType.datetime,
                      ),
                      _buildCompactEditField(
                        'Employee Email',
                        _employeeEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _buildCompactEditField(
                        'Phone Number',
                        _employeePhoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildCompactEditField(
                        'Login Username',
                        _employeeUsernameCtrl,
                      ),
                      _buildCompactEditField(
                        'Login Password',
                        _employeePasswordCtrl,
                        obscureText: true,
                      ),
                      _buildCompactEditField(
                        'Department',
                        _employeeDepartmentCtrl,
                      ),
                      _buildCompactEditField(
                        'Designation',
                        _employeeDesignationCtrl,
                      ),
                      _buildEmployeePhotoCapturePanel(
                        photo: _employeeProfilePhotoBiometric,
                        onCapture: _captureEmployeeProfilePhoto,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildDashboardPermissionBoxes(
                    canUser: _employeeCanAccessUser,
                    canAdmin: _employeeCanAccessAdmin,
                    canHr: _employeeCanAccessHr,
                    onUserChanged: (value) =>
                        setState(() => _employeeCanAccessUser = value ?? false),
                    onAdminChanged: (value) => setState(
                      () => _employeeCanAccessAdmin = value ?? false,
                    ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineColor),
        boxShadow: _softShadow(0.04),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 30, color: _brandBlue),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _inkBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isActive
                ? _brandTeal.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isActive ? const Color(0xFF6EE7B7) : Colors.white,
            size: 19,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        onTap: () => _selectMenu(menuKey),
      ),
    );
  }

  Widget _buildSubMenuItem(String label, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 48, right: 12, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: isActive
            ? _brandTeal.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        minLeadingWidth: 8,
        leading: Icon(
          Icons.circle,
          size: 8,
          color: isActive ? const Color(0xFF6EE7B7) : Colors.white54,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lineColor),
        boxShadow: _softShadow(0.04),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor),
        boxShadow: _softShadow(0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 25, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _inkBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
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
