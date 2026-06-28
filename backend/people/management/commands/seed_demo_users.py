from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from people.models import UserProfile


class Command(BaseCommand):
    help = 'Create or update local demo users for the Flutter login screen.'

    def handle(self, *args, **options):
        users = [
            {
                'username': 'admin',
                'password': 'Admin@123',
                'email': 'admin@healon.local',
                'first_name': 'Admin',
                'last_name': 'User',
                'is_staff': True,
                'is_superuser': True,
                'is_active': True,
                'profile': {
                    'employee_code': 'ADMIN001',
                    'department': 'Administration',
                    'designation': 'System Admin',
                    'mobile_number': '9000000001',
                    'can_access_user_dashboard': False,
                    'can_access_admin_dashboard': True,
                    'can_access_hr_dashboard': False,
                },
            },
            {
                'username': 'employee',
                'password': 'Employee@123',
                'email': 'employee@healon.local',
                'first_name': 'Employee',
                'last_name': 'User',
                'is_staff': False,
                'is_superuser': False,
                'is_active': True,
                'profile': {
                    'employee_code': 'EMP001',
                    'department': 'Operations',
                    'designation': 'Employee',
                    'mobile_number': '9000000002',
                    'can_access_user_dashboard': True,
                    'can_access_admin_dashboard': False,
                    'can_access_hr_dashboard': False,
                },
            },
            {
                'username': 'hr',
                'password': 'HR@123',
                'email': 'hr@healon.local',
                'first_name': 'HR',
                'last_name': 'User',
                'is_staff': False,
                'is_superuser': False,
                'is_active': True,
                'profile': {
                    'employee_code': 'HR001',
                    'department': 'HR',
                    'designation': 'HR Manager',
                    'mobile_number': '9000000003',
                    'can_access_user_dashboard': True,
                    'can_access_admin_dashboard': False,
                    'can_access_hr_dashboard': True,
                },
            },
        ]

        User = get_user_model()
        for user_config in users:
            item = user_config.copy()
            profile_data = item.pop('profile')
            password = item.pop('password')
            user, _ = User.objects.update_or_create(
                username=item['username'],
                defaults=item,
            )
            user.set_password(password)
            user.save()
            UserProfile.objects.update_or_create(
                user=user,
                defaults=profile_data,
            )
            self.stdout.write(
                self.style.SUCCESS(
                    f"Ready: {user.username} / {password}"
                )
            )
