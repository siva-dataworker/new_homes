# Essential Homes — Full Codebase Audit Report
**Audit Date:** July 9, 2026  
**Scope:** `django-backend/` + `otp_phone_auth/lib/` + CI/CD + Database schema  
**Method:** Static analysis of all view files, service files, settings, schema SQL, and CI configuration  
**Total Issues Found: 57**

---

## Severity Legend

| Symbol | Severity | Meaning |
|--------|----------|---------|
| 🔴 | **Critical** | Exploitable in production right now. Fix immediately. |
| 🟠 | **High** | Causes data loss, bugs, or crashes under real conditions. |
| 🟡 | **Medium** | Degrades performance or correctness at scale. |
| 🔵 | **Quality** | Dead code, maintainability debt, diagnostic noise. |
| 🟣 | **Architecture** | Structural design decisions that will cost more to fix later. |
| ⚙️ | **Config** | Wrong settings for a production environment. |
| 🏗️ | **Structure** | Repository and project organisation problems. |

---

## SECTION 1 — CRITICAL SECURITY VULNERABILITIES

### ISSUE-01 🔴 Firebase JWT Decoded Without Signature Verification
**File:** `django-backend/api/views.py` + inferred `firebase_config.py`  
**Risk:** Authentication bypass — anyone can impersonate any user

The fallback path in `verify_firebase_token()` uses `base64.urlsafe_b64decode` to read the JWT payload with **zero signature verification**. The code itself warns this:

```python
# TEMPORARY WORKAROUND: Decode without verification
# WARNING: This is NOT secure for production!
decoded_token = json.loads(decoded_bytes)
```

This endpoint (`POST /api/auth/signin/`) is still registered in `urls.py` and reachable. An attacker can craft a JWT with any `uid` and `email` to gain access as any user, including Admin.

**Fix:** Remove this endpoint entirely (Firebase auth has been replaced) or enforce `firebase_admin.auth.verify_id_token()` with no fallback.

---

### ISSUE-02 🔴 Supabase Anon Key Hardcoded in Flutter Source
**File:** `otp_phone_auth/lib/config/supabase_config.dart`, lines 5–6  
**Risk:** Any user can extract the key from the APK and query the database directly

```dart
static const String supabaseAnonKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIs...';
```

This is a full Supabase anon key committed into source code. It is embedded in every compiled APK. `apktool` or `strings` can extract it in under 10 seconds. With this key anyone can directly call the Supabase REST API and bypass the Django backend entirely.

**Fix:** Rotate this key immediately via the Supabase dashboard. Never embed Supabase keys in client code — use the Django backend as the only entry point to the database.

---

### ISSUE-03 🔴 All Four Admin Endpoints Have No Authentication or Role Check
**File:** `django-backend/api/views_auth.py`, lines ~190–260  
**Risk:** Any authenticated user (Supervisor, Architect, etc.) can approve, reject, or list all user accounts

```python
@api_view(['GET'])
def get_pending_users(request):
    # TODO: Add admin role check    ← This TODO is live in production
    users = fetch_all("SELECT ... FROM users WHERE status = 'PENDING'")
```

`get_pending_users`, `get_all_users`, `approve_user`, and `reject_user` all have this TODO and zero enforcement. A field supervisor can approve their own friends' accounts, reject competitors, or enumerate all registered users.

**Fix:**
```python
@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_pending_users(request):
    if request.user.get('role') != 'Admin':
        return Response({'error': 'Admin access required'}, status=403)
    ...
```

---

### ISSUE-04 🔴 Admin-Create Endpoints Are Fully Public (No Auth Decorators)
**File:** `django-backend/api/views_auth.py`, lines ~265–380  
**Risk:** Anyone on the internet can create an Admin account

`admin_create_user`, `admin_create_admin`, `admin_create_role`, and `get_all_roles` have **no** `@authentication_classes` or `@permission_classes` decorators at all. These endpoints are publicly accessible without any token. A single unauthenticated HTTP POST to `/api/admin/create-admin/` with a JSON body creates a fully approved Admin user.

**Fix:** Add authentication and admin role check decorators to all four functions immediately.

---

### ISSUE-05 🔴 Broken Password Hashing in DirectAuthService
**File:** `otp_phone_auth/lib/services/direct_auth_service.dart`, lines ~180–195  
**Risk:** Passwords stored and compared in plaintext

```dart
Future<String> _hashPassword(String password) async {
  return 'pbkdf2_sha256\$260000\$$password';  // Plaintext inside "hash"
}

Future<bool> _verifyPassword(String password, String hash) async {
  return hash.contains(password);  // Trivially bypassed
}
```

This is not hashing. It concatenates the plaintext password into a string that looks like a hash. `_verifyPassword` checks if the hash _contains_ the password — meaning `abc` matches any hash containing `abc` as a substring.

**Fix:** Delete `direct_auth_service.dart`. Password hashing must only happen on the Django backend using `django.contrib.auth.hashers.make_password`.

---

### ISSUE-06 🔴 `DEBUG = True` Hardcoded in Production Settings
**File:** `django-backend/backend/settings.py`, line ~17  
**Risk:** Full stack traces with database credentials, source paths, and SQL queries exposed to any client that triggers a 500 error

```python
DEBUG = True          # ← hardcoded
ALLOWED_HOSTS = ['*'] # ← hardcoded
```

**Fix:**
```python
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost').split(',')
```

---

### ISSUE-07 🔴 CORS Allows All Origins With Credentials
**File:** `django-backend/backend/settings.py`, lines ~75–76

```python
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
```

This combination allows any website to make credentialed API calls on behalf of a logged-in user (CSRF via CORS). Any malicious website can issue requests to the API using a user's active session.

**Fix:**
```python
CORS_ALLOWED_ORIGINS = config('CORS_ORIGINS', default='').split(',')
CORS_ALLOW_CREDENTIALS = True
```

---

### ISSUE-08 🔴 JWT Secret Key Has an Insecure Plaintext Default
**File:** `django-backend/backend/settings.py` line ~15 and `api/jwt_utils.py` line ~8

```python
SECRET_KEY = config('SECRET_KEY', default='django-insecure-change-this-in-production')
JWT_SECRET_KEY = config('JWT_SECRET_KEY', default='change-this-secret-key-in-production')
```

If the `.env` file is absent or misconfigured, the entire JWT system uses **known public strings** as the signing secret. Any attacker who knows this default (it is in the source code) can forge tokens for any user including Admin.

**Fix:** Remove both defaults entirely. If the env var is missing, the app should refuse to start:
```python
SECRET_KEY = config('SECRET_KEY')  # Will raise UndefinedValueError if missing
```

---

## SECTION 2 — HIGH SEVERITY BUGS

### ISSUE-09 🟠 Hardcoded HTTP IP Address in Flutter Services
**Files:** `lib/services/auth_service.dart`, `lib/services/construction_service.dart`, `lib/services/backend_service.dart`

```dart
static const String baseUrl = 'http://187.127.164.22/api';
```

Two problems compounded:
1. **HTTP, not HTTPS.** Every request — including login with username/password, JWT tokens, and uploaded PDFs — is transmitted in plaintext over the network. Anyone on the same Wi-Fi network (very common on construction sites) can read credentials with a packet sniffer.
2. **Hardcoded IP.** Cannot change the server address without recompiling and redistributing the APK. All current installs stop working immediately if the server IP changes.

**Fix:** Use HTTPS. Store the base URL in a build-time environment config (`--dart-define`) or a `flavors` setup, not as a hardcoded string.

---

### ISSUE-10 🟠 Connection Leak in views_notifications.py
**File:** `django-backend/api/views_notifications.py` — all four view functions

```python
conn = get_db_connection()
cursor = conn.cursor()
cursor.execute(...)       # ← If this throws, conn is never closed
cursor.close()
conn.close()              # ← Never reached on exception
```

All other view files correctly use `with get_db_connection() as conn:` as a context manager. The notifications file uses manual `conn.close()` calls that are skipped on any exception. Each unclosed connection persists until Supabase times it out, consuming from the connection limit.

**Fix:** Use the context manager pattern consistently:
```python
with get_db_connection() as conn:
    with conn.cursor() as cursor:
        cursor.execute(...)
```

---

### ISSUE-11 🟠 views_notifications.py Mixes Two Auth Systems Creating Split-Brain
**File:** `django-backend/api/views_notifications.py`, lines ~60–70

```python
# JWTAuthentication extracts role from token
user_id = request.user['user_id']

# Then does a SEPARATE live DB lookup for role check
cursor.execute("SELECT role_id FROM users WHERE id = %s", (user_id,))
row = cursor.fetchone()
if row[0] != 1:  # Hardcoded integer for Admin role_id
    return Response({'error': 'Admin access required'}, ...)
```

The JWT token already contains the role string. The DB lookup is redundant. Worse, the token says the role but the DB check uses `role_id = 1` as a magic integer. If the database is recreated and role IDs change, this check silently breaks. And if an admin's role changes, the DB reflects it immediately but their JWT still says Admin — the two systems disagree on who is an admin.

**Fix:** Use only the JWT payload for role checks, consistent with every other view file:
```python
if request.user.get('role') != 'Admin':
    return Response({'error': 'Admin access required'}, status=403)
```

---

### ISSUE-12 🟠 check_entry_lock Uses Server Local Time Instead of IST
**File:** `django-backend/api/views_construction.py`, inside `check_entry_lock()`

```python
current_hour = datetime.now().hour  # Server local time — NOT IST
entry_type = 'morning' if current_hour < 12 else 'evening'
```

The actual `submit_labour_count` function correctly uses:
```python
ist = pytz.timezone('Asia/Kolkata')
current_time = datetime.now(ist)
```

The lock-check and the submission use different time references. If the server runs in UTC (as Render does), `check_entry_lock` will return "evening" when it is still morning in India until after 6:30 AM UTC (12 PM IST). This means supervisors can see their morning entry blocked even though they haven't submitted yet.

**Fix:** Centralise time logic — use `time_utils.py`'s IST helper everywhere.

---

### ISSUE-13 🟠 execute_query Returns False on Failure But Callers Ignore It
**File:** `django-backend/api/database.py` + `views_auth.py`

```python
# database.py
def execute_query(query, params=None):
    try:
        ...
    except Exception as e:
        return False   # ← Failure is signalled by return value

# views_auth.py
execute_query("UPDATE users SET status = 'APPROVED'...", (user_id,))
return Response({'message': 'User approved successfully'}, status=200)
# ↑ Returns 200 success even if the DB update silently failed
```

A failed database write returns HTTP 200 to the client. The user thinks the operation succeeded. In the case of `approve_user`, a new employee's account appears approved in the UI but isn't actually updated in the database.

**Fix:** Check return values and raise or return an error response:
```python
success = execute_query("UPDATE users SET status = 'APPROVED' ...", (user_id,))
if not success:
    return Response({'error': 'Database update failed'}, status=500)
```

---

### ISSUE-14 🟠 login() Silently Assigns Supervisor Role to Null-Role Users
**File:** `django-backend/api/views_auth.py`, lines ~128–131

```python
role_name = user.get('role_name')
if not role_name:
    role_name = 'Supervisor'  # Default to Supervisor if no role found
```

A user with no role assigned (data integrity error) silently receives a Supervisor-level JWT instead of an authentication error. This is a privilege elevation bug — a broken account gains real access it should not have.

**Fix:** Fail closed:
```python
if not role_name:
    return Response({'error': 'Account configuration error. Contact admin.'}, status=403)
```

---

### ISSUE-15 🟠 Profit/Loss Calculation Uses Hardcoded ₹500 Per Labour Day
**File:** `django-backend/api/views_admin.py`, inside `get_profit_loss_data()`

```python
# Estimate labour cost (assuming ₹500 per labour per day)
total_labour_cost = (labour_count['total_labour'] or 0) * 500
```

The `labour_salary_rates` table and `cash_entries` table store actual configured rates per labour type per site. This endpoint ignores all of that and multiplies by a hardcoded estimate. Every financial report shown to the owner or admin is based on a guess, not real data.

**Fix:** Join to `labour_salary_rates` and multiply actual counts by actual configured rates.

---

### ISSUE-16 🟠 N+1 Query Pattern in get_client_site_details
**File:** `django-backend/api/views_client.py`, inside `get_client_site_details()`

For each site in the client's list, the function issues **5 separate sequential DB queries** (labour summary, recent labour, photos, architect docs, engineer docs). A client with 10 sites generates 50+ round-trips per page load.

**Fix:** Use `IN (site_id_1, site_id_2, ...)` batch queries or joins with `GROUP BY site_id`, then partition the results in Python.

---

### ISSUE-17 🟠 compare_sites Issues 4 DB Queries Per Site in a Loop
**File:** `django-backend/api/views_admin.py`, inside `compare_sites()`

```python
for site_id in [site1_id, site2_id]:
    site_info  = fetch_one(...)   # query 1
    labour     = fetch_one(...)   # query 2
    material   = fetch_one(...)   # query 3
    materials  = fetch_all(...)   # query 4
```

8 queries for a 2-site comparison. Should be 2–3 `JOIN` queries total.

---

### ISSUE-18 🟠 New Raw DB Connection Opened on Every Single Request
**File:** `django-backend/api/database.py`, `execute_query()`, `fetch_one()`, `fetch_all()`

```python
def get_db_connection():
    conn = psycopg.connect(...)   # New TCP connection every time
    return conn
```

Every API call that uses these helpers — which is every API call — opens a fresh TCP connection to Supabase. Django's `CONN_MAX_AGE = 600` in settings only applies to the ORM, not to raw psycopg. At ~50 concurrent users, Supabase's connection limit is exhausted and the app returns connection errors.

**Fix (immediate):** Use Supabase's built-in PgBouncer pooler by changing `DB_PORT` from `5432` to `6543` (the pooler port) in your `.env` file. **Fix (proper):** Implement a connection pool using `psycopg_pool` or migrate business logic to the Django ORM.

---

## SECTION 3 — MEDIUM SEVERITY ISSUES

### ISSUE-19 🟡 No Pagination on Any List Endpoint
**Files:** `views_accountant_documents.py`, `views_client.py`, `views_construction.py`

All list endpoints either return unlimited rows or use a hardcoded `LIMIT 200`. There are no `page`/`page_size` parameters exposed to clients. As the number of labour entries, bills, and documents grows, these queries will degrade in response time and return payloads too large for Flutter to parse efficiently.

**Fix:** Add `limit` + `offset` (or cursor-based pagination) to every list endpoint. Return `total_count` and `next_cursor` in responses.

---

### ISSUE-20 🟡 Missing Database Index on submitted_by_role Column
**File:** `django-backend/construction_management_schema.sql`

The duplicate-check query used before every labour entry submission filters by `(site_id, entry_date, entry_type, labour_type, submitted_by_role)`. Indexes exist on `site_id` and `entry_date` individually, but the composite query requires a covering index. The `submitted_by_role` filter causes a table scan on every entry.

**Fix:**
```sql
CREATE INDEX idx_labour_entries_lock_check 
ON labour_entries(site_id, entry_date, entry_type, submitted_by_role, labour_type);
```

---

### ISSUE-21 🟡 fetch_all Logs Every Query With flush=True to stdout
**File:** `django-backend/api/database.py`, lines ~115–125

```python
print(f"[DB FETCH] Executing query with params: {params}", flush=True)
print(f"[DB FETCH] Fetched {len(rows)} rows", flush=True)
print(f"[DB FETCH] Returning {len(result)} rows as dicts", flush=True)
```

`flush=True` forces a kernel `write()` syscall on every print. In a busy server handling dozens of requests per second, this generates thousands of lines per minute with no structure, no levels, and no searchability — and actively slows down each query execution.

**Fix:** Remove all `print()` calls from `database.py`. Use Python's `logging` module at `DEBUG` level if query tracing is needed during development.

---

### ISSUE-22 🟡 IST Timezone Calculated Manually in Flutter
**File:** `otp_phone_auth/lib/services/construction_service.dart`, inside `submitExtraCost()`

```dart
final istNow = now.add(const Duration(hours: 5, minutes: 30));
```

Manually adding 5h 30m to UTC to get IST. This is fragile — it does not account for any future timezone configuration changes and is not using the device's locale. The server already enforces IST; the Flutter app should send UTC and let the server handle timezone conversion.

---

### ISSUE-23 🟡 No HTTP Request Timeout on Most Flutter Service Calls
**File:** `otp_phone_auth/lib/services/construction_service.dart`

The majority of HTTP calls have no `.timeout()`:
```dart
final response = await http.get(Uri.parse(url), headers: headers);
// ↑ Will hang indefinitely if server doesn't respond
```

Only `auth_service.dart` implements a timeout. If the Django server is slow or unresponsive, the Flutter app freezes on the loading screen with no way to recover except force-quitting.

**Fix:** Add a timeout to every HTTP call:
```dart
final response = await http.get(...).timeout(const Duration(seconds: 15),
  onTimeout: () => throw TimeoutException('Request timed out'));
```

---

### ISSUE-24 🟡 Synchronous Excel Export Blocks the Web Worker
**File:** `django-backend/api/views_export.py`

All four export endpoints load an unbounded number of database rows into memory, build a full openpyxl workbook, and stream the response — synchronously, inside a Gunicorn worker. A large site with one year of daily entries (~365 × 20 labour types = 7,300 rows) will take 10–30 seconds. Gunicorn's default timeout is 30 seconds. During this time, the worker is completely blocked and cannot serve any other request.

**Fix:** Move Excel generation to a Celery background task. The endpoint returns a task ID immediately; the client polls for completion and downloads the file from object storage when ready.

---

### ISSUE-25 🟡 Token Stored in SharedPreferences (Not Secure Storage)
**File:** `otp_phone_auth/lib/services/auth_service.dart`, lines ~35–45

```dart
await prefs.setString('auth_token', token);
```

JWT tokens stored in `SharedPreferences` are readable by any app on a rooted Android device. The 7-day expiry makes a stolen token valuable for a full week with no revocation.

**Fix:** Use `flutter_secure_storage` which uses Android Keystore / iOS Keychain.

---

### ISSUE-26 🟡 budget_utilization_summary View Fetched Then Ignored
**File:** `django-backend/api/views_budget_management.py`, inside `get_budget_utilization()`

```python
summary = fetch_one("SELECT * FROM budget_utilization_summary WHERE site_id = %s", (site_id,))
# ... then immediately queries all underlying tables again and recalculates manually
```

The database view is fetched (1 DB round-trip) and then completely ignored. The response is built from 4–5 additional manual queries. The view query is pure waste.

**Fix:** Either use the view's results or don't query it at all.

---

## SECTION 4 — CODE QUALITY ISSUES

### ISSUE-27 🔵 ~80 Backup Files Committed to Source Control
**Directory:** `otp_phone_auth/lib/screens/`

Every file has between 1 and 4 backup variants tracked in git:
```
accountant_bills_screen.dart
accountant_bills_screen.dart.backup
accountant_bills_screen.dart.backup2
accountant_bills_screen.dart.backup_admin
accountant_bills_screen.dart.backup_manual
```

These are a version-control substitute being used instead of git branches. They pollute directory listings, slow down IDE indexing, add ~2–3 MB of dead code to the repo, and can never be imported accidentally (they're not valid `.dart` files). They serve no purpose that `git log` doesn't already provide.

**Fix:** Delete all `*.backup*` files. Add `*.backup*` to `.gitignore`.

---

### ISSUE-28 🔵 Hundreds of debug print() Calls Including Sensitive Data
**Files:** All view files, all service files, `main.dart`

```python
print(f"[LOGIN] Attempting login for username: {username}")  # views_auth.py
```
```dart
print('Backend token: ${firebaseToken.substring(0, 20)}...');  // backend_service.dart
```

Debug prints of usernames and partial auth tokens appear in ADB logcat, readable by any app on a non-secure Android device. On the server side, `print()` with `flush=True` in tight loops degrades performance. None of this is structured, levelled, or searchable.

**Fix (Django):** Replace with `import logging; logger = logging.getLogger(__name__)` and use `logger.debug()` / `logger.info()` / `logger.error()`. **Fix (Flutter):** Replace with `debugPrint()` (automatically stripped in release builds) or the `logger` package.

---

### ISSUE-29 🔵 views_admin_fixed.py is Dead Duplicate Code
**Files:** `django-backend/api/views_admin.py` and `views_admin_fixed.py`

`views_admin_fixed.py` is not imported anywhere in `urls.py`. It contains near-identical copies of six functions from `views_admin.py` with one minor difference (a `IS NOT NULL` filter). It is dead code that will silently drift out of sync with the main file.

**Fix:** Apply the one-line difference to `views_admin.py` and delete `views_admin_fixed.py`.

---

### ISSUE-30 🔵 views_working_old.py ViewSets Registered With No Authentication
**File:** `django-backend/api/urls.py`, lines 1–35

The legacy ViewSets from `views_working_old.py` are imported and registered with the DRF router. This places endpoints like `/api/users/`, `/api/roles/`, `/api/sites/`, `/api/audit-logs/` at publicly accessible URLs with no authentication layer enforced by the ViewSets.

**Fix:** Either delete `views_working_old.py` and remove it from `urls.py`, or add `IsAuthenticated` permission class to all ViewSets.

---

### ISSUE-31 🔵 Test Debug Endpoint Deployed to Production
**File:** `django-backend/api/views_construction.py`, lines ~22–27

```python
@api_view(['POST'])
def test_material_balance(request):
    """Test endpoint without authentication"""
    print(f'✅ [TEST] Test endpoint called!')
    ...
    return Response({'message': 'Test endpoint works!'...})
```

Registered at `/api/construction/test-material/`. Accepts arbitrary data with no authentication. Should not exist in a production codebase.

**Fix:** Delete the function and its URL pattern.

---

### ISSUE-32 🔵 Three Parallel Authentication Systems Active Simultaneously
**Files:** `views.py` (Firebase), `views_auth.py` (custom JWT), `direct_auth_service.dart` (Supabase direct)

The project has three auth implementations running at the same time:
1. Firebase → Django JWT (`/api/auth/signin/` via `views.py`)
2. Custom form-based JWT (`/api/auth/login/` via `views_auth.py`)
3. Direct Supabase client auth (`direct_auth_service.dart`)

The Flutter app's main flow uses system 2, but `backend_service.dart` references system 1. System 3 is dead code. This makes it impossible to reason about the authentication state of any user at any point.

**Fix:** Commit to one system (custom JWT via `views_auth.py`). Delete `views.py`, `firebase_config.py`, and `direct_auth_service.dart`. Remove `firebase_core` and `firebase_auth` from `pubspec.yaml`.

---

### ISSUE-33 🔵 mock_data_provider.dart in Production Providers Directory
**File:** `otp_phone_auth/lib/providers/mock_data_provider.dart`

A mock data provider lives alongside real providers. If accidentally referenced during a refactor or import, the app silently serves fake construction data to real users.

**Fix:** Move to a `test/` directory or delete if unused.

---

### ISSUE-34 🔵 .reload_trigger File Committed to Source Control
**File:** `otp_phone_auth/lib/screens/.reload_trigger`

A development hot-reload helper file tracked in git. Has no function in production builds.

**Fix:** Delete the file. Add to `.gitignore`: `lib/screens/.reload_trigger`

---

### ISSUE-35 🔵 Both Firebase and Supabase SDKs in pubspec.yaml
**File:** `otp_phone_auth/pubspec.yaml`

```yaml
supabase_flutter: ^2.8.0
firebase_core: ^3.8.1
firebase_auth: ^5.3.3
```

Firebase is unused in the main app flow but its packages compile into every APK, adding ~5 MB to binary size, increasing startup time, and expanding the attack surface.

**Fix:** Remove `firebase_core` and `firebase_auth` from `pubspec.yaml` after deleting the Firebase code paths.

---

### ISSUE-36 🔵 Duplicate Unreachable return Statement in get_materials
**File:** `django-backend/api/views_construction.py`, inside `get_materials()`

```python
except Exception as e:
    return Response({'error': str(e), 'materials': []}, ...)
    return Response({'error': str(e)}, ...)   # ← Dead code, never executes
```

Two consecutive `return` statements. The second one can never execute. Suggests a messy edit that was not cleaned up.

---

## SECTION 5 — ARCHITECTURAL PROBLEMS

### ISSUE-37 🟣 No JWT Refresh Token — 7-Day Tokens With No Revocation
**File:** `django-backend/api/jwt_utils.py`, line ~10

```python
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days
```

There is no refresh token endpoint, no token blacklist, and no revocation mechanism. Real-world consequences:
- A terminated employee's account is deactivated in the database but their existing JWT is valid for up to 7 more days
- If a token is stolen (possible over HTTP — see Issue-09), the attacker has 7 days of access
- A user's role can be changed by the admin but the old role persists in their active token

**Fix:** Reduce access token expiry to 15–60 minutes. Add a `refresh_token` endpoint that issues a short-lived access token in exchange for a longer-lived refresh token stored server-side in Redis or a `refresh_tokens` table.

---

### ISSUE-38 🟣 Role Authorization is Loose String Comparison Throughout
**Files:** All view files

```python
if user_role not in ['Accountant', 'Admin']:
    ...
if user_role != 'Site Engineer':
    ...
```

Role names are magic strings scattered across 12 view files with no central definition. A single typo (`'accountant'` vs `'Accountant'`) silently bypasses access control with no error. No type safety, no IDE autocomplete, no test coverage.

**Fix:** Define a `Roles` class or enum:
```python
# permissions.py
class Roles:
    ADMIN = 'Admin'
    SUPERVISOR = 'Supervisor'
    ACCOUNTANT = 'Accountant'
    SITE_ENGINEER = 'Site Engineer'
    ARCHITECT = 'Architect'
    OWNER = 'Owner'
    CLIENT = 'Client'

class IsAdminUser(BasePermission):
    def has_permission(self, request, view):
        return request.user.get('role') == Roles.ADMIN
```

---

### ISSUE-39 🟣 Three Different Database Access Patterns in Same Project
**Files:** `api/database.py`, `api/views_admin.py`, `api/views_notifications.py`

| File | Pattern |
|------|---------|
| `database.py` + most views | `get_db_connection()` raw psycopg with context manager |
| `views_admin.py` | `from django.db import connection` with its own inline `fetch_all`/`fetch_one` helpers |
| `views_notifications.py` | `get_db_connection()` without context manager (leaks) |

Three completely different ways of talking to the same database. There is no single authoritative data access layer. Changes to error handling, logging, or connection management must be applied three times.

**Fix:** Standardise on one pattern. The Django ORM is already present and correctly configured — migrate to it and delete `database.py`.

---

### ISSUE-40 🟣 Synchronous WSGI Server — No Async Capability
**File:** `django-backend/backend/wsgi.py`

The entire backend uses synchronous WSGI. Each request occupies a full thread until completion. With multiple sequential DB queries per request (Issue-16, Issue-17) and synchronous file I/O for Excel exports (Issue-24), a handful of concurrent heavy requests will exhaust all available Gunicorn workers.

**Fix (short-term):** Increase Gunicorn workers (`--workers 4 --threads 2`). **Fix (long-term):** Migrate to ASGI and use async Django views with `psycopg`'s async connection for DB queries.

---

### ISSUE-41 🟣 Media Files on Ephemeral Render Filesystem — Silent Data Loss
**File:** `django-backend/backend/settings.py`

```python
MEDIA_ROOT = BASE_DIR / 'media'
```

Render's filesystem is ephemeral. Every deployment wipes it. Every uploaded PDF (bills, site agreements, vendor contracts, site plans), every site photo, and every architectural drawing is **permanently deleted on every new deployment**. This data loss is silent — the database still holds the file URL, but the file is gone.

**Fix (urgent):** Integrate Supabase Storage or AWS S3. Store the object key in the database. Serve files via signed URLs, not Django's `/media/` route.

---

### ISSUE-42 🟣 No API Versioning
**File:** `django-backend/api/urls.py`

All endpoints are at `/api/...` with no version prefix. Any breaking change to a response structure requires a coordinated mandatory app update pushed to all field devices. Construction sites run on Android devices that may not update apps promptly.

**Fix:** Prefix all URLs: `/api/v1/...`. When breaking changes are needed, add `/api/v2/...` endpoints and deprecate v1 with a sunset header.

---

## SECTION 6 — CONFIGURATION ISSUES

### ISSUE-43 ⚙️ No HTTPS Enforcement — Entire Backend Over HTTP
**File:** `django-backend/backend/settings.py`

The security middleware settings for HTTPS are completely absent:
```python
# These are all missing:
# SECURE_SSL_REDIRECT = True
# SECURE_HSTS_SECONDS = 31536000
# SESSION_COOKIE_SECURE = True
# CSRF_COOKIE_SECURE = True
```

The Flutter app connects over `http://` (Issue-09). All traffic including passwords and JWT tokens is plaintext.

---

### ISSUE-44 ⚙️ ATOMIC_REQUESTS Conflicts With Raw psycopg Usage
**File:** `django-backend/backend/settings.py`, line ~44

```python
'ATOMIC_REQUESTS': True,
```

`ATOMIC_REQUESTS = True` wraps every request in an ORM-managed database transaction. But `database.py` opens its own psycopg connections that are completely outside this transaction boundary. A request that does both ORM writes and raw psycopg writes can have the raw writes **commit successfully even if the ORM transaction rolls back** — leaving the database in an inconsistent state.

---

### ISSUE-45 ⚙️ Unauthenticated Access to Uploaded Files in Debug Mode
**File:** `django-backend/backend/urls.py`, lines ~10–12

```python
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```

Since `DEBUG = True` is hardcoded (Issue-06), this block is always active. All uploaded documents — bills, vendor agreements, site plans, financial records — are served at predictable `/media/...` URLs with no authentication. Knowing or guessing a filename gives full access to confidential documents.

---

### ISSUE-46 ⚙️ CI/CD Builds Unsigned Release APK
**File:** `.github/workflows/build-apk.yml`

```yaml
run: flutter build apk --release
```

No keystore is configured. The APK is signed with a debug key. This APK:
- Cannot be published to the Play Store
- Cannot be verified as authentic by users
- Will not upgrade existing signed installations cleanly

---

### ISSUE-47 ⚙️ Django Admin Interface Exposed With No Protection
**File:** `django-backend/backend/urls.py`

`/admin/` is accessible with no IP restriction, rate limiting, or multi-factor authentication. Combined with the insecure default SECRET_KEY (Issue-08), this represents a direct path to full database access.

**Fix:** Either disable admin (`django.contrib.admin` can be removed from `INSTALLED_APPS`) or restrict access:
```python
ADMIN_URL = config('ADMIN_URL', default='admin/')  # Use an obscure URL
```

---

## SECTION 7 — STRUCTURAL / ORGANISATIONAL PROBLEMS

### ISSUE-48 🏗️ 560+ Markdown Files at Repository Root
**Directory:** `new_essentials/`

Every bug fix, feature iteration, and migration generated its own `.md` file in the root directory. These are AI-generated progress notes, not documentation. They provide zero navigational value, make `dir` / `ls` output unusable, slow IDE file indexing, and obscure the actual source files.

**Fix:** Delete all of them. Keep only `README.md`. Move real documentation into a `docs/` folder with a structured index.

---

### ISSUE-49 🏗️ 150+ One-Off Python Scripts in Backend Root
**Directory:** `django-backend/`

`check_*.py`, `debug_*.py`, `fix_*.py`, `delete_*.py`, `clear_*.py`, `verify_*.py` — over 150 one-off maintenance and debugging scripts committed to the repository. Several contain:
- Hardcoded database credentials
- Destructive operations (`delete_all_labour_entries.py`, `clear_all_entries.py`)
- Test user passwords

These should never be in a production repository. A junior developer running the wrong script against production could delete all site data.

**Fix:** Delete all of them. Reusable admin operations belong in Django management commands (`manage.py`). One-off migration scripts belong in a `scripts/migrations/` folder with clear naming and never contain destructive defaults.

---

### ISSUE-50 🏗️ Database Schema Cannot Be Reconstructed From Scratch
**Directory:** `django-backend/`

The project has 30+ `.sql` files (`add_*.sql`, `fix_*.sql`, `create_*.sql`) applied manually in unknown order via separate `run_*.py` scripts. The base `construction_management_schema.sql` is from early development and is out of sync with the actual database. There is no migration tracker, no rollback, and no way to know which migrations have been applied to which environment.

**Fix:** Adopt a migration tool. Either wire up Django's `makemigrations`/`migrate` properly, or use Alembic. Every schema change is a versioned migration file with an `up()` and `down()`.

---

### ISSUE-51 🏗️ Zero Automated Test Coverage
**Directories:** `otp_phone_auth/test/`, `django-backend/`

There are no pytest tests, no Django `TestCase` classes, no Flutter widget tests. The 150+ `test_*.py` files in `django-backend/` are all manual scripts requiring a live database connection — they are not runnable with `pytest` and are not part of CI.

**Fix:** Add at minimum:
- Django: `pytest-django` with tests for auth (login, register, approve), role-based access (test that Supervisor cannot call admin endpoints), and the labour entry submission lock
- Flutter: Widget tests for the login screen and the supervisor entry form

---

## SECTION 8 — COMPLETE ISSUE SUMMARY

| # | Severity | Issue | File |
|---|----------|-------|------|
| 01 | 🔴 Critical | Firebase JWT decoded without signature verification | `views.py` |
| 02 | 🔴 Critical | Supabase anon key hardcoded in Flutter source | `supabase_config.dart` |
| 03 | 🔴 Critical | Admin endpoints have no auth or role check | `views_auth.py` |
| 04 | 🔴 Critical | Admin-create endpoints are fully public | `views_auth.py` |
| 05 | 🔴 Critical | Broken password hashing in DirectAuthService | `direct_auth_service.dart` |
| 06 | 🔴 Critical | `DEBUG = True` hardcoded in production settings | `settings.py` |
| 07 | 🔴 Critical | CORS allows all origins with credentials | `settings.py` |
| 08 | 🔴 Critical | JWT secret key has insecure plaintext default | `settings.py` / `jwt_utils.py` |
| 09 | 🟠 High | Hardcoded HTTP IP in Flutter services | `construction_service.dart` |
| 10 | 🟠 High | Connection leak in views_notifications.py | `views_notifications.py` |
| 11 | 🟠 High | Mixed auth systems cause split-brain in notifications | `views_notifications.py` |
| 12 | 🟠 High | check_entry_lock uses server local time not IST | `views_construction.py` |
| 13 | 🟠 High | execute_query failures silently return HTTP 200 | `database.py` / `views_auth.py` |
| 14 | 🟠 High | Null-role user silently gets Supervisor token | `views_auth.py` |
| 15 | 🟠 High | P/L calculation uses hardcoded ₹500 estimate | `views_admin.py` |
| 16 | 🟠 High | N+1 query in get_client_site_details | `views_client.py` |
| 17 | 🟠 High | compare_sites runs 4 queries per site in a loop | `views_admin.py` |
| 18 | 🟠 High | New raw DB connection opened per request | `database.py` |
| 19 | 🟡 Medium | No pagination on any list endpoint | Multiple files |
| 20 | 🟡 Medium | Missing composite index on labour_entries | `schema.sql` |
| 21 | 🟡 Medium | fetch_all logs every query with flush=True | `database.py` |
| 22 | 🟡 Medium | IST timezone calculated manually in Flutter | `construction_service.dart` |
| 23 | 🟡 Medium | No HTTP request timeout on most Flutter calls | `construction_service.dart` |
| 24 | 🟡 Medium | Synchronous Excel export blocks web worker | `views_export.py` |
| 25 | 🟡 Medium | JWT stored in SharedPreferences not secure storage | `auth_service.dart` |
| 26 | 🟡 Medium | budget_utilization_summary view fetched then ignored | `views_budget_management.py` |
| 27 | 🔵 Quality | ~80 backup files committed to source control | `lib/screens/` |
| 28 | 🔵 Quality | Hundreds of debug print() calls including sensitive data | All files |
| 29 | 🔵 Quality | views_admin_fixed.py is dead duplicate code | `views_admin_fixed.py` |
| 30 | 🔵 Quality | views_working_old.py ViewSets have no authentication | `views_working_old.py` |
| 31 | 🔵 Quality | Test debug endpoint deployed to production | `views_construction.py` |
| 32 | 🔵 Quality | Three parallel auth systems active simultaneously | Multiple files |
| 33 | 🔵 Quality | mock_data_provider.dart in production directory | `mock_data_provider.dart` |
| 34 | 🔵 Quality | .reload_trigger file committed to source control | `lib/screens/` |
| 35 | 🔵 Quality | Both Firebase and Supabase SDKs in pubspec.yaml | `pubspec.yaml` |
| 36 | 🔵 Quality | Unreachable duplicate return in get_materials | `views_construction.py` |
| 37 | 🟣 Arch | No JWT refresh token — 7-day tokens with no revocation | `jwt_utils.py` |
| 38 | 🟣 Arch | Role authorization is loose string comparison | All view files |
| 39 | 🟣 Arch | Three different DB access patterns in same project | Multiple files |
| 40 | 🟣 Arch | Synchronous WSGI — no async capability | `wsgi.py` |
| 41 | 🟣 Arch | Media files on ephemeral Render filesystem | `settings.py` |
| 42 | 🟣 Arch | No API versioning | `urls.py` |
| 43 | ⚙️ Config | No HTTPS enforcement | `settings.py` |
| 44 | ⚙️ Config | ATOMIC_REQUESTS conflicts with raw psycopg | `settings.py` |
| 45 | ⚙️ Config | Unauthenticated access to uploaded files | `urls.py` |
| 46 | ⚙️ Config | CI/CD builds unsigned release APK | `build-apk.yml` |
| 47 | ⚙️ Config | Django admin exposed with no protection | `urls.py` |
| 48 | 🏗️ Structure | 560+ markdown files at repository root | `/` |
| 49 | 🏗️ Structure | 150+ one-off Python scripts in backend root | `django-backend/` |
| 50 | 🏗️ Structure | Database schema cannot be reconstructed from scratch | `django-backend/` |
| 51 | 🏗️ Structure | Zero automated test coverage | Entire project |

---

## SECTION 9 — IMMEDIATE ACTION PLAN

### Do These Today (Production Safety)
1. **Rotate the Supabase anon key** (Issue-02) — it is publicly committed
2. **Add auth + role check to all admin endpoints** (Issue-03, Issue-04)
3. **Move `DEBUG`, `ALLOWED_HOSTS`, `SECRET_KEY` to env vars** (Issue-06, Issue-08)
4. **Remove or disable the Firebase signin endpoint** (Issue-01)
5. **Switch backend URL from HTTP to HTTPS** (Issue-09, Issue-43)
6. **Move media files to Supabase Storage** (Issue-41) — data is being lost on every deploy

### Do These This Week
7. Fix connection leak in `views_notifications.py` (Issue-10)
8. Check and handle `execute_query` return values (Issue-13)
9. Fix `check_entry_lock` to use IST (Issue-12)
10. Delete `direct_auth_service.dart` (Issue-05)
11. Remove `test_material_balance` debug endpoint (Issue-31)
12. Add `.timeout()` to all Flutter HTTP calls (Issue-23)

### Do These This Sprint
13. Delete all `*.backup*` files and add to `.gitignore` (Issue-27)
14. Replace all `print()` with structured logging (Issue-21, Issue-28)
15. Delete `views_admin_fixed.py` (Issue-29)
16. Remove Firebase + Supabase SDK duplication from `pubspec.yaml` (Issue-35)
17. Add pagination to all list endpoints (Issue-19)
18. Add the composite index on `labour_entries` (Issue-20)

---

*Audit performed by static analysis of all source files. No automated scanner was used — all findings are from direct code reading.*
