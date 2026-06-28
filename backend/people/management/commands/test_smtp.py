from django.conf import settings
from django.core.mail import send_mail
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = 'Verify Gmail SMTP credentials by sending a test email.'

    def handle(self, *args, **options):
        email_user = (settings.EMAIL_HOST_USER or '').strip()
        email_password = (settings.EMAIL_HOST_PASSWORD or '').strip()

        if not email_user or not email_password:
            self.stderr.write(
                self.style.ERROR(
                    'SMTP is not configured. Copy .env.example to .env in the repo root '
                    'and set EMAIL_HOST_USER plus EMAIL_HOST_PASSWORD (Gmail App Password).'
                )
            )
            return

        recipient = email_user
        send_mail(
            'HealOn SMTP test',
            'If you received this message, OTP email delivery is configured correctly.',
            settings.DEFAULT_FROM_EMAIL,
            [recipient],
            fail_silently=False,
        )
        self.stdout.write(
            self.style.SUCCESS(f'SMTP test email sent to {recipient}')
        )
