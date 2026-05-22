from django.conf import settings
from django.db import migrations


def create_missing_profiles(apps, schema_editor):
    UserProfile = apps.get_model('people', 'UserProfile')
    app_label, model_name = settings.AUTH_USER_MODEL.split('.')
    User = apps.get_model(app_label, model_name)

    for user in User.objects.filter(is_staff=False):
        UserProfile.objects.get_or_create(
            user=user,
            defaults={'employee_code': user.username.upper()},
        )


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(create_missing_profiles, migrations.RunPython.noop),
    ]
