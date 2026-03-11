import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'platform_io.dart' if (dart.library.html) 'platform_web.dart' as _platform;

const String _kNotificationsEnabledKey = 'mechanic_notifications_enabled';

// Top-level so background isolate can use them
const String _kChannelId = 'mechanic_requests';
const String _kChannelName = 'Mechanic requests';
const String _kActionAccept = 'accept';
const String _kActionReject = 'reject';
const String _kAlarmChannel = 'dyganox/mechanic_alarm';

/// Stop the 30-sec mechanic alarm (e.g. when user taps Accept/Reject).
void _stopMechanicAlarm() {
  if (!_platform.kIsAndroid) return;
  try {
    const channel = MethodChannel(_kAlarmChannel);
    channel.invokeMethod('stopAlarm');
  } catch (_) {}
}

/// Start 30-sec continuous alarm for mechanic request (foreground only).
Future<void> _startMechanicAlarm() async {
  if (!_platform.kIsAndroid) return;
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
/// Note: On Android the default Flutter FCM service is replaced by a custom native handler
/// (DyganoxFirebaseMessagingService), so foreground/background notifications are shown by native code.
class FcmNotificationService {
  /// Whether in-app notifications are enabled (stored in SharedPreferences). Default true.
  static Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kNotificationsEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Enable or disable showing notifications in the app (foreground local notifications).
  /// Background/native notifications may still appear depending on OS; this controls the in-app local notification.
  static Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotificationsEnabledKey, enabled);
    } catch (_) {}
  }
  static final FcmNotificationService _instance = FcmNotificationService._();
  factory FcmNotificationService() => _instance;

  FcmNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  // Use getter so we only access FirebaseMessaging after Firebase.initializeApp() in _init()
  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;

  bool _initialized = false;

  /// When a mechanic request FCM arrives and app is in foreground, call this so UI can show bottom sheet.
  /// Set from MechanicServiceDashboard; pass requestId (String).
  static void Function(String requestId)? onMechanicRequestInForeground;

  /// Register background message handler. Must be called from main() before [initialize].
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessage);
  }

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
    if (_platform.kIsAndroid) {
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

    // FCM: foreground messages -> show local notification with actions (used if default Flutter FCM service were enabled)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // FCM: user tapped notification (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Background handler already registered in main() via registerBackgroundHandler()

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

  void _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];
    final requestId = data['requestId'];
    final title = data['title'] ?? message.notification?.title ?? 'New request';
    final body = data['body'] ?? message.notification?.body ?? 'A customer requested your service.';

    if (type == 'mechanic_request' && requestId != null) {
      onMechanicRequestInForeground?.call(requestId);
      if (_platform.kIsAndroid) {
        return;
      }
      final enabled = await areNotificationsEnabled();
      if (!enabled) return;
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
      playSound: true,
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
    if (!_platform.kIsAndroid) return;
    try {
      await const MethodChannel(_kAlarmChannel).invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Open system battery / optimization settings (some phones need "Don't restrict" for notifications when app is closed).
  static Future<void> openBatterySettings() async {
    if (!_platform.kIsAndroid) return;
    try {
      await const MethodChannel(_kAlarmChannel).invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  /// When app was opened from "Accept" notification, returns the request ID so app can show request details. Does not clear; call clearLaunchRequestId after navigating.
  static Future<String?> getLaunchRequestId() async {
    if (!_platform.kIsAndroid) return null;
    try {
      final id = await const MethodChannel(_kAlarmChannel).invokeMethod<String>('getLaunchRequestId');
      return id;
    } catch (_) {
      return null;
    }
  }

  /// Set to true when we already navigated to request detail from Accept (method channel or lifecycle).
  /// Splash checks this so it does NOT replace request detail with HomePage at 3s.
  static bool didOpenRequestDetailFromNotification = false;

  /// Clear the launch request id after we have navigated to request detail (so we don't reopen it later).
  static Future<void> clearLaunchRequestId() async {
    if (!_platform.kIsAndroid) return;
    try {
      await const MethodChannel(_kAlarmChannel).invokeMethod('clearLaunchRequestId');
    } catch (_) {}
  }

  /// Save mechanic ID on device so Accept-from-notification can call accept-by/{mechanicId} and app can open Book flow detail.
  static Future<void> saveMechanicId(int mechanicId) async {
    if (!_platform.kIsAndroid) return;
    try {
      await const MethodChannel(_kAlarmChannel).invokeMethod('saveMechanicId', mechanicId);
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

  if (_platform.kIsAndroid) {
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
