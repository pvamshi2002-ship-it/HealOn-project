# HealOn Backend

Django REST API and Jazzmin admin for the HealOn HR and attendance system.

## Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\pip.exe install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py seed_demo_users
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

## Key URLs

- Django Admin: `http://127.0.0.1:8000/admin/`
- API base: `http://127.0.0.1:8000/api/`
- Admin panel: `http://127.0.0.1:8000/api/admin-panel/`

## Project layout

| Path | Purpose |
|------|---------|
| `healon_backend/` | Settings, root URLs |
| `people/` | Models, views, serializers, admin |
| `templates/` | Admin template overrides |
| `media/` | Runtime uploads |
| `static/` | Collected static files |

## Tests

```powershell
.\.venv\Scripts\python.exe manage.py test people
```

See `../docs/API_DOCUMENTATION.md` for endpoint reference.
