from django.core.management.base import BaseCommand

from people.models import Department, Designation, LeaveType, Shift


class Command(BaseCommand):
    help = 'Seed default HR administration master data'

    def handle(self, *args, **options):
        departments = [
            ('Human Resources', 'HR'),
            ('Engineering', 'ENG'),
            ('Operations', 'OPS'),
            ('Finance', 'FIN'),
        ]
        for name, code in departments:
            Department.objects.update_or_create(
                code=code,
                defaults={'name': name, 'description': f'{name} department', 'is_active': True},
            )

        for dept in Department.objects.all():
            Designation.objects.update_or_create(
                code=f'{dept.code}-EXEC',
                defaults={
                    'name': f'{dept.name} Executive',
                    'department': dept,
                    'level': 3,
                    'is_active': True,
                },
            )

        leave_types = [
            ('Casual Leave', 12, True),
            ('Sick Leave', 10, True),
            ('Paid Leave', 15, True),
            ('Unpaid Leave', 5, False),
        ]
        for name, quota, is_paid in leave_types:
            LeaveType.objects.update_or_create(
                name=name,
                defaults={'annual_quota': quota, 'is_paid': is_paid, 'is_active': True},
            )

        shifts = [
            ('General Shift', '09:00', '18:00', 15),
            ('Morning Shift', '06:00', '14:00', 10),
            ('Night Shift', '22:00', '06:00', 10),
        ]
        for name, start, end, grace in shifts:
            Shift.objects.update_or_create(
                name=name,
                defaults={
                    'start_time': start,
                    'end_time': end,
                    'grace_minutes': grace,
                    'is_active': True,
                },
            )

        self.stdout.write(self.style.SUCCESS('HR administration seed data applied.'))
