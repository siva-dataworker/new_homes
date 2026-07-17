"""
Refresh Token Management Views
Part of ISSUE-37 fix: JWT refresh token implementation

These endpoints handle token refresh and revocation.
"""

import logging
import uuid
from datetime import datetime, timedelta

from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from .database import execute_query, fetch_one, fetch_all
from .jwt_utils import (
    decode_refresh_token,
    generate_token_pair,
    REFRESH_TOKEN_EXPIRE_DAYS
)
from .authentication import JWTAuthentication

logger = logging.getLogger(__name__)


@api_view(['POST'])
@permission_classes([AllowAny])
def refresh_access_token(request):
    """
    Exchange a valid refresh token for a new access token.
    
    POST /api/auth/refresh/
    Body: {
        "refresh_token": "eyJ..."
    }
    
    Response: {
        "access_token": "eyJ...",
        "expires_in": 1800
    }
    """
    try:
        refresh_token = request.data.get('refresh_token')
        if not refresh_token:
            return Response(
                {'error': 'refresh_token is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Decode and validate refresh token
        payload = decode_refresh_token(refresh_token)
        if not payload:
            return Response(
                {'error': 'Invalid or expired refresh token'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        user_id = payload.get('user_id')
        token_id = payload.get('token_id')
        
        # Check if token exists and is not revoked
        token_record = fetch_one("""
            SELECT id, user_id, revoked, expires_at
            FROM refresh_tokens
            WHERE token_id = %s
        """, (token_id,))
        
        if not token_record:
            return Response(
                {'error': 'Refresh token not found'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        if token_record['revoked']:
            return Response(
                {'error': 'Refresh token has been revoked'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        if token_record['expires_at'] < datetime.now(token_record['expires_at'].tzinfo):
            return Response(
                {'error': 'Refresh token has expired'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Get user data for new access token
        user = fetch_one("""
            SELECT u.id, u.username, u.email, u.user_uid, r.role_name
            FROM users u
            LEFT JOIN roles r ON u.role_id = r.id
            WHERE u.id = %s AND u.status = 'APPROVED' AND u.is_active = TRUE
        """, (user_id,))
        
        if not user:
            return Response(
                {'error': 'User not found or inactive'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Generate new access token (refresh token remains valid)
        from .jwt_utils import generate_access_token, ACCESS_TOKEN_EXPIRE_MINUTES
        
        access_token = generate_access_token({
            'user_id': str(user['id']),
            'user_uid': user['user_uid'],
            'username': user['username'],
            'email': user['email'],
            'role': user['role_name']
        })
        
        return Response({
            'access_token': access_token,
            'expires_in': ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            'token_type': 'Bearer'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Token refresh failed: {str(e)}")
        return Response(
            {'error': 'Token refresh failed'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def logout(request):
    """
    Revoke the user's refresh tokens (logout).
    
    POST /api/auth/logout/
    Body: {
        "refresh_token": "eyJ..." (optional - if not provided, revokes all user tokens)
    }
    
    Response: {
        "message": "Logged out successfully"
    }
    """
    try:
        user_id = request.user.get('user_id')
        refresh_token = request.data.get('refresh_token')
        
        if refresh_token:
            # Revoke specific token
            payload = decode_refresh_token(refresh_token)
            if payload:
                token_id = payload.get('token_id')
                success = execute_query("""
                    UPDATE refresh_tokens
                    SET revoked = TRUE, revoked_at = %s
                    WHERE token_id = %s AND user_id = %s
                """, (datetime.utcnow(), token_id, user_id))
                
                if not success:
                    return Response(
                        {'error': 'Failed to revoke token'},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )
        else:
            # Revoke all user tokens
            success = execute_query("""
                UPDATE refresh_tokens
                SET revoked = TRUE, revoked_at = %s
                WHERE user_id = %s AND revoked = FALSE
            """, (datetime.utcnow(), user_id))
            
            if not success:
                return Response(
                    {'error': 'Failed to revoke tokens'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        
        return Response({
            'message': 'Logged out successfully'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Logout failed: {str(e)}")
        return Response(
            {'error': 'Logout failed'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def list_active_sessions(request):
    """
    List user's active refresh tokens (sessions).
    Admin only.
    
    GET /api/auth/sessions/
    
    Response: {
        "sessions": [
            {
                "id": "uuid",
                "created_at": "2026-07-18T...",
                "expires_at": "2026-08-17T...",
                "device_info": "Chrome on Windows",
                "ip_address": "192.168.1.1"
            }
        ]
    }
    """
    try:
        if request.user.get('role') != 'Admin':
            user_id = request.user.get('user_id')
        else:
            # Admin can view any user's sessions
            user_id = request.query_params.get('user_id', request.user.get('user_id'))
        
        sessions = fetch_all("""
            SELECT id, created_at, expires_at, device_info, ip_address
            FROM refresh_tokens
            WHERE user_id = %s AND revoked = FALSE
            ORDER BY created_at DESC
        """, (user_id,))
        
        return Response({
            'sessions': [
                {
                    'id': str(s['id']),
                    'created_at': s['created_at'].isoformat(),
                    'expires_at': s['expires_at'].isoformat(),
                    'device_info': s['device_info'],
                    'ip_address': str(s['ip_address']) if s['ip_address'] else None
                }
                for s in sessions
            ]
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Failed to list sessions: {str(e)}")
        return Response(
            {'error': 'Failed to retrieve sessions'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def revoke_session(request, session_id):
    """
    Revoke a specific session (Admin only or own session).
    
    POST /api/auth/sessions/<session_id>/revoke/
    
    Response: {
        "message": "Session revoked successfully"
    }
    """
    try:
        user_id = request.user.get('user_id')
        is_admin = request.user.get('role') == 'Admin'
        
        # Verify ownership or admin
        session = fetch_one("""
            SELECT user_id FROM refresh_tokens WHERE id = %s
        """, (session_id,))
        
        if not session:
            return Response(
                {'error': 'Session not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        if not is_admin and str(session['user_id']) != user_id:
            return Response(
                {'error': 'Permission denied'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Revoke the session
        success = execute_query("""
            UPDATE refresh_tokens
            SET revoked = TRUE, revoked_at = %s
            WHERE id = %s
        """, (datetime.utcnow(), session_id))
        
        if not success:
            return Response(
                {'error': 'Failed to revoke session'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        return Response({
            'message': 'Session revoked successfully'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Failed to revoke session: {str(e)}")
        return Response(
            {'error': 'Failed to revoke session'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
