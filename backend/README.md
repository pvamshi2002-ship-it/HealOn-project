# HealOn Backend

Fresh Django REST backend for the HealOn Flutter app.

## Run

```powershell
cd "D:\projects\healOn project\backend"
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

## Local Login

- Admin: `admin` / `Admin@123`
- User: `employee` / `Employee@123`
- HR: `hr` / `HR@123`

To create or refresh these users:

```powershell
cd "D:\projects\healOn project\backend"
.\.venv\Scripts\python.exe manage.py seed_demo_users
```

## Mobile OTP Password Reset

Password reset uses the `mobile_number` saved on the employee's user profile.
For local development, OTPs are printed in the backend console and returned as
`dev_otp` so the Flutter flow can be tested.

To send real authentication OTPs, create a Twilio Verify service in your Twilio
account and set these environment variables before starting Django:

```powershell
$env:SMS_PROVIDER="twilio"
$env:TWILIO_ACCOUNT_SID="your_account_sid"
$env:TWILIO_AUTH_TOKEN="your_auth_token"
$env:TWILIO_VERIFY_SERVICE_SID="your_verify_service_sid"
```

With `TWILIO_VERIFY_SERVICE_SID` configured, Twilio generates and sends the OTP
to the employee mobile number saved in Django admin. The API will not return
`dev_otp` in this mode.

If you do not use Twilio Verify and only configure `TWILIO_FROM_NUMBER`, the
fallback SMS message format is:

`HealOn password reset OTP is 123456. It is valid for 10 minutes.`

## Main URLs

- Django Admin: `http://127.0.0.1:8000/admin/`
- Admin Dashboard Panel: `http://127.0.0.1:8000/api/admin-panel/`
- Login API: `POST /api/auth/`
- Admin Dashboard API: `GET /api/admin/dashboard/`
- Admin Employees API: `GET /api/admin/employees/`
- Admin Attendance API: `GET /api/admin/attendance/`
- User/HR Dashboard API: `GET /api/dashboard/`
