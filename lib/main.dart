
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('Pesan latar belakang: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await NotificationService.initialize();
  NotificationService.listenToForegroundMessages();

  // Konfigurasi background service khusus Android.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await initializeBackgroundService();
  }

  runApp(const FireSmartAlarmApp());
}

class FireSmartAlarmApp extends StatelessWidget {
  const FireSmartAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fire Smart Alarm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const AuthenticatedDashboard();
        }

        return const LoginScreen();
      },
    );
  }
}

// Dashboard sekaligus mengaktifkan background service setelah login.
class AuthenticatedDashboard extends StatefulWidget {
  const AuthenticatedDashboard({super.key});

  @override
  State<AuthenticatedDashboard> createState() =>
      _AuthenticatedDashboardState();
}

class _AuthenticatedDashboardState
    extends State<AuthenticatedDashboard> {

  @override
  void initState() {
    super.initState();
    _startBackgroundMonitoring();
  }

  Future<void> _startBackgroundMonitoring() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final service = FlutterBackgroundService();

      final isRunning = await service.isRunning();

      if (!isRunning) {
        await service.startService();
      }

      debugPrint('Background monitoring diaktifkan.');
    } catch (e) {
      debugPrint('Gagal mengaktifkan background service: $e');
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      FlutterBackgroundService().invoke('stopService');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScreen();
  }
}