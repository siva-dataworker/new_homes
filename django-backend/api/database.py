import logging
import traceback

import psycopg
from django.conf import settings

logger = logging.getLogger(__name__)


def get_db_connection():
    """Get database connection to Supabase PostgreSQL with UTF-8 encoding."""
    conn = psycopg.connect(
        host=settings.DATABASES['default']['HOST'],
        port=settings.DATABASES['default']['PORT'],
        dbname=settings.DATABASES['default']['NAME'],
        user=settings.DATABASES['default']['USER'],
        password=settings.DATABASES['default']['PASSWORD'],
        sslmode='require',
        client_encoding='UTF8',
    )
    conn.execute("SET CLIENT_ENCODING TO 'UTF8'")
    return conn


# ── Legacy Firebase-era helpers (kept for backward compat with old views) ────

def get_user_by_uid(user_uid):
    """Get user from database by UID."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT user_id, user_uid, full_name, email, phone,
                           role_id, role_locked, is_active
                    FROM users
                    WHERE user_uid = %s
                """, (user_uid,))
                row = cur.fetchone()
                if row:
                    return {
                        'user_id':    row[0],
                        'user_uid':   row[1],
                        'full_name':  row[2],
                        'email':      row[3],
                        'phone':      row[4],
                        'role_id':    row[5],
                        'role_locked': row[6],
                        'is_active':  row[7],
                    }
                return None
    except Exception as e:
        logger.error("Error fetching user by uid: %s", e)
        return None


def create_user(user_uid, email, full_name):
    """Create new user in database."""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO users
                        (user_uid, email, full_name, phone, role_id, role_locked, is_active)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING user_id, user_uid, full_name, email, phone,
                              role_id, role_locked, is_active
                """, (user_uid, email, full_name, '', 2, False, True))
                conn.commit()
                row = cur.fetchone()
                if row:
                    return {
                        'user_id':    row[0],
                        'user_uid':   row[1],
                        'full_name':  row[2],
                        'email':      row[3],
                        'phone':      row[4],
                        'role_id':    row[5],
                        'role_locked': row[6],
                        'is_active':  row[7],
                    }
                return None
    except Exception as e:
        logger.error("Error creating user: %s", e)
        return None


def update_user_profile(user_uid, full_name=None, phone=None):
    """Update user profile by UID."""
    try:
        updates, params = [], []
        if full_name is not None:
            updates.append("full_name = %s")
            params.append(full_name)
        if phone is not None:
            updates.append("phone = %s")
            params.append(phone)
        if not updates:
            return True
        params.append(user_uid)
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"UPDATE users SET {', '.join(updates)} WHERE user_uid = %s",
                    params
                )
                conn.commit()
                return cur.rowcount > 0
    except Exception as e:
        logger.error("Error updating user profile: %s", e)
        return False


def update_user_profile_by_email(email, full_name=None, phone=None):
    """Update user profile using email as identifier (fallback for old JWT tokens)."""
    try:
        updates, params = [], []
        if full_name is not None:
            updates.append("full_name = %s")
            params.append(full_name)
        if phone is not None:
            updates.append("phone = %s")
            params.append(phone)
        if not updates:
            return True
        params.append(email)
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"UPDATE users SET {', '.join(updates)} WHERE email = %s",
                    params
                )
                conn.commit()
                return cur.rowcount > 0
    except Exception as e:
        logger.error("Error updating user by email: %s", e)
        return False


def get_role_name(role_id):
    """Get role name from role_id (legacy helper)."""
    role_map = {
        1: 'Admin',
        2: 'Supervisor',
        3: 'Site Engineer',
        4: 'Junior Accountant',
    }
    return role_map.get(role_id, 'Unknown')


# ── Generic helpers used by Strategy 2 views ─────────────────────────────────

def execute_query(query, params=None):
    """
    Execute a write query (INSERT / UPDATE / DELETE).

    Returns:
        True  — query executed and committed successfully
        False — exception occurred (caller should treat as failure and return 500)

    Issue-13 fix: callers must check the return value and NOT return HTTP 200
    on False. All admin views were updated in Issue-03/04 to do this correctly.
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params or ())
                conn.commit()
                return True
    except Exception as e:
        logger.error("execute_query failed: %s\n%s", e, traceback.format_exc())
        return False


def fetch_one(query, params=None):
    """
    Fetch a single row and return it as a dict, or None if not found.

    Issue-21 fix: removed flush=True print() — use logger.debug() if tracing
    is needed during development.
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params or ())
                row = cur.fetchone()
                if row:
                    columns = [desc[0] for desc in cur.description]
                    return dict(zip(columns, row))
                return None
    except Exception as e:
        logger.error("fetch_one failed: %s", e)
        return None


def fetch_all(query, params=None):
    """
    Fetch all rows and return a list of dicts.

    Issue-21 fix: removed flush=True print() on every query.
    Each print with flush=True forced a kernel write() syscall, degrading
    performance under load. Use logger.debug() if query tracing is needed.
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params or ())
                rows = cur.fetchall()
                if rows:
                    columns = [desc[0] for desc in cur.description]
                    return [dict(zip(columns, row)) for row in rows]
                return []
    except Exception as e:
        logger.error("fetch_all failed: %s\n%s", e, traceback.format_exc())
        return []

# ── Pagination Helpers ────────────────────────────────────────────────────────
# ISSUE-19 fix: Pagination support for list endpoints

from rest_framework.response import Response

def paginate_query(query, params=None, limit=20, offset=0):
    """
    Add pagination to a query and return paginated results.
    
    Args:
        query: Original SELECT query (without LIMIT/OFFSET)
        params: Query parameters
        limit: Number of rows per page (default 20)
        offset: Number of rows to skip (default 0)
    
    Returns:
        tuple: (results_list, total_count, has_more)
    """
    # Get total count (remove ORDER BY for count query)
    count_query = f"SELECT COUNT(*) FROM ({query}) as subquery"
    try:
        total = fetch_one(count_query, params)
        total_count = total['count'] if total else 0
    except Exception as e:
        logger.error("paginate_query count failed: %s", e)
        total_count = 0
    
    # Add pagination to original query
    paginated_query = f"{query} LIMIT %s OFFSET %s"
    paginated_params = (params or ()) + (limit, offset)
    
    results = fetch_all(paginated_query, paginated_params)
    has_more = len(results) == limit and (offset + limit) < total_count
    
    return results, total_count, has_more


def get_pagination_info(total_count, limit, offset):
    """
    Generate pagination metadata.
    
    Args:
        total_count: Total number of items
        limit: Items per page
        offset: Current offset
    
    Returns:
        dict: Pagination metadata
    """
    page = (offset // limit) + 1
    total_pages = (total_count + limit - 1) // limit if total_count > 0 else 1
    
    return {
        'current_page': page,
        'per_page': limit,
        'total_items': total_count,
        'total_pages': total_pages,
        'has_next': offset + limit < total_count,
        'has_prev': offset > 0,
        'next_offset': offset + limit if offset + limit < total_count else None,
        'prev_offset': offset - limit if offset > 0 else None
    }
