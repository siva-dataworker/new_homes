import logging
import uuid
from datetime import datetime

from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from .database import get_db_connection
from .authentication import JWTAuthentication

logger = logging.getLogger(__name__)

# ── helpers ──────────────────────────────────────────────────────────────────

def _is_admin(request):
    """
    Role check using JWT payload only (Strategy 2).
    Consistent with every other view in the project.
    """
    return request.user.get('role') == 'Admin'


def _admin_required(request):
    """Return a 403 Response if caller is not Admin, else None."""
    if not _is_admin(request):
        return Response(
            {'error': 'Admin access required'},
            status=status.HTTP_403_FORBIDDEN
        )
    return None


# ── views ─────────────────────────────────────────────────────────────────────

@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def create_late_entry_notification(request):
    """Create a notification for late entry."""
    try:
        data = request.data
        site_id    = data.get('site_id')
        entry_type = data.get('entry_type')
        message    = data.get('message')
        actual_time = data.get('actual_time')

        if not all([site_id, entry_type, message, actual_time]):
            return Response(
                {'error': 'Missing required fields: site_id, entry_type, message, actual_time'},
                status=status.HTTP_400_BAD_REQUEST
            )

        supervisor_id = request.user.get('user_id')

        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT full_name FROM users WHERE id = %s",
                    (supervisor_id,)
                )
                row = cursor.fetchone()
                supervisor_name = row[0] if row else 'Unknown'

                cursor.execute(
                    "SELECT site_name FROM sites WHERE id = %s",
                    (site_id,)
                )
                row = cursor.fetchone()
                site_name = row[0] if row else 'Unknown Site'

                notification_id = str(uuid.uuid4())
                cursor.execute("""
                    INSERT INTO notifications (
                        id, site_id, entry_type, message, actual_time,
                        supervisor_id, supervisor_name, site_name
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, created_at
                """, (
                    notification_id, site_id, entry_type, message, actual_time,
                    supervisor_id, supervisor_name, site_name
                ))
                result = cursor.fetchone()

                cursor.execute("SELECT id FROM users WHERE role_id = 1")
                admin_ids = [str(row[0]) for row in cursor.fetchall()]

                conn.commit()

        return Response({
            'success': True,
            'notification_id': str(result[0]),
            'created_at': result[1].isoformat(),
            'sent_to': admin_ids
        }, status=status.HTTP_201_CREATED)

    except Exception as e:
        logger.error("Error creating notification: %s", e)
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_notifications(request):
    """Get all notifications (Admin only)."""
    denied = _admin_required(request)
    if denied:
        return denied

    try:
        is_read_param = request.GET.get('is_read')
        limit  = int(request.GET.get('limit', 50))
        offset = int(request.GET.get('offset', 0))

        query = """
            SELECT
                n.id, n.site_id, n.entry_type, n.message, n.actual_time,
                n.created_at, n.is_read, n.read_at,
                n.supervisor_id, n.supervisor_name, n.site_name
            FROM notifications n
            WHERE 1=1
        """
        params = []

        if is_read_param is not None:
            query += " AND n.is_read = %s"
            params.append(is_read_param == 'true')

        query += " ORDER BY n.created_at DESC LIMIT %s OFFSET %s"
        params.extend([limit, offset])

        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(query, params)
                notifications = cursor.fetchall()

                count_query  = "SELECT COUNT(*) FROM notifications WHERE 1=1"
                count_params = []
                if is_read_param is not None:
                    count_query += " AND is_read = %s"
                    count_params.append(is_read_param == 'true')
                cursor.execute(count_query, count_params)
                total_count = cursor.fetchone()[0]

                cursor.execute(
                    "SELECT COUNT(*) FROM notifications WHERE is_read = FALSE"
                )
                unread_count = cursor.fetchone()[0]

        notifications_list = [
            {
                'id':              str(n[0]),
                'site_id':         str(n[1]),
                'entry_type':      n[2],
                'message':         n[3],
                'actual_time':     n[4].isoformat() if n[4] else None,
                'created_at':      n[5].isoformat() if n[5] else None,
                'is_read':         n[6],
                'read_at':         n[7].isoformat() if n[7] else None,
                'supervisor_id':   str(n[8]) if n[8] else None,
                'supervisor_name': n[9],
                'site_name':       n[10],
            }
            for n in notifications
        ]

        return Response({
            'success':      True,
            'notifications': notifications_list,
            'total':        total_count,
            'unread_count': unread_count,
        })

    except Exception as e:
        logger.error("Error fetching notifications: %s", e)
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def mark_notification_read(request, notification_id):
    """Mark a single notification as read (Admin only)."""
    denied = _admin_required(request)
    if denied:
        return denied

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    UPDATE notifications
                    SET is_read = TRUE, read_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                    RETURNING id
                """, (notification_id,))
                result = cursor.fetchone()
                conn.commit()

        if not result:
            return Response(
                {'error': 'Notification not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        return Response({'success': True, 'message': 'Notification marked as read'})

    except Exception as e:
        logger.error("Error marking notification as read: %s", e)
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def mark_all_notifications_read(request):
    """Mark all notifications as read (Admin only)."""
    denied = _admin_required(request)
    if denied:
        return denied

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    UPDATE notifications
                    SET is_read = TRUE, read_at = CURRENT_TIMESTAMP
                    WHERE is_read = FALSE
                """)
                updated_count = cursor.rowcount
                conn.commit()

        return Response({
            'success': True,
            'message': f'{updated_count} notifications marked as read'
        })

    except Exception as e:
        logger.error("Error marking all notifications as read: %s", e)
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
