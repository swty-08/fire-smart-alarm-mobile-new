import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

const String serviceChannelId = 'fire_smart_alarm_service';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  final AndroidNotificationChannel channel =
    AndroidNotificationChannel(
    serviceChannelId,
    'Pemantauan Fire Smart Alarm',
    description: 'Layanan pemantauan sensor Fire Smart Alarm',
    importance: Importance.low,
    playSound: false,
  );

  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: serviceChannelId,
      initialNotificationTitle: 'Fire Smart Alarm',
      initialNotificationContent: 'Pemantauan sensor aktif',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void backgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  WidgetsFlutterBinding.ensureInitialized();

  const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

await localNotifications.initialize(
  settings: const InitializationSettings(
    android: androidSettings,
  ),
);

  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  await _checkSensorStatus();

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!await service.isForegroundService()) {
        return;
      }
    }

    await _checkSensorStatus();
  });
}

Future<void> _checkSensorStatus() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('fire-activity')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) return;

    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
        latestByDevice = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final deviceId = data['deviceId']?.toString() ?? '';

      if (deviceId.isEmpty) continue;

      latestByDevice.putIfAbsent(deviceId, () => doc);
    }

    final prefs = await SharedPreferences.getInstance();

    for (final entry in latestByDevice.entries) {
      final deviceId = entry.key;
      final data = entry.value.data();

      final status =
          (data['status'] ?? 'Normal').toString().toLowerCase();

      final previousStatus =
          prefs.getString('last_status_$deviceId');

      if (previousStatus == status) continue;

      await prefs.setString('last_status_$deviceId', status);

      if (status != 'warning' && status != 'danger') continue;

      final smoke = (data['smoke'] as num?)?.toDouble() ?? 0;
      final temperature =
          (data['temperature'] as num?)?.toDouble() ?? 0;

      final isDanger = status == 'danger';

      await localNotifications.show(
        id: deviceId.hashCode,
        title: isDanger
            ? 'DANGER! Fire Smart Alarm'
            : 'Peringatan Fire Smart Alarm',
        body:
            '$deviceId | Suhu: ${temperature.toStringAsFixed(1)}°C | Asap: ${smoke.toStringAsFixed(0)}',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            isDanger
                ? 'fire_smart_alarm_danger'
                : 'fire_smart_alarm_warning',
            isDanger
                ? 'Danger - Alarm Kebakaran'
                : 'Warning - Peringatan',
            channelDescription: 'Peringatan kondisi sensor',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(
              isDanger ? 'danger_alarm' : 'warning_alarm',
            ),
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('Background monitoring error: $e');
  }
}