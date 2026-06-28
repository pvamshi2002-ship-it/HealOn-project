import re

from django.core.exceptions import ValidationError


PASSWORD_RULE_MESSAGE = (
    'Password must be at least 6 characters and include 1 uppercase letter, '
    '1 lowercase letter, and 1 number.'
)


def password_rule_error(password):
    password = password or ''
    if len(password) < 6:
        return PASSWORD_RULE_MESSAGE
    if not re.search(r'[A-Z]', password):
        return PASSWORD_RULE_MESSAGE
    if not re.search(r'[a-z]', password):
        return PASSWORD_RULE_MESSAGE
    if not re.search(r'\d', password):
        return PASSWORD_RULE_MESSAGE
    return ''


def validate_password_rules(password):
    error = password_rule_error(password)
    if error:
        raise ValidationError(error)


class HealOnPasswordValidator:
    def validate(self, password, user=None):
        validate_password_rules(password)

    def get_help_text(self):
        return PASSWORD_RULE_MESSAGE
