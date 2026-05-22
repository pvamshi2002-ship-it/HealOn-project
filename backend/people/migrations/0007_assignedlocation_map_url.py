from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0006_assignedlocation_attendance_location_restriction'),
    ]

    operations = [
        migrations.AddField(
            model_name='assignedlocation',
            name='map_url',
            field=models.URLField(blank=True, max_length=500),
        ),
    ]
