from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0019_career_module_updates'),
    ]

    operations = [
        migrations.AddField(
            model_name='employeedocument',
            name='is_archived',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='employeedocument',
            name='is_required',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='employeedocument',
            name='notes',
            field=models.TextField(blank=True),
        ),
        migrations.AlterField(
            model_name='employeedocument',
            name='category',
            field=models.CharField(
                choices=[
                    ('offer_letter', 'Offer Letter'),
                    ('appointment_letter', 'Appointment Letter'),
                    ('id_proof', 'ID Proof'),
                    ('address_proof', 'Address Proof'),
                    ('certificate', 'Certificates'),
                    ('experience_letter', 'Experience Letter'),
                    ('contract', 'Contract'),
                    ('policy', 'Policy'),
                    ('other', 'Other'),
                ],
                default='other',
                max_length=32,
            ),
        ),
    ]
