# HealOn Project

HealOn is a smart attendance system built with a Flutter frontend and Django REST backend.

"The main theme of the project is to ensure secure and accurate employee attendance using GPS-based location tracking and radius-based validation, allowing attendance to be marked only within authorized locations."

## Project Structure

```text
HealOn_Project/
├── frontend/          Flutter application
├── backend/           Django REST API and admin system
├── docs/              API docs, testing report, structure guide
├── .gitignore
└── README.md
```

See `docs/PROJECT_STRUCTURE.md` for the full layout.

## Backend

The backend is located in `backend/`.

Main technologies:

- Django
- Django REST Framework
- Django token authentication
- Django Jazzmin admin UI
- SQLite for local development

Run the backend:

```powershell
cd "D:\project 2\ff\HealOn-project-main"
.\scripts\start-backend.ps1
```

Or manually:

```powershell
cd backend
..\venv\Scripts\python.exe manage.py migrate
..\venv\Scripts\python.exe manage.py seed_demo_users
..\venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

Useful backend URLs:

- Django Admin: `http://127.0.0.1:8000/admin/`
- Admin Dashboard Panel: `http://127.0.0.1:8000/api/admin-panel/`
- Login API: `POST /api/auth/`
- User Dashboard API: `GET /api/dashboard/`
- Admin Dashboard API: `GET /api/admin/dashboard/`

## Frontend

The frontend is located in `frontend/`.

Main technologies:

- Flutter
- Dart
- `http`
- `geolocator`
- `fl_chart`

Run the frontend (keep the backend running in another terminal):

```powershell
cd "D:\project 2\ff\HealOn-project-main\frontend"
flutter pub get
flutter run -d chrome
```

Run Flutter web on a fixed local port:

```powershell
cd "D:\project 2\ff\HealOn-project-main\frontend"
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 3000
```

## Demo Login Details

| Dashboard | Username | Password |
| --- | --- | --- |
| User Dashboard | `vamshi` | `vamshi@123` |
| Admin Dashboard | `admin` | `Admin@123` |
| HR Dashboard | `hr` | `HR@123` |
| Backend Admin | `admin` | `Admin@123` |

Seed/demo users can be refreshed with:

```powershell
cd "D:\project 2\ff\HealOn-project-main\backend"
..\venv\Scripts\python.exe manage.py seed_demo_users
```

After cloning from GitHub, always start the backend before the frontend. The Flutter app connects to `http://<same-host>:8000` automatically. Override with `--dart-define=BACKEND_URL=http://127.0.0.1:8000` if needed.

## Core Features

- Role-based login for User, HR, and Admin dashboards.
- GPS attendance check-in and check-out.
- Employee-specific attendance location and radius restriction.
- Photo biometric validation.
- Employee registration and profile management.
- Attendance reports and admin attendance monitoring.
- Leave request and approval workflow.
- Attendance regularization workflow.
- Payroll records and payslip download.
- Reimbursement request upload.
- Helpdesk ticket management.
- Task tracking.
-Email OTP verification validates a user's identity by sending a one-time password to their registered email address.

In Firebase Console, create a Web app for project `healon-a62fd`, enable
Authentication > Sign-in method > Phone, and add your local host under
Authentication > Settings > Authorized domains. Copy the Web app's `appId`
from Project settings > Your apps > SDK setup and configuration. Then run
Chrome/Web with:

```powershell
cd "D:\projects\healOn project\frontend"
flutter run -d chrome `
  --dart-define=FIREBASE_WEB_API_KEY=your_web_api_key `
  --dart-define=FIREBASE_WEB_APP_ID=your_web_app_id
```

The API key defaults to the project key already in
`frontend/lib/firebase_options.dart`, so `FIREBASE_WEB_APP_ID` is the only
required local define when that key is unchanged.

## Notes

- Keep Flutter files inside `frontend/`.
- Keep Django files inside `backend/`.
- Keep only this root `README.md` for project-level guidance.
- Do not commit generated logs, build output, cache folders, or extra virtual environments.
