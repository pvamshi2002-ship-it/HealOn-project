from django.contrib.auth import get_user_model
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .hr_serializers import (
    AdminLeaveRequestSerializer,
    CandidateSerializer,
    DepartmentSerializer,
    DesignationSerializer,
    EmployeeDocumentSerializer,
    ExitRequestSerializer,
    JobOpeningSerializer,
    LeaveTypeSerializer,
    PerformanceReviewSerializer,
    ShiftAssignmentSerializer,
    ShiftSerializer,
)
from .models import (
    Attendance,
    AttendanceRegularization,
    Candidate,
    Department,
    Designation,
    EmployeeDocument,
    EmployeeTask,
    ExitRequest,
    HelpdeskTicket,
    JobOpening,
    LeaveRequest,
    LeaveType,
    PerformanceReview,
    ReimbursementRequest,
    SalaryRecord,
    Shift,
    ShiftAssignment,
    UserProfile,
)
from .views import admin_managed_users, user_can_manage_people

User = get_user_model()


def _require_hr_access(request):
    if not user_can_manage_people(request.user):
        raise PermissionDenied


class HrCrudListCreateView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]
    model = None
    serializer_class = None
    list_key = None
    select_related = ()
    prefetch_related = ()
    default_ordering = ('-id',)

    def get_queryset(self):
        qs = self.model.objects.all()
        if self.select_related:
            qs = qs.select_related(*self.select_related)
        if self.prefetch_related:
            qs = qs.prefetch_related(*self.prefetch_related)
        active = self.request.query_params.get('active')
        if active in {'true', 'false'} and hasattr(self.model, 'is_active'):
            qs = qs.filter(is_active=(active == 'true'))
        search = (self.request.query_params.get('q') or '').strip()
        if search:
            if hasattr(self.model, 'name'):
                qs = qs.filter(name__icontains=search)
            elif hasattr(self.model, 'title'):
                qs = qs.filter(title__icontains=search)
        return qs.order_by(*self.default_ordering)

    def get(self, request):
        _require_hr_access(request)
        items = self.get_queryset()[:500]
        return Response(
            {self.list_key: self.serializer_class(items, many=True).data}
        )

    def post(self, request):
        _require_hr_access(request)
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        item = serializer.save()
        return Response(
            {self.list_key[:-1]: self.serializer_class(item).data},
            status=status.HTTP_201_CREATED,
        )


class HrCrudDetailView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]
    model = None
    serializer_class = None
    list_key = None

    def get_object(self, pk):
        return get_object_or_404(self.model, pk=pk)

    def get(self, request, pk):
        _require_hr_access(request)
        item = self.get_object(pk)
        return Response({self.list_key[:-1]: self.serializer_class(item).data})

    def patch(self, request, pk):
        _require_hr_access(request)
        item = self.get_object(pk)
        serializer = self.serializer_class(item, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        item = serializer.save()
        return Response({self.list_key[:-1]: self.serializer_class(item).data})

    def delete(self, request, pk):
        _require_hr_access(request)
        item = self.get_object(pk)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class HrDepartmentListCreateView(HrCrudListCreateView):
    model = Department
    serializer_class = DepartmentSerializer
    list_key = 'departments'
    select_related = ('head',)
    default_ordering = ('name',)


class HrDepartmentDetailView(HrCrudDetailView):
    model = Department
    serializer_class = DepartmentSerializer
    list_key = 'departments'


class HrDesignationListCreateView(HrCrudListCreateView):
    model = Designation
    serializer_class = DesignationSerializer
    list_key = 'designations'
    select_related = ('department',)
    default_ordering = ('name',)


class HrDesignationDetailView(HrCrudDetailView):
    model = Designation
    serializer_class = DesignationSerializer
    list_key = 'designations'


class HrShiftListCreateView(HrCrudListCreateView):
    model = Shift
    serializer_class = ShiftSerializer
    list_key = 'shifts'
    default_ordering = ('name',)


class HrShiftDetailView(HrCrudDetailView):
    model = Shift
    serializer_class = ShiftSerializer
    list_key = 'shifts'


class HrShiftAssignmentListCreateView(HrCrudListCreateView):
    model = ShiftAssignment
    serializer_class = ShiftAssignmentSerializer
    list_key = 'shift_assignments'
    select_related = ('employee', 'shift')
    default_ordering = ('-effective_from',)

    def get_queryset(self):
        qs = super().get_queryset()
        employee_id = self.request.query_params.get('employee_id')
        if employee_id:
            qs = qs.filter(employee_id=employee_id)
        return qs


class HrShiftAssignmentDetailView(HrCrudDetailView):
    model = ShiftAssignment
    serializer_class = ShiftAssignmentSerializer
    list_key = 'shift_assignments'


class HrLeaveTypeListCreateView(HrCrudListCreateView):
    model = LeaveType
    serializer_class = LeaveTypeSerializer
    list_key = 'leave_types'
    default_ordering = ('name',)


class HrLeaveTypeDetailView(HrCrudDetailView):
    model = LeaveType
    serializer_class = LeaveTypeSerializer
    list_key = 'leave_types'


class HrAdminLeaveListCreateView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        _require_hr_access(request)
        leaves = LeaveRequest.objects.select_related('employee').order_by('-applied_at')
        status_filter = request.query_params.get('status')
        if status_filter:
            leaves = leaves.filter(status=status_filter)
        employee_id = request.query_params.get('employee_id')
        if employee_id:
            leaves = leaves.filter(employee_id=employee_id)
        return Response(
            {'leaves': AdminLeaveRequestSerializer(leaves[:500], many=True).data}
        )

    def post(self, request):
        _require_hr_access(request)
        employee = get_object_or_404(
            User,
            pk=request.data.get('employee'),
            is_superuser=False,
        )
        serializer = AdminLeaveRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        leave = serializer.save(employee=employee)
        return Response(
            {'leave': AdminLeaveRequestSerializer(leave).data},
            status=status.HTTP_201_CREATED,
        )


class HrAdminLeaveDetailView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        _require_hr_access(request)
        leave = get_object_or_404(LeaveRequest.objects.select_related('employee'), pk=pk)
        return Response({'leave': AdminLeaveRequestSerializer(leave).data})

    def patch(self, request, pk):
        _require_hr_access(request)
        leave = get_object_or_404(LeaveRequest, pk=pk)
        if 'employee' in request.data:
            employee = get_object_or_404(
                User,
                pk=request.data['employee'],
                is_superuser=False,
            )
            leave.employee = employee
        serializer = AdminLeaveRequestSerializer(leave, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        leave = serializer.save()
        return Response({'leave': AdminLeaveRequestSerializer(leave).data})

    def delete(self, request, pk):
        _require_hr_access(request)
        leave = get_object_or_404(LeaveRequest, pk=pk)
        leave.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class HrJobOpeningListCreateView(HrCrudListCreateView):
    model = JobOpening
    serializer_class = JobOpeningSerializer
    list_key = 'job_openings'
    select_related = ('department', 'designation')
    default_ordering = ('-posted_at',)

    def get_queryset(self):
        qs = super().get_queryset()
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs

    def post(self, request):
        _require_hr_access(request)
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        item = serializer.save()
        return Response(
            {self.list_key[:-1]: self.serializer_class(item).data},
            status=status.HTTP_201_CREATED,
        )


class HrJobOpeningDetailView(HrCrudDetailView):
    model = JobOpening
    serializer_class = JobOpeningSerializer
    list_key = 'job_openings'

    def patch(self, request, pk):
        _require_hr_access(request)
        item = self.get_object(pk)
        serializer = self.serializer_class(item, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data.get('status')
        if new_status == JobOpening.STATUS_CLOSED and not item.closed_at:
            item = serializer.save(closed_at=timezone.now())
        else:
            item = serializer.save()
        return Response({self.list_key[:-1]: self.serializer_class(item).data})


class HrCandidateListCreateView(HrCrudListCreateView):
    model = Candidate
    serializer_class = CandidateSerializer
    list_key = 'candidates'
    select_related = ('job_opening',)
    default_ordering = ('-applied_at',)

    def get_queryset(self):
        qs = super().get_queryset()
        job_opening_id = self.request.query_params.get('job_opening_id')
        if job_opening_id:
            qs = qs.filter(job_opening_id=job_opening_id)
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        search = (self.request.query_params.get('q') or '').strip()
        if search:
            qs = qs.filter(
                Q(full_name__icontains=search)
                | Q(email__icontains=search)
                | Q(phone__icontains=search)
                | Q(experience__icontains=search)
                | Q(skills__icontains=search)
            )
        return qs

    def post(self, request):
        _require_hr_access(request)
        return Response(
            {'detail': 'Candidates are created through job applications only.'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED,
        )


class HrCandidateDetailView(HrCrudDetailView):
    model = Candidate
    serializer_class = CandidateSerializer
    list_key = 'candidates'


class HrExitRequestListCreateView(HrCrudListCreateView):
    model = ExitRequest
    serializer_class = ExitRequestSerializer
    list_key = 'exit_requests'
    select_related = ('employee',)
    default_ordering = ('-created_at',)

    def get_queryset(self):
        qs = super().get_queryset()
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs

    def post(self, request):
        _require_hr_access(request)
        employee = get_object_or_404(
            User,
            pk=request.data.get('employee'),
            is_superuser=False,
        )
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        item = serializer.save(employee=employee)
        return Response(
            {self.list_key[:-1]: self.serializer_class(item).data},
            status=status.HTTP_201_CREATED,
        )


class HrExitRequestDetailView(HrCrudDetailView):
    model = ExitRequest
    serializer_class = ExitRequestSerializer
    list_key = 'exit_requests'

    def patch(self, request, pk):
        _require_hr_access(request)
        item = self.get_object(pk)
        serializer = self.serializer_class(item, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        item = serializer.save()
        if item.status == ExitRequest.STATUS_COMPLETED and item.employee.is_active:
            item.employee.is_active = False
            item.employee.save(update_fields=['is_active'])
        return Response({self.list_key[:-1]: self.serializer_class(item).data})


class HrEmployeeDocumentListCreateView(HrCrudListCreateView):
    model = EmployeeDocument
    serializer_class = EmployeeDocumentSerializer
    list_key = 'documents'
    select_related = ('employee', 'uploaded_by')
    default_ordering = ('-created_at',)

    def get_queryset(self):
        qs = super().get_queryset()
        employee_id = self.request.query_params.get('employee_id')
        if employee_id:
            qs = qs.filter(employee_id=employee_id)
        category = self.request.query_params.get('category')
        if category:
            qs = qs.filter(category=category)
        if self.request.query_params.get('include_archived') != 'true':
            qs = qs.filter(is_archived=False)
        return qs

    def post(self, request):
        _require_hr_access(request)
        employee = get_object_or_404(
            User,
            pk=request.data.get('employee'),
            is_superuser=False,
        )
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        item = serializer.save(employee=employee, uploaded_by=request.user)
        return Response(
            {self.list_key[:-1]: self.serializer_class(item).data},
            status=status.HTTP_201_CREATED,
        )


class HrEmployeeDocumentDetailView(HrCrudDetailView):
    model = EmployeeDocument
    serializer_class = EmployeeDocumentSerializer
    list_key = 'documents'

    def delete(self, request, pk):
        _require_hr_access(request)
        item = self.get_object(pk)
        item.is_archived = True
        item.save(update_fields=['is_archived', 'updated_at'])
        return Response(
            {self.list_key[:-1]: self.serializer_class(item).data},
            status=status.HTTP_200_OK,
        )


class HrPerformanceReviewListCreateView(HrCrudListCreateView):
    model = PerformanceReview
    serializer_class = PerformanceReviewSerializer
    list_key = 'performance_reviews'
    select_related = ('employee', 'reviewer')
    default_ordering = ('-period_end',)

    def get_queryset(self):
        qs = super().get_queryset()
        employee_id = self.request.query_params.get('employee_id')
        if employee_id:
            qs = qs.filter(employee_id=employee_id)
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs

    def post(self, request):
        _require_hr_access(request)
        employee = get_object_or_404(
            User,
            pk=request.data.get('employee'),
            is_superuser=False,
        )
        reviewer_id = request.data.get('reviewer')
        reviewer = request.user
        if reviewer_id:
            reviewer = get_object_or_404(User, pk=reviewer_id, is_superuser=False)
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        item = serializer.save(employee=employee, reviewer=reviewer)
        return Response(
            {self.list_key[:-1]: self.serializer_class(item).data},
            status=status.HTTP_201_CREATED,
        )


class HrPerformanceReviewDetailView(HrCrudDetailView):
    model = PerformanceReview
    serializer_class = PerformanceReviewSerializer
    list_key = 'performance_reviews'


class HrReportsSummaryView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        _require_hr_access(request)
        employees = admin_managed_users()
        today = timezone.localdate()
        return Response(
            {
                'summary': {
                    'total_employees': employees.count(),
                    'active_employees': employees.filter(is_active=True).count(),
                    'departments': Department.objects.filter(is_active=True).count(),
                    'designations': Designation.objects.filter(is_active=True).count(),
                    'shifts': Shift.objects.filter(is_active=True).count(),
                    'pending_leaves': LeaveRequest.objects.filter(
                        status=LeaveRequest.STATUS_PENDING
                    ).count(),
                    'open_jobs': JobOpening.objects.filter(
                        status=JobOpening.STATUS_OPEN
                    ).count(),
                    'active_candidates': Candidate.objects.exclude(
                        status=Candidate.STATUS_REJECTED
                    ).exclude(status=Candidate.STATUS_SELECTED).count(),
                    'pending_exits': ExitRequest.objects.filter(
                        status=ExitRequest.STATUS_PENDING
                    ).count(),
                    'documents': EmployeeDocument.objects.count(),
                    'performance_reviews': PerformanceReview.objects.count(),
                    'open_helpdesk': HelpdeskTicket.objects.filter(
                        status__in={
                            HelpdeskTicket.STATUS_OPEN,
                            HelpdeskTicket.STATUS_IN_PROGRESS,
                        }
                    ).count(),
                    'pending_regularizations': AttendanceRegularization.objects.filter(
                        status=AttendanceRegularization.STATUS_PENDING
                    ).count(),
                    'present_today': Attendance.objects.filter(
                        event_type=Attendance.CHECK_IN,
                        timestamp__date=today,
                    )
                    .values('user_id')
                    .distinct()
                    .count(),
                },
                'reports': {
                    'leave_by_status': list(
                        LeaveRequest.objects.values('status')
                        .annotate(count=Count('id'))
                        .order_by('status')
                    ),
                    'department_headcount': list(
                        UserProfile.objects.exclude(department='')
                        .values('department')
                        .annotate(count=Count('id'))
                        .order_by('-count')[:20]
                    ),
                    'recruitment_pipeline': list(
                        Candidate.objects.values('status')
                        .annotate(count=Count('id'))
                        .order_by('status')
                    ),
                    'performance_by_rating': list(
                        PerformanceReview.objects.values('rating')
                        .annotate(count=Count('id'))
                        .order_by('rating')
                    ),
                    'payroll_records': SalaryRecord.objects.count(),
                    'reimbursements': ReimbursementRequest.objects.count(),
                    'tasks': EmployeeTask.objects.count(),
                },
            }
        )
