from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .career_serializers import (
    EmployeeExitRequestSerializer,
    EmployeeLeaveTypeSerializer,
    PublicJobApplySerializer,
    PublicJobOpeningSerializer,
)
from .hr_serializers import EmployeeDocumentReadSerializer
from .models import Candidate, EmployeeDocument, ExitRequest, JobOpening, LeaveRequest, LeaveType

User = get_user_model()


def open_job_queryset():
    return JobOpening.objects.filter(status=JobOpening.STATUS_OPEN).select_related(
        'department',
        'designation',
    )


class PublicJobOpeningListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        jobs = open_job_queryset()
        return Response({'jobs': PublicJobOpeningSerializer(jobs, many=True).data})


class PublicJobOpeningDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, slug):
        job = get_object_or_404(open_job_queryset(), public_slug=slug)
        return Response({'job': PublicJobOpeningSerializer(job).data})


class PublicJobApplyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request, slug):
        job = get_object_or_404(open_job_queryset(), public_slug=slug)
        serializer = PublicJobApplySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email']
        if Candidate.objects.filter(job_opening=job, email__iexact=email).exists():
            return Response(
                {'detail': 'An application with this email already exists for this job.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        candidate = serializer.save(job_opening=job, status=Candidate.STATUS_APPLIED)
        return Response(
            {
                'message': 'Application submitted successfully.',
                'application_id': candidate.id,
            },
            status=status.HTTP_201_CREATED,
        )


class EmployeeJobOpeningsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        jobs = open_job_queryset()
        return Response({'jobs': PublicJobOpeningSerializer(jobs, many=True).data})


class EmployeeExitRequestsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        exits = ExitRequest.objects.filter(employee=request.user).order_by('-created_at')
        return Response(
            {
                'exit_requests': EmployeeExitRequestSerializer(exits, many=True).data,
            }
        )

    def post(self, request):
        if ExitRequest.objects.filter(
            employee=request.user,
            status__in=[ExitRequest.STATUS_PENDING, ExitRequest.STATUS_APPROVED],
        ).exists():
            return Response(
                {'detail': 'You already have an active resignation request.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = EmployeeExitRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        exit_request = serializer.save(
            employee=request.user,
            status=ExitRequest.STATUS_PENDING,
        )
        return Response(
            {'exit_request': EmployeeExitRequestSerializer(exit_request).data},
            status=status.HTTP_201_CREATED,
        )


class EmployeeLeaveTypesView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        leave_types = LeaveType.objects.filter(is_active=True).order_by('name')
        leaves = LeaveRequest.objects.filter(employee=request.user)
        used_by_type = {}
        for leave in leaves.filter(status=LeaveRequest.STATUS_APPROVED):
            used_by_type[leave.leave_type] = used_by_type.get(leave.leave_type, 0) + leave.total_days

        payload = []
        for leave_type in leave_types:
            item = EmployeeLeaveTypeSerializer(leave_type).data
            used = used_by_type.get(leave_type.name, 0)
            item['used_days'] = used
            item['available_days'] = max(leave_type.annual_quota - used, 0)
            payload.append(item)

        return Response({'leave_types': payload})


class EmployeeDocumentsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        documents = EmployeeDocument.objects.filter(
            employee=request.user,
            is_archived=False,
        ).order_by('-created_at')
        return Response(
            {'documents': EmployeeDocumentReadSerializer(documents, many=True).data}
        )
