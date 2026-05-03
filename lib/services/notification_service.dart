import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service notifikasi lokal — mendukung notifikasi langsung dan terjadwal.
///
/// Strategi penjadwalan ganda: Timer (selama app aktif) + zonedSchedule (background).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  /// Menampilkan notifikasi secara langsung.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'airpulse_channel_id',
        'AirPulse Notifications',
        channelDescription: 'Notifikasi peringatan kualitas udara AirPulse',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  /// Menjadwalkan notifikasi pada waktu tertentu.
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'airpulse_planner_channel_id',
        'AirPulse Planner Notifications',
        channelDescription: 'Notifikasi jadwal perencana aktivitas',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    final difference = scheduledDate.difference(DateTime.now());
    if (difference.isNegative) return;

    // Timer fallback — aktif selama app terbuka
    Timer(difference, () {
      showNotification(id: id + 1000, title: title, body: body);
    });

    // zonedSchedule — aktif meskipun app di-background
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(difference),
        details,
        payload: scheduledDate.toIso8601String(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Timer fallback tetap aktif sebagai cadangan
    }
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() {
    return _plugin.pendingNotificationRequests();
  }

  static Future<void> cancelNotification(int id) => _plugin.cancel(id);
}
