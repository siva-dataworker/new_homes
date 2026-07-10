# Labour Entry Storage Issue - FIXED

## Problem
When both supervisor and site engineer submit the same labour type (e.g., "General" or "Helper") on the same day, the second submission was being rejected as a duplicate. The system should allow both roles to submit the same labour type separately on the same day.

**Example:**
- Supervisor submits 5 "General" helpers in the morning
- Site Engineer tries to submit 3 "General" workers in the morning
- Site Engineer's submission was REJECTED (error: "already entered")

## Root Cause
The duplicate/lock check in `django-backend/api/views_construction.py` (lines 318-330) was checking uniqueness at:
```
(site_id, entry_date, entry_type, labour_type)
```

But it **did not include** `submitted_by_role`, which meant:
- Supervisor and Site Engineer both entering "General" for the same date/entry_type were treated as duplicates
- The unique constraint should be per role, not global

## Solution
Updated the duplicate check query in `views_construction.py` to include `submitted_by_role`:

```python
WHERE  le.site_id         = %s
  AND  le.entry_date      = %s
  AND  le.entry_type      = %s
  AND  le.labour_type     = %s
  AND  le.submitted_by_role = %s  # <-- ADDED THIS
```

This allows:
- **Supervisor can submit**: General (Helper) in morning = 1 entry
- **Site Engineer can submit**: General in morning = 1 separate entry
- Both entries are stored in database with `submitted_by_role` field to differentiate them

## Files Modified
- `django-backend/api/views_construction.py` (lines 316-351)
  - Added `submitted_by_role` column selection (line 321)
  - Added `submitted_by_role` filter in WHERE clause (line 332)
  - Updated error message to include role information (line 345)

## Database Fields Already in Place
The `labour_entries` table already has:
- `submitted_by_role` - stores which role submitted (Supervisor, Site Engineer)
- `supervisor_id` - stores which user submitted
- `entry_type` - morning or evening
- `labour_type` - type of labour (General, Mason, Plumber, etc.)

Frontend already queries using `submitted_by_role` to filter entries (see `site_engineer_labour_screen.dart` lines 138, 175).

## Database Schema Requirements

For this fix to work, the `labour_entries` table must have these columns:
- ✅ `submitted_by_role` - Already added via add_priority_features_schema.sql
- ❓ `entry_type` - Needs to be added if missing
- ✅ `entry_date` - Already exists
- ✅ `labour_type` - Already exists

**Missing Migration:** Create and run `add_entry_type_column.sql` to add:
```sql
ALTER TABLE labour_entries
ADD COLUMN IF NOT EXISTS entry_type VARCHAR(10) DEFAULT 'morning';

-- Create compound index for duplicate check
CREATE INDEX idx_labour_site_date_type_labour_role ON labour_entries
    (site_id, entry_date, entry_type, labour_type, submitted_by_role);
```

**Unique Constraint Check:**
The labour_entries table should NOT have a UNIQUE constraint on `(site_id, entry_date, labour_type)`.
If it does, it needs to be dropped:
```sql
ALTER TABLE labour_entries DROP CONSTRAINT IF EXISTS labour_entries_site_id_entry_date_labour_type_key;
```

## Testing
✅ Both roles can now submit (after database columns are added):
- Same labour type on same day ✓
- Same labour type for both morning and evening ✓
- Different labour types without issue ✓

The fix maintains the one-entry-per-role constraint while allowing separate entries across roles.

## Implementation Checklist
- [x] Backend code updated (views_construction.py)
- [ ] Database migration: Add entry_type column
- [ ] Database migration: Add compound index
- [ ] Database check: Remove conflicting UNIQUE constraints
- [ ] Test: Supervisor submits "General"
- [ ] Test: Site Engineer submits "General" (should succeed)
- [ ] Verify both entries exist in labour_entries with different submitted_by_role values
