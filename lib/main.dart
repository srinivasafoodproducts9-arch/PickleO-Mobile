import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'state/app_state.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/referral_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Determine if device is a tablet based on shortest display side (>= 600dp)
  final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
  final pixelRatio = (view?.devicePixelRatio ?? 1.0) > 0 ? (view?.devicePixelRatio ?? 1.0) : 1.0;
  final isTablet = view != null && (view.physicalSize.shortestSide / pixelRatio) >= 600;

  if (isTablet) {
    // Enable full rotation (portrait & landscape) on iPad and Android tablets
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    // Keep mobile phones in portrait
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Firebase and Push Notification Service
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification service initialization exception: $e');
  }

  runApp(const PickleOApp());
}

class PickleOApp extends StatefulWidget {
  const PickleOApp({super.key});

  @override
  State<PickleOApp> createState() => _PickleOAppState();
}

class _PickleOAppState extends State<PickleOApp> with WidgetsBindingObserver {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReferralLinkService.instance.initialize(
        onReferral: (referral, validation) {
          final ctx = NotificationService.navigatorKey.currentContext;
          if (ctx != null) {
            ReferralLinkService.showReferralWelcomeDialog(
              ctx,
              code: referral.code,
              validation: validation,
            );
          }
        },
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ReferralLinkService.instance.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_appState.isLoggedIn) {
        _appState.loadCartFromApi();
        _appState.loadWalletFromApi();
        _appState.loadLoyaltyFromApi();
        _appState.fetchOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      appState: _appState,
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: 'PickleO - Pickles • Foods • Goodness',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
