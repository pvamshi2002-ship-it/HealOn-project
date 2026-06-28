from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0012_reimbursementrequest'),
    ]

    operations = [
        migrations.AddField(
            model_name='assignedlocation',
            name='effective_from',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='assignedlocation',
            name='effective_to',
            field=models.DateField(blank=True, null=True),
        ),
    ]
