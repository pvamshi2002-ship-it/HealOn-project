from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0011_userprofile_profile_photo_biometric'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='ReimbursementRequest',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('expense_date', models.DateField()),
                ('reason', models.TextField()),
                ('file_name', models.CharField(max_length=255)),
                ('pdf_data', models.TextField()),
                ('submitted_at', models.DateTimeField(auto_now_add=True)),
                ('employee', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='reimbursement_requests', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-expense_date', '-submitted_at'],
            },
        ),
    ]
