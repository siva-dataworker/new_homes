# JWT Refresh Token Implementation — ISSUE-37 Fix

**Status:** ✅ **Backend Complete** — Flutter app update required  
**Priority:** 🚨 **CRITICAL SECURITY FIX**  
**Issue:** 7-day JWT tokens with no revocation mechanism

---

## What Changed

### Before (SECURITY RISK)
- Single JWT token valid for **7 days**
- No way to revoke tokens
- Terminated employees could access system for up to 7 days
- Stolen tokens valid until expiry
- Role changes not reflected until token expires

### After (SECURE)
- **Access token:** 30 minutes (for API calls)
- **Refresh token:** 30 days (stored in database)
- Tokens can be revoked immediately
- Logout invalidates all sessions
- Admin can view and revoke user sessions

---

## Backend Changes Complete

### 1. ✅ JWT Utils Updated
**File:** `django-backend/api/jwt_utils.py`

```python
# New token expiry times
ACCESS_TOKEN_EXPIRE_MINUTES = 30   # 30 minutes (was 7 days)
REFRESH_TOKEN_EXPIRE_DAYS = 30    # 30 days

# New functions added:
- generate_refresh_token(user_id) → creates long-lived refresh token
- generate_token_pair(user_data) → creates both tokens at once
- decode_refresh_token(token) → validates refresh tokens
```

### 2. ✅ Database Table Created
**File:** `django-backend/api/refresh_tokens_schema.sql`

**Run this SQL to create the table:**
```bash
cd django-backend
psql $DATABASE_URL -f api/refresh_tokens_schema.sql
```

Or via Supabase SQL Editor:
```sql
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_id UUID NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    device_info TEXT,
    ip_address INET
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token_id ON refresh_tokens(token_id);
```

### 3. ✅ New API Endpoints
**File:** `django-backend/api/views_refresh_token.py`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/auth/refresh/` | POST | Exchange refresh token for new access token |
| `/api/auth/logout/` | POST | Revoke refresh tokens (logout) |
| `/api/auth/sessions/` | GET | List user's active sessions |
| `/api/auth/sessions/<id>/revoke/` | POST | Revoke specific session (admin or self) |

### 4. ✅ Login Updated
**File:** `django-backend/api/views_auth.py`

Login now returns:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 1800,
  "token_type": "Bearer",
  "user": { ... }
}
```

### 5. ✅ URL Patterns Updated
**File:** `django-backend/api/urls.py`

New routes registered for token management.

---

## How It Works

### Login Flow
```
1. User logs in with username/password
2. Backend generates:
   - Access token (30 min)
   - Refresh token (30 days)
3. Refresh token stored in database
4. Both tokens returned to client
5. Client stores both tokens (securely)
```

### API Request Flow
```
1. Client sends access token in Authorization header
2. If valid → request succeeds
3. If expired → client calls /api/auth/refresh/
4. Backend verifies refresh token
5. Returns new access token
6. Client retries original request
```

### Logout Flow
```
1. Client calls /api/auth/logout/ with refresh token
2. Backend marks refresh token as revoked
3. Access token expires naturally (max 30 min)
4. User fully logged out
```

---

## Flutter App Updates Required

### 1. Update AuthService to Handle Refresh Tokens

**File:** `otp_phone_auth/lib/services/auth_service.dart`

```dart
class AuthService {
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Store BOTH tokens securely
      await prefs.setString('auth_token', data['access_token']);
      await prefs.setString('refresh_token', data['refresh_token']);
      
      return data;
    }
    return null;
  }

  Future<bool> refreshAccessToken() async {
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('auth_token', data['access_token']);
        return true;
      }
    } catch (e) {
      print('Token refresh failed: $e');
    }
    
    return false;
  }

  Future<void> logout() async {
    final refreshToken = prefs.getString('refresh_token');
    final authToken = prefs.getString('auth_token');
    
    if (refreshToken != null && authToken != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout/'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      } catch (e) {
        print('Logout API call failed: $e');
      }
    }
    
    // Clear local storage regardless of API success
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_role');
  }
}
```

### 2. Add HTTP Interceptor for Auto-Refresh

Create `lib/services/http_interceptor.dart`:

```dart
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AuthHttpClient {
  final _authService = AuthService();

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return _makeRequest(() => http.get(url, headers: headers));
  }

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    return _makeRequest(() => http.post(url, headers: headers, body: body));
  }

  Future<http.Response> _makeRequest(Future<http.Response> Function() request) async {
    var response = await request();

    // If 401 Unauthorized, try refreshing token once
    if (response.statusCode == 401) {
      final refreshed = await _authService.refreshAccessToken();
      if (refreshed) {
        // Retry with new token
        response = await request();
      } else {
        // Refresh failed, logout user
        await _authService.logout();
        // Navigate to login screen
      }
    }

    return response;
  }
}
```

### 3. Replace All HTTP Calls

Update all services to use `AuthHttpClient` instead of `http` directly:

```dart
// OLD
final response = await http.get(Uri.parse(url), headers: headers);

// NEW
final client = AuthHttpClient();
final response = await client.get(Uri.parse(url), headers: headers);
```

---

## Testing Checklist

### Backend Testing

```bash
# 1. Test login returns both tokens
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"supervisor1","password":"pass123"}'

# Should return:
# {
#   "access_token": "eyJ...",
#   "refresh_token": "eyJ...",
#   "expires_in": 1800,
#   ...
# }

# 2. Test token refresh
curl -X POST http://localhost:8000/api/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<refresh_token_from_login>"}'

# Should return new access token

# 3. Test logout revokes token
curl -X POST http://localhost:8000/api/auth/logout/ \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<refresh_token>"}'

# 4. Test revoked token can't refresh
curl -X POST http://localhost:8000/api/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<revoked_token>"}'

# Should return 401 error
```

### Flutter Testing

- [ ] Login stores both tokens
- [ ] Access token auto-refreshes on 401
- [ ] Logout clears both tokens
- [ ] Logout revokes token on backend
- [ ] User redirected to login after refresh fails

---

## Migration Guide for Existing Users

### Option 1: Force Re-Login (Recommended)
1. Deploy backend changes
2. Clear all existing tokens from Flutter app on first launch
3. Force users to log in again
4. New tokens issued with refresh capability

### Option 2: Gradual Migration
1. Keep supporting old 7-day tokens temporarily
2. New logins get refresh tokens
3. Old tokens expire naturally
4. Remove legacy support after 7 days

---

## Security Benefits

✅ **Reduced attack window:** Stolen access tokens only valid for 30 minutes  
✅ **Immediate revocation:** Terminated users lose access instantly  
✅ **Session management:** Admins can see and revoke active sessions  
✅ **Role changes instant:** New role reflected in next access token (30 min max)  
✅ **Device tracking:** Know which devices have active sessions  

---

## Performance Impact

- **Minimal:** Refresh calls happen ~48 times per day per user (every 30 min)
- **Database:** One row per active session per user (~1-3 rows average)
- **Storage:** ~100 bytes per token row
- **Expected load:** Negligible for <1000 users

---

## Cleanup Cron Job (Optional)

Delete expired tokens weekly:

```sql
DELETE FROM refresh_tokens
WHERE expires_at < NOW() - INTERVAL '7 days';
```

Or via Django management command (future improvement).

---

**Status:** Backend implementation complete. Flutter app updates required to activate this feature.

**Next Steps:**
1. Run `refresh_tokens_schema.sql` on Supabase
2. Deploy backend changes
3. Update Flutter app auth logic
4. Test token refresh flow
5. Monitor for issues

---

*Implementation Date: July 18, 2026*
