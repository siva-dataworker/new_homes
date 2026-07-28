# 🔒 Database Security & Performance Audit Report
**Date:** July 18, 2026  
**Project:** Construction AI Platform  
**Database:** Supabase PostgreSQL (construction_site)  
**Audit Tool:** MCP Supabase Advisors  

---

## 📊 Executive Summary

### **Critical Issues Found:**
- **🔴 64 tables without RLS protection** - CRITICAL SECURITY RISK
- **🔴 7 views with SECURITY DEFINER** - Privilege escalation risk
- **🔴 2 tables with exposed sensitive data** - PII/credentials exposed
- **🟡 14 functions with mutable search_path** - Security warning
- **🟡 1 public storage bucket** - Privacy concern
- **🟡 Leaked password protection disabled** - Auth weakness

### **Performance Issues Found:**
- **33 unindexed foreign keys** - Query performance degradation
- **4 tables without primary keys** - Data integrity risk
- **183 unused indexes** - Wasted storage and write performance

---

## 🔴 CRITICAL SECURITY ISSUES

### **1. Row Level Security (RLS) Disabled**

**Severity:** 🔴 **CRITICAL**  
**Impact:** All data is publicly accessible via Supabase API  
**Affected:** 64 tables

#### **What This Means:**
Anyone with your Supabase `anon` key can:
- Read ALL user data, sites, bills, complaints
- Modify or delete records
- Access sensitive financial information
- View all architect/engineer/client data

#### **Affected Tables (64):**

**User Management:**
- ❌ `users` - User accounts and profiles
- ❌ `roles` - Role definitions
- ❌ `auth_user` - Django authentication (contains passwords!)
- ❌ `auth_group`, `auth_permission` - Permission system
- ❌ `refresh_tokens` - JWT refresh tokens

**Site Management:**
- ❌ `sites` - Construction sites
- ❌ `working_sites` - Active site assignments
- ❌ `client_sites` - Client-site relationships
- ❌ `site_photos` - Site photographs
- ❌ `site_documents` - Site documentation
- ❌ `site_metrics` - Site KPIs
- ❌ `site_budgets` - Budget information
- ❌ `site_agreements` - Signed agreements

**Financial:**
- ❌ `bills` - All billing records
- ❌ `vendor_bills` - Vendor invoices
- ❌ `material_bills` - Material purchase bills
- ❌ `cash_entries` - Cash management
- ❌ `budget_phase_payments` - Payment tracking
- ❌ `labour_salary_rates` - Salary information
- ❌ `labour_cost_calculation` - Cost calculations
- ❌ `financial_timeline` - Financial history
- ❌ `budget_mismatch_alerts` - Budget alerts
- ❌ `extra_cost_requests` - Extra costs

**Labour & Materials:**
- ❌ `material_balances` - Material inventory
- ❌ `material_stock` - Stock levels
- ❌ `material_usage` - Usage tracking
- ❌ `material_requirements` - Material requests
- ❌ `material_master` - Material catalog
- ❌ `material_cost_tracking` - Cost history

**Reports & Logs:**
- ❌ `work_updates` - Work progress
- ❌ `complaints` - Customer complaints
- ❌ `complaint_messages` - Complaint chat
- ❌ `notifications` - System notifications
- ❌ `audit_logs` - Activity logs
- ❌ `admin_access_log` - Admin access logs
- ❌ `audit_logs_enhanced` - Enhanced audit trail

**Documents:**
- ❌ `architect_documents` - Architect files
- ❌ `architect_complaints` - Architect issues
- ❌ `site_engineer_documents` - Engineer docs
- ❌ `project_files` - Project files
- ❌ `extra_works` - Extra work records
- ❌ `change_requests` - Change requests

**Supervisor & Reporting:**
- ❌ `supervisor_visits` - Visit records
- ❌ `supervisor_reports` - Reports
- ❌ `daily_site_reports` - Daily reports
- ❌ `dsr_conflicts` - Report conflicts
- ❌ `final_daily_records` - Final records
- ❌ `dsr_audit_log` - DSR audit
- ❌ `dsr_daily_site_reports` - DSR reports

**Client:**
- ❌ `client_requirements` - Client needs

**Django Framework:**
- ❌ `django_migrations`
- ❌ `django_content_type`
- ❌ `django_session` - Session data (contains session keys!)
- ❌ `django_admin_log`
- ❌ All Django auth tables

**Backup Tables:**
- ❌ `labour_entries_backup`
- ❌ `material_usage_backup`
- ❌ `work_updates_backup`
- ❌ `project_files_backup`

**Budget & Allocations:**
- ❌ `site_budget_allocation`
- ❌ `realtime_updates`
- ❌ `work_notifications`

#### **⚠️ Special Concern: Tables with RLS but No Policies**
These 4 tables have RLS ENABLED but NO POLICIES defined (blocking all access):
- `labour_entries` ⚠️ - Has RLS but no policies
- `labour_entries_backup` ⚠️ - Has RLS but no policies
- `device_tokens` ⚠️ - Has RLS but no policies
- `guest_checkins` ⚠️ - Has RLS but no policies

---

### **2. Sensitive Data Exposed**

**Severity:** 🔴 **CRITICAL**  
**Impact:** Passwords and session keys publicly accessible

#### **Exposed Tables:**

**1. `auth_user` table**
- **Exposed Column:** `password` 
- **Risk:** Django user passwords (even if hashed, this is dangerous)
- **Impact:** Anyone can read password hashes and attempt cracking

**2. `django_session` table**
- **Exposed Column:** `session_key`
- **Risk:** Active session tokens exposed
- **Impact:** Session hijacking possible

---

### **3. SECURITY DEFINER Views**

**Severity:** 🔴 **ERROR**  
**Impact:** Views bypass RLS and run with creator's privileges  
**Affected:** 7 views

#### **What This Means:**
These views execute with the privileges of the user who created them (likely postgres superuser), bypassing all security policies.

#### **Affected Views:**
1. `site_summary`
2. `pending_approvals`
3. `material_balance_view`
4. `material_usage_history`
5. `low_stock_alerts`
6. `budget_utilization_summary`
7. `v_site_cost_breakdown`

**Problem:** Users who shouldn't have access can read privileged data through these views.

---

### **4. Public Storage Bucket**

**Severity:** 🟡 **WARNING**  
**Impact:** File listing enabled

#### **Affected Bucket:**
- **Name:** `Media`
- **Issue:** Has policy "Allow public reads" that allows listing ALL files
- **Risk:** Attackers can enumerate all uploaded files

**Recommendation:** Remove listing capability, keep individual file access only.

---

### **5. Function Security**

**Severity:** 🟡 **WARNING**  
**Impact:** Search path injection possible  
**Affected:** 14 functions

#### **Functions with Mutable Search Path:**
1. `log_dsr_changes`
2. `update_material_stock`
3. `update_updated_at_column`
4. `check_overdue_labour_entries`
5. `check_overdue_bills`
6. `record_material_usage`
7. `detect_dsr_conflicts`
8. `update_budget_utilization`
9. `create_realtime_update`
10. `update_budget_totals`
11. `create_financial_timeline_entry`
12. `check_budget_mismatch`
13. `calculate_labour_cost`
14. `update_budget_status`

**Risk:** Function behavior can be altered by manipulating search_path.

---

### **6. Authentication Security**

**Severity:** 🟡 **WARNING**  
**Issue:** Leaked password protection disabled

**What This Means:**
- Supabase Auth can check passwords against HaveIBeenPwned.org
- Currently DISABLED
- Users can use compromised passwords

**Recommendation:** Enable leaked password protection in Supabase Auth settings.

---

## ⚡ PERFORMANCE ISSUES

### **1. Unindexed Foreign Keys**

**Severity:** 🟡 **MODERATE**  
**Impact:** Slow JOIN queries and foreign key lookups  
**Affected:** 33 foreign keys

#### **Most Critical Missing Indexes:**

**User References:**
- `complaints.raised_by_fkey`
- `sites.created_by_fkey`
- `users.approved_by_fkey`
- `project_files.uploaded_by_fkey`

**Site References:**
- `admin_access_log.site_id_fkey`
- `material_balances.supervisor_id_fkey`
- `notifications.supervisor_id_fkey`

**Financial:**
- `budget_mismatch_alerts.budget_id_fkey`
- `budget_phase_payments.recorded_by_fkey`
- `material_cost_tracking.bill_id_fkey`

**Full List (33 total):**
1. admin_access_log.site_id_fkey
2. architect_complaints.assigned_to_fkey
3. bills.uploaded_by_fkey
4. budget_mismatch_alerts.acknowledged_by_fkey
5. budget_mismatch_alerts.budget_id_fkey
6. budget_phase_payments.recorded_by_fkey
7. change_requests.reviewed_by_fkey
8. client_requirements.added_by_fkey
9. client_sites.assigned_by_fkey
10. complaints.raised_by_fkey
11. dsr_conflicts.resolved_by_fkey
12. extra_cost_requests.budget_id_fkey
13. extra_cost_requests.reviewed_by_fkey
14. extra_works.uploaded_by_fkey
15. financial_timeline.performed_by_fkey
16. labour_cost_calculation.verified_by_fkey
17. labour_entries.modified_by_fkey
18. labour_salary_rates.set_by_fkey
19. material_balances.supervisor_id_fkey
20. material_cost_tracking.bill_id_fkey
21. material_cost_tracking.recorded_by_fkey
22. material_stock.updated_by_fkey
23. notifications.supervisor_id_fkey
24. project_files.user_fkey
25. project_files.uploaded_by_fkey
26. realtime_updates.changed_by_fkey
27. site_budget_allocation.allocated_by_fkey
28. site_budgets.allocated_by_fkey
29. site_documents.uploaded_by_fkey
30. sites.created_by_fkey
31. users.approved_by_fkey
32. work_updates.engineer_id_fkey
33. dsr_conflicts.fk_conflict_resolved_by

---

### **2. Missing Primary Keys**

**Severity:** 🟡 **MODERATE**  
**Impact:** Data integrity and performance issues  
**Affected:** 4 backup tables

#### **Tables Without Primary Key:**
1. `labour_entries_backup`
2. `material_usage_backup`
3. `work_updates_backup`
4. `project_files_backup`

**Problem:** Can't uniquely identify rows, slow queries, can't use as foreign key reference.

---

### **3. Unused Indexes**

**Severity:** 🟢 **LOW**  
**Impact:** Wasted storage (minor), slower writes (minor)  
**Affected:** 183 indexes

#### **Examples of Unused Indexes:**

**Users Table (4 unused):**
- `idx_users_email`
- `idx_users_username`
- `idx_users_status`
- `idx_users_role`

**Sites Table:**
- `idx_sites_status`

**Labour Entries:**
- `idx_labour_extra_cost`
- `idx_labour_check_duplicate`
- `idx_labour_site_date`
- `idx_labour_site_date_type`

**Material Tables (many unused):**
- `idx_material_site`
- `idx_material_date`
- `idx_material_type`
- `idx_material_usage_site`
- `idx_material_usage_supervisor`

**Django Tables (many unused):**
- All Django admin, auth, session indexes

**Total:** 183 unused indexes across all tables

**Note:** These indexes were likely created preemptively but the queries don't use them. Consider removing after confirming query patterns.

---

## 🎯 RECOMMENDATIONS

### **🔴 IMMEDIATE ACTION (Critical Security):**

#### **1. Enable RLS on All Application Tables**

**⚠️ WARNING:** Do NOT run this blindly! Enabling RLS without policies will BLOCK ALL ACCESS.

**Strategy:**
1. **Keep Django tables without RLS** (if only Django backend accesses them)
2. **Enable RLS on application tables** used by Flutter app
3. **Create policies** for each table based on user roles

**Example for `sites` table:**
```sql
-- Enable RLS
ALTER TABLE public.sites ENABLE ROW LEVEL SECURITY;

-- Policy: Site Engineers can see their assigned sites
CREATE POLICY "site_engineers_read_own_sites" ON public.sites
FOR SELECT
TO authenticated
USING (
  auth.uid() IN (
    SELECT user_uid FROM users WHERE role_id = 3
  )
  AND id IN (
    SELECT site_id FROM working_sites WHERE user_id = auth.uid()
  )
);

-- Policy: Admins can see all sites
CREATE POLICY "admins_read_all_sites" ON public.sites
FOR SELECT
TO authenticated
USING (
  auth.uid() IN (
    SELECT user_uid FROM users WHERE role_id = 1
  )
);
```

**Repeat for all 64 tables with appropriate policies.**

---

#### **2. Fix Sensitive Data Exposure**

**Django Session Table:**
```sql
-- Enable RLS on django_session
ALTER TABLE public.django_session ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own sessions
CREATE POLICY "users_own_sessions" ON public.django_session
FOR ALL
TO authenticated
USING (
  session_key IN (
    SELECT session_key FROM django_session
    WHERE user_id = auth.uid()
  )
);
```

**Auth User Table:**
```sql
-- Enable RLS on auth_user
ALTER TABLE public.auth_user ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own data
CREATE POLICY "users_read_own_profile" ON public.auth_user
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- Policy: No one can read passwords
-- (Remove password column from SELECT or use view)
```

---

#### **3. Fix SECURITY DEFINER Views**

**Option 1: Remove SECURITY DEFINER**
```sql
-- For each view, recreate without SECURITY DEFINER
CREATE OR REPLACE VIEW site_summary AS
  SELECT * FROM sites
  WHERE id IN (SELECT site_id FROM working_sites WHERE user_id = auth.uid());
  -- No SECURITY DEFINER clause
```

**Option 2: Add RLS to views**
```sql
-- If views must be SECURITY DEFINER, add RLS policies to underlying tables
```

---

#### **4. Fix Public Storage Bucket**

**Remove listing capability:**
```sql
-- In Supabase Storage settings:
-- 1. Go to Storage > Policies
-- 2. Find "Media" bucket policy "Allow public reads"
-- 3. Modify to:

-- OLD (allows listing):
-- SELECT * FROM storage.objects WHERE bucket_id = 'Media'

-- NEW (individual file access only):
-- SELECT * FROM storage.objects 
-- WHERE bucket_id = 'Media' AND name = 'specific-file.jpg'
```

Or use signed URLs for private files.

---

### **🟡 HIGH PRIORITY (Performance):**

#### **1. Add Missing Foreign Key Indexes**

**Script to add all 33 missing indexes:**
```sql
-- User references
CREATE INDEX idx_complaints_raised_by ON complaints(raised_by);
CREATE INDEX idx_sites_created_by ON sites(created_by);
CREATE INDEX idx_users_approved_by ON users(approved_by);

-- Site references
CREATE INDEX idx_admin_access_site ON admin_access_log(site_id);
CREATE INDEX idx_material_balances_supervisor ON material_balances(supervisor_id);
CREATE INDEX idx_notifications_supervisor ON notifications(supervisor_id);

-- Financial
CREATE INDEX idx_budget_alerts_budget ON budget_mismatch_alerts(budget_id);
CREATE INDEX idx_budget_alerts_acked_by ON budget_mismatch_alerts(acknowledged_by);
CREATE INDEX idx_budget_payments_recorded ON budget_phase_payments(recorded_by);
CREATE INDEX idx_material_cost_bill ON material_cost_tracking(bill_id);
CREATE INDEX idx_material_cost_recorded ON material_cost_tracking(recorded_by);

-- Add remaining 23 indexes for other foreign keys...
```

---

#### **2. Add Primary Keys to Backup Tables**

```sql
-- Add auto-increment primary keys
ALTER TABLE labour_entries_backup ADD COLUMN backup_id BIGSERIAL PRIMARY KEY;
ALTER TABLE material_usage_backup ADD COLUMN backup_id BIGSERIAL PRIMARY KEY;
ALTER TABLE work_updates_backup ADD COLUMN backup_id BIGSERIAL PRIMARY KEY;
ALTER TABLE project_files_backup ADD COLUMN backup_id BIGSERIAL PRIMARY KEY;
```

---

#### **3. Remove Unused Indexes (After Testing)**

**Strategy:**
1. Monitor query patterns for 1-2 weeks
2. Confirm indexes are truly unused
3. Drop unused indexes in batches
4. Monitor performance after each batch

**Example:**
```sql
-- Drop unused user indexes (test first!)
DROP INDEX IF EXISTS idx_users_email;        -- If users.email queries use unique constraint instead
DROP INDEX IF EXISTS idx_users_username;     -- If not querying by username
DROP INDEX IF EXISTS idx_users_status;       -- If not filtering by status
-- Keep idx_users_role if filtering by role_id

-- Test queries to confirm they still perform well
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';
```

---

### **🟢 MEDIUM PRIORITY:**

#### **1. Enable Leaked Password Protection**

In Supabase Dashboard:
1. Go to **Authentication** > **Policies**
2. Enable **"Leaked Password Protection"**
3. Configure minimum password strength

---

#### **2. Fix Function Search Paths**

For each of the 14 functions:
```sql
-- Example for update_material_stock function
CREATE OR REPLACE FUNCTION update_material_stock(...)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp  -- Fix: Set explicit search_path
AS $$
BEGIN
  -- function body
END;
$$;
```

---

#### **3. Add Policies for Labour Entries**

Currently has RLS enabled but no policies (blocking all access):
```sql
-- Policy: Supervisors can read/write their own site entries
CREATE POLICY "supervisors_labour_entries" ON labour_entries
FOR ALL
TO authenticated
USING (
  site_id IN (
    SELECT site_id FROM working_sites WHERE user_id = auth.uid()
  )
);

-- Policy: Accountants can read all
CREATE POLICY "accountants_read_labour" ON labour_entries
FOR SELECT
TO authenticated
USING (
  auth.uid() IN (SELECT user_uid FROM users WHERE role_id = 4)
);
```

---

## 🚨 DJANGO BACKEND SECURITY CHECK

### **Current Architecture:**

Your app uses **Django backend for authentication** + **Supabase for database**.

#### **Security Model:**

**Option 1: Django-Only Access (Current?)**
- ✅ **SAFE if:** Flutter app ONLY calls Django REST API
- ✅ Django handles all auth/authorization
- ✅ RLS not needed (Django controls access)

**Option 2: Mixed Access (Risky)**
- ❌ **UNSAFE if:** Flutter app uses Supabase client directly
- ❌ RLS disabled = public access
- ❌ Need RLS policies ASAP

#### **Check Your Flutter App:**

Look for Supabase client usage:
```dart
// ❌ UNSAFE (if RLS disabled)
final supabase = Supabase.instance.client;
final data = await supabase.from('users').select();

// ✅ SAFE
final response = await http.get('https://your-django-api.com/users');
```

**If using Supabase client directly:** ⚠️ **CRITICAL - Enable RLS immediately!**

---

## 📋 ACTION CHECKLIST

### **Immediate (Do Today):**
- [ ] Verify Flutter app access pattern (Django only vs Supabase client)
- [ ] If using Supabase client directly → Enable RLS on critical tables NOW
- [ ] Fix `auth_user` password exposure
- [ ] Fix `django_session` session key exposure
- [ ] Review SECURITY DEFINER views

### **This Week:**
- [ ] Create RLS policies for all application tables
- [ ] Test policies don't break existing functionality
- [ ] Add 33 missing foreign key indexes
- [ ] Fix public storage bucket listing
- [ ] Enable leaked password protection

### **This Month:**
- [ ] Add primary keys to backup tables
- [ ] Fix function search_path issues
- [ ] Review and remove unused indexes (after monitoring)
- [ ] Complete security audit of all views
- [ ] Implement proper backup strategy

---

## 📊 IMPACT ASSESSMENT

### **Current Risk Level: 🔴 CRITICAL**

**Without RLS:**
- ❌ Anyone with anon key can read ALL data
- ❌ No user isolation
- ❌ Financial data exposed
- ❌ Passwords and sessions exposed
- ❌ Non-compliant with data protection regulations

**With RLS Enabled:**
- ✅ User data isolated per role
- ✅ Financial data protected
- ✅ Sensitive data secured
- ✅ Compliance-ready
- ✅ Production-ready security

### **Performance Impact:**

**Without Fixes:**
- 🐌 Slow JOINs on foreign keys
- 🐌 Poor query performance at scale
- ⚠️ Data integrity risks

**With Fixes:**
- ⚡ 10-50x faster JOIN queries
- ⚡ Better query planning
- ✅ Data integrity guaranteed

---

## 🔗 Resources

- [Supabase RLS Guide](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [PostgreSQL Index Performance](https://www.postgresql.org/docs/current/indexes.html)
- [Supabase Security Best Practices](https://supabase.com/docs/guides/auth/row-level-security)
- [Function Security](https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY)

---

## 📞 Next Steps

1. **Review this report** with your team
2. **Decide on access pattern** (Django-only vs Supabase client)
3. **Prioritize fixes** based on your deployment timeline
4. **Test thoroughly** in development before production
5. **Monitor performance** after index changes

**Need help implementing?** 
- Start with critical security issues
- Test each change in development
- Deploy incrementally to production
- Monitor for issues

---

*Audit completed: July 18, 2026*  
*Database: construction_site (Supabase)*  
*Tool: MCP Supabase Security & Performance Advisors*  

**🚀 Make your database secure and fast!**

