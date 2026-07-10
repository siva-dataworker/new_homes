import jwt
import datetime
import logging
from django.conf import settings

logger = logging.getLogger(__name__)

# JWT secret key — loaded from settings which reads from .env
# Will raise ImproperlyConfigured if JWT_SECRET_KEY is missing from .env
SECRET_KEY = settings.JWT_SECRET_KEY
ALGORITHM = 'HS256'
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days


def generate_access_token(user_data):
    """
    Generate JWT access token for user.
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
        'iat': datetime.datetime.utcnow()
    }

    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return token


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
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("JWT token has expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.warning("Invalid JWT token: %s", str(e))
        return None
