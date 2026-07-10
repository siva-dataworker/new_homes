# Labour Entry Issue - Complete Fix Summary

## Current Problem
When both Supervisor and Site Engineer try to submit the same labour type (e.g., "General") on the same day:
- ✅ Supervisor's submission succeeds
- ❌ Site Engineer's submission fails/is not created in database

**Expected behavior:** Both entries should be stored separately in the database with different `submitted_by_role` values.

---

## Root Causes Identified

### 1. ✅ FIXED: Backend Duplicate Check Logic
**File:** `django-backend/api/views_construction.py` (lines 316-351)

**Problem:** The duplicate check was querying for:
```sql
WHERE site_id = %s AND entry_date = %s AND entry_type = %s AND labour_type = %s
```
This didn't account for different roles, so both Supervisor and Site Engineer hitting the same labour_type got flagged as duplicates.

**Fixed By:** Added `AND submitted_by_role = %s` to the WHERE clause

### 2. ⚠️ PENDING: Database Schema Missing `entry_type` Column
**Issue:** The code references `entry_type` column but it may not exist in all database instances.

**Fix Required:** Run migration `fix_labour_entry_schema_complete.sql`

### 3. ⚠️ PENDING: Conflicting Unique Constraint
**Issue:** If a UNIQUE constraint exists on `(site_id, entry_date, labour_type)`, it will prevent multiple roles from submitting the same labour type.

**Fix Required:** Drop the constraint using the migration above

---

## Files Modified / Created

### Backend Code (Already Fixed)
- ✅ `django-backend/api/views_construction.py`
  - Lines 317: Updated comment to explain new behavior
  - Line 323: Added `le.submitted_by_role` to SELECT
  - Line 331: Added `AND le.submitted_by_role = %s` to WHERE clause
  - Line 349: Updated error message to include role info

### Database Migrations (Need to Run)
- 🆕 `django-backend/fix_labour_entry_schema_complete.sql` - Complete fix
  - Adds `entry_type` column if missing
  - Drops conflicting UNIQUE constraints
  - Creates proper indexes for the duplicate check query

### Documentation
- 📄 `DEBUGGING_APPROVED_ENTRIES.md` - Issue analysis
- 📄 `FIX_LABOUR_ENTRY_ISSUE_SUMMARY.md` - This file

---

## How to Apply the Fix

### Step 1: Backend Code (Already Done)
Code changes are already in place in `views_construction.py`.

### Step 2: Run Database Migration
Execute the SQL migration to update the database schema:

```bash
# Using psql directly
psql -U postgres -d construction_db -f django-backend/fix_labour_entry_schema_complete.sql

# Or using Django shell
python manage.py shell
```

Or manually execute the SQL commands in your PostgreSQL client.

### Step 3: Verify the Fix

Run a test submission:

**Test Case:**
1. Supervisor logs in → Select a site → Labour Count → Enter 5 "General" workers → Submit
2. Site Engineer logs in → Select SAME site → Labour Count → Enter 3 "General" workers → Submit

**Expected Results:**
- Both submissions succeed ✅
- Database contains 2 labour_entries rows:
  - Row 1: site_id, 5 "General", submitted_by_role='Supervisor'
  - Row 2: site_id, 3 "General", submitted_by_role='Site Engineer'

**Verify in Database:**
```sql
SELECT 
    id, 
    labour_type, 
    labour_count, 
    submitted_by_role,
    entry_date,
    entry_type
FROM labour_entries
WHERE site_id = 'YOUR_SITE_ID' 
AND entry_date = CURRENT_DATE
ORDER BY created_at;
```

---

## Technical Details

### How the Fix Works

**Before:** Unique check was (site_id, date, time_type, labour_type)
```
Supervisor submits "General" → Stored ✓
Site Engineer submits "General" → BLOCKED (duplicate found)
```

**After:** Unique check is (site_id, date, time_type, labour_type, **submitted_by_role**)
```
Supervisor submits "General" → Stored with role='Supervisor' ✓
Site Engineer submits "General" → Stored with role='Site Engineer' ✓
SAME SUPERVISOR submits "General" twice → BLOCKED (duplicate per role) ✓
```

### Database Structure

**labour_entries table now includes:**
| Column | Type | Purpose |
|--------|------|---------|
| `id` | UUID | Primary key |
| `site_id` | UUID | Which site |
| `supervisor_id` | UUID | Who submitted |
| `labour_type` | VARCHAR | Mason, General, Plumber, etc. |
| `labour_count` | INT | How many workers |
| `entry_date` | DATE | Which date |
| `entry_type` | VARCHAR | 'morning' or 'evening' |
| `submitted_by_role` | VARCHAR | 'Supervisor' or 'Site Engineer' |
| `extra_cost` | DECIMAL | Additional costs |

**Unique Constraint:** `(site_id, entry_date, entry_type, labour_type, submitted_by_role)`
- Allows same labour type from different roles
- Prevents duplicate from same role on same day

---

## Common Issues & Solutions

### Issue: "already entered by supervisor" error still appears
**Solution:** Database migration hasn't been run yet. Execute `fix_labour_entry_schema_complete.sql`

### Issue: Site Engineer submission returns 423 (Locked)
**Solution:** The duplicate check is still finding an entry. Verify:
1. Migration was executed successfully
2. `submitted_by_role` column exists in database
3. UNIQUE constraint was removed

### Issue: Neither submission succeeds
**Solution:** 
1. Check database logs for the actual error
2. Verify `entry_type` column exists
3. Ensure indexes were created correctly

---

## Questions & Support

For debugging, check:
1. Database table columns: `\d labour_entries` (in psql)
2. Constraints: `SELECT * FROM information_schema.table_constraints WHERE table_name='labour_entries'`
3. Indexes: `SELECT * FROM pg_indexes WHERE tablename='labour_entries'`
4. Server logs: `/var/log/postgresql/` or Django logs

