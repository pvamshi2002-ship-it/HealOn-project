from django.contrib.auth import get_user_model
from django.test import override_settings
from django.urls import reverse
from unittest.mock import patch
from urllib.error import URLError
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .admin import AssignedLocationAdminForm
from .models import AssignedLocation, Attendance, UserProfile
from .views import haversine_distance_meters


class TwilioResponse:
    def __init__(self, body, status_code=200):
        self.body = body
        self.status = status_code

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self):
        return self.body.encode('utf-8')


class AdminLocationResponse:
    def __init__(self, body, final_url='https://maps.example/location'):
        self.body = body
        self.final_url = final_url

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self):
        return self.body.encode('utf-8')

    def geturl(self):
        return self.final_url


class DashboardLoginTests(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.admin = User.objects.create_superuser(
            username='admin',
            password='Admin@123',
            email='admin@healon.local',
        )
        self.employee = User.objects.create_user(
            username='employee',
            password='Employee@123',
        )
        self.hr = User.objects.create_user(
            username='hr',
            password='HR@123',
            email='hr@healon.local',
        )
        self.admin_token = Token.objects.create(user=self.admin)
        self.employee_token = Token.objects.create(user=self.employee)
        self.hr_token = Token.objects.create(user=self.hr)

    def test_auth_allows_matching_admin_role(self):
        response = self.client.post(
            '/api/auth/',
            {'username': 'admin', 'password': 'Admin@123', 'role': 'Admin'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['user']['role'], 'Admin')

    def test_auth_allows_matching_employee_role(self):
        response = self.client.post(
            '/api/auth/',
            {'username': 'employee', 'password': 'Employee@123', 'role': 'User'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['user']['role'], 'User')

    def test_auth_allows_matching_hr_role(self):
        response = self.client.post(
            '/api/auth/',
            {'username': 'hr', 'password': 'HR@123', 'role': 'HR'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['user']['role'], 'HR')

    def test_auth_rejects_role_mismatch(self):
        response = self.client.post(
            '/api/auth/',
            {'username': 'employee', 'password': 'Employee@123', 'role': 'Admin'},
        )

        self.assertEqual(response.status_code, 403)

    def test_admin_dashboard_api_allows_staff(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.admin_token.key}')
        response = self.client.get('/api/admin/dashboard/')

        self.assertEqual(response.status_code, 200)
        self.assertIn('summary', response.data)

    def test_employee_dashboard_api_allows_non_staff(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')
        response = self.client.get('/api/dashboard/')

        self.assertEqual(response.status_code, 200)
        self.assertIn('attendance', response.data)
        self.assertEqual(response.data['user']['role'], 'User')

    def test_hr_dashboard_api_allows_hr_user(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.hr_token.key}')
        response = self.client.get('/api/dashboard/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['user']['role'], 'HR')

    def test_admin_can_create_employee_with_login_password(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.admin_token.key}')
        response = self.client.post(
            '/api/admin/employees/',
            {
                'first_name': 'New',
                'last_name': 'Employee',
                'date_of_birth': '1995-04-12',
                'email': 'new.employee@healon.local',
                'username': 'newemployee',
                'password': 'Newpass@123',
                'department': 'Support',
                'designation': 'Support Executive',
                'can_access_user_dashboard': True,
                'can_access_admin_dashboard': False,
                'can_access_hr_dashboard': False,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['employee']['username'], 'newemployee')
        self.assertEqual(response.data['employee']['first_name'], 'New')
        self.assertEqual(response.data['employee']['last_name'], 'Employee')
        self.assertEqual(response.data['employee']['date_of_birth'], '1995-04-12')
        self.assertEqual(response.data['employee']['dashboard_permissions'], ['User'])

        login_response = self.client.post(
            '/api/auth/',
            {
                'username': 'newemployee',
                'password': 'Newpass@123',
                'role': 'User',
            },
        )

        self.assertEqual(login_response.status_code, 200)

    def test_admin_can_create_user_with_admin_and_hr_dashboard_access(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.admin_token.key}')
        response = self.client.post(
            '/api/admin/employees/',
            {
                'first_name': 'Access',
                'last_name': 'Manager',
                'email': 'access.manager@healon.local',
                'username': 'accessmanager',
                'password': 'Access@123',
                'department': 'People',
                'designation': 'Manager',
                'can_access_user_dashboard': True,
                'can_access_admin_dashboard': True,
                'can_access_hr_dashboard': True,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(
            response.data['employee']['dashboard_permissions'],
            ['User', 'Admin', 'HR'],
        )

        login_response = self.client.post(
            '/api/auth/',
            {
                'username': 'accessmanager',
                'password': 'Access@123',
                'role': 'HR',
            },
        )

        self.assertEqual(login_response.status_code, 200)

    def test_admin_can_create_employee_with_assigned_location(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.admin_token.key}')
        response = self.client.post(
            '/api/admin/employees/',
            {
                'name': 'Location User',
                'email': 'location.user@healon.local',
                'username': 'locationuser',
                'password': 'Location@123',
                'department': 'Operations',
                'designation': 'Executive',
                'location_name': 'Head Office',
                'location_address': 'HealOn Head Office, Hyderabad, Telangana, India',
                'location_latitude': '17.385044',
                'location_longitude': '78.486671',
                'location_radius_meters': 100,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(
            response.data['employee']['assigned_location']['address'],
            'HealOn Head Office, Hyderabad, Telangana, India',
        )
        self.assertEqual(
            response.data['employee']['assigned_location']['radius_meters'],
            100,
        )

    def test_admin_can_edit_employee_assigned_location(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Old Office',
            address='Old Office Address',
            latitude='17.385044',
            longitude='78.486671',
            coordinates_resolved=True,
            radius_meters=100,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.admin_token.key}')

        response = self.client.put(
            f'/api/admin/employees/{self.employee.id}/location/',
            {
                'name': 'New Office',
                'address': 'Complete New Office Address',
                'latitude': '17.400000',
                'longitude': '78.500000',
                'radius_meters': 100,
                'is_active': True,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.employee.refresh_from_db()
        self.assertEqual(self.employee.assigned_location.address, 'Complete New Office Address')
        self.assertEqual(self.employee.assigned_location.radius_meters, 100)

    def test_checkin_requires_assigned_location_and_100m_radius(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Head Office',
            address='HealOn Head Office, Hyderabad, Telangana, India',
            latitude='17.385044',
            longitude='78.486671',
            coordinates_resolved=True,
            radius_meters=100,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        far_response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '17.400000',
                'longitude': '78.500000',
                'accuracy': 8.5,
            },
            format='json',
        )
        self.assertEqual(far_response.status_code, 400)
        self.assertIn('outside the assigned attendance location', far_response.data['detail'])

        near_response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '17.385044',
                'longitude': '78.486671',
                'accuracy': 8.5,
            },
            format='json',
        )

        self.assertEqual(near_response.status_code, 201)
        self.assertEqual(
            near_response.data['location_address'],
            'HealOn Head Office, Hyderabad, Telangana, India',
        )
        self.assertLessEqual(near_response.data['distance_meters'], 100)

    @patch('people.location_utils.urlopen')
    def test_checkin_resolves_admin_assigned_address_before_radius_check(self, mock_urlopen):
        mock_urlopen.return_value = AdminLocationResponse(
            '[{"lat": "13.0533332", "lon": "77.5306036"}]'
        )
        AssignedLocation.objects.create(
            user=self.employee,
            name='Work Location',
            address='kg halli',
            radius_meters=100,
            coordinates_resolved=False,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '13.053333',
                'longitude': '77.530604',
                'accuracy': 8.5,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.employee.assigned_location.refresh_from_db()
        self.assertTrue(self.employee.assigned_location.coordinates_resolved)

    def test_checkin_prefers_admin_map_link_over_address_lookup(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Work Location',
            address='46, 16th Cross Rd, Kammagondahalli, Jalahalli West, Bengaluru, Karnataka 560015',
            map_url='https://www.google.com/maps/place/Test/@13.064800,77.530600,17z',
            radius_meters=100,
            coordinates_resolved=False,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '13.064800',
                'longitude': '77.530600',
                'accuracy': 8.5,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.employee.assigned_location.refresh_from_db()
        self.assertTrue(self.employee.assigned_location.coordinates_resolved)

    def test_checkin_refreshes_stale_coordinates_from_admin_map_link(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Work Location',
            address='46, 16th Cross Rd, Kammagondahalli, Jalahalli West, Bengaluru, Karnataka 560015',
            map_url='https://www.google.com/maps/place/Test/@13.064800,77.530600,17z',
            latitude='13.053333',
            longitude='77.530604',
            radius_meters=100,
            coordinates_resolved=True,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '13.064800',
                'longitude': '77.530600',
                'accuracy': 8.5,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.employee.assigned_location.refresh_from_db()
        self.assertEqual(str(self.employee.assigned_location.latitude), '13.064800')
        self.assertEqual(str(self.employee.assigned_location.longitude), '77.530600')

    def test_haversine_distance_is_used_for_location_radius(self):
        distance = haversine_distance_meters(
            17.385044,
            78.486671,
            17.385944,
            78.486671,
        )

        self.assertGreater(distance, 99)
        self.assertLess(distance, 101)

    def test_backend_admin_created_user_gets_profile_and_can_login(self):
        User = get_user_model()
        employee = User.objects.create_user(
            username='backenduser',
            password='Backend@123',
            email='backend.user@healon.local',
            first_name='Backend',
            last_name='User',
        )
        UserProfile.objects.filter(user=employee).update(
            employee_code='EMP-BACKEND',
            department='Operations',
            designation='Executive',
        )

        self.assertTrue(UserProfile.objects.filter(user=employee).exists())

        response = self.client.post(
            '/api/auth/',
            {'username': 'backenduser', 'password': 'Backend@123', 'role': 'User'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['user']['employee_id'], 'EMP-BACKEND')
        self.assertEqual(response.data['user']['department'], 'Operations')

    def test_custom_backend_admin_panel_lists_employees(self):
        User = get_user_model()
        employee = User.objects.create_user(
            username='paneluser',
            password='Panel@123',
            email='panel.user@healon.local',
            first_name='Panel',
            last_name='User',
        )
        UserProfile.objects.filter(user=employee).update(
            employee_code='EMP-PANEL',
            department='Support',
            designation='Agent',
        )
        self.client.force_login(self.admin)

        response = self.client.get('/api/admin-panel/')

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'paneluser')
        self.assertContains(response, 'EMP-PANEL')
        self.assertContains(response, 'Support')

    def test_django_user_admin_shows_attendance_location(self):
        Attendance.objects.create(
            user=self.employee,
            event_type=Attendance.CHECK_IN,
            latitude='17.385044',
            longitude='78.486671',
            accuracy=8.5,
        )
        self.client.force_login(self.admin)

        response = self.client.get(
            reverse('admin:auth_user_change', args=[self.employee.id])
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Open map')
        self.assertContains(response, 'https://www.google.com/maps?q=17.385044,78.486671')

    def test_assigned_location_admin_form_accepts_google_maps_link(self):
        form = AssignedLocationAdminForm(
            data={
                'user': self.employee.id,
                'name': 'Head Office',
                'address': 'HealOn Head Office, Hyderabad, Telangana, India',
                'map_location': 'https://www.google.com/maps/place/Test/@17.385044,78.486671,17z',
                'radius_meters': 100,
                'is_active': 'on',
            }
        )

        self.assertTrue(form.is_valid(), form.errors)
        location = form.save()
        self.assertEqual(location.map_url, 'https://www.google.com/maps/place/Test/@17.385044,78.486671,17z')
        self.assertEqual(str(location.latitude), '17.385044')
        self.assertEqual(str(location.longitude), '78.486671')
        self.assertTrue(location.coordinates_resolved)

    def test_assigned_location_has_separate_backend_admin_section(self):
        self.client.force_login(self.admin)

        response = self.client.get(reverse('admin:people_assignedlocation_add'))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Google Maps link')
        self.assertNotContains(response, 'Latitude')
        self.assertNotContains(response, 'Longitude')

    @patch('people.admin.urlopen')
    def test_assigned_location_admin_form_accepts_full_address(self, mock_urlopen):
        mock_urlopen.return_value = AdminLocationResponse(
            '[{"lat": "13.058901", "lon": "77.513686"}]'
        )
        address = (
            '46, 16th Cross Rd, Kammagondahalli, Jalahalli West, '
            'Bengaluru, Karnataka 560015'
        )
        form = AssignedLocationAdminForm(
            data={
                'user': self.employee.id,
                'name': 'Bengaluru Office',
                'address': address,
                'radius_meters': 100,
                'is_active': 'on',
            }
        )

        self.assertTrue(form.is_valid(), form.errors)
        location = form.save()
        self.assertEqual(str(location.latitude), '13.058901')
        self.assertEqual(str(location.longitude), '77.513686')
        self.assertIn('google.com/maps/search', location.map_url)
        self.assertTrue(location.coordinates_resolved)

    @patch('people.admin.urlopen')
    def test_assigned_location_admin_form_saves_even_when_address_lookup_fails(self, mock_urlopen):
        mock_urlopen.side_effect = URLError('lookup unavailable')
        form = AssignedLocationAdminForm(
            data={
                'user': self.employee.id,
                'name': 'Work Location',
                'address': 'kg halli',
                'radius_meters': 100,
                'is_active': 'on',
            }
        )

        self.assertTrue(form.is_valid(), form.errors)
        location = form.save()
        self.assertEqual(location.address, 'kg halli')
        self.assertFalse(location.coordinates_resolved)

    def test_password_reset_sends_verifies_and_changes_password(self):
        UserProfile.objects.filter(user=self.employee).update(
            mobile_number='9998887776'
        )

        request_response = self.client.post(
            '/api/password-reset/request/',
            {'mobile_number': '9998887776'},
        )

        self.assertEqual(request_response.status_code, 200)
        self.assertIn('HealOn password reset OTP sent', request_response.data['detail'])
        otp = request_response.data['dev_otp']

        verify_response = self.client.post(
            '/api/password-reset/verify/',
            {'mobile_number': '9998887776', 'otp': otp},
        )

        self.assertEqual(verify_response.status_code, 200)

        confirm_response = self.client.post(
            '/api/password-reset/confirm/',
            {
                'mobile_number': '9998887776',
                'otp': otp,
                'new_password': 'Changed@123',
            },
        )

        self.assertEqual(confirm_response.status_code, 200)

        login_response = self.client.post(
            '/api/auth/',
            {'username': 'employee', 'password': 'Changed@123', 'role': 'User'},
        )

        self.assertEqual(login_response.status_code, 200)

    def test_password_reset_rejects_unknown_mobile(self):
        response = self.client.post(
            '/api/password-reset/request/',
            {'mobile_number': '1112223333'},
        )

        self.assertEqual(response.status_code, 404)

    @override_settings(
        SMS_PROVIDER='twilio',
        TWILIO_ACCOUNT_SID='AC_test',
        TWILIO_AUTH_TOKEN='auth_test',
        TWILIO_VERIFY_SERVICE_SID='VA_test',
    )
    @patch('people.views.urlrequest.urlopen')
    def test_password_reset_uses_twilio_verify_for_real_otp(self, mock_urlopen):
        UserProfile.objects.filter(user=self.employee).update(
            mobile_number='+919998887776'
        )
        mock_urlopen.side_effect = [
            TwilioResponse('{"status": "pending"}'),
            TwilioResponse('{"status": "approved"}'),
        ]

        request_response = self.client.post(
            '/api/password-reset/request/',
            {'mobile_number': '+91 99988 87776'},
        )

        self.assertEqual(request_response.status_code, 200)
        self.assertTrue(request_response.data['sms_delivered'])
        self.assertEqual(request_response.data['sms_provider'], 'twilio_verify')
        self.assertNotIn('dev_otp', request_response.data)

        verify_response = self.client.post(
            '/api/password-reset/verify/',
            {'mobile_number': '+919998887776', 'otp': '123456'},
        )

        self.assertEqual(verify_response.status_code, 200)

        confirm_response = self.client.post(
            '/api/password-reset/confirm/',
            {
                'mobile_number': '+919998887776',
                'otp': '123456',
                'new_password': 'Twilio@123',
            },
        )

        self.assertEqual(confirm_response.status_code, 200)
        self.assertEqual(mock_urlopen.call_count, 2)

        login_response = self.client.post(
            '/api/auth/',
            {'username': 'employee', 'password': 'Twilio@123', 'role': 'User'},
        )

        self.assertEqual(login_response.status_code, 200)

    @override_settings(
        SMS_PROVIDER='twilio',
        TWILIO_ACCOUNT_SID='AC_test',
        TWILIO_AUTH_TOKEN='auth_test',
        TWILIO_VERIFY_SERVICE_SID='VA_test',
    )
    @patch('people.views.urlrequest.urlopen')
    def test_password_reset_adds_india_country_code_for_twilio(self, mock_urlopen):
        UserProfile.objects.filter(user=self.employee).update(
            mobile_number='9876543210'
        )
        mock_urlopen.return_value = TwilioResponse('{"status": "pending"}')

        response = self.client.post(
            '/api/password-reset/request/',
            {'mobile_number': '9876543210'},
        )

        self.assertEqual(response.status_code, 200)
        request_body = mock_urlopen.call_args.args[0].data.decode('utf-8')
        self.assertIn('To=%2B919876543210', request_body)
