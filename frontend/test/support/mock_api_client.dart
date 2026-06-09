import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fixtures/api_responses.dart';

/// Routes mocked API requests to fixture JSON. No real network calls.
MockClient createHealOnMockClient({
  Map<String, http.Response> overrides = const {},
  int authStatusCode = 200,
  String authRole = 'User',
}) {
  return MockClient((request) async {
    final key = '${request.method} ${request.url.path}';
    if (overrides.containsKey(key)) {
      return overrides[key]!;
    }

    switch (key) {
      case 'POST /api/auth/':
        final body = authStatusCode == 200
            ? (authRole == 'Admin'
                ? authAdminResponse
                : authRole == 'HR'
                    ? authHrResponse
                    : authUserResponse)
            : '{"detail":"Invalid credentials"}';
        return http.Response(body, authStatusCode);

      case 'GET /api/dashboard/':
        return http.Response(userDashboardResponse, 200);
      case 'GET /api/admin/dashboard/':
        return http.Response(adminDashboardResponse, 200);
      case 'GET /api/admin/employees/':
        return http.Response(employeesListResponse, 200);
      case 'GET /api/admin/attendance/':
        return http.Response(attendanceListResponse, 200);
      case 'GET /api/admin/attendance-settings/':
        return http.Response(attendanceSettingsResponse, 200);
      case 'GET /api/employee/leaves/':
        return http.Response(leavesResponse, 200);
      case 'GET /api/employee/tasks/':
        return http.Response(tasksResponse, 200);
      case 'GET /api/employee/helpdesk/':
        return http.Response(helpdeskResponse, 200);
      case 'GET /api/employee/directory/':
        return http.Response(directoryResponse, 200);
      case 'GET /api/admin/tasks/':
        return http.Response(adminTasksResponse, 200);
      case 'GET /api/admin/reimbursements/':
        return http.Response(reimbursementsResponse, 200);
      case 'GET /api/employee/reimbursements/':
        return http.Response(reimbursementsResponse, 200);
      case 'GET /api/employee/salary/':
        return http.Response(salaryResponse, 200);
      case 'GET /api/admin/salary-records/':
        return http.Response(adminSalaryRecordsResponse, 200);
    }

    if (request.url.path.startsWith('/api/attendance-report/')) {
      return http.Response(attendanceReportResponse, 200);
    }

    if (key == 'POST /api/employee/leaves/') {
      return http.Response(
        '{"id":99,"leave_type":"Paid Leave","status":"pending"}',
        201,
      );
    }
    if (key == 'POST /api/checkin/' || key == 'POST /api/checkout/') {
      return http.Response(
        '{"id":1,"event_type":"check_in","distance_meters":12}',
        201,
      );
    }
    if (key.startsWith('POST /api/password-reset/')) {
      return http.Response('{"detail":"ok"}', 200);
    }

    return http.Response(
      '{"detail":"Unhandled mock route: $key"}',
      404,
    );
  });
}
