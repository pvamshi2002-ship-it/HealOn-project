from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0015_attendance_settings'),
    ]

    operations = [
        migrations.AddField(
            model_name='assignedlocation',
            name='face_verification_enabled',
            field=models.BooleanField(default=True),
        ),
    ]
