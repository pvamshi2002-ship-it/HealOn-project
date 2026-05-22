from django.db import migrations, models


def backfill_dashboard_permissions(apps, schema_editor):
    UserProfile = apps.get_model('people', 'UserProfile')
    for profile in UserProfile.objects.select_related('user'):
        user = profile.user
        markers = [
            user.username,
            user.email,
            profile.department,
            profile.designation,
        ]
        profile.can_access_user_dashboard = True
        profile.can_access_admin_dashboard = user.is_staff
        profile.can_access_hr_dashboard = any(
            'hr' in (marker or '').lower() for marker in markers
        )
        profile.save(
            update_fields=[
                'can_access_user_dashboard',
                'can_access_admin_dashboard',
                'can_access_hr_dashboard',
            ]
        )


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0008_assignedlocation_coordinates_resolved_defaults'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='can_access_admin_dashboard',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='can_access_hr_dashboard',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='can_access_user_dashboard',
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='date_of_birth',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.RunPython(backfill_dashboard_permissions, migrations.RunPython.noop),
    ]
