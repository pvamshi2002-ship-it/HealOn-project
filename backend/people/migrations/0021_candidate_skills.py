from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0020_employee_document_enhancements'),
    ]

    operations = [
        migrations.AddField(
            model_name='candidate',
            name='skills',
            field=models.TextField(blank=True),
        ),
    ]
