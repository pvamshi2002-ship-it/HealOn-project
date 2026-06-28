from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import (
    EmployeeTask,
    HelpdeskTicket,
    LeaveRequest,
    ReimbursementRequest,
    SalaryRecord,
    UserProfile,
)

PHOTO_BIOMETRIC = 'data:image/png;base64,cGhvdG8='
VALID_PDF = 'data:application/pdf;base64,QUJDRA=='


class WorkflowTestBase(APITestCase):
    """Isolated API workflow tests using Django's ephemeral test database."""

    def setUp(self):
        User = get_user_model()
        self.admin = User.objects.create_superuser(
            username='wf_admin',
            password='Admin@123',
            email='wf_admin@healon.local',
        )
        self.employee = User.objects.create_user(
            username='wf_employee',
            password='Employee@123',
            email='wf_employee@healon.local',
            first_name='Workflow',
            last_name='Employee',
        )
        self.hr = User.objects.create_user(
            username='wf_hr',
            password='HR@123',
            email='wf_hr@healon.local',
        )
        self.other_employee = User.objects.create_user(
            username='wf_other',
            password='Other@123',
            email='wf_other@healon.local',
            first_name='Other',
            last_name='Employee',
        )

        for user in (self.employee, self.other_employee):
            UserProfile.objects.update_or_create(
                user=user,
                defaults={'profile_photo_biometric': PHOTO_BIOMETRIC},
            )

        self.admin_token = Token.objects.create(user=self.admin)
        self.employee_token = Token.objects.create(user=self.employee)
        self.hr_token = Token.objects.create(user=self.hr)

        self.today = timezone.localdate()
        self.leave_start = self.today + timedelta(days=7)
        self.leave_end = self.leave_start + timedelta(days=1)

    def auth(self, token):
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')


class LeaveWorkflowTests(WorkflowTestBase):
    def test_employee_can_submit_leave_application(self):
        self.auth(self.employee_token)
        response = self.client.post(
            '/api/employee/leaves/',
            {
                'leave_type': 'Paid Leave',
                'from_date': self.leave_start.isoformat(),
                'to_date': self.leave_end.isoformat(),
                'reason': 'Family event',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['leave_type'], 'Paid Leave')
        self.assertEqual(response.data['status'], LeaveRequest.STATUS_PENDING)
        self.assertEqual(
            LeaveRequest.objects.filter(employee=self.employee).count(),
            1,
        )

    def test_admin_can_approve_leave_request(self):
        leave = LeaveRequest.objects.create(
            employee=self.employee,
            leave_type='Casual Leave',
            from_date=self.leave_start,
            to_date=self.leave_start,
            reason='Workflow approval test',
            status=LeaveRequest.STATUS_PENDING,
        )

        self.auth(self.admin_token)
        response = self.client.post(
            f'/api/admin/leaves/{leave.id}/status/',
            {'status': LeaveRequest.STATUS_APPROVED},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        leave.refresh_from_db()
        self.assertEqual(leave.status, LeaveRequest.STATUS_APPROVED)

    def test_hr_can_reject_leave_request(self):
        leave = LeaveRequest.objects.create(
            employee=self.employee,
            leave_type='Sick Leave',
            from_date=self.leave_start,
            to_date=self.leave_start,
            reason='Workflow rejection test',
            status=LeaveRequest.STATUS_PENDING,
        )

        self.auth(self.hr_token)
        response = self.client.post(
            f'/api/admin/leaves/{leave.id}/status/',
            {'status': LeaveRequest.STATUS_REJECTED},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        leave.refresh_from_db()
        self.assertEqual(leave.status, LeaveRequest.STATUS_REJECTED)

    def test_employee_cannot_approve_leave_request(self):
        leave = LeaveRequest.objects.create(
            employee=self.employee,
            leave_type='Casual Leave',
            from_date=self.leave_start,
            to_date=self.leave_start,
            status=LeaveRequest.STATUS_PENDING,
        )

        self.auth(self.employee_token)
        response = self.client.post(
            f'/api/admin/leaves/{leave.id}/status/',
            {'status': LeaveRequest.STATUS_APPROVED},
            format='json',
        )

        self.assertEqual(response.status_code, 403)
        leave.refresh_from_db()
        self.assertEqual(leave.status, LeaveRequest.STATUS_PENDING)

    def test_admin_rejects_invalid_leave_status(self):
        leave = LeaveRequest.objects.create(
            employee=self.employee,
            leave_type='Casual Leave',
            from_date=self.leave_start,
            to_date=self.leave_start,
            status=LeaveRequest.STATUS_PENDING,
        )

        self.auth(self.admin_token)
        response = self.client.post(
            f'/api/admin/leaves/{leave.id}/status/',
            {'status': 'cancelled'},
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        leave.refresh_from_db()
        self.assertEqual(leave.status, LeaveRequest.STATUS_PENDING)


class ReimbursementWorkflowTests(WorkflowTestBase):
    def test_employee_can_create_reimbursement(self):
        self.auth(self.employee_token)
        response = self.client.post(
            '/api/employee/reimbursements/',
            {
                'expense_date': self.today.isoformat(),
                'reason': 'Client travel',
                'file_name': 'travel.pdf',
                'pdf_data': VALID_PDF,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['reimbursement']['reason'], 'Client travel')
        self.assertEqual(
            ReimbursementRequest.objects.filter(employee=self.employee).count(),
            1,
        )

    def test_reimbursement_rejects_invalid_pdf(self):
        self.auth(self.employee_token)
        response = self.client.post(
            '/api/employee/reimbursements/',
            {
                'expense_date': self.today.isoformat(),
                'reason': 'Invalid upload',
                'file_name': 'bad.pdf',
                'pdf_data': 'not-a-pdf',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(ReimbursementRequest.objects.count(), 0)

    def test_admin_can_list_reimbursements(self):
        ReimbursementRequest.objects.create(
            employee=self.employee,
            expense_date=self.today,
            reason='Listed reimbursement',
            file_name='receipt.pdf',
            pdf_data=VALID_PDF,
        )

        self.auth(self.admin_token)
        response = self.client.get('/api/admin/reimbursements/')

        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(len(response.data['reimbursements']), 1)


class PayrollWorkflowTests(WorkflowTestBase):
    def test_admin_can_publish_payroll_record(self):
        self.auth(self.admin_token)
        response = self.client.post(
            '/api/admin/salary-records/',
            {
                'employee_id': self.employee.id,
                'year': self.today.year,
                'month': self.today.month,
                'basic_salary': '45000',
                'allowances': '5000',
                'deductions': '1500',
                'bonus': '1000',
                'incentives': '500',
                'tax_deducted': '800',
                'is_published': True,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        record = SalaryRecord.objects.get(employee=self.employee)
        self.assertTrue(record.is_published)
        self.assertEqual(record.net_salary, Decimal('49200.00'))

    def test_employee_sees_only_published_salary_records(self):
        SalaryRecord.objects.create(
            employee=self.employee,
            year=self.today.year,
            month=self.today.month,
            basic_salary=40000,
            is_published=True,
        )
        unpublished_month = self.today.month - 1 if self.today.month > 1 else 12
        unpublished_year = (
            self.today.year if self.today.month > 1 else self.today.year - 1
        )
        SalaryRecord.objects.create(
            employee=self.employee,
            year=unpublished_year,
            month=unpublished_month,
            basic_salary=39000,
            is_published=False,
        )

        self.auth(self.employee_token)
        response = self.client.get('/api/employee/salary/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['salary_records']), 1)
        self.assertTrue(response.data['salary_records'][0]['is_published'])


class PayslipPdfWorkflowTests(WorkflowTestBase):
    def setUp(self):
        super().setUp()
        self.record = SalaryRecord.objects.create(
            employee=self.employee,
            year=self.today.year,
            month=self.today.month,
            basic_salary=42000,
            allowances=4000,
            deductions=1000,
            tax_deducted=500,
            is_published=True,
        )

    def test_employee_can_download_published_payslip_pdf(self):
        self.auth(self.employee_token)
        response = self.client.get(
            '/api/employee/salary/payslip/',
            {'year': self.record.year, 'month': self.record.month},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['Content-Type'], 'application/pdf')
        self.assertTrue(response.content.startswith(b'%PDF'))
        self.assertIn(
            f'payslip-{self.record.year}-{self.record.month:02d}.pdf',
            response['Content-Disposition'],
        )

    def test_employee_cannot_download_unpublished_payslip(self):
        self.record.is_published = False
        self.record.save(update_fields=['is_published'])

        self.auth(self.employee_token)
        response = self.client.get(
            '/api/employee/salary/payslip/',
            {'year': self.record.year, 'month': self.record.month},
        )

        self.assertEqual(response.status_code, 404)

    def test_payslip_requires_month_and_year(self):
        self.auth(self.employee_token)
        response = self.client.get('/api/employee/salary/payslip/')

        self.assertEqual(response.status_code, 400)


class HelpdeskWorkflowTests(WorkflowTestBase):
    def test_employee_can_create_helpdesk_ticket(self):
        self.auth(self.employee_token)
        response = self.client.post(
            '/api/employee/helpdesk/',
            {
                'subject': 'Laptop issue',
                'description': 'Screen flickers during video calls.',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['subject'], 'Laptop issue')
        self.assertEqual(response.data['status'], HelpdeskTicket.STATUS_OPEN)
        self.assertEqual(
            HelpdeskTicket.objects.filter(employee=self.employee).count(),
            1,
        )

    def test_admin_can_update_helpdesk_ticket_status(self):
        ticket = HelpdeskTicket.objects.create(
            employee=self.employee,
            subject='VPN access',
            description='Cannot connect to VPN.',
            status=HelpdeskTicket.STATUS_OPEN,
        )

        self.auth(self.admin_token)
        response = self.client.post(
            f'/api/admin/helpdesk/{ticket.id}/status/',
            {'status': HelpdeskTicket.STATUS_RESOLVED},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        ticket.refresh_from_db()
        self.assertEqual(ticket.status, HelpdeskTicket.STATUS_RESOLVED)
        self.assertIsNotNone(ticket.resolved_at)


class TaskManagementWorkflowTests(WorkflowTestBase):
    def setUp(self):
        super().setUp()
        self.task = EmployeeTask.objects.create(
            employee=self.employee,
            title='Prepare monthly report',
            description='Compile attendance summary.',
            status=EmployeeTask.STATUS_ASSIGNED,
        )

    def test_employee_can_submit_task_for_review(self):
        self.auth(self.employee_token)
        response = self.client.post(
            '/api/employee/tasks/',
            {'task_id': self.task.id, 'reason': 'Report draft attached.'},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.task.refresh_from_db()
        self.assertEqual(self.task.status, EmployeeTask.STATUS_REVIEW)
        self.assertIn('Report draft', self.task.description)

    def test_employee_cannot_resubmit_completed_task(self):
        self.task.status = EmployeeTask.STATUS_COMPLETED
        self.task.save(update_fields=['status'])

        self.auth(self.employee_token)
        response = self.client.post(
            '/api/employee/tasks/',
            {'task_id': self.task.id, 'reason': 'Trying again.'},
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.task.refresh_from_db()
        self.assertEqual(self.task.status, EmployeeTask.STATUS_COMPLETED)

    def test_admin_can_list_tasks_by_status(self):
        EmployeeTask.objects.create(
            employee=self.other_employee,
            title='Follow up calls',
            status=EmployeeTask.STATUS_IN_PROGRESS,
        )

        self.auth(self.admin_token)
        response = self.client.get(
            '/api/admin/tasks/',
            {'status': EmployeeTask.STATUS_ASSIGNED},
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn('summary', response.data)
        self.assertTrue(
            any(task['id'] == self.task.id for task in response.data['tasks']),
        )


class EmployeeDeletionSafeguardTests(WorkflowTestBase):
    def setUp(self):
        super().setUp()
        self.delete_target = get_user_model().objects.create_user(
            username='wf_delete_target',
            password='Delete@123',
            email='wf_delete_target@healon.local',
        )
        UserProfile.objects.update_or_create(
            user=self.delete_target,
            defaults={'profile_photo_biometric': PHOTO_BIOMETRIC},
        )
        LeaveRequest.objects.create(
            employee=self.delete_target,
            leave_type='Casual Leave',
            from_date=self.leave_start,
            to_date=self.leave_start,
            status=LeaveRequest.STATUS_PENDING,
        )

    def test_admin_can_delete_other_employee(self):
        target_id = self.delete_target.id
        self.auth(self.admin_token)
        response = self.client.delete(f'/api/admin/employees/{target_id}/')

        self.assertEqual(response.status_code, 204)
        self.assertFalse(
            get_user_model().objects.filter(pk=target_id).exists(),
        )
        self.assertFalse(LeaveRequest.objects.filter(employee_id=target_id).exists())

    def test_staff_admin_cannot_delete_own_account(self):
        User = get_user_model()
        staff_admin = User.objects.create_user(
            username='wf_staff_admin',
            password='Staff@123',
            email='wf_staff_admin@healon.local',
            is_staff=True,
        )
        UserProfile.objects.update_or_create(
            user=staff_admin,
            defaults={
                'can_access_admin_dashboard': True,
                'profile_photo_biometric': PHOTO_BIOMETRIC,
            },
        )
        token = Token.objects.create(user=staff_admin)
        self.auth(token)
        response = self.client.delete(f'/api/admin/employees/{staff_admin.id}/')

        self.assertEqual(response.status_code, 400)
        self.assertIn('cannot delete your own', response.data['detail'].lower())
        self.assertTrue(User.objects.filter(pk=staff_admin.id).exists())

    def test_superuser_not_deletable_via_employee_delete_api(self):
        self.auth(self.admin_token)
        response = self.client.delete(f'/api/admin/employees/{self.admin.id}/')

        self.assertEqual(response.status_code, 404)
        self.assertTrue(
            get_user_model().objects.filter(pk=self.admin.id).exists(),
        )

    def test_employee_cannot_delete_employees(self):
        target_id = self.delete_target.id
        self.auth(self.employee_token)
        response = self.client.delete(f'/api/admin/employees/{target_id}/')

        self.assertEqual(response.status_code, 403)
        self.assertTrue(
            get_user_model().objects.filter(pk=target_id).exists(),
        )
