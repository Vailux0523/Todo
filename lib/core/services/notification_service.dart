import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database for scheduled notifications
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _fln.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification taps
        if (kDebugMode) {
          debugPrint('Notification tapped: ${response.payload}');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Android notification channel (required for Android 8.0+)
    const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
      'todo_default_channel',
      'General',
      description: 'General notifications',
      importance: Importance.high,
    );
    final androidImpl = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(defaultChannel);

    _initialized = true;
  }

  static void notificationTapBackground(NotificationResponse response) {
    // Handle background tap
    if (kDebugMode) {
      debugPrint('Background notification tapped: ${response.payload}');
    }
  }

  Future<bool> requestPermissions() async {
    // Use permission_handler uniformly for both platforms
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  NotificationDetails _defaultDetails() {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'todo_default_channel',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.high, // heads-up
      priority: Priority.high,     // heads-up
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public, // lock screen content
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
    );
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _fln.show(id, title, body, _defaultDetails(), payload: payload);
  }

  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    bool allowWhileIdle = true,
  }) async {
    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _fln.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      _defaultDetails(),
      // Use default/inexact scheduling to avoid requiring exact alarm permission
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      payload: payload,
    );
  }

  Future<void> cancel(int id) async => _fln.cancel(id);
  Future<void> cancelAll() async => _fln.cancelAll();
}
