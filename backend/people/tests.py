from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import override_settings
from django.urls import reverse
from django.utils import timezone
from unittest.mock import patch
from urllib.error import URLError
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .admin import AssignedLocationAdminForm
from .models import (
    AssignedLocation,
    Attendance,
    AttendanceSettings,
    PasswordResetOTP,
    UserProfile,
)
from .views import haversine_distance_meters


PHOTO_BIOMETRIC = 'data:image/png;base64,cGhvdG8='


def assert_decimal_equal(testcase, actual, expected):
    testcase.assertEqual(Decimal(str(actual)), Decimal(str(expected)))


def fresh_gps_fields(timestamp=None):
    captured_at = timestamp or timezone.now()
    return {
        'position_timestamp': captured_at.isoformat(),
        'location_captured_at': captured_at.isoformat(),
    }


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
        UserProfile.objects.update_or_create(
            user=self.employee,
            defaults={'profile_photo_biometric': PHOTO_BIOMETRIC},
        )

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

    def test_hr_can_access_people_management_apis(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.hr_token.key}')

        dashboard_response = self.client.get('/api/admin/dashboard/')
        employees_response = self.client.get('/api/admin/employees/')
        attendance_response = self.client.get('/api/admin/attendance/')

        self.assertEqual(dashboard_response.status_code, 200)
        self.assertEqual(employees_response.status_code, 200)
        self.assertEqual(attendance_response.status_code, 200)

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
                'profile_photo_biometric': PHOTO_BIOMETRIC,
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
                'profile_photo_biometric': PHOTO_BIOMETRIC,
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
                'profile_photo_biometric': PHOTO_BIOMETRIC,
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
        self.assertEqual(
            response.data['employee']['assigned_location']['latitude'],
            '17.385044',
        )
        self.assertEqual(
            response.data['employee']['assigned_location']['longitude'],
            '78.486671',
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
                'latitude_longitude': '17.400000,78.500000',
                'radius_meters': 100,
                'is_active': True,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.employee.refresh_from_db()
        self.assertEqual(self.employee.assigned_location.address, 'Complete New Office Address')
        assert_decimal_equal(self, self.employee.assigned_location.latitude, '17.400000')
        assert_decimal_equal(self, self.employee.assigned_location.longitude, '78.500000')
        self.assertEqual(self.employee.assigned_location.radius_meters, 100)

    def test_admin_location_rejects_invalid_latitude_longitude_box(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.admin_token.key}')

        response = self.client.put(
            f'/api/admin/employees/{self.employee.id}/location/',
            {
                'name': 'New Office',
                'address': 'Complete New Office Address',
                'latitude_longitude': '177.400000,78.500000',
                'radius_meters': 100,
                'is_active': True,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn('Latitude/Longitude', response.data['detail'])

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
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )
        self.assertEqual(far_response.status_code, 400)
        self.assertIn(
            'You are outside the allowed office location radius.',
            far_response.data['detail'],
        )
        self.assertIn('meters away from the office location', far_response.data['detail'])
        self.assertGreater(far_response.data['distance_meters'], 100)
        self.assertEqual(far_response.data['allowed_radius_meters'], 100)

        near_response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '17.385044',
                'longitude': '78.486671',
                'accuracy': 8.5,
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(near_response.status_code, 201)
        self.assertEqual(
            near_response.data['location_address'],
            'HealOn Head Office, Hyderabad, Telangana, India',
        )
        self.assertLessEqual(near_response.data['distance_meters'], 100)

    def test_checkout_blocks_outside_configured_office_radius(self):
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

        response = self.client.post(
            '/api/checkout/',
            {
                'latitude': '17.400000',
                'longitude': '78.500000',
                'accuracy': 8.5,
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn(
            'You are outside the allowed office location radius.',
            response.data['detail'],
        )
        self.assertIn('meters away from the office location', response.data['detail'])
        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

    def test_checkin_rejects_employee_1650m_from_office(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Head Office',
            address='HealOn Office, Bengaluru, Karnataka, India',
            latitude='13.065275000000000',
            longitude='77.529900000000000',
            coordinates_resolved=True,
            radius_meters=100,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '13.069141221891336',
                'longitude': '77.54462080506971',
                'accuracy': 8.5,
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn(
            'You are outside the allowed office location radius.',
            response.data['detail'],
        )
        self.assertGreater(response.data['distance_meters'], 1600)
        self.assertEqual(response.data['allowed_radius_meters'], 100)
        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

    def test_checkout_rejects_employee_1650m_from_office(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Head Office',
            address='HealOn Office, Bengaluru, Karnataka, India',
            latitude='13.065275000000000',
            longitude='77.529900000000000',
            coordinates_resolved=True,
            radius_meters=100,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkout/',
            {
                'latitude': '13.069141221891336',
                'longitude': '77.54462080506971',
                'accuracy': 8.5,
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn(
            'You are outside the allowed office location radius.',
            response.data['detail'],
        )
        self.assertGreater(response.data['distance_meters'], 1600)
        self.assertEqual(response.data['allowed_radius_meters'], 100)
        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

    def test_restricted_attendance_rejects_employee_1800m_from_office_for_both_events(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Head Office',
            address='HealOn Office, Bengaluru, Karnataka, India',
            latitude='13.058889689752338',
            longitude='77.54593290059762',
            coordinates_resolved=True,
            radius_meters=100,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        for endpoint in ('/api/checkin/', '/api/checkout/'):
            with self.subTest(endpoint=endpoint):
                with self.assertLogs('people.views', level='INFO') as logs:
                    response = self.client.post(
                        endpoint,
                        {
                            'latitude': '13.065275000000000',
                            'longitude': '77.529900000000000',
                            'accuracy': 8.5,
                            **fresh_gps_fields(),
                            'photo_biometric': PHOTO_BIOMETRIC,
                        },
                        format='json',
                    )

                self.assertEqual(response.status_code, 400)
                self.assertIn(
                    'You are outside the allowed office location radius.',
                    response.data['detail'],
                )
                self.assertGreater(response.data['distance_meters'], 1700)
                self.assertEqual(response.data['allowed_radius_meters'], 100)
                self.assertIn('office_latitude=13.058889689752', logs.output[0])
                self.assertIn('office_longitude=77.545932900597', logs.output[0])
                self.assertIn('employee_latitude=13.065275000000000', logs.output[0])
                self.assertIn('employee_longitude=77.529900000000000', logs.output[0])
                self.assertIn('distance_meters=', logs.output[0])
                self.assertIn('allowed_radius_meters=100', logs.output[0])

        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

    def test_checkin_allows_without_assigned_location_restriction(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertFalse(response.data['biometric_details']['location_restriction_enabled'])
        attendance = Attendance.objects.get(user=self.employee)
        assert_decimal_equal(self, attendance.latitude, '0')
        assert_decimal_equal(self, attendance.longitude, '0')
        self.assertIsNone(attendance.distance_meters)

    def test_face_recognition_toggle_blocks_mismatched_attendance_photo(self):
        AttendanceSettings.current().save()
        AttendanceSettings.objects.filter(pk=1).update(face_recognition_enabled=True)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'photo_biometric': 'data:image/png;base64,bWlzbWF0Y2g=',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['detail'], 'Face not matched')
        self.assertTrue(response.data['face_recognition_enabled'])
        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

    def test_face_recognition_disabled_still_saves_attendance_photo(self):
        AttendanceSettings.current().save()
        AttendanceSettings.objects.filter(pk=1).update(face_recognition_enabled=False)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'photo_biometric': 'data:image/png;base64,bWlzbWF0Y2g=',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        attendance = Attendance.objects.get(user=self.employee)
        self.assertEqual(attendance.photo_biometric, 'data:image/png;base64,bWlzbWF0Y2g=')

    def test_admin_can_update_face_recognition_setting(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.admin_token.key}')

        response = self.client.patch(
            '/api/admin/attendance-settings/',
            {'face_recognition_enabled': True},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['face_recognition_enabled'])
        self.assertTrue(AttendanceSettings.current().face_recognition_enabled)

    def test_checkout_allows_disabled_assigned_location_without_restriction(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Head Office',
            address='HealOn Head Office, Hyderabad, Telangana, India',
            latitude='17.385044',
            longitude='78.486671',
            coordinates_resolved=True,
            radius_meters=100,
            is_active=False,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkout/',
            {
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertFalse(response.data['biometric_details']['location_restriction_enabled'])
        attendance = Attendance.objects.get(user=self.employee)
        self.assertEqual(attendance.assigned_location, self.employee.assigned_location)
        assert_decimal_equal(self, attendance.latitude, '0')
        assert_decimal_equal(self, attendance.longitude, '0')
        self.assertIsNone(attendance.distance_meters)

    def test_checkin_uses_saved_coordinates_without_swapping(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Head Office',
            address='HealOn Head Office, Hyderabad, Telangana, India',
            latitude='78.486671',
            longitude='17.385044',
            coordinates_resolved=True,
            radius_meters=100,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '17.385044',
                'longitude': '78.486671',
                'accuracy': 8.5,
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.employee.assigned_location.refresh_from_db()
        assert_decimal_equal(self, self.employee.assigned_location.latitude, '78.486671')
        assert_decimal_equal(self, self.employee.assigned_location.longitude, '17.385044')
        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

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
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
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
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.employee.assigned_location.refresh_from_db()
        self.assertTrue(self.employee.assigned_location.coordinates_resolved)

    def test_checkin_uses_saved_coordinates_over_admin_map_link(self):
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
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.employee.assigned_location.refresh_from_db()
        assert_decimal_equal(self, self.employee.assigned_location.latitude, '13.053333')
        assert_decimal_equal(self, self.employee.assigned_location.longitude, '77.530604')
        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

    def test_checkin_uses_saved_coordinates_over_address_coordinates(self):
        AssignedLocation.objects.create(
            user=self.employee,
            name='Work Location',
            address=(
                '46, 16th Cross Rd, Kammagondahalli, Jalahalli West, '
                'Bengaluru, Karnataka 560015\n13.06527461242068, 77.52989980407031'
            ),
            latitude='13.054916',
            longitude='77.534523',
            radius_meters=100,
            coordinates_resolved=True,
        )
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.employee_token.key}')

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '13.065240',
                'longitude': '77.529911',
                'accuracy': 79,
                **fresh_gps_fields(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.employee.assigned_location.refresh_from_db()
        assert_decimal_equal(self, self.employee.assigned_location.latitude, '13.054916')
        assert_decimal_equal(self, self.employee.assigned_location.longitude, '77.534523')
        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

    def test_haversine_distance_is_used_for_location_radius(self):
        distance = haversine_distance_meters(
            17.385044,
            78.486671,
            17.385944,
            78.486671,
        )

        self.assertGreater(distance, 99)
        self.assertLess(distance, 101)

    def test_checkin_rejects_stale_live_gps_timestamp(self):
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
        stale_timestamp = timezone.now() - timezone.timedelta(minutes=5)

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '17.385044',
                'longitude': '78.486671',
                'accuracy': 8.5,
                'position_timestamp': stale_timestamp.isoformat(),
                'location_captured_at': timezone.now().isoformat(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn('Live GPS coordinates are stale', response.data['detail'])

    def test_checkin_rejects_missing_live_gps_timestamp_when_location_restricted(self):
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

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '17.385044',
                'longitude': '78.486671',
                'accuracy': 8.5,
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.data['detail'],
            'Fresh live GPS timestamp is required for attendance.',
        )
        self.assertFalse(Attendance.objects.filter(user=self.employee).exists())

    def test_checkin_accepts_fresh_live_gps_timestamp(self):
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
        fresh_timestamp = timezone.now()

        response = self.client.post(
            '/api/checkin/',
            {
                'latitude': '17.385044',
                'longitude': '78.486671',
                'accuracy': 8.5,
                'position_timestamp': fresh_timestamp.isoformat(),
                'location_captured_at': fresh_timestamp.isoformat(),
                'photo_biometric': PHOTO_BIOMETRIC,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(Attendance.objects.filter(user=self.employee).count(), 1)
        self.assertLessEqual(response.data['distance_meters'], 100)

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
                'is_active': 'True',
            }
        )

        self.assertTrue(form.is_valid(), form.errors)
        location = form.save()
        self.assertEqual(location.map_url, 'https://www.google.com/maps/place/Test/@17.385044,78.486671,17z')
        assert_decimal_equal(self, location.latitude, '17.385044')
        assert_decimal_equal(self, location.longitude, '78.486671')
        self.assertTrue(location.coordinates_resolved)

    def test_assigned_location_admin_form_accepts_latitude_longitude_box(self):
        form = AssignedLocationAdminForm(
            data={
                'user': self.employee.id,
                'name': 'Head Office',
                'address': 'HealOn Head Office, Hyderabad, Telangana, India',
                'latitude_longitude': '13.05580947189991,77.54149038010287',
                'radius_meters': 100,
                'is_active': 'True',
            }
        )

        self.assertTrue(form.is_valid(), form.errors)
        location = form.save()
        assert_decimal_equal(self, location.latitude, '13.05580947189991')
        assert_decimal_equal(self, location.longitude, '77.54149038010287')
        self.assertTrue(location.coordinates_resolved)

    def test_assigned_location_has_separate_backend_admin_section(self):
        self.client.force_login(self.admin)

        response = self.client.get(reverse('admin:people_assignedlocation_add'))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Google Maps link')
        self.assertContains(response, 'Latitude/Longitude')

    @patch('people.location_utils.urlopen')
    def test_assigned_location_admin_form_rejects_address_without_coordinates(self, mock_urlopen):
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
                'is_active': 'True',
            }
        )

        self.assertFalse(form.is_valid())
        self.assertIn('latitude_longitude', form.errors)
        mock_urlopen.assert_not_called()

    @patch('people.location_utils.urlopen')
    def test_assigned_location_admin_form_requires_coordinates_when_lookup_fails(self, mock_urlopen):
        mock_urlopen.side_effect = URLError('lookup unavailable')
        form = AssignedLocationAdminForm(
            data={
                'user': self.employee.id,
                'name': 'Work Location',
                'address': 'kg halli',
                'radius_meters': 100,
                'is_active': 'True',
            }
        )

        self.assertFalse(form.is_valid())
        self.assertIn('latitude_longitude', form.errors)

    @patch('people.views.get_random_string', return_value='123456')
    @patch('people.views.send_mail')
    @override_settings(
        EMAIL_HOST_USER='sender@gmail.com',
        EMAIL_HOST_PASSWORD='app-password',
    )
    def test_password_reset_uses_email_otp_and_changes_password(
        self,
        mock_send_mail,
        mock_get_random_string,
    ):
        self.employee.email = 'employee@healon.local'
        self.employee.save(update_fields=['email'])

        request_response = self.client.post(
            '/api/password-reset/request/',
            {'email': 'employee@healon.local'},
        )

        self.assertEqual(request_response.status_code, 200)
        self.assertEqual(request_response.data['otp_provider'], 'email')
        mock_send_mail.assert_called_once()
        self.assertNotEqual(PasswordResetOTP.objects.latest('created_at').otp_hash, '123456')

        verify_response = self.client.post(
            '/api/password-reset/verify/',
            {
                'email': 'employee@healon.local',
                'otp': '123456',
            },
        )

        self.assertEqual(verify_response.status_code, 200)

        confirm_response = self.client.post(
            '/api/password-reset/confirm/',
            {
                'email': 'employee@healon.local',
                'new_password': 'Changed@123',
            },
        )

        self.assertEqual(confirm_response.status_code, 200)

        login_response = self.client.post(
            '/api/auth/',
            {'username': 'employee', 'password': 'Changed@123', 'role': 'User'},
        )

        self.assertEqual(login_response.status_code, 200)

    @patch('people.views.get_random_string', return_value='123456')
    @patch('people.views.send_mail')
    @override_settings(
        EMAIL_HOST_USER='sender@gmail.com',
        EMAIL_HOST_PASSWORD='app-password',
    )
    def test_password_reset_rejects_invalid_email_otp(
        self,
        mock_send_mail,
        mock_get_random_string,
    ):
        self.employee.email = 'employee@healon.local'
        self.employee.save(update_fields=['email'])

        request_response = self.client.post(
            '/api/password-reset/request/',
            {'email': 'employee@healon.local'},
        )
        verify_response = self.client.post(
            '/api/password-reset/verify/',
            {'email': 'employee@healon.local', 'otp': '000000'},
        )

        self.assertEqual(request_response.status_code, 200)
        self.assertEqual(verify_response.status_code, 400)
        self.assertIn('Invalid OTP', verify_response.data['detail'])
        self.assertTrue(PasswordResetOTP.objects.exists())

    def test_password_reset_does_not_expose_unknown_email(self):
        response = self.client.post(
            '/api/password-reset/request/',
            {'email': 'unknown@healon.local'},
        )

        self.assertEqual(response.status_code, 200)
        self.assertFalse(PasswordResetOTP.objects.exists())
