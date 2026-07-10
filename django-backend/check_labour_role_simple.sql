-- Simple Labour Role Diagnostic (no assumptions about columns)

-- ===== CHECK TABLE STRUCTURE =====
-- Run this first to see what columns exist
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'labour_entries'
ORDER BY ordinal_position;


-- ===== 1. ROLES TABLE =====
SELECT id, role_name FROM roles ORDER BY role_name;


-- ===== 2. USERS AND THEIR ROLES =====
SELECT u.username, u.role_id, r.role_name, u.is_active
FROM users u
LEFT JOIN roles r ON u.role_id = r.id
ORDER BY u.username;


-- ===== 3. RECENT LABOUR ENTRIES =====
SELECT le.id, le.site_id, le.labour_type, le.entry_date,
       le.entry_type, le.submitted_by_role, u.username, r.role_name
FROM labour_entries le
LEFT JOIN users u ON le.supervisor_id = u.id
LEFT JOIN roles r ON u.role_id = r.id
ORDER BY le.entry_date DESC
LIMIT 20;


-- ===== 4. CRITICAL: CHECK FOR MISMATCHED ROLES =====
SELECT le.id, le.labour_type, le.entry_date, le.entry_type,
       le.submitted_by_role, u.username, r.role_name
FROM labour_entries le
LEFT JOIN users u ON le.supervisor_id = u.id
LEFT JOIN roles r ON u.role_id = r.id
WHERE le.submitted_by_role IS NOT NULL
  AND le.submitted_by_role != COALESCE(r.role_name, '')
ORDER BY le.entry_date DESC
LIMIT 20;
