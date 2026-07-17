# OLD WORKING VIEWS - ViewSets for full CRUD operations
# This was the original working backend before Firebase integration

from rest_framework import viewsets, status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db import connection

from .models import (
    Role, User, Site, MaterialMaster, DailySiteReport,
    DailyLabourSummary, DailySalaryEntry, DailyMaterialBalance,
    MaterialBill, WorkActivity, Notification, Complaint,
    ComplaintAction, AuditLog, AdminRoleChangeLog
)
from .serializers import (
    RoleSerializer, UserSerializer, SiteSerializer, MaterialMasterSerializer,
    DailySiteReportSerializer, DailyLabourSummarySerializer, DailySalaryEntrySerializer,
    DailyMaterialBalanceSerializer, MaterialBillSerializer, WorkActivitySerializer,
    NotificationSerializer, ComplaintSerializer, ComplaintActionSerializer,
    AuditLogSerializer, AdminRoleChangeLogSerializer
)


# Health check endpoints
@api_view(['GET'])
def health_check(request):
    """Simple health check"""
    return Response({'status': 'healthy', 'service': 'Essential Homes API'})


@api_view(['GET'])
def database_health(request):
    """Database connection health check"""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        return Response({'status': 'healthy', 'database': 'connected'})
    except Exception as e:
        return Response(
            {'status': 'unhealthy', 'database': 'disconnected', 'error': str(e)},
            status=status.HTTP_503_SERVICE_UNAVAILABLE
        )


# ViewSets for full CRUD operations
class RoleViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for roles (read-only)"""
    queryset = Role.objects.all()
    serializer_class = RoleSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class UserViewSet(viewsets.ModelViewSet):
    """ViewSet for users"""
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class SiteViewSet(viewsets.ModelViewSet):
    """ViewSet for sites"""
    queryset = Site.objects.all()
    serializer_class = SiteSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class MaterialMasterViewSet(viewsets.ModelViewSet):
    """ViewSet for material master"""
    queryset = MaterialMaster.objects.all()
    serializer_class = MaterialMasterSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class DailySiteReportViewSet(viewsets.ModelViewSet):
    """ViewSet for daily site reports"""
    queryset = DailySiteReport.objects.all()
    serializer_class = DailySiteReportSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class DailyLabourSummaryViewSet(viewsets.ModelViewSet):
    """ViewSet for daily labour summary"""
    queryset = DailyLabourSummary.objects.all()
    serializer_class = DailyLabourSummarySerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class DailySalaryEntryViewSet(viewsets.ModelViewSet):
    """ViewSet for daily salary entries"""
    queryset = DailySalaryEntry.objects.all()
    serializer_class = DailySalaryEntrySerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class DailyMaterialBalanceViewSet(viewsets.ModelViewSet):
    """ViewSet for daily material balance"""
    queryset = DailyMaterialBalance.objects.all()
    serializer_class = DailyMaterialBalanceSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class MaterialBillViewSet(viewsets.ModelViewSet):
    """ViewSet for material bills"""
    queryset = MaterialBill.objects.all()
    serializer_class = MaterialBillSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class WorkActivityViewSet(viewsets.ModelViewSet):
    """ViewSet for work activities"""
    queryset = WorkActivity.objects.all()
    serializer_class = WorkActivitySerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class NotificationViewSet(viewsets.ModelViewSet):
    """ViewSet for notifications"""
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class ComplaintViewSet(viewsets.ModelViewSet):
    """ViewSet for complaints"""
    queryset = Complaint.objects.all()
    serializer_class = ComplaintSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class ComplaintActionViewSet(viewsets.ModelViewSet):
    """ViewSet for complaint actions"""
    queryset = ComplaintAction.objects.all()
    serializer_class = ComplaintActionSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for audit logs (read-only)"""
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication


class AdminRoleChangeLogViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for admin role change logs (read-only)"""
    queryset = AdminRoleChangeLog.objects.all()
    serializer_class = AdminRoleChangeLogSerializer
    permission_classes = [IsAuthenticated]  # ISSUE-30: Added authentication
