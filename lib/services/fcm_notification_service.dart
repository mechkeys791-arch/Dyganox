import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

// Top-level so background isolate can use them
const String _kChannelId = 'mechanic_requests';
const String _kChannelName = 'Mechanic requests';
const String _kActionAccept = 'accept';
const String _kActionReject = 'reject';
const String _kAlarmChannel = 'dyganox/mechanic_alarm';

/// Stop the 30-sec mechanic alarm (e.g. when user taps Accept/Reject).
void _stopMechanicAlarm() {
  if (!Platform.isAndroid) return;
  try {
    const channel = MethodChannel(_kAlarmChannel);
    channel.invokeMethod('stopAlarm');
  } catch (_) {}
}

/// Start 30-sec continuous alarm for mechanic request (foreground only).
Future<void> _startMechanicAlarm() async {
  if (!Platform.isAndroid) return;
  try {
    const channel = MethodChannel(_kAlarmChannel);
    await channel.invokeMethod('startAlarm');
  } catch (_) {}
}

/// Top-level so background isolate can invoke when user taps Accept/Reject.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  if (response.payload == null || response.payload!.isEmpty) return;
  try {
    _stopMechanicAlarm();
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    final type = data['type'] as String?;
    final requestId = data['requestId'] as String?;
    final actionId = response.actionId;
    if (type != 'mechanic_request' || requestId == null) return;
    final id = int.tryParse(requestId);
    if (id == null) return;
    if (actionId == _kActionAccept) {
      _executeAcceptRequest(id);
    } else if (actionId == _kActionReject) {
      _executeRejectRequest(id);
    }
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<void> _executeAcceptRequest(int requestId) async {
  try {
    final res = await http.put(
      Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$requestId/accept'),
      headers: {'Content-Type': 'application/json'},
    );
    print('FCM: Accept $requestId -> ${res.statusCode}');
  } catch (e) {
    print('FCM: Accept failed: $e');
  }
}

@pragma('vm:entry-point')
Future<void> _executeRejectRequest(int requestId) async {
  try {
    final res = await http.put(
      Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$requestId/reject'),
      headers: {'Content-Type': 'application/json'},
    );
    print('FCM: Reject $requestId -> ${res.statusCode}');
  } catch (e) {
    print('FCM: Reject failed: $e');
  }
}

/// Handles FCM and local notifications for mechanic request Accept/Reject.
/// Call [initialize] from main() before runApp.
class FcmNotificationService {
  static final FcmNotificationService _instance = FcmNotificationService._();
  factory FcmNotificationService() => _instance;

  FcmNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  // Use getter so we only access FirebaseMessaging after Firebase.initializeApp() in _init()
  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;

  bool _initialized = false;

  /// Call once at app startup (from main.dart).
  static Future<void> initialize() async {
    await _instance._init();
  }

  /// Process notification action that launched the app (e.g. Accept/Reject from terminated state). Call after [initialize].
  static Future<void> processLaunchNotificationResponse() async {
    if (!_instance._initialized) return;
    try {
      final details = await _instance._localNotifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true && details?.notificationResponse != null) {
        _onNotificationResponse(details!.notificationResponse!);
      }
    } catch (_) {}
  }

  Future<void> _init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('[FCM] Firebase.initializeApp failed (add google-services.json in android/app/ and ensure Firebase project is set up): $e');
      return;
    }

    // Request permission (iOS, Android 13+)
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('FCM: Notification permission denied');
    }

    // Local notifications for foreground + action buttons
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Android: create channel and set up for FCM
    if (Platform.isAndroid) {
      final androidChannel = AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        description: 'New mechanic service requests',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    // FCM: foreground messages -> show local notification with actions
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // FCM: user tapped notification (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Background message handler (must be top-level for isolate)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessage);

    _initialized = true;
    print('FCM: Initialized');
  }

  static void _onNotificationResponse(NotificationResponse response) {
    print('FCM: NotificationResponse received actionId=${response.actionId} payload=${response.payload}');
    _stopMechanicAlarm();
    if (response.payload == null || response.payload!.isEmpty) {
      print('FCM: Ignoring response - no payload');
      return;
    }
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final requestId = data['requestId'] as String?;
      final actionId = response.actionId;
      if (type != 'mechanic_request' || requestId == null) {
        print('FCM: Ignoring response - type=$type requestId=$requestId');
        return;
      }
      final id = int.tryParse(requestId);
      if (id == null) {
        print('FCM: Invalid requestId $requestId');
        return;
      }
      if (actionId == _kActionAccept) {
        print('FCM: Executing Accept for requestId=$id');
        _executeAcceptRequest(id);
      } else if (actionId == _kActionReject) {
        print('FCM: Executing Reject for requestId=$id');
        _executeRejectRequest(id);
      } else {
        print('FCM: Unknown actionId=$actionId');
      }
    } catch (e) {
      print('FCM: _onNotificationResponse error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final requestId = data['requestId'];
    // Data-only FCM: title/body come from data map
    final title = data['title'] ?? message.notification?.title ?? 'New request';
    final body = data['body'] ?? message.notification?.body ?? 'A customer requested your service.';

    if (type == 'mechanic_request' && requestId != null) {
      print('FCM: Foreground message received, showing notification requestId=$requestId');
      _startMechanicAlarm();
      final payload = jsonEncode({'type': type, 'requestId': requestId});
      _showLocalNotification(
        id: _notificationIdFromRequestId(requestId),
        title: title,
        body: body,
        payload: payload,
      );
    }
  }

  /// Use a positive int for Android notification id (hashCode can be negative).
  static int _notificationIdFromRequestId(String requestId) {
    return requestId.hashCode & 0x7FFFFFFF;
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final requestId = data['requestId'];
    if (type == 'mechanic_request' && requestId != null) {
      // App opened from notification; could navigate to pending requests
      // For now we just log; dashboard will show pending on next load.
      print('FCM: Opened from notification requestId=$requestId');
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    // Strong vibration pattern: wait 0ms, vibrate 500ms, wait 250ms, vibrate 500ms (more noticeable)
    final vibrationPattern = Int64List.fromList([0, 500, 250, 500]);
    final androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: 'New mechanic service requests',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      enableLights: true,
      visibility: NotificationVisibility.public,
      // For a custom loud sound: add android/app/src/main/res/raw/notification_alert.mp3
      // and set: sound: RawResourceAndroidNotificationSound('notification_alert'),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(_kActionAccept, 'Accept', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction(_kActionReject, 'Reject', showsUserInterface: true, cancelNotification: true),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'mechanic_request',
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Returns current FCM token for this device. Use to register with backend.
  Future<String?> getToken() async {
    if (!_initialized) {
      print('[FCM] getToken skipped: not initialized (Firebase init failed or not run).');
      return null;
    }
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('[FCM] getToken failed: $e');
      return null;
    }
  }

  /// Open system notification settings for this app (so user can ensure notifications when app is closed).
  static Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await const MethodChannel(_kAlarmChannel).invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Open system battery / optimization settings (some phones need "Don't restrict" for notifications when app is closed).
  static Future<void> openBatterySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await const MethodChannel(_kAlarmChannel).invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  /// Register this device's FCM token for the given mechanic so they receive request notifications.
  static Future<void> registerMechanicToken(int mechanicId) async {
    final token = await _instance.getToken();
    if (token == null || token.isEmpty) {
      print('[FCM] Cannot register: no token (Firebase not initialized or permission denied?). Mechanic $mechanicId will NOT get push notifications.');
      return;
    }
    try {
      final url = '${ApiConfig.mechanicEndpoint}/$mechanicId/fcm-token';
      final res = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcmToken': token}),
      );
      if (res.statusCode == 200) {
        print('[FCM] Token registered for mechanicId=$mechanicId (this device will receive request notifications).');
      } else {
        print('[FCM] Register FAILED mechanicId=$mechanicId status=${res.statusCode} body=${res.body}');
      }
    } catch (e) {
      print('[FCM] Register error mechanicId=$mechanicId: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  final type = data['type'];
  final requestId = data['requestId'];
  // Data-only FCM: title/body come from data map
  final title = data['title'] ?? message.notification?.title ?? 'New request';
  final body = data['body'] ?? message.notification?.body ?? 'A customer requested your service.';
  if (type != 'mechanic_request' || requestId == null) return;

  // Note: 30-sec alarm only starts when app is in foreground (via _handleForegroundMessage).
  // Background handler runs in isolate without Activity, so method channel isn't available.

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await plugin.initialize(
    InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
  );

  if (Platform.isAndroid) {
    const androidChannel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: 'New mechanic service requests',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
  }

  final vibrationPattern = Int64List.fromList([0, 500, 250, 500]);
  final androidDetails = AndroidNotificationDetails(
    _kChannelId,
    _kChannelName,
    channelDescription: 'New mechanic service requests',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: vibrationPattern,
    visibility: NotificationVisibility.public,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(_kActionAccept, 'Accept', showsUserInterface: true, cancelNotification: true),
      AndroidNotificationAction(_kActionReject, 'Reject', showsUserInterface: true, cancelNotification: true),
    ],
  );
  const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
  final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
  final payload = jsonEncode({'type': type, 'requestId': requestId});
  final notifId = requestId.hashCode & 0x7FFFFFFF;
  await plugin.show(notifId, title, body, details, payload: payload);
}
