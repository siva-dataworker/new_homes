import jwt
import datetime
import uuid
import logging
from django.conf import settings

logger = logging.getLogger(__name__)

# JWT secret key — loaded from settings which reads from .env
# Will raise ImproperlyConfigured if JWT_SECRET_KEY is missing from .env
SECRET_KEY = settings.JWT_SECRET_KEY
ALGORITHM = 'HS256'

# ISSUE-37 FIX: Reduced token expiry from 7 days to 30 minutes
# Refresh tokens provide long-term access with revocation capability
ACCESS_TOKEN_EXPIRE_MINUTES = 30  # 30 minutes (was 7 days)
REFRESH_TOKEN_EXPIRE_DAYS = 30   # 30 days


def generate_access_token(user_data):
    """
    Generate JWT access token for user.
    Short-lived token (30 minutes) for API access.
    
    Args:
        user_data (dict): User information to encode in token
    Returns:
        str: JWT access token
    """
    payload = {
        'user_id': user_data.get('user_id'),
        'user_uid': user_data.get('user_uid'),
        'username': user_data.get('username'),
        'email': user_data.get('email'),
        'role': user_data.get('role'),
        'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
        'iat': datetime.datetime.utcnow(),
        'type': 'access'
    }

    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return token


def generate_refresh_token(user_id):
    """
    Generate JWT refresh token for user.
    Long-lived token (30 days) used to obtain new access tokens.
    
    Args:
        user_id (str): User ID
    Returns:
        tuple: (refresh_token, token_id) - token_id is stored in DB for revocation
    """
    token_id = str(uuid.uuid4())
    payload = {
        'user_id': user_id,
        'token_id': token_id,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
        'iat': datetime.datetime.utcnow(),
        'type': 'refresh'
    }
    
    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return token, token_id


def generate_token_pair(user_data):
    """
    Generate both access and refresh tokens.
    
    Args:
        user_data (dict): User information
    Returns:
        dict: {'access_token': str, 'refresh_token': str, 'refresh_token_id': str}
    """
    access_token = generate_access_token(user_data)
    refresh_token, refresh_token_id = generate_refresh_token(user_data.get('user_id'))
    
    return {
        'access_token': access_token,
        'refresh_token': refresh_token,
        'refresh_token_id': refresh_token_id,
        'expires_in': ACCESS_TOKEN_EXPIRE_MINUTES * 60  # seconds
    }


def decode_access_token(token):
    """
    Decode and verify JWT access token.
    Args:
        token (str): JWT access token
    Returns:
        dict: Decoded token payload or None if invalid/expired
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get('type') != 'access':
            logger.warning("Token is not an access token")
            return None
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("JWT token has expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.warning("Invalid JWT token: %s", str(e))
        return None


def decode_refresh_token(token):
    """
    Decode and verify JWT refresh token.
    Args:
        token (str): JWT refresh token
    Returns:
        dict: Decoded token payload or None if invalid/expired
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get('type') != 'refresh':
            logger.warning("Token is not a refresh token")
            return None
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("Refresh token has expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.warning("Invalid refresh token: %s", str(e))
        return None

