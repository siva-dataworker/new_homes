import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/supervisor_dashboard_feed.dart';
import 'screens/admin_dashboard.dart';
import 'screens/site_engineer_dashboard.dart';
import 'screens/accountant_dashboard.dart';
import 'screens/architect_dashboard.dart';
import 'screens/owner_dashboard.dart';
import 'screens/client_dashboard.dart';
import 'utils/app_theme.dart';
import 'utils/app_logger.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'providers/construction_provider.dart';
import 'providers/change_request_provider.dart';
import 'providers/site_engineer_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/material_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/supervisor_provider.dart';
import 'providers/accountant_provider.dart';
import 'providers/accountant_dashboard_provider.dart';
import 'providers/accountant_entries_provider.dart';
import 'providers/architect_provider.dart';
import 'providers/client_provider.dart';
import 'services/api_client.dart';

/// Root navigator key so app-level services (the 401 handler below) can
/// redirect to the login screen without needing a BuildContext of their own.
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Catches everything Flutter's own error zone would otherwise only print
  // and forget: async errors outside a widget's build/event callbacks (a
  // failed Future in a Timer, a dropped Stream error, etc). Combined with
  // FlutterError.onError below, no exception in this app is silently lost.
  //
  // There is no crash-reporting SDK wired in yet (Sentry/Crashlytics would
  // need an account + API key this repo doesn't have) — both handlers log
  // via AppLogger today. Swap the body of `_reportError` for a real SDK
  // call once one is provisioned; every crash already flows through this
  // single choke point.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      _reportError(details.exception, details.stack, context: 'FlutterError');
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _reportError(error, stack, context: 'PlatformDispatcher');
      return true;
    };

    runApp(const MyApp());
  }, (error, stack) {
    _reportError(error, stack, context: 'runZonedGuarded');
  });
}

void _reportError(Object error, StackTrace? stack, {required String context}) {
  AppLogger.e('Uncaught error [$context]', error, stack);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConstructionProvider()),
        ChangeNotifierProvider(create: (_) => ChangeRequestProvider()),
        ChangeNotifierProvider(create: (_) => SiteEngineerProvider()),
        ChangeNotifierProvider(create: (_) => MaterialProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => SupervisorProvider()),
        ChangeNotifierProvider(create: (_) => AccountantProvider()),
        ChangeNotifierProvider(create: (_) => AccountantDashboardProvider()),
        ChangeNotifierProvider(create: (_) => AccountantEntriesProvider()),
        ChangeNotifierProvider(create: (_) => ArchitectProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ScreenUtilInit(
            // Design base: standard Android phone (360×800 dp)
            designSize: const Size(360, 800),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (_, __) => MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Essential Homes',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const AuthChecker(),
              debugShowCheckedModeBanner: false,
            ),
          );
        },
      ),
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  bool _unauthorizedHandlerRegistered = false;

  @override
  void initState() {
    super.initState();
    _registerUnauthorizedHandler();
    // AuthProvider.initialize() calls notifyListeners() before its first
    // await — calling it synchronously from initState() means that
    // notification lands mid-build, which Flutter disallows
    // ("setState() or markNeedsBuild() called during build"). Deferring to
    // a post-frame callback runs it after the first frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  /// Routes any 401 from any service, app-wide, to logout + login — this is
  /// what was previously missing entirely: an expired token used to fail
  /// silently and independently on every screen instead of prompting
  /// re-authentication once.
  void _registerUnauthorizedHandler() {
    if (_unauthorizedHandlerRegistered) return;
    _unauthorizedHandlerRegistered = true;

    var handling = false;
    ApiClient.onUnauthorized = () async {
      if (handling) return;
      handling = true;
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        final nav = navigatorKey.currentState;
        if (nav != null) {
          nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } finally {
        handling = false;
      }
    };
  }

  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    if (!mounted) return;

    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      final user = authProvider.currentUser!;
      final role = user['role'];
      final roleNormalized = role?.toString().toLowerCase() ?? '';
      AppLogger.d('Auth check: user=${user['username']} role=$roleNormalized');

      final dashboard = _dashboardForRole(roleNormalized, user);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => dashboard),
        );
      }
    } else {
      // Not logged in, show login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  /// One dashboard-routing switch instead of five copy-pasted `UserModel`
  /// constructions that differed only by `role`.
  Widget _dashboardForRole(String roleNormalized, Map<String, dynamic> user) {
    UserModel dummyUser(UserRole role) => UserModel(
          uid: user['id'],
          phoneNumber: user['phone'] ?? '',
          name: user['full_name'],
          email: user['email'],
          role: role,
          createdAt: DateTime.now(),
        );

    switch (roleNormalized) {
      case 'admin':
        return const AdminDashboard();
      case 'supervisor':
        return const SupervisorDashboardFeed();
      case 'site engineer':
        return SiteEngineerDashboard(user: dummyUser(UserRole.siteEngineer));
      case 'accountant':
        return AccountantDashboard(user: dummyUser(UserRole.accountant));
      case 'architect':
        return ArchitectDashboard(user: dummyUser(UserRole.architect));
      case 'owner':
        return OwnerDashboard(user: dummyUser(UserRole.owner));
      case 'client':
        return const ClientDashboard();
      default:
        AppLogger.d('Unknown role "$roleNormalized" — showing login');
        return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/essential_homes_logo.png',
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.construction,
                  size: 100,
                  color: Color(0xFFFF6B35),
                );
              },
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
