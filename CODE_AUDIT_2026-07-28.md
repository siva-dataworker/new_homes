# Code Audit — July 28, 2026

**Scope**: Fresh, independent read of the live source code (Django backend + Flutter frontend) — not a summary of prior `*_AUDIT_REPORT.md` files in this repo. Those older reports were spot-checked only to avoid re-reporting genuinely-fixed issues; every finding below was verified against the current code.

**How to use this doc**: Issues are grouped by area, ranked by severity within each group, and each has a numbered ID (e.g. `BE-01`) for tracking. Check the box and note the commit/date when you fix one. Suggested execution order is at the bottom.

**Summary**:

| Area | Critical | High | Medium | Low |
|---|---|---|---|---|
| Backend (security/correctness/perf) | 3 | 4 | 4 | 0 |
| Frontend performance | 0 | 5 | 3 | 3 |
| Frontend UI/UX consistency | 0 | 3 | 4 | 2 |

---

## PART 1 — Backend (Django) — Security & Correctness

### 🔴 CRITICAL

#### `[ ]` BE-01 — Privilege escalation: any logged-in user can promote themselves to Admin
**Files**: `django-backend/api/views_working_old.py:54-58`, `django-backend/api/urls.py:32`, `django-backend/api/serializers.py:18-25`

**Problem**: `UserViewSet` (a full `ModelViewSet` — GET/POST/PUT/PATCH/DELETE) is routed live at `/api/users/` with only `permission_classes = [IsAuthenticated]` — no role check. `UserSerializer` makes `role` and `is_active` **writable** fields.

**Failure scenario**: Any authenticated Supervisor sends `PATCH /api/users/<their_id>/ {"role": <admin_role_id>}` and becomes Admin. Or `GET /api/users/` to dump every user's name/email/phone/role. Or `DELETE /api/users/<id>/` to remove any account.

**Steps to fix**:
1. Open `api/urls.py`, remove or comment out the router registrations for `UserViewSet` and the other sensitive ViewSets (`SiteViewSet`, `MaterialBillViewSet`, `ComplaintViewSet`, `AuditLogViewSet`, `AdminRoleChangeLogViewSet`) at lines 31-45, since real user/site/bill/complaint CRUD already exists properly-gated in `views_admin.py`/`views_auth.py`/etc.
2. If any of these ViewSets are actually still needed, instead: add `permission_classes = [IsAuthenticated]` **plus** a custom permission class checking `request.user['role'] == 'Admin'`, and add `read_only_fields = ['role', 'is_active']` to `UserSerializer`.
3. Grep the Flutter app for any call to `/api/users/` to confirm nothing legitimate depends on this route before removing it: `grep -r "api/users/" otp_phone_auth/lib`.
4. Deploy and manually verify `PATCH /api/users/<id>/` now returns 403/404 for a non-admin token.

---

#### `[ ]` BE-02 — 12 admin endpoints reachable with zero authentication token
**Files**: `django-backend/api/views_admin.py` — `get_all_sites` (58), `get_site_metrics` (109), `get_labour_count_data` (147), `get_bills_data` (183), `get_total_material_purchases` (291), `get_site_documents` (327), `compare_sites` (375), `update_site_metrics` (466), `specialized_login` (472), `get_work_notifications` (478), `mark_notification_read` (484), `upload_site_document` (490); `django-backend/backend/settings.py:156-169`

**Problem**: `REST_FRAMEWORK` settings never set `DEFAULT_PERMISSION_CLASSES`, so DRF defaults to `AllowAny`. These 12 view functions have no `@authentication_classes`/`@permission_classes` decorator at all, unlike their siblings in the same file (e.g. `get_profit_loss_data` at line 226 does it correctly).

**Failure scenario**: An unauthenticated request to `GET /api/admin/sites/<id>/bills/` or `/material-purchases/` returns full financial data for any site, no login required.

**Steps to fix**:
1. In `backend/settings.py`, inside the `REST_FRAMEWORK` dict (around line 156), add:
   ```python
   'DEFAULT_PERMISSION_CLASSES': ['rest_framework.permissions.IsAuthenticated'],
   ```
   This is defense-in-depth — closes the hole even if a future view forgets the decorator.
2. For each of the 12 functions listed above, add the standard pattern already used elsewhere in the same file:
   ```python
   @api_view(['GET'])  # or appropriate methods
   @authentication_classes([JWTAuthentication])
   @permission_classes([IsAuthenticated])
   def get_all_sites(request):
       if request.user['role'] != 'Admin':
           return Response({'error': 'Admin access required'}, status=403)
       ...
   ```
3. Test each of the 12 endpoints with no `Authorization` header — confirm 401, not 200.

---

#### `[ ]` BE-03 — Unrestricted file upload (no type/extension validation)
**Files**: `django-backend/api/views_construction.py:2654-2721` (`upload_site_photo`), `:4368` (`supervisor_upload_photos`), `:3419` (`upload_project_file`); `django-backend/api/views_site_engineer.py` (work-activity/complaint-rectification uploads)

**Problem**: `ext = os.path.splitext(photo.name)[1]` takes the client-supplied filename extension verbatim and uses it to build the stored filename/URL. No server-side check of `photo.content_type` or a file-type whitelist.

**Failure scenario**: A caller uploads a `.html` or `.svg` file as a "photo" — stored and served under `MEDIA_URL`, enabling stored XSS if ever rendered/opened directly, or just arbitrary file hosting on your infrastructure.

**Steps to fix**:
1. Add a shared validator function in `api/database.py` or a new `api/validators.py`:
   ```python
   ALLOWED_IMAGE_TYPES = {'image/jpeg', 'image/png', 'image/webp'}
   ALLOWED_IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp'}

   def validate_image_upload(uploaded_file):
       ext = os.path.splitext(uploaded_file.name)[1].lower()
       if ext not in ALLOWED_IMAGE_EXTENSIONS:
           raise ValueError(f'Unsupported file extension: {ext}')
       if uploaded_file.content_type not in ALLOWED_IMAGE_TYPES:
           raise ValueError(f'Unsupported content type: {uploaded_file.content_type}')
   ```
2. Call `validate_image_upload(photo)` at the top of every photo-upload view listed above, returning a 400 on `ValueError`.
3. Generate the stored filename server-side with `uuid.uuid4()` + the validated extension — never reuse the client-supplied name directly (also closes a path-traversal risk if `photo.name` ever contains `../`).
4. Apply the same pattern (with a PDF/doc whitelist) to `upload_project_file` and the site-engineer upload endpoints — only the material-bill upload currently checks `.endswith('.pdf')`.

---

### 🟠 HIGH

#### `[ ]` BE-04 — Two live endpoints are broken in production (MySQL syntax against PostgreSQL)
**Files**: `django-backend/api/views_site_engineer.py:141-213` (`upload_work_activity`), `:256-310` (`upload_complaint_rectification`)

**Problem**: `cursor.lastrowid` (lines 175, 206, 298) and `CURDATE()` (lines 278, 296) are MySQL-only — this backend runs on `psycopg3`/PostgreSQL, where these will raise `AttributeError`/`UndefinedFunction`. Every call 500s. Separately, the uploaded image is never actually saved — a fabricated path string is stored instead (line 184 has a literal `# TODO: Actually save the image file`).

**Steps to fix**:
1. Replace every `CURDATE()` with `CURRENT_DATE` in the SQL strings at lines 278 and 296.
2. Replace `cursor.lastrowid` usage: change the `INSERT` statements to end with `RETURNING report_id` (or `activity_id`, matching the actual PK column name), then do `new_id = cursor.fetchone()[0]` instead of reading `.lastrowid`.
3. Implement the actual file save at line 184 — copy the pattern from `upload_site_photo` in `views_construction.py:2654-2721` (validate with `BE-03`'s new validator, save via `default_storage.save()`, store the real returned path).
4. Manually test both endpoints end-to-end (call from the Flutter app or curl) after the fix — they've apparently never worked, so there's no regression risk in changing them, only verification needed.

---

#### `[ ]` BE-05 — Pagination is silently broken everywhere — `total_count` always reports 0
**File**: `django-backend/api/database.py:221-249` (`paginate_query`)

**Problem**: `fetch_one(count_query, params)` returns a dict (`{'count': N}`), but line 238 does `total_count = total[0] if total else 0` — indexing a dict with an integer raises `KeyError`, silently caught by a bare `except:` at line 239, forcing `total_count = 0` always. This makes `has_more` always `False` and `total_pages` always `1` for every paginated endpoint in the app (admin site list, accountant documents, auth-related lists, etc.) — clients are told "no more pages" after page 1 even with thousands of rows remaining.

**Steps to fix**:
1. In `paginate_query`, change line 238 from:
   ```python
   total_count = total[0] if total else 0
   ```
   to:
   ```python
   total_count = total['count'] if total else 0
   ```
2. Remove or narrow the bare `except:` around it (or at minimum log it) so this class of bug surfaces immediately next time instead of silently degrading.
3. Spot-check `get_pagination_info()` (lines 252-276) output for one real endpoint (e.g. `get_all_sites` in `views_admin.py`) before/after — confirm `total_pages` now reflects real row counts.

---

#### `[ ]` BE-06 — N+1 queries in `get_approved_entries` (accountant approval screen)
**File**: `django-backend/api/views_construction.py:2093-2169`

**Problem**: For every unique site+date+source combination, two separate `fetch_one` queries run inside a loop (site info, accountant info), then a second loop issues one `fetch_all` per site — with a comment explicitly saying *"Use individual site queries if ANY() doesn't work"* instead of just using it. For 30 active sites in a day, this is 90+ sequential DB round trips for one API call.

**Steps to fix**:
1. Replace the per-site-id loop (~lines 2159-2169) with a single batched query using `WHERE site_id = ANY(%s)`, passing the full `site_ids` list as one parameter — this exact pattern is already used correctly elsewhere in the codebase (`api/views_client.py:65-169`), copy it directly.
2. Replace the inner per-entry `fetch_one` calls for site info and accountant info (lines ~2093-2132) with a single upfront batched fetch keyed by ID, then look up from an in-memory dict inside the loop instead of hitting the DB again.
3. Time the endpoint before/after with a realistic dataset (30 sites) to confirm the round-trip count and response time actually drop.

---

#### `[ ]` BE-07 — N+1 nested-loop writes in `assign_sites_to_supervisors`
**File**: `django-backend/api/views_construction.py:4630-4667`

**Problem**: Nested `for supervisor in supervisors: for site_data in sites:` does an existence-check `fetch_one` plus an `execute_query` insert/update per pair — up to `2 × supervisors × sites` round trips (10 supervisors × 20 sites = 400 queries in one request).

**Steps to fix**:
1. Replace the existence-check-then-branch logic with a single `INSERT ... ON CONFLICT (supervisor_id, site_id) DO UPDATE SET ...` per row, removing the separate `fetch_one` check entirely — this exact pattern already exists ~80 lines later in the same file at line 4744, copy it directly into this function.
2. If possible, batch all the assignment rows into one multi-row `INSERT ... VALUES (...), (...), ... ON CONFLICT ...` instead of looping row-by-row, using `execute_values` (psycopg) or building the VALUES clause dynamically.
3. Re-test the assignment flow with a realistic supervisor/site count.

---

### 🟡 MEDIUM

#### `[ ]` BE-08 — No rate limiting on login/register
**File**: `django-backend/api/views_auth.py:20-237`

**Steps to fix**:
1. `pip install django-ratelimit` and add to `INSTALLED_APPS` in `settings.py` if not already present.
2. Decorate `login` and `register` with `@ratelimit(key='ip', rate='10/m', block=True)` (tune the rate).
3. Confirm the existing "Invalid username or password" generic error message is preserved (already good — no user-enumeration leak) and that hitting the rate limit returns a clean 429, not a stack trace.

#### `[ ]` BE-09 — `ImproperlyConfigured` used but never imported — settings crash with a confusing error
**File**: `django-backend/backend/settings.py:145-150`

**Steps to fix**:
1. Add `from django.core.exceptions import ImproperlyConfigured` near the top of `settings.py` alongside the existing imports.
2. Verify by temporarily unsetting `CORS_ALLOWED_ORIGINS` locally and confirming the raised error is now the intended message, not a `NameError`.

#### `[ ]` BE-10 — Raw exception messages leaked to API clients
**Files**: `views_auth.py` (lines 98, 236, 782, 826), `views_construction.py` (455, 584, 2038, and many more), `views_admin.py`, others

**Steps to fix**:
1. Search for the pattern `Response({'error': str(e)}` across `api/*.py`: `grep -rn "'error': str(e)" django-backend/api/`.
2. For each hit in a `status=500` (server error) branch, keep the existing `logger.error(...)` call (or add one if missing) and change the response body to a fixed generic message, e.g. `Response({'error': 'Internal server error'}, status=500)`.
3. Leave `status=400`-class validation errors alone if they already return safe, specific messages (e.g. `"Missing required field: site_id"`) — the concern is only leaking internals (SQL fragments, stack details), not helpful validation text.

#### `[ ]` BE-11 — Unbounded/negative pagination inputs cause 500s instead of clean 400s
**File**: `django-backend/api/views_budget.py:254-261`, and similar `int(request.GET.get('page'/'offset', ...))` sites elsewhere

**Steps to fix**:
1. After parsing `page`/`offset`/`limit` from query params, clamp them: `page = max(1, page)`, `offset = max(0, offset)`, and cap `limit` to a sane max (e.g. `limit = min(limit, 100)`) to also prevent someone requesting `limit=999999`.
2. Apply the same clamp wherever else this pattern recurs (grep `int(request.GET.get(` across `api/*.py` to find all sites).

---

## PART 2 — Frontend (Flutter) — Performance

*(This directly addresses the "performance is slow all over screens" report — findings below are systemic, i.e. the same pattern repeats across most/all screens rather than being isolated to one flow.)*

### 🟠 HIGH

#### `[ ]` FE-01 — Every major screen is a single 2,000–4,000-line widget with no sub-widget extraction, so any small state change re-renders the entire screen
**Files**: `otp_phone_auth/lib/screens/supervisor_dashboard_feed.dart` (2069 lines, 1 build method, 31 `setState()` sites), `accountant_dashboard.dart` (2001 lines, 16 `setState()` sites), `admin_site_full_view.dart`, `site_engineer_dashboard.dart`, `client_dashboard.dart`

**Problem**: Sections like `_buildDashboard()`, `_buildStatsScreen()`, `_buildSiteListItem()` are plain private methods, not separate `Widget` classes — Flutter can't skip re-executing them on `setState()`, so toggling one dropdown re-renders the whole multi-hundred-widget tree (gradients, cards, decorations included).

**Steps to fix** (do this incrementally, one screen at a time, starting with the most-used: `supervisor_dashboard_feed.dart`):
1. Pick one `_build*()` method that returns a self-contained visual section (e.g. a card, a list item, a stats row).
2. Convert it into its own `StatelessWidget` (or `StatefulWidget` only if it needs its own local state) — pass in only the specific data/callbacks it needs, not the whole parent state.
3. Mark the new widget's constructor `const` wherever the call site's arguments are themselves const/unchanging, so Flutter can skip it entirely on unrelated rebuilds.
4. Repeat for the other `_build*()` methods in the file, prioritizing the ones inside frequently-rebuilt sections (i.e. sections that sit alongside a `setState()` call for something unrelated).
5. Move to the next screen (`accountant_dashboard.dart`, then the others) using the same process.

#### `[ ]` FE-02 — `Consumer<Provider>` wraps entire screens everywhere; `Selector` is never used (0 occurrences app-wide)
**Files**: `lib/screens/admin_labour_count_screen.dart:36`, `accountant_entry_screen.dart:1183,1442`, `accountant_reports_screen.dart:261,442`, `admin_bills_view_screen.dart:36`, `admin_material_purchases_screen.dart:53`, `admin_site_comparison_screen.dart:62`, `admin_site_documents_screen.dart:71`, `material_usage_history_screen.dart:115`, `site_engineer_dashboard.dart:197`, `site_engineer_history_screen.dart:132`, `site_engineer_reports_screen.dart:166`; providers e.g. `lib/providers/admin_provider.dart` (shared `_loadingStates` map, lines 24, 69-92, 103-126, 137-160, 171-194, 205-233)

**Problem**: Each `Consumer<X>` wraps a whole `Scaffold` body. Providers like `AdminProvider` store many independent loading flags in one shared map and call `notifyListeners()` on every change — every call rebuilds the entire wrapped subtree (AppBar, selectors, lists) regardless of which specific field changed.

**Steps to fix**:
1. For each `Consumer<Provider>` site listed above, identify the specific field(s) the wrapped subtree actually reads (e.g. just `provider.sites` or just `provider.isLoadingBills`).
2. Replace `Consumer<AdminProvider>(builder: (context, provider, child) => Scaffold(...))` with `Selector<AdminProvider, T>(selector: (context, provider) => provider.specificField, builder: (context, value, child) => Scaffold(...))`, narrowing to just the value(s) needed. Use a record/tuple selector (`(a, b)`) if a widget genuinely needs 2-3 fields.
3. Where the whole-screen `Consumer` is only there for a loading spinner around otherwise-static chrome, split into two widgets: static chrome outside any `Consumer`/`Selector`, and only the data-dependent inner section wrapped narrowly.
4. Start with the highest-traffic screens (dashboards) and work outward.

#### `[ ]` FE-03 — No cache-first loading anywhere — ~73% of screens re-fetch from network on every navigation/tab switch
**Files**: `lib/screens/admin_site_full_view.dart:69-109` (`_loadTabData`, no "already loaded" guard, no `CacheService` import at all despite being a 7-tab screen); `lib/services/cache_service.dart` (used by only 13 of 49 screens, and by **zero** of the 14 providers)

**Steps to fix**:
1. In `admin_site_full_view.dart`, add a per-tab "loaded" flag (e.g. `Set<int> _loadedTabs = {}`) and check it in the `TabController` listener before calling any `_load*Data()` method — skip the network call if already loaded for that tab, add a pull-to-refresh or explicit refresh button for the user to force a re-fetch.
2. Pick the 2-3 most-navigated screens without `CacheService` usage and wire in `CacheService.get`/`set` around their main data load, following the pattern already used in the 13 screens that do this correctly (grep those for a reference implementation: `grep -l "CacheService" lib/screens/*.dart`).
3. Longer-term (bigger effort, can be its own follow-up): move caching into the provider layer itself (none of the 14 providers currently use `CacheService`) so every screen consuming a provider gets caching for free instead of needing to opt in per-screen.

#### `[ ]` FE-04 — Photo compression blocks the UI thread and runs sequentially per photo
**File**: `lib/services/construction_service.dart:1380-1444` (`_compressImage`, called in a `for` loop with `await` inside it, no `compute()` usage anywhere in the app)

**Problem**: `img.decodeImage` → `img.copyResize` → `img.encodeJpg` are all CPU-bound and run on the main isolate. This is invoked every time a supervisor/site-engineer uploads photos — a routine, frequent action — freezing the UI for the full duration, serialized across however many photos were picked.

**Steps to fix**:
1. Extract the body of `_compressImage` into a **top-level function** (not a class method — `compute()` requires a top-level or static function) that takes the raw bytes and returns compressed bytes.
2. Replace the direct call with `await compute(compressImageIsolate, photoBytes)`.
3. Replace the sequential `for` loop with `await Future.wait(photos.map((p) => compute(compressImageIsolate, p)))` so multiple photos compress in parallel across isolates instead of one at a time.
4. Test uploading 5+ photos at once before/after — confirm the UI stays responsive (e.g. a loading spinner still animates smoothly) during compression.

#### `[ ]` FE-05 — `CachedNetworkImage` never sets `memCacheWidth`/`memCacheHeight` — thumbnails decode at full upload resolution
**Files**: 16 call sites including `accountant_entry_screen.dart:511,660`; `admin_dashboard.dart:3440,3538,3609,3759`; `admin_site_full_view.dart:1964,2060`; `client_dashboard.dart:585,699`; `site_photo_gallery_screen.dart:215,415`; `supervisor_photo_upload_screen.dart:670,735`

**Problem**: Photos are uploaded at up to 1920px width but grid thumbnails render at ~150-200dp — every thumbnail still decodes and holds the full-resolution bitmap in memory, causing scroll jank in every photo grid/gallery in the app.

**Steps to fix**:
1. For each thumbnail/grid-context `CachedNetworkImage` call, add `memCacheWidth`/`memCacheHeight` sized to the actual render size × device pixel ratio, e.g.:
   ```dart
   CachedNetworkImage(
     imageUrl: url,
     memCacheWidth: (150 * MediaQuery.of(context).devicePixelRatio).round(),
     ...
   )
   ```
2. Leave full-screen/detail-view image displays (if any) without this cap, or size them to the actual viewport instead.
3. Verify visually that thumbnails still look sharp after the change (device pixel ratio multiplication should prevent blurriness).

### 🟡 MEDIUM

#### `[ ]` FE-06 — N+1 API fan-out on Admin's "Stories" tab (one HTTP request per site)
**File**: `lib/screens/admin_dashboard.dart:3161-3232` (`_AdminStoryTab._load()`, lines 3184-3186); `lib/services/construction_service.dart:999-1015` (`getSupervisorPhotosForAccountant`, requires per-site `site_id`, no batch variant)

**Steps to fix**:
1. Preferred: add a new backend endpoint that accepts a list of site IDs and returns supervisor photos for all of them in one response (batched query, following the `ANY(%s)` pattern from `BE-06`), then update `getSupervisorPhotosForAccountant` (or add a new service method) to call it once instead of per-site.
2. If a backend change isn't feasible right now: at minimum cache `_storiesBySite` in the widget with a short TTL so re-opening the tab within a few minutes doesn't refire all N requests.

#### `[ ]` FE-07 — "God" providers mix many unrelated data domains, amplifying unnecessary rebuilds
**File**: `lib/providers/construction_provider.dart` (625 lines — owns supervisor history, accountant labour/material/extra-costs, accountant photos, supervisor photos, architect documents/complaints, sites, areas; only 3 of ~10 load methods use `SimpleCache`)

**Steps to fix**:
1. Split `ConstructionProvider` into smaller, domain-focused providers (e.g. `SupervisorHistoryProvider`, `AccountantDataProvider`, `ArchitectDataProvider`) — each with its own `notifyListeners()` scope, so a change in one domain doesn't trigger rebuilds in widgets only interested in another.
2. This is a larger refactor — pair it with FE-02 (introducing `Selector`) since splitting providers and narrowing subscriptions solve the same root problem from two angles. Consider doing FE-02 first (cheaper, immediate) and treat this as a follow-up.
3. While splitting, extend `SimpleCache` usage to the remaining ~7 load methods that currently lack it.

#### `[ ]` FE-08 — Data reshaping (grouping/sorting) recomputed on every build instead of memoized
**File**: `lib/screens/admin_site_full_view.dart:1795-1820` (`_buildPhotosWithDropdown`, called from a plain `ListView(children: ...)` that re-executes on every `setState()` in the class, not just photo-related ones)

**Steps to fix**:
1. Add a field to hold the last-computed grouped/sorted result and a marker (e.g. hash or reference check) of the `_photos` list it was computed from.
2. In `_buildPhotosWithDropdown`, return the cached result if `_photos` hasn't changed since the last computation; recompute only when it has.
3. Combine with FE-01 — once this section is extracted into its own widget, consider moving the grouping logic into a `didUpdateWidget`/memoized getter instead of the build method entirely.

### 🟢 LOW

#### `[ ]` FE-09 — Undisposed `TextEditingController`s in dialog builders
**Files**: `client_dashboard.dart:1221-1222` (`titleController`, `descriptionController`), `supervisor_dashboard_feed.dart:1631-1632` (`nameCtrl`, `phoneCtrl`)

**Steps to fix**: Add `.dispose()` calls for each controller when the dialog closes (on both the "submit" and "cancel" paths, or wrap in a `try/finally`) — copy the correct pattern already used in `admin_dashboard.dart` (lines 2101-2102, 2434-2437, 2804-2808, 2940-2944, 3047).

#### `[ ]` FE-10 — Dead providers registered at app root (no functional cost today, but a footgun)
**File**: `lib/main.dart:75-90` (`MultiProvider` registers `SupervisorProvider`, `AccountantProvider`, `ArchitectProvider`, `ClientProvider`, `SiteEngineerProvider` — none referenced by any screen); `lib/providers/supervisor_provider.dart:65-70` (`startAutoRefresh()` sets a 30s `Timer.periodic` that would poll indefinitely if this provider is ever wired up)

**Steps to fix**: Either remove these unused provider registrations from `main.dart`, or if they're meant for future use, add a code comment flagging that `SupervisorProvider.startAutoRefresh()` must not be called from app-root scope without an explicit stop condition (e.g. tied to a screen's `dispose()`), to prevent an accidental infinite background poll later.

#### `[ ]` FE-11 — Debug-log string interpolation still executes (just doesn't print) in release builds
**File**: `lib/utils/app_logger.dart:13-17`; heavy use in `lib/providers/construction_provider.dart:251-256` and similar loops elsewhere

**Steps to fix**: Where a log call's message involves looping/building a string from a collection (not just interpolating a couple of simple variables), guard the whole block with `if (kDebugMode) { ... }` so the loop itself doesn't run in release, not just the `print`.

---

## PART 3 — Frontend (Flutter) — UI/UX Design Consistency

*(Addresses "design is not good except admin screens." Root cause first, then role-specific fixes.)*

### 🟠 HIGH — Root causes (fixing these has the widest impact)

#### `[ ]` UX-01 — The shared color system (`app_colors.dart`) is effectively grayscale/monochrome; Admin doesn't even use it
**File**: `lib/utils/app_colors.dart:4-49`

**Problem**: `supervisorColor`, `accountantColor`, `architectColor`, `ownerColor` are all the *same* `Color(0xFF1A1A2E)` (lines 39-43); `primaryPurple` is pure black (`0xFF000000`, line 12); `safetyOrange` is dark gray (`0xFF424242`, line 16), not orange. Admin screens don't import this file at all — they hand-pick saturated per-screen hex colors instead (e.g. `admin_dashboard.dart:651,661,672,683` uses distinct blue/green/amber per category). Every other role is stuck with the grayscale palette.

**Steps to fix**:
1. In `app_colors.dart`, give each role a genuinely distinct, saturated accent color (not all pointing at the same navy) — e.g. keep Admin's navy, but give Supervisor/Accountant/Architect/Client each their own hue drawn from the existing-but-unused vibrant constants already in the file (e.g. `accountantAccent = #2563EB`).
2. Add 3-4 semantic category colors (matching Admin's blue/green/amber/red pattern) that any role's screen can use for status/category differentiation, not just one flat brand color per role.
3. This alone doesn't fix anything until screens adopt it — pair with UX-05/UX-06/UX-08 below for the actual screen-level changes.

#### `[ ]` UX-02 — Supervisor's main/most-used screen is literally styled black-and-white
**File**: `lib/screens/supervisor_dashboard_feed.dart` — `AppColors.bwPrimary` (78 uses), `bwSecondaryText` (30), `bwMuted` (9), `bwCard` (6), `bwSurface` (5), `bwGradient` (3) — e.g. lines 323, 332, 336, 364, 400, 410, 456, 478, 579, 602, 610

**Problem**: Per `app_colors.dart:187-196`, these `bw*` tokens are literally a leftover "black-and-white theme variant." This is the single most visually damaging finding — Supervisor's primary screen has zero color coding while Admin's equivalent grid (`admin_dashboard.dart:647-689`) rotates a distinct color per card.

**Steps to fix**:
1. Do UX-01 first (add a real Supervisor accent color).
2. In `supervisor_dashboard_feed.dart`, systematically replace each `AppColors.bw*` reference with the new Supervisor accent (or a category-rotated color for cards/badges, matching Admin's `_cardColors[index % _cardColors.length]` pattern at `admin_dashboard.dart:830`).
3. Do this file section by section (cards, badges, headers) rather than a blind find-replace, since some `bw*` uses may be intentionally neutral (e.g. plain text) and shouldn't become colorful noise.

#### `[ ]` UX-03 — `admin_theme.dart`, the file that looks like it should be "the" design system, is unused dead code — including by Admin itself
**File**: `lib/utils/admin_theme.dart` (defines `modernCard()`, `elevatedCard()`, `gradientCard()`, `metricCard()`, `statusBadge()`, `heading1/2/3`, `bodyLarge/Medium/Small`, full input-decoration helpers — lines 43-278). Confirmed zero references anywhere (`grep -rl "admin_theme" lib` / `grep -rl "AdminTheme\." lib` both empty).

**Problem**: Admin's actual polish comes from painstaking inline re-implementation per screen (each `admin_*.dart` file re-declares its own hex constants and card decorations from scratch) — not from any shared system. This is the most actionable lever: a well-designed token set already exists, it's just orphaned.

**Steps to fix**:
1. Move `AdminTheme`'s card/badge/metric-card helper methods into `lib/widgets/common_widgets.dart` (or keep `admin_theme.dart` but actually import it from there) so they're available app-wide, not admin-scoped in name only.
2. Migrate 1-2 Admin screens onto these helpers first (proves they work and looks the same, since it's Admin's own pattern) — e.g. replace `admin_dashboard.dart`'s hand-rolled card decoration with `AdminTheme.gradientCard(...)`.
3. Then migrate non-Admin screens onto the same shared helpers as part of UX-05/UX-06/UX-07 below, instead of each role reinventing card/badge styling independently.

### 🟡 MEDIUM

#### `[ ]` UX-04 — Shared reusable widgets (`CommonWidgets`) exist but adoption is inconsistent — worst in the roles that look weakest
**File**: `lib/widgets/common_widgets.dart` (`buildCard`, `buildEmptyState`, `buildErrorState`, `buildLoadingIndicator`, `SummaryCard`, `EntryCard`, `StatusBadge`, `SectionHeader`). Usage counts per dashboard: Accountant 6, Site Engineer 4, Architect 3, **Supervisor 0, Client 0**.

**Steps to fix**:
1. Start with Supervisor and Client (currently zero adoption): replace their hand-rolled cards/empty-states/loading-indicators with `CommonWidgets.buildCard`/`buildEmptyState`/`buildLoadingIndicator`/`SummaryCard`/`EntryCard` one section at a time.
2. Once Supervisor/Client are migrated, revisit Site Engineer/Architect to raise their partial adoption (3-4 uses) to full coverage.

#### `[ ]` UX-05 — Supervisor: monochrome badges destroy scannability vs Admin's color-coded equivalents
**File**: `lib/screens/supervisor_dashboard_feed.dart:815-842` (site-area badge, flat `bwPrimary` for background/border/icon/text regardless of what it represents) vs. `lib/screens/admin_dashboard.dart:830,838-843,848-857` (`_cardColors[index % _cardColors.length]` rotates navy/blue/green/amber, driving both card shadow and gradient header)

**Steps to fix**: After UX-01/UX-02 land, apply the same `_cardColors[index % _cardColors.length]`-style rotation (or a category-based color assignment) to Supervisor's badges/cards instead of one flat color — copy the pattern directly from `admin_dashboard.dart:830`.

#### `[ ]` UX-06 — Site Engineer: flat single-hue list cards vs Admin's gradient hero cards
**File**: `lib/screens/site_engineer_history_screen.dart:232-317` (`_buildDateSection` — plain white card, light tinted header, small solid icon chip) vs. `lib/screens/admin_dashboard.dart:832-936` (`_buildSiteManagementCard` — full-bleed gradient header, translucent icon badge, numbered chip) for a near-identical data shape (title + 2 metadata lines + expand affordance)

**Steps to fix**: Port the gradient-header card structure from `admin_dashboard.dart:848-936` into `site_engineer_history_screen.dart`'s `_buildDateSection`, reusing whatever becomes the shared `AdminTheme`/`CommonWidgets` card helper from UX-03/UX-04 rather than copy-pasting the raw gradient code.

#### `[ ]` UX-07 — Client: inconsistent, ad hoc gray literals instead of theme tokens
**File**: `lib/screens/client_dashboard.dart` — mixes `Colors.grey`, `Colors.grey.shade500`, `Colors.grey.shade100`, `Colors.grey.shade400`, `Colors.grey[300]`, `Colors.grey[600]` (7 different forms across the same file, e.g. lines 185,193,381,549,590,595,604,609,626,633,654,658,819,915) despite `AppColors.textSecondary`/`textTertiary` already existing.

**Steps to fix**: Replace every `Colors.grey*` literal in this file with the appropriate semantic token — `AppColors.textSecondary`, `AppColors.textTertiary`, or `AppColors.borderColor` — picking one consistent token per semantic purpose (primary body gray, disabled/muted gray, border gray) rather than 6+ arbitrary shades.

### 🟢 LOW

#### `[ ]` UX-08 — Architect: same single-hue-for-everything pattern as Site Engineer, no status/category differentiation at all
**File**: `lib/screens/architect_dashboard.dart` — `AppColors.deepNavy` (53 uses), `textSecondary` (14), `deepNavyLight` (10) as essentially the only colors on the screen; no `success`/`warning`/`error` status tokens referenced anywhere in the file.

**Steps to fix**: Introduce 2-3 semantic accent colors for document/complaint status (e.g. pending/approved/rejected) using the new tokens from UX-01, applied to badges/chips the way Admin's status badges work.

#### `[ ]` UX-09 — Client: bare loading spinner with no context on initial load
**File**: `lib/screens/client_dashboard.dart:109-112` — plain `CircularProgressIndicator` with no accompanying text, blanking the entire screen.

**Steps to fix**: Add a short message ("Loading your site...") near the spinner, or keep any static chrome (app bar, greeting) visible during the load instead of blanking to just a spinner.

---

## Suggested Execution Order

This maps onto `.kiro/steering/roadmap.md`'s Phase 0 (Pre-Launch Essentials) — treat the items below as the concrete backlog behind that phase's checklist items.

1. **Week 1 — Security lockdown** (do first, these are live exploitable holes): `BE-01`, `BE-02`, `BE-03`
2. **Week 1 — Broken-in-production fixes** (zero-risk to fix, currently just failing): `BE-04`, `BE-05`
3. **Week 2 — Backend performance**: `BE-06`, `BE-07`, then `BE-08`–`BE-11`
4. **Week 2-3 — Frontend performance, systemic fixes first**: `FE-02` (Selector) and `FE-04` (photo compression off UI thread) give the biggest felt improvement for the least risk; then `FE-01` (widget extraction, incremental, can run alongside other work), `FE-03`, `FE-05`
5. **Week 3-4 — Frontend performance, remaining**: `FE-06`–`FE-11`
6. **Week 3-4 — Design system foundation**: `UX-01` and `UX-03` first (these unlock everything else), then `UX-02`/`UX-05` (Supervisor, highest visual impact), then `UX-04`, `UX-06`, `UX-07`, `UX-08`, `UX-09`

**Total**: 11 backend issues, 11 frontend performance issues, 9 UI/UX issues = **31 tracked items**, all independently verified against the current source code as of 2026-07-28.
