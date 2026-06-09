# HealOn Project Structure

```text
HealOn_Project/
├── frontend/                 # Flutter client (web, Android, iOS, desktop)
│   ├── lib/                  # Application source code
│   ├── assets/               # Static assets (images, fonts)
│   ├── test/                 # Flutter widget and integration tests
│   ├── web/                  # Web platform configuration
│   ├── pubspec.yaml          # Flutter dependencies
│   └── README.md             # Frontend setup notes
│
├── backend/                  # Django REST API and admin
│   ├── healon_backend/       # Project settings, URLs, WSGI
│   ├── people/               # Main HR/attendance app
│   ├── media/                # User-uploaded files (runtime)
│   ├── static/               # Collected static files (runtime)
│   ├── templates/            # Django admin templates
│   ├── manage.py
│   ├── requirements.txt
│   └── README.md
│
├── docs/                     # Project documentation
│   ├── API_DOCUMENTATION.md
│   ├── TESTING_REPORT.md
│   └── PROJECT_STRUCTURE.md
│
├── .gitignore
└── README.md
```

## Backend (`people` app)

| Area | Location |
|------|----------|
| Models | `backend/people/models.py` |
| API views | `backend/people/views.py` |
| Serializers | `backend/people/serializers.py` |
| Admin | `backend/people/admin.py` |
| Migrations | `backend/people/migrations/` |
| Static admin JS/CSS | `backend/people/static/people/` |

## Frontend

| Area | Location |
|------|----------|
| Main UI | `frontend/lib/main.dart` |
| Platform helpers | `frontend/lib/*_web.dart`, `*_stub.dart` |
| Tests | `frontend/test/` |

## Generated artifacts (not in source control)

- `__pycache__/`, `*.pyc`, `.pytest_cache/`
- `backend/.venv/`
- `frontend/build/`, `frontend/.dart_tool/`
- `frontend/**/ephemeral/`
- IDE folders (`.idea/`, `.vscode/`)
