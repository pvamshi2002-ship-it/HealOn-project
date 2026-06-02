from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0013_assignedlocation_effective_dates'),
    ]

    operations = [
        migrations.AlterField(
            model_name='assignedlocation',
            name='latitude',
            field=models.DecimalField(decimal_places=15, default=0, max_digits=18),
        ),
        migrations.AlterField(
            model_name='assignedlocation',
            name='longitude',
            field=models.DecimalField(decimal_places=15, default=0, max_digits=18),
        ),
        migrations.AlterField(
            model_name='attendance',
            name='latitude',
            field=models.DecimalField(decimal_places=15, max_digits=18),
        ),
        migrations.AlterField(
            model_name='attendance',
            name='longitude',
            field=models.DecimalField(decimal_places=15, max_digits=18),
        ),
    ]
