import 'hardware/sensor_node_controller.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'auth/auth_service.dart';
import 'auth/auth_state.dart';
import 'data/api_service.dart';
import 'data/firestore_api_service.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// OAuth 2.0 Web Client ID from android/app/google-services.json (client_type: 3).
const String kGoogleServerClientId =
    '699720500665-q7anpaqphfig5q2n505pprm5jc3sp264.apps.googleusercontent.com';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // 1. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[auth] Firebase initialized successfully');
  } catch (e) {
    debugPrint('[auth] Firebase initialization notice (pending project setup): $e');
  }

  // 2. Initialize Google Sign-In v7
  try {
    if (kGoogleServerClientId.isNotEmpty) {
      await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
    } else {
      await GoogleSignIn.instance.initialize();
    }
    debugPrint('[auth] GoogleSignIn initialized successfully');
  } catch (e) {
    debugPrint('[auth] GoogleSignIn initialization notice: $e');
  }

  runApp(const PulseApp());
}

class PulseApp extends StatefulWidget {
  const PulseApp({super.key});

  @override
  State<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends State<PulseApp> {
  late final MockApiService _mockApiService;
  late final FirestoreApiService _firestoreApiService;
  late final AuthService _authService;
  late final AuthState _authState;
  late final SensorNodeController _sensorNodeController;

  @override
  void initState() {
    super.initState();
    _mockApiService = MockApiService(seedDemoHistory: true);
    _firestoreApiService = FirestoreApiService();
    _authService = AuthService();
    _sensorNodeController = SensorNodeController();
    _authState = AuthState(
      authService: _authService,
      apiService: _firestoreApiService,
      apiServiceProvider: () =>
          _authState.status == AuthStatus.guest ? _mockApiService : _firestoreApiService,
    )..init();
  }

  @override
  void dispose() {
    _sensorNodeController.dispose();
    _authState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<AuthState>.value(value: _authState),
        ChangeNotifierProvider<SensorNodeController>.value(value: _sensorNodeController),
        Provider<MockApiService>.value(value: _mockApiService),
        Provider<FirestoreApiService>.value(value: _firestoreApiService),
        ProxyProvider<AuthState, ApiService>(
          update: (context, auth, _) {
            if (auth.status == AuthStatus.guest) {
              return _mockApiService;
            }
            return _firestoreApiService;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final auth = context.watch<AuthState>();
          return MaterialApp.router(
            title: 'P.U.L.S.E.',
            theme: AppTheme.light(),
            routerConfig: createRouter(auth),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
