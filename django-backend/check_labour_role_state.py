#!/usr/bin/env python
"""
Diagnostic script to check labour entry role issues
"""

import os
import sys
import django

# Setup Django
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from api.database import fetch_all, fetch_one

print("\n" + "="*80)
print("LABOUR ENTRY ROLE DIAGNOSTIC")
print("="*80)

# 1. Check roles table
print("\n1. ROLES TABLE:")
print("-" * 80)
roles = fetch_all("""
    SELECT id, role_name, description
    FROM roles
    ORDER BY role_name
""")
if roles:
    for r in roles:
        print(f"  ID: {r['id']:<40} | Name: {r['role_name']:<25} | Desc: {r['description']}")
else:
    print("  ⚠️ No roles found in database!")

# 2. Check users and their roles
print("\n2. USERS AND THEIR ROLES:")
print("-" * 80)
users = fetch_all("""
    SELECT u.id, u.username, u.role_id, r.role_name, u.is_active
    FROM users u
    LEFT JOIN roles r ON u.role_id = r.id
    ORDER BY u.username
""")
if users:
    for u in users:
        status = "🟢" if u['is_active'] else "🔴"
        role_display = u['role_name'] if u['role_name'] else "⚠️ NULL"
        print(f"  {status} {u['username']:<25} | role_id: {u['role_id']:<40} | role_name: {role_display}")
else:
    print("  ⚠️ No users found!")

# 3. Check labour entries with submitted_by_role
print("\n3. RECENT LABOUR ENTRIES:")
print("-" * 80)
entries = fetch_all("""
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
if entries:
    for e in entries:
        user_role = f"{e['username']} ({e['role_name'] or 'NULL'})" if e['username'] else "Unknown"
        mismatch = "⚠️ MISMATCH!" if e['submitted_by_role'] != e['role_name'] else ""
        print(f"  Date: {e['entry_date']} | Type: {e['entry_type']:<8} | {e['labour_type']:<15}")
        print(f"    Submitted as: {e['submitted_by_role']:<18} | User: {user_role:<35} {mismatch}")
else:
    print("  ⚠️ No labour entries found!")

# 4. Check for mismatches
print("\n4. MISMATCHED SUBMITTED_BY_ROLE:")
print("-" * 80)
mismatches = fetch_all("""
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
    WHERE le.submitted_by_role != r.role_name
       OR (le.submitted_by_role IS NOT NULL AND r.role_name IS NULL)
       OR (le.submitted_by_role IS NULL AND r.role_name IS NOT NULL)
    LIMIT 20
""")
if mismatches:
    print(f"  Found {len(mismatches)} mismatched entries:")
    for m in mismatches:
        print(f"    Entry: {m['labour_type']} on {m['entry_date']}")
        print(f"      submitted_by_role: {m['submitted_by_role']}")
        print(f"      user {m['username']}'s actual role: {m['role_name']}")
else:
    print("  ✅ No mismatches found - all entries have correct role info")

# 5. Check for duplicate prevention issues
print("\n5. CHECKING ROLE-BASED DUPLICATE PREVENTION:")
print("-" * 80)
# Find entries where same role submitted same labour_type on same date
duplicates = fetch_all("""
    SELECT
        le.site_id,
        le.labour_type,
        le.entry_date,
        le.entry_type,
        le.submitted_by_role,
        COUNT(*) as count,
        STRING_AGG(DISTINCT u.username, ', ') as users
    FROM labour_entries le
    LEFT JOIN users u ON le.supervisor_id = u.id
    GROUP BY le.site_id, le.labour_type, le.entry_date, le.entry_type, le.submitted_by_role
    HAVING COUNT(*) > 1
    ORDER BY le.created_at DESC
    LIMIT 10
""")
if duplicates:
    print(f"  Found {len(duplicates)} duplicate entries for same role:")
    for d in duplicates:
        print(f"    ❌ {d['labour_type']} on {d['entry_date']} ({d['entry_type']}) - {d['submitted_by_role']}")
        print(f"       Submitted {d['count']} times by: {d['users']}")
else:
    print("  ✅ No duplicate entries per role")

print("\n" + "="*80)
print("END DIAGNOSTIC")
print("="*80 + "\n")
