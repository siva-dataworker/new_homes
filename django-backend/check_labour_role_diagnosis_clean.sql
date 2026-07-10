-- Labour Role Issue Diagnostic SQL Script (for SQL Editors)
-- Remove comments and \echo lines, run queries one at a time in pgAdmin/DBeaver

-- ===== 1. ROLES TABLE =====
SELECT id, role_name FROM roles ORDER BY role_name;


-- ===== 2. USERS AND THEIR ROLES =====
SELECT
    u.id,
    u.username,
    u.role_id,
    r.role_name,
    u.is_active
FROM users u
LEFT JOIN roles r ON u.role_id = r.id
ORDER BY u.username;


-- ===== 3. RECENT LABOUR ENTRIES (LAST 20) =====
SELECT
    le.id,
    le.site_id,
    le.labour_type,
    le.labour_count,
    le.entry_date,
    le.entry_type,
    le.submitted_by_role,
    u.username,
    r.role_name,
    CASE WHEN le.submitted_by_role = r.role_name THEN 'CORRECT' ELSE 'MISMATCH' END as match_status
FROM labour_entries le
LEFT JOIN users u ON le.supervisor_id = u.id
LEFT JOIN roles r ON u.role_id = r.id
ORDER BY le.created_at DESC
LIMIT 20;


-- ===== 4. CHECK FOR MISMATCHED SUBMITTED_BY_ROLE (CRITICAL) =====
SELECT
    le.id,
    le.labour_type,
    le.entry_date,
    le.entry_type,
    le.submitted_by_role as stored_role,
    r.role_name as actual_user_role,
    u.username
FROM labour_entries le
LEFT JOIN users u ON le.supervisor_id = u.id
LEFT JOIN roles r ON u.role_id = r.id
WHERE le.submitted_by_role IS NOT NULL
  AND le.submitted_by_role != COALESCE(r.role_name, '')
ORDER BY le.created_at DESC
LIMIT 20;


-- ===== 5. DUPLICATE ENTRY CHECK (SAME ROLE, SAME LABOUR, SAME DATE) =====
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
LIMIT 20;


-- ===== 6. ROLE VALIDATION SUMMARY =====
WITH recent_entries AS (
    SELECT
        le.id,
        le.labour_type,
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
)
SELECT
    labour_type,
    entry_date,
    entry_type,
    username,
    submitted_by_role as "Stored Role",
    role_name as "Actual User Role",
    CASE
        WHEN submitted_by_role = role_name THEN 'CORRECT'
        WHEN submitted_by_role IS NULL THEN 'NULL'
        WHEN role_name IS NULL THEN 'USER HAS NO ROLE'
        ELSE 'MISMATCH: ' || submitted_by_role || ' vs ' || role_name
    END as status
FROM recent_entries
ORDER BY entry_date DESC;
