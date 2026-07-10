#!/usr/bin/env python
"""
Diagnostic script to check labour entry role issues - direct database connection
"""

import psycopg
import os
from decouple import config

# Database connection
db_config = {
    'host': config('DB_HOST', 'localhost'),
    'port': int(config('DB_PORT', '5432')),
    'database': config('DB_NAME', 'construction_db'),
    'user': config('DB_USER', 'postgres'),
    'password': config('DB_PASSWORD'),
    'sslmode': 'require'
}

print("\nConnecting to database:", db_config['database'], "at", db_config['host'])

with psycopg.connect(**db_config) as conn:
    with conn.cursor(row_factory=psycopg.rows.dict_cursor) as cur:

        print("\n" + "="*80)
        print("LABOUR ENTRY ROLE DIAGNOSTIC")
        print("="*80)

        # 1. Check roles table
        print("\n1. ROLES TABLE:")
        print("-" * 80)
        cur.execute("SELECT id, role_name, description FROM roles ORDER BY role_name")
        roles = cur.fetchall()
        if roles:
            for r in roles:
                print(f"  ID: {r['id']:<40} | Name: {r['role_name']:<25}")
        else:
            print("  ⚠️ No roles found in database!")

        # 2. Check users and their roles
        print("\n2. USERS AND THEIR ROLES:")
        print("-" * 80)
        cur.execute("""
            SELECT u.id, u.username, u.role_id, r.role_name, u.is_active
            FROM users u
            LEFT JOIN roles r ON u.role_id = r.id
            ORDER BY u.username
        """)
        users = cur.fetchall()
        if users:
            for u in users:
                status = "✓" if u['is_active'] else "✗"
                role_display = u['role_name'] if u['role_name'] else "⚠️ NULL"
                print(f"  [{status}] {u['username']:<25} | role_id: {str(u['role_id']):<40} | role_name: {role_display}")
        else:
            print("  ⚠️ No users found!")

        # 3. Check labour entries with submitted_by_role
        print("\n3. RECENT LABOUR ENTRIES (Last 20):")
        print("-" * 80)
        cur.execute("""
            SELECT
                le.id,
                le.site_id,
                le.labour_type,
                le.labour_count,
                le.entry_date,
                le.entry_type,
                le.submitted_by_role,
                u.username,
                u.role_id,
                r.role_name
            FROM labour_entries le
            LEFT JOIN users u ON le.supervisor_id = u.id
            LEFT JOIN roles r ON u.role_id = r.id
            ORDER BY le.created_at DESC
            LIMIT 20
        """)
        entries = cur.fetchall()
        if entries:
            for e in entries:
                user_info = f"{e['username']} ({e['role_name'] or 'NULL'})" if e['username'] else "Unknown"
                mismatch = "❌" if e['submitted_by_role'] != e['role_name'] else ""
                print(f"  {mismatch} {e['entry_date']} {e['entry_type']:<8} {e['labour_type']:<15} submitted_as={e['submitted_by_role']:<18} user={user_info}")
        else:
            print("  ⚠️ No labour entries found!")

        # 4. Check for mismatches
        print("\n4. MISMATCHED SUBMITTED_BY_ROLE:")
        print("-" * 80)
        cur.execute("""
            SELECT
                le.id,
                le.labour_type,
                le.entry_date,
                le.submitted_by_role,
                u.username,
                r.role_name
            FROM labour_entries le
            LEFT JOIN users u ON le.supervisor_id = u.id
            LEFT JOIN roles r ON u.role_id = r.id
            WHERE le.submitted_by_role IS NOT NULL
              AND (le.submitted_by_role != COALESCE(r.role_name, ''))
            ORDER BY le.created_at DESC
            LIMIT 20
        """)
        mismatches = cur.fetchall()
        if mismatches:
            print(f"  ❌ Found {len(mismatches)} mismatched entries:")
            for m in mismatches:
                print(f"    {m['labour_type']} on {m['entry_date']} by {m['username']}")
                print(f"      Stored as: '{m['submitted_by_role']}' | Actual role: '{m['role_name']}'")
        else:
            print("  ✅ No mismatches found - all entries have correct role info")

        print("\n" + "="*80)
        print("END DIAGNOSTIC")
        print("="*80 + "\n")
