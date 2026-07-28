# Developer Quick Start Guide
## Essential Homes Construction Management Platform

**Last Updated**: January 27, 2025

---

## ARCHITECTURE AT A GLANCE

```
┌─────────────────┐       HTTPS/JSON        ┌──────────────┐       SQL        ┌────────────┐
│  Flutter App    │ ◄──────────────────────► │  Django API  │ ◄────────────────► │ PostgreSQL │
│  (Mobile Only)  │                          │  (REST)      │                  │ (Supabase) │
└─────────────────┘                          └──────────────┘                  └────────────┘
      52 screens                                200+ endpoints                   25+ tables
   14 providers                                 12 view modules                   
   13 services                                                                    
```

---

## PROJECT STRUCTURE

### Backend (Django)
```
django-backend/
├── api/
│   ├── views_auth.py              # Authentication (login, register)
│   ├── views_construction.py      # ⚠️ 6000+ lines - NEEDS REFACTOR
│   ├── views_admin.py             # Admin features
│   ├── views_accountant_documents.py
│   ├── views_budget.py
│   ├── views_client.py
│   ├── views_material.py
│   ├── views_site_engineer.py
│   ├── models.py                  # Django ORM models
│   ├── database.py                # SQL helpers (fetch_one, execute_query)
│   ├── authentication.py          # JWT middleware
│   ├── jwt_utils.py               # Token generation
│   └── urls.py                    # API routing (200+ endpoints)
├── backend/
│   └── settings.py                # Django configuration
└── requirements.txt
```

### Frontend (Flutter)
```
otp_phone_auth/lib/
├── config/
│   └── app_config.dart            # Base URL configuration
├── models/                        # Data models (4 files)
├── providers/                     # State management (14 providers)
│   ├── auth_provider.dart
│   ├── construction_provider.dart  # Multi-role data
│   ├── admin_provider.dart
│   ├── accountant_provider.dart
│   └── ... (10 more)
├── services/                      # API communication (13 services)
│   ├── api_client.dart            # HTTP wrapper with timeout
│   ├── auth_service.dart
│   ├── construction_service.dart
│   └── ... (10 more)
├── screens/                       # UI screens (52 files)
│   ├── login_screen.dart
│   ├── admin_dashboard.dart
│   ├── supervisor_dashboard_feed.dart
│   └── ... (49 more)
├── utils/                         # Utilities (9 files)
│   ├── app_theme.dart             # Material 3 theme
│   ├── app_colors.dart            # Color palette
│   └── app_logger.dart            # Logging utility
├── widgets/                       # Reusable widgets (4 files)
└── main.dart                      # App entry point
```

---

## QUICK SETUP

### Backend Setup (5 minutes)

```bash
# 1. Navigate to backend
cd e:\constructiion_AI_PLATFORM\essential_homes\new_essentials\django-backend

# 2. Create virtual environment (first time only)
python -m venv venv

# 3. Activate virtual environment
venv\Scripts\activate  # Windows
source venv/bin/activate  # Mac/Linux

# 4. Install dependencies
pip install -r requirements.txt

# 5. Create .env file (copy from .env.example)
copy .env.example .env  # Windows
cp .env.example .env    # Mac/Linux

# 6. Edit .env with your Supabase credentials
# Get credentials from: https://supabase.com → Project Settings → Database

# 7. Run server
python manage.py runserver

# Server will start at: http://127.0.0.1:8000
```

### Frontend Setup (5 minutes)

```bash
# 1. Navigate to Flutter project
cd e:\constructiion_AI_PLATFORM\essential_homes\new_essentials\otp_phone_auth

# 2. Get dependencies
flutter pub get

# 3. Update base URL in lib/config/app_config.dart
# Change to your backend URL (local or production)

# 4. Run on emulator/device
flutter run

# Or build APK:
flutter build apk --release
```

### Database Setup (10 minutes)

```bash
# 1. Connect to Supabase PostgreSQL
# URL from Supabase → Project Settings → Database → Connection string

# 2. Run schema file
psql "postgresql://postgres:[password]@[host]:5432/postgres" -f construction_management_schema.sql

# 3. Create initial data
python add_sample_sites.py
python set_test_passwords.py

# Done! Database ready
```

---

## COMMON TASKS

### Add New API Endpoint

1. **Choose appropriate view file** (or create new one)
   ```python
   # api/views_your_feature.py
   
   from rest_framework.decorators import api_view, authentication_classes, permission_classes
   from rest_framework.permissions import IsAuthenticated
   from rest_framework.response import Response
   from .authentication import JWTAuthentication
   from .database import fetch_all, execute_query
   
   @api_view(['GET'])
   @authentication_classes([JWTAuthentication])
   @permission_classes([IsAuthenticated])
   def your_endpoint(request):
       try:
           user_id = request.user['user_id']
           role = request.user['role']
           
           # Your logic here
           data = fetch_all("SELECT * FROM table WHERE user_id = %s", (user_id,))
           
           return Response({'data': data}, status=200)
       except Exception as e:
           return Response({'error': str(e)}, status=500)
   ```

2. **Register in urls.py**
   ```python
   # api/urls.py
   from . import views_your_feature
   
   urlpatterns = [
       # ... existing patterns
       path('your-endpoint/', views_your_feature.your_endpoint, name='your-endpoint'),
   ]
   ```

3. **Test with curl or Postman**
   ```bash
   curl -X GET http://localhost:8000/api/your-endpoint/ \
     -H "Authorization: Bearer YOUR_JWT_TOKEN"
   ```

### Add New Flutter Screen

1. **Create screen file**
   ```dart
   // lib/screens/your_feature_screen.dart
   
   import 'package:flutter/material.dart';
   import 'package:provider/provider.dart';
   import '../providers/your_provider.dart';
   
   class YourFeatureScreen extends StatefulWidget {
     @override
     _YourFeatureScreenState createState() => _YourFeatureScreenState();
   }
   
   class _YourFeatureScreenState extends State<YourFeatureScreen> {
     @override
     void initState() {
       super.initState();
       Future.microtask(() => 
         context.read<YourProvider>().loadData()
       );
     }
     
     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(title: Text('Your Feature')),
         body: Consumer<YourProvider>(
           builder: (context, provider, child) {
             if (provider.isLoading) {
               return Center(child: CircularProgressIndicator());
             }
             
             return ListView(
               children: provider.data.map((item) => 
                 ListTile(title: Text(item.title))
               ).toList(),
             );
           },
         ),
       );
     }
   }
   ```

2. **Create provider**
   ```dart
   // lib/providers/your_provider.dart
   
   import 'package:flutter/foundation.dart';
   import '../services/your_service.dart';
   
   class YourProvider with ChangeNotifier {
     final YourService _service = YourService();
     
     bool _isLoading = false;
     List<YourModel> _data = [];
     String? _error;
     
     bool get isLoading => _isLoading;
     List<YourModel> get data => _data;
     String? get error => _error;
     
     Future<void> loadData() async {
       _isLoading = true;
       _error = null;
       notifyListeners();
       
       try {
         _data = await _service.fetchData();
         _isLoading = false;
         notifyListeners();
       } catch (e) {
         _error = e.toString();
         _isLoading = false;
         notifyListeners();
       }
     }
   }
   ```

3. **Register provider in main.dart**
   ```dart
   MultiProvider(
     providers: [
       // ... existing providers
       ChangeNotifierProvider(create: (_) => YourProvider()),
     ],
     // ...
   )
   ```

### Add Database Migration

```bash
# 1. Create SQL file
# migrations/add_your_feature.sql

-- Your SQL changes
CREATE TABLE your_table (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

# 2. Run migration
python run_migration.py add_your_feature.sql

# 3. Verify
psql "your-connection-string" -c "\d your_table"
```

---

## DEBUGGING

### Backend Debugging

**Check logs**:
```bash
# Django server logs are in terminal where you ran `python manage.py runserver`
```

**Common Issues**:
- **Database connection failed**: Check `.env` credentials
- **401 Unauthorized**: Token expired or invalid
- **500 Internal Server Error**: Check server logs
- **Import errors**: Run `pip install -r requirements.txt`

**Database queries**:
```python
# Add logging to see queries
import logging
logger = logging.getLogger(__name__)
logger.debug("Query: %s", query)
```

### Frontend Debugging

**Flutter DevTools**:
```bash
# Run with debug mode
flutter run

# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

**Common Issues**:
- **Network error**: Check `app_config.dart` base URL
- **401 error**: Token expired, user logged out
- **Widget rebuild issues**: Use `flutter run --profile` to check performance

**Debug prints**:
```dart
import '../utils/app_logger.dart';

AppLogger.d('Debug message', data);
AppLogger.e('Error occurred', error, stackTrace);
```

---

## TESTING

### Manual Testing

**Test Users** (created by `set_test_passwords.py`):
- Admin: `admin` / `admin123`
- Supervisor: `supervisor1` / `super123`
- Site Engineer: `engineer1` / `eng123`
- Accountant: `accountant1` / `acc123`

**Critical Flows to Test**:
1. Login → Dashboard
2. Create labour entry
3. Submit photo
4. View history
5. Generate report

### API Testing

**Using curl**:
```bash
# Login
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Save token from response

# Call protected endpoint
curl -X GET http://localhost:8000/api/sites/ \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Using Postman**:
1. Import: New Collection → Essential Homes API
2. Add request: GET http://localhost:8000/api/sites/
3. Headers: `Authorization: Bearer YOUR_TOKEN`

---

## DEPLOYMENT

### Quick Deploy to Render (Backend)

1. Push code to GitHub
2. Go to Render.com → New Web Service
3. Connect repository
4. Configure:
   - Build: `pip install -r requirements.txt`
   - Start: `gunicorn backend.wsgi:application`
5. Add environment variables from `.env`
6. Deploy!

### Build APK (Frontend)

```bash
cd otp_phone_auth

# Build release APK
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk

# Distribute to users via Google Drive, Dropbox, etc.
```

---

## USEFUL COMMANDS

### Backend
```bash
# Run server
python manage.py runserver

# Create admin user
python manage.py createsuperuser

# Database shell
python manage.py dbshell

# Python shell with Django context
python manage.py shell
```

### Frontend
```bash
# Run on device
flutter run

# Build APK
flutter build apk --release

# Clean build
flutter clean && flutter pub get

# Analyze code
flutter analyze

# Format code
dart format lib/
```

### Database
```bash
# Connect to Supabase
psql "postgresql://postgres:[password]@[host]:5432/postgres"

# List tables
\dt

# Describe table
\d table_name

# Run SQL file
\i path/to/file.sql
```

---

## NEED HELP?

### Documentation
- **Product**: `.kiro/steering/product.md`
- **Architecture**: `.kiro/steering/architecture.md`
- **Frontend**: `.kiro/steering/frontend.md`
- **Backend**: `.kiro/steering/backend.md`
- **Security**: `.kiro/steering/security.md`
- **Testing**: `.kiro/steering/testing.md`
- **Deployment**: `.kiro/steering/deployment.md`

### Audit Reports
- **Comprehensive Audit**: `COMPREHENSIVE_AUDIT_REPORT.md`
- **Executive Summary**: `EXECUTIVE_SUMMARY.md`

### Code Examples
- Check existing screens/providers for patterns
- See `views_auth.py` for authentication examples
- See `construction_provider.dart` for state management

---

## TIPS FOR NEW DEVELOPERS

1. **Read steering documents** - They contain all architectural decisions
2. **Follow existing patterns** - Don't reinvent the wheel
3. **Use providers for state** - Don't use setState in complex screens
4. **Always use parameterized queries** - Never string interpolation
5. **Test manually before committing** - We have 0% automated test coverage
6. **Check for 401 errors** - Token might be expired
7. **Use AppLogger** - Better than print statements
8. **Keep view files under 1000 lines** - Split if larger

---

**Happy Coding! 🚀**
