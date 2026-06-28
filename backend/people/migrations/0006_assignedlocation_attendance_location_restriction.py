import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0005_alter_attendanceregularization_cc'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='AssignedLocation',
            fields=[
                (
                    'id',
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name='ID',
                    ),
                ),
                ('name', models.CharField(default='Work Location', max_length=120)),
                (
                    'address',
                    models.TextField(
                        help_text='Complete location address shown to admins and employees.'
                    ),
                ),
                ('latitude', models.DecimalField(decimal_places=6, max_digits=9)),
                ('longitude', models.DecimalField(decimal_places=6, max_digits=9)),
                ('radius_meters', models.PositiveIntegerField(default=100)),
                ('is_active', models.BooleanField(default=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                (
                    'user',
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='assigned_location',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                'ordering': ['user__username'],
            },
        ),
        migrations.AddField(
            model_name='attendance',
            name='assigned_location',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                to='people.assignedlocation',
            ),
        ),
        migrations.AddField(
            model_name='attendance',
            name='distance_meters',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='attendance',
            name='location_address',
            field=models.TextField(blank=True),
        ),
    ]
