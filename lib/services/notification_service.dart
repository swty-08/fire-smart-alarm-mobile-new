
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _dangerChannelId = 'fire_smart_alarm_danger';
  static const String _warningChannelId = 'fire_smart_alarm_warning';
  static const String _normalChannelId = 'fire_smart_alarm_normal';

  static Future<void> initialize({String? webVapidKey}) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Status izin notifikasi: ${settings.authorizationStatus}',
    );

    if (!kIsWeb) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initializationSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localPlugin.initialize(
        settings: initializationSettings,
      );

      final androidPlugin = _localPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();

      // Channel Danger: suara alarm khusus.
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _dangerChannelId,
          'Danger - Alarm Kebakaran',
          description: 'Alarm untuk kondisi bahaya',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('danger_alarm'),
        ),
      );

      // Channel Warning: suara peringatan khusus.
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _warningChannelId,
          'Warning - Peringatan',
          description: 'Peringatan kondisi sensor',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('warning_alarm'),
        ),
      );

      // Channel Normal: tanpa suara.
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _normalChannelId,
          'Informasi Fire Smart Alarm',
          description: 'Informasi kondisi normal tanpa suara',
          importance: Importance.low,
          playSound: false,
        ),
      );
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Izin notifikasi ditolak.');
      return;
    }

    if (kIsWeb) {
      if (webVapidKey == null || webVapidKey.isEmpty) {
        debugPrint('Web VAPID key belum dikonfigurasi.');
        return;
      }

      final token = await _messaging.getToken(vapidKey: webVapidKey);
      debugPrint('TOKEN FCM: $token');
    } else {
      final token = await _messaging.getToken();
      debugPrint('TOKEN FCM: $token');
    }
  }

  static void listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title =
          message.notification?.title ?? 'Fire Smart Alarm';
      final body = message.notification?.body ?? '';

      debugPrint('Notifikasi FCM: $title');

      if (kIsWeb || message.notification == null) return;

      // Utamakan status dari data payload FCM.
      final status = (message.data['status'] ??
              '$title $body')
          .toString()
          .toLowerCase();

      final bool isDanger = status.contains('danger');
      final bool isWarning = status.contains('warning');
      final bool isNormal = status.contains('normal');

      // Hanya Danger dan Warning yang menggunakan suara khusus.
      // Normal ditampilkan tanpa suara.
      final String channelId;
      final String channelName;
      final AndroidNotificationDetails androidDetails;

      if (isDanger) {
        channelId = _dangerChannelId;
        channelName = 'Danger - Alarm Kebakaran';
        androidDetails = const AndroidNotificationDetails(
          _dangerChannelId,
          'Danger - Alarm Kebakaran',
          channelDescription: 'Alarm untuk kondisi bahaya',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('danger_alarm'),
        );
      } else if (isWarning) {
        channelId = _warningChannelId;
        channelName = 'Warning - Peringatan';
        androidDetails = const AndroidNotificationDetails(
          _warningChannelId,
          'Warning - Peringatan',
          channelDescription: 'Peringatan kondisi sensor',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('warning_alarm'),
        );
      } else if (isNormal) {
        channelId = _normalChannelId;
        channelName = 'Informasi Fire Smart Alarm';
        androidDetails = const AndroidNotificationDetails(
          _normalChannelId,
          'Informasi Fire Smart Alarm',
          channelDescription: 'Informasi kondisi normal tanpa suara',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
        );
      } else {
        // Pesan yang tidak diketahui statusnya tidak diberi
        // suara alarm Danger atau Warning.
        return;
      }

      debugPrint('Channel notifikasi: $channelId ($channelName)');

      await _localPlugin.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
        ),
      );
    });
  }

  static Future<void> showStatusNotification({
    required String status,
    required double temperature,
    required double smoke,
  }) async {
    if (kIsWeb) return;

    final normalizedStatus = status.toLowerCase();
    final isDanger = normalizedStatus == 'danger';
    final isWarning = normalizedStatus == 'warning';

    // Status Normal tidak menghasilkan alarm khusus.
    if (!isDanger && !isWarning) return;

    final String channelId = isDanger
        ? _dangerChannelId
        : _warningChannelId;

    final String channelName = isDanger
        ? 'Danger - Alarm Kebakaran'
        : 'Warning - Peringatan';

    final AndroidNotificationDetails androidDetails =
        isDanger
            ? const AndroidNotificationDetails(
                _dangerChannelId,
                'Danger - Alarm Kebakaran',
                channelDescription: 'Alarm untuk kondisi bahaya',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                sound: RawResourceAndroidNotificationSound('danger_alarm'),
              )
            : const AndroidNotificationDetails(
                _warningChannelId,
                'Warning - Peringatan',
                channelDescription: 'Peringatan kondisi sensor',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                sound: RawResourceAndroidNotificationSound('warning_alarm'),
              );

    await _localPlugin.show(
      id: isDanger ? 1001 : 1002,
      title: isDanger
          ? 'DANGER! Fire Smart Alarm'
          : 'Peringatan Fire Smart Alarm',
      body:
          'Status: $status | Suhu: ${temperature.toStringAsFixed(1)}°C | Asap: ${smoke.toStringAsFixed(0)}',
      notificationDetails: NotificationDetails(
        android: androidDetails,
      ),
    );

    debugPrint(
      'Notifikasi ditampilkan: $status, channel: $channelId ($channelName)',
    );
  }

static Future<void> testDangerNotification() async {
  await _localPlugin.show(
    id: 9999,
    title: 'TES DANGER',
    body: 'Jika pesan ini muncul, notifikasi lokal berfungsi.',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _dangerChannelId,
        'Danger - Alarm Kebakaran',
        channelDescription: 'Alarm untuk kondisi bahaya',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('danger_alarm'),
      ),
    ),
  );
}

}