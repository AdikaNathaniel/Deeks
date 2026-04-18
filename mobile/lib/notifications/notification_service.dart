import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  int _idFromMeetingId(String meetingId) => meetingId.hashCode & 0x7FFFFFFF;

  Future<void> scheduleTenMinutesBefore({
    required String meetingId,
    required String title,
    required String platformLabel,
    required DateTime scheduledAt,
  }) async {
    final fireAt = scheduledAt.subtract(const Duration(minutes: 10));
    if (fireAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: _idFromMeetingId(meetingId),
      title: 'Meeting in 10 minutes',
      body: '$title ($platformLabel)',
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'meetings_reminders',
          'Meeting reminders',
          channelDescription: '10-minute-before-meeting alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: meetingId,
    );
  }

  Future<void> cancelForMeeting(String meetingId) =>
      _plugin.cancel(id: _idFromMeetingId(meetingId));
}
