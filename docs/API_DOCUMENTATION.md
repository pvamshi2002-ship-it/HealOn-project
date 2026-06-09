# HealOn API Documentation

Base URL (local): `http://127.0.0.1:8000/api/`

Authentication: Token header — `Authorization: Token <token>`

## Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/` | Login; body: `username`, `password`, `role` |
| GET | `/api/me/` | Current user profile |

## Password reset

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/password-reset/request/` | Request email OTP |
| POST | `/api/password-reset/verify/` | Verify OTP |
| POST | `/api/password-reset/confirm/` | Set new password |

## Employee dashboard

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard/` | User dashboard data |
| POST | `/api/checkin/` | Check in with GPS + photo |
| POST | `/api/checkout/` | Check out with GPS + photo |
| GET | `/api/attendance-report/` | Monthly attendance report |
| POST | `/api/attendance-regularizations/` | Request regularization |
| GET | `/api/employee/tasks/` | Employee tasks |
| GET/POST | `/api/employee/leaves/` | Leave requests |
| GET | `/api/employee/salary/` | Salary records |
| GET | `/api/employee/salary/payslip/` | Payslip PDF |
| GET/POST | `/api/employee/reimbursements/` | Reimbursements |
| GET/POST | `/api/employee/helpdesk/` | Helpdesk tickets |
| GET | `/api/employee/directory/` | Employee directory |

## Admin / HR APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/admin/dashboard/` | Admin dashboard |
| GET | `/api/admin/stats/` | Dashboard statistics |
| GET/POST | `/api/admin/employees/` | List/create employees |
| GET/PATCH/DELETE | `/api/admin/employees/<id>/` | Employee detail |
| PATCH | `/api/admin/employees/<id>/location/` | Assigned location |
| GET/POST | `/api/admin/attendance/` | Attendance records |
| GET/PATCH | `/api/admin/attendance-settings/` | Face recognition settings (`face_recognition_enabled`, `face_match_threshold`) |
| GET/POST | `/api/admin/salary-records/` | Payroll records |
| GET/POST | `/api/admin/reimbursements/` | Reimbursements |
| GET/POST | `/api/admin/tasks/` | Task management |
| PATCH | `/api/admin/leaves/<id>/status/` | Approve/reject leave |
| PATCH | `/api/admin/regularizations/<id>/status/` | Regularization status |
| PATCH | `/api/admin/helpdesk/<id>/status/` | Ticket status |

## Django admin

| URL | Description |
|-----|-------------|
| `/admin/` | Jazzmin admin UI |
| `/api/admin-panel/` | Custom HR admin panel |
