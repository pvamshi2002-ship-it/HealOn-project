from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0007_assignedlocation_map_url'),
    ]

    operations = [
        migrations.AddField(
            model_name='assignedlocation',
            name='coordinates_resolved',
            field=models.BooleanField(default=False),
        ),
        migrations.AlterField(
            model_name='assignedlocation',
            name='latitude',
            field=models.DecimalField(decimal_places=6, default=0, max_digits=9),
        ),
        migrations.AlterField(
            model_name='assignedlocation',
            name='longitude',
            field=models.DecimalField(decimal_places=6, default=0, max_digits=9),
        ),
    ]
