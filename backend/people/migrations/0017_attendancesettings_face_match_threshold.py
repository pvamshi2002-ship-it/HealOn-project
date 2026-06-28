from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0016_assignedlocation_face_verification_enabled'),
    ]

    operations = [
        migrations.AddField(
            model_name='attendancesettings',
            name='face_match_threshold',
            field=models.FloatField(default=0.86),
        ),
    ]
