import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/order_tracking_screen.dart';

/// Firebase options extracted from google-services.json for Pickleo (pickleo-67911)
const FirebaseOptions pickleoFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCxQiaIcnrjb0TvOC8jOfz3_8Xqy-7YJQI',
  appId: '1:1070966647789:android:3a548e3414b1f3c3cd95e4',
  messagingSenderId: '1070966647789',
  projectId: 'pickleo-67911',
  storageBucket: 'pickleo-67911.firebasestorage.app',
);

/// Top-level background message handler for Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: pickleoFirebaseOptions);
    }
  } catch (e) {
    debugPrint('[NotificationService] Firebase init in bg handler exception: $e');
  }
  await NotificationService.instance.handleBackgroundMessage(message);
}

/// Centralized service managing Push Notifications, FCM Tokens, Device IDs,
/// and Redirection to Order Details on notification clicks.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  /// Global Navigator key for app navigation across notification callbacks
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _cachedDeviceId;
  String? _cachedFcmToken;
  String? _pendingOrderId;

  /// High importance notification channel for Android Order updates
  static const AndroidNotificationChannel orderChannel =
      AndroidNotificationChannel(
    'orders_channel',
    'Order Updates',
    description: 'Notifications regarding your Pickleo orders and deliveries',
    importance: Importance.max,
    playSound: true,
  );

  /// Initialize Firebase Core, FCM listeners, and Local Notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // On Android: initialize Firebase and FCM
      if (!kIsWeb && Platform.isAndroid) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: pickleoFirebaseOptions);
        }
        await _setupLocalNotifications();
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        await requestNotificationPermission();
        _setupMessageListeners();
        await _checkInitialMessage();
      } else {
        // On iOS & Web: only initialize local notifications (skip Firebase to prevent native iOS crash)
        await _setupLocalNotifications();
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('[NotificationService] Initialization error (safe fallback): $e');
    }
  }

  /// Request push notification permissions (iOS and Android 13+)
  Future<bool> requestNotificationPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final isGranted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isGranted) {
        await getFcmToken();
      }

      return isGranted;
    } catch (e) {
      debugPrint('[NotificationService] Permission request failed: $e');
      return false;
    }
  }

  /// Generates a UUID v4 once per app installation and stores it in SharedPreferences.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('pickleo_device_id');
      if (deviceId != null && deviceId.isNotEmpty) {
        _cachedDeviceId = deviceId;
        return deviceId;
      }

      deviceId = _generateUuidV4();
      await prefs.setString('pickleo_device_id', deviceId);
      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (e) {
      debugPrint('[NotificationService] Error reading deviceId prefs: $e');
      final fallback = _generateUuidV4();
      _cachedDeviceId = fallback;
      return fallback;
    }
  }

  /// Returns 'ios' for iOS, 'android' for Android, or 'web'
  String getPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {}
    return 'android';
  }

  /// Returns FCM device registration token
  Future<String?> getFcmToken() async {
    if (Firebase.apps.isEmpty) return null;
    if (_cachedFcmToken != null && _cachedFcmToken!.isNotEmpty) {
      return _cachedFcmToken;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedFcmToken = prefs.getString('pickleo_fcm_token');

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedFcmToken = token;
        await prefs.setString('pickleo_fcm_token', token);
      }
      return _cachedFcmToken;
    } catch (e) {
      debugPrint('[NotificationService] Error fetching FCM token: $e');
      return _cachedFcmToken;
    }
  }

  /// Returns the three push fields (fcmToken, deviceId, platform) together
  /// or null if notification permission is unavailable or token is absent.
  Future<Map<String, String>?> getPushCredentials() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final isAuthorized = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!isAuthorized) {
        debugPrint('[NotificationService] Permission not granted, omitting push credentials');
        return null;
      }

      final fcmToken = await getFcmToken();
      if (fcmToken == null || fcmToken.trim().isEmpty) {
        debugPrint('[NotificationService] FCM token unavailable, omitting push credentials');
        return null;
      }

      final deviceId = await getDeviceId();
      final platform = getPlatform();

      return {
        'fcmToken': fcmToken.trim(),
        'deviceId': deviceId.trim(),
        'platform': platform.trim(),
      };
    } catch (e) {
      debugPrint('[NotificationService] getPushCredentials error: $e');
      return null;
    }
  }

  /// Configures local notification channels & click callbacks
  Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationClick(response);
      },
    );

    // Create high importance notification channel on Android
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(orderChannel);
    }
  }

  /// Listeners for Foreground and Background Resumption
  void _setupMessageListeners() {
    // 1. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Foreground message received: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // 2. Notification opened app while in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Notification opened app from background: ${message.data}');
      handleNotificationData(message.data);
    });

    // 3. Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
      _cachedFcmToken = newToken;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pickleo_fcm_token', newToken);
      } catch (_) {}
    });
  }

  /// Displays a local heads-up notification when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Order Update';
    final body = notification?.body ??
        data['body'] ??
        'You have a new update on your Pickleo order.';

    await _showLocalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(data),
    );
  }

  /// Displays local notification if data-only payload received while closed/background
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('[NotificationService] Background message received: ${message.data}');
    // If notification payload exists, Android system tray automatically shows it.
    // If it is data-only (no top-level notification block), display local notification.
    if (message.notification == null) {
      final data = message.data;
      final title = data['title'] ?? 'Order Update';
      final body = data['body'] ?? 'You have a new update on your order.';
      await _showLocalNotification(
        id: message.hashCode,
        title: title,
        body: body,
        payload: jsonEncode(data),
      );
    }
  }

  /// Shows a notification via FlutterLocalNotificationsPlugin
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'orders_channel',
      'Order Updates',
      channelDescription:
          'Notifications regarding your Pickleo orders and deliveries',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      color: Color(0xFF1B4D3E),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Failed to show local notification: $e');
    }
  }

  /// Inspects if app was launched via notification click from terminated/cold start state
  Future<void> _checkInitialMessage() async {
    try {
      // 1. From Firebase push notification
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] App launched from FCM notification: ${initialMessage.data}');
        handleNotificationData(initialMessage.data);
        return;
      }

      // 2. From Local Notification
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          debugPrint('[NotificationService] App launched from local notification payload: $payload');
          _handleLocalNotificationPayload(payload);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error checking initial message: $e');
    }
  }

  void _handleLocalNotificationClick(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _handleLocalNotificationPayload(payload);
    }
  }

  void _handleLocalNotificationPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        handleNotificationData(decoded);
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to parse notification payload: $e');
    }
  }

  /// Processes FCM data payload.
  /// Backend specification:
  /// {
  ///   "notificationType": "Orders",
  ///   "orderId": "[canonical order ID]"
  /// }
  void handleNotificationData(Map<String, dynamic> data) {
    debugPrint('[NotificationService] Processing notification data: $data');
    final type = (data['notificationType'] ?? data['type'] ?? '')
        .toString()
        .trim();
    final orderId = (data['orderId'] ?? data['id'] ?? '')
        .toString()
        .trim();

    if (type.toLowerCase() == 'orders' && orderId.isNotEmpty) {
      navigateToOrderDetails(orderId);
    }
  }

  /// Redirects to Order Details / Tracking screen
  void navigateToOrderDetails(String orderId) {
    if (orderId.trim().isEmpty) return;
    debugPrint('[NotificationService] Navigating to Order Details for: $orderId');

    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen.byOrderId(orderId: orderId.trim()),
        ),
      );
    } else {
      // Navigator not attached yet (e.g. during cold start)
      _pendingOrderId = orderId.trim();
    }
  }

  /// Called after splash screen or main app mount to dispatch pending order navigation
  void checkPendingNavigation() {
    if (_pendingOrderId != null && _pendingOrderId!.isNotEmpty) {
      final id = _pendingOrderId!;
      _pendingOrderId = null;
      Future.delayed(const Duration(milliseconds: 300), () {
        navigateToOrderDetails(id);
      });
    }
  }

  /// Generates a standard RFC 4122 Version 4 UUID
  String _generateUuidV4() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 10
    return '${values.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}-'
        '${values.sublist(4, 6).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}-'
        '${values.sublist(6, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}-'
        '${values.sublist(8, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}-'
        '${values.sublist(10, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}
