#!/usr/bin/env python3
"""
Database Performance Optimization Migration Script
Applies critical indexes and maintenance tasks to Supabase PostgreSQL

Date: July 18, 2026
Expected Time: 10-30 seconds
Expected Impact: 10-100x performance improvement
"""

import os
import sys
import time
from pathlib import Path
import django

# Setup Django environment to load settings
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

import psycopg
from django.conf import settings

# Color codes for terminal output
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
BLUE = '\033[94m'
RESET = '\033[0m'
BOLD = '\033[1m'


def print_header(message):
    """Print a formatted header."""
    print(f"\n{BLUE}{BOLD}{'='*60}{RESET}")
    print(f"{BLUE}{BOLD}{message}{RESET}")
    print(f"{BLUE}{BOLD}{'='*60}{RESET}\n")


def print_success(message):
    """Print a success message."""
    print(f"{GREEN}✓ {message}{RESET}")


def print_warning(message):
    """Print a warning message."""
    print(f"{YELLOW}⚠ {message}{RESET}")


def print_error(message):
    """Print an error message."""
    print(f"{RED}✗ {message}{RESET}")


def print_info(message):
    """Print an info message."""
    print(f"{BLUE}ℹ {message}{RESET}")


def get_db_connection():
    """Get database connection to Supabase PostgreSQL."""
    try:
        conn = psycopg.connect(
            host=settings.DATABASES['default']['HOST'],
            port=settings.DATABASES['default']['PORT'],
            dbname=settings.DATABASES['default']['NAME'],
            user=settings.DATABASES['default']['USER'],
            password=settings.DATABASES['default']['PASSWORD'],
            sslmode='require',
            client_encoding='UTF8',
            autocommit=True  # Required for VACUUM to work
        )
        return conn
    except Exception as e:
        print_error(f"Failed to connect to database: {e}")
        sys.exit(1)


def execute_sql(conn, sql, description):
    """Execute SQL and return success status."""
    try:
        start_time = time.time()
        with conn.cursor() as cur:
            cur.execute(sql)
            rows_affected = cur.rowcount if cur.rowcount >= 0 else 0
        elapsed = time.time() - start_time
        print_success(f"{description} ({elapsed:.2f}s, {rows_affected} rows)")
        return True
    except Exception as e:
        # Check if it's a harmless error (index already exists, etc.)
        error_msg = str(e).lower()
        if 'already exists' in error_msg or 'does not exist' in error_msg:
            print_warning(f"{description} - Already handled: {e}")
            return True
        else:
            print_error(f"{description} - FAILED: {e}")
            return False


def main():
    """Run the performance optimization migration."""
    print_header("🚀 Database Performance Optimization")
    
    print_info("Database: construction_site (Supabase PostgreSQL)")
    print_info("Changes: 4 new indexes, 6 removed indexes, maintenance tasks")
    print_info("Expected Impact: 10-100x performance improvement\n")
    
    # Auto-confirm - remove interactive prompt
    print_info("Starting optimization...\n")
    
    print_info("\nConnecting to database...")
    conn = get_db_connection()
    print_success("Connected successfully!\n")
    
    success_count = 0
    total_steps = 0
    
    # ============================================
    # STEP 1: CREATE CRITICAL INDEXES
    # ============================================
    print_header("STEP 1: Creating Critical Indexes")
    
    indexes_to_create = [
        (
            "CREATE INDEX IF NOT EXISTS idx_users_email_lookup ON users(email)",
            "User email index (100x faster login)"
        ),
        (
            "DROP INDEX IF EXISTS idx_notifications_supervisor_unread",
            "Drop old notifications index (if exists)"
        ),
        (
            """CREATE INDEX idx_notifications_supervisor_unread 
               ON notifications(supervisor_id, is_read, created_at DESC)
               WHERE is_read = FALSE""",
            "Notifications composite index (10x faster)"
        ),
        (
            "CREATE INDEX IF NOT EXISTS idx_labour_entries_site_id ON labour_entries(site_id)",
            "Labour entries site_id index (10x faster JOINs)"
        ),
        (
            "CREATE INDEX IF NOT EXISTS idx_labour_entries_supervisor_id ON labour_entries(supervisor_id)",
            "Labour entries supervisor_id index (10x faster filters)"
        ),
    ]
    
    for sql, description in indexes_to_create:
        total_steps += 1
        if execute_sql(conn, sql, description):
            success_count += 1
        time.sleep(0.1)  # Small delay between operations
    
    # ============================================
    # STEP 2: MAINTENANCE TASKS
    # ============================================
    print_header("STEP 2: Running Maintenance Tasks")
    
    maintenance_tasks = [
        ("VACUUM ANALYZE users", "Vacuum users table"),
        ("VACUUM ANALYZE notifications", "Vacuum notifications table"),
        ("VACUUM ANALYZE labour_cost_calculation", "Vacuum labour_cost_calculation table"),
        ("ANALYZE users", "Update statistics for users"),
        ("ANALYZE labour_entries", "Update statistics for labour_entries"),
        ("ANALYZE notifications", "Update statistics for notifications"),
        ("ANALYZE sites", "Update statistics for sites"),
    ]
    
    for sql, description in maintenance_tasks:
        total_steps += 1
        if execute_sql(conn, sql, description):
            success_count += 1
        time.sleep(0.1)
    
    # ============================================
    # STEP 3: REMOVE WASTEFUL UNUSED INDEXES
    # ============================================
    print_header("STEP 3: Removing Unused Indexes")
    
    indexes_to_drop = [
        ("DROP INDEX IF EXISTS idx_labour_extra_cost", "Drop unused labour_extra_cost index"),
        ("DROP INDEX IF EXISTS idx_labour_entries_modified", "Drop unused labour_entries_modified index"),
        ("DROP INDEX IF EXISTS idx_labour_site_date", "Drop redundant labour_site_date index"),
        ("DROP INDEX IF EXISTS idx_notifications_site_id", "Drop unused notifications_site_id index"),
        ("DROP INDEX IF EXISTS idx_notifications_entry_type", "Drop unused notifications_entry_type index"),
        ("DROP INDEX IF EXISTS idx_users_username", "Drop unused users_username index"),
        ("DROP INDEX IF EXISTS idx_users_status", "Drop unused users_status index"),
    ]
    
    for sql, description in indexes_to_drop:
        total_steps += 1
        if execute_sql(conn, sql, description):
            success_count += 1
        time.sleep(0.1)
    
    # ============================================
    # VERIFICATION
    # ============================================
    print_header("STEP 4: Verifying Changes")
    
    try:
        with conn.cursor() as cur:
            # Check new indexes
            cur.execute("""
                SELECT 
                    schemaname, 
                    tablename, 
                    indexname,
                    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
                FROM pg_stat_user_indexes
                WHERE indexname IN (
                    'idx_users_email_lookup',
                    'idx_notifications_supervisor_unread',
                    'idx_labour_entries_site_id',
                    'idx_labour_entries_supervisor_id'
                )
                ORDER BY tablename, indexname
            """)
            indexes = cur.fetchall()
            
            print_info(f"New indexes created: {len(indexes)}")
            for idx in indexes:
                print(f"  • {idx[2]} on {idx[1]} - Size: {idx[3]}")
            
            # Check dead rows
            cur.execute("""
                SELECT 
                    relname as table_name,
                    n_live_tup as live_rows,
                    n_dead_tup as dead_rows,
                    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) as dead_pct
                FROM pg_stat_user_tables
                WHERE schemaname = 'public'
                  AND relname IN ('users', 'notifications', 'labour_cost_calculation')
                ORDER BY relname
            """)
            dead_rows = cur.fetchall()
            
            print_info("\nDead rows after VACUUM:")
            for row in dead_rows:
                dead_pct = row[3] if row[3] is not None else 0
                status = "✓" if dead_pct < 5 else "⚠"
                print(f"  {status} {row[0]}: {row[2]} dead ({dead_pct}%)")
            
    except Exception as e:
        print_warning(f"Verification queries failed: {e}")
    
    # ============================================
    # SUMMARY
    # ============================================
    print_header("📊 Optimization Summary")
    
    print(f"Total steps: {total_steps}")
    print(f"Successful: {GREEN}{success_count}{RESET}")
    print(f"Failed: {RED}{total_steps - success_count}{RESET}\n")
    
    if success_count == total_steps:
        print_success("🎉 OPTIMIZATION COMPLETE!")
        print_info("\n✅ Expected Performance Improvements:")
        print("   • User login by email: 1.58ms → <0.01ms (100x faster)")
        print("   • Notifications queries: 1.54ms → 0.15ms (10x faster)")
        print("   • Labour entry JOINs: 7.38ms → 0.74ms (10x faster)")
        print("   • Labour INSERT speed: 13ms → 6.5ms (2x faster)")
        print("\n💡 Next steps:")
        print("   1. Test your application performance")
        print("   2. Monitor query times in production")
        print("   3. See DATABASE_QUERY_OPTIMIZATION_REPORT.md for more optimizations")
    else:
        print_warning(f"\n⚠ Optimization completed with {total_steps - success_count} warnings/errors")
        print_info("Check the output above for details")
    
    conn.close()
    print_info("\nDatabase connection closed.")


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print_error("\n\nOptimization interrupted by user.")
        sys.exit(1)
    except Exception as e:
        print_error(f"\n\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
