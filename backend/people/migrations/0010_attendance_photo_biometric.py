from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0009_userprofile_dashboard_permissions_dob'),
    ]

    operations = [
        migrations.AddField(
            model_name='attendance',
            name='photo_biometric',
            field=models.TextField(blank=True),
        ),
    ]
