import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = BASE_DIR.parent


def load_env_file(path):
    if not path.exists():
        return
    for raw_line in path.read_text(encoding='utf-8').splitlines():
        line = raw_line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        # Project .env should win over empty shell defaults after clone/pull.
        os.environ[key] = value


for env_path in (REPO_ROOT / '.env', BASE_DIR / '.env'):
    load_env_file(env_path)

SECRET_KEY = 'healon-dev-secret-key'
DEBUG = True
ALLOWED_HOSTS = ['*']

EMAIL_OTP_EXPIRY_MINUTES = int(os.environ.get('EMAIL_OTP_EXPIRY_MINUTES', '10'))
EMAIL_BACKEND = os.environ.get(
    'EMAIL_BACKEND',
    'django.core.mail.backends.smtp.EmailBackend',
)
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', '587'))
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'true').lower() in {
    '1',
    'true',
    'yes',
}
EMAIL_USE_SSL = os.environ.get('EMAIL_USE_SSL', '').lower() in {'1', 'true', 'yes'}
EMAIL_TIMEOUT = int(os.environ.get('EMAIL_TIMEOUT', '20'))
DEFAULT_FROM_EMAIL = os.environ.get(
    'DEFAULT_FROM_EMAIL',
    EMAIL_HOST_USER or 'no-reply@healon.local',
)

INSTALLED_APPS = [
    'jazzmin',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
    'people.apps.PeopleConfig',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'healon_backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'healon_backend.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'people.password_rules.HealOnPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kolkata'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Employee verification photos are posted as base64 data URLs from Django Admin.
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024

CORS_ALLOW_ALL_ORIGINS = True
CSRF_TRUSTED_ORIGINS = [
    'http://localhost',
    'http://127.0.0.1',
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    'http://localhost:8080',
    'http://127.0.0.1:8080',
]
FRONTEND_PUBLIC_BASE_URL = os.environ.get('FRONTEND_PUBLIC_BASE_URL', 'http://localhost:8080')

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

JAZZMIN_SETTINGS = {
    'site_title': 'HealOn Admin System',
    'site_header': 'HealOn HR',
    'site_brand': 'HealOn Admin System',
    'welcome_sign': 'Welcome Admin',
    'copyright': 'HealOn Admin System',
    'site_logo': 'people/healon-logo.svg',
    'login_logo': 'people/healon-logo.svg',
    'site_icon': 'people/healon-logo.svg',
    'show_sidebar': True,
    'navigation_expanded': True,
    'hide_apps': ['authtoken'],
    'hide_models': ['auth.Group', 'authtoken.TokenProxy'],
    'order_with_respect_to': [
        'auth.User',
        'people.UserProfile',
        'people.AssignedLocation',
        'people.Department',
        'people.Designation',
        'people.Attendance',
        'people.AttendanceSettings',
        'people.AttendanceRegularization',
        'people.SalaryRecord',
        'people.ReimbursementRequest',
        'people.LeaveRequest',
        'people.LeaveType',
        'people.Holiday',
        'people.JobOpening',
        'people.Candidate',
        'people.ExitRequest',
        'people.EmployeeDocument',
        'people.HelpdeskTicket',
        'people.PasswordResetOTP',
        'people.EmployeeTask',
    ],
    'icons': {
        'auth.User': 'fas fa-users',
        'people.UserProfile': 'fas fa-id-badge',
        'people.AssignedLocation': 'fas fa-map-marker-alt',
        'people.Department': 'fas fa-building',
        'people.Designation': 'fas fa-id-badge',
        'people.Attendance': 'fas fa-calendar-check',
        'people.AttendanceSettings': 'fas fa-user-shield',
        'people.AttendanceRegularization': 'fas fa-clipboard-list',
        'people.SalaryRecord': 'fas fa-wallet',
        'people.ReimbursementRequest': 'fas fa-file-invoice-dollar',
        'people.LeaveRequest': 'fas fa-plane-departure',
        'people.LeaveType': 'fas fa-tags',
        'people.Holiday': 'fas fa-calendar-day',
        'people.JobOpening': 'fas fa-briefcase',
        'people.Candidate': 'fas fa-user-tie',
        'people.ExitRequest': 'fas fa-door-open',
        'people.EmployeeDocument': 'fas fa-folder-open',
        'people.HelpdeskTicket': 'fas fa-headset',
        'people.PasswordResetOTP': 'fas fa-key',
        'people.EmployeeTask': 'fas fa-tasks',
    },
    'custom_links': {
        'people': [
            {
                'name': 'HR Management',
                'url': '/admin/auth/user/',
                'icon': 'fas fa-briefcase',
                'permissions': ['auth.view_user'],
            },
            {
                'name': 'Department Management',
                'url': '/admin/people/department/',
                'icon': 'fas fa-building',
                'permissions': ['people.view_department'],
            },
            {
                'name': 'Designation Management',
                'url': '/admin/people/designation/',
                'icon': 'fas fa-id-badge',
                'permissions': ['people.view_designation'],
            },
            {
                'name': 'Exit Management',
                'url': '/admin/people/exitrequest/',
                'icon': 'fas fa-door-open',
                'permissions': ['people.view_exitrequest'],
            },
            {
                'name': 'Document Management',
                'url': '/admin/people/employeedocument/',
                'icon': 'fas fa-folder-open',
                'permissions': ['people.view_employeedocument'],
            },
            {
                'name': 'Attendance Management',
                'url': '/admin/people/attendance/',
                'icon': 'fas fa-business-time',
                'permissions': ['people.view_attendance'],
            },
            {
                'name': 'Payroll Management',
                'url': '/admin/people/salaryrecord/',
                'icon': 'fas fa-money-check-alt',
                'permissions': ['people.view_salaryrecord'],
            },
            {
                'name': 'Leave Management',
                'url': '/admin/people/leaverequest/',
                'icon': 'fas fa-calendar-minus',
                'permissions': ['people.view_leaverequest'],
            },
            {
                'name': 'Support Center',
                'url': '/admin/people/helpdeskticket/',
                'icon': 'fas fa-life-ring',
                'permissions': ['people.view_helpdeskticket'],
            },
        ]
    },
    'changeform_format': 'horizontal_tabs',
    'related_modal_active': True,
    'show_ui_builder': False,
    'custom_css': 'people/healon_admin.css',
    'custom_js': 'people/healon_admin.js',
}

JAZZMIN_UI_TWEAKS = {
    'theme': 'flatly',
    'default_theme_mode': 'light',
    'navbar': 'navbar-white navbar-light',
    'sidebar': 'sidebar-light-primary',
    'brand_colour': 'navbar-white',
    'accent': 'accent-success',
    'button_classes': {
        'primary': 'btn btn-primary',
        'secondary': 'btn btn-outline-secondary',
        'info': 'btn btn-info',
        'warning': 'btn btn-warning',
        'danger': 'btn btn-danger',
        'success': 'btn btn-success',
    },
    'actions_sticky_top': True,
}
