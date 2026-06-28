from django.db import migrations, models


def create_default_attendance_settings(apps, schema_editor):
    AttendanceSettings = apps.get_model('people', 'AttendanceSettings')
    AttendanceSettings.objects.get_or_create(
        pk=1,
        defaults={
            'name': 'Default attendance settings',
            'face_recognition_enabled': False,
        },
    )


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0014_increase_coordinate_precision'),
    ]

    operations = [
        migrations.CreateModel(
            name='AttendanceSettings',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(default='Default attendance settings', max_length=80, unique=True)),
                ('face_recognition_enabled', models.BooleanField(default=False)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Attendance setting',
                'verbose_name_plural': 'Attendance settings',
            },
        ),
        migrations.RunPython(create_default_attendance_settings, migrations.RunPython.noop),
    ]
