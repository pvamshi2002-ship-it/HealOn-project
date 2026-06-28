from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0010_attendance_photo_biometric'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='profile_photo_biometric',
            field=models.TextField(blank=True),
        ),
    ]
