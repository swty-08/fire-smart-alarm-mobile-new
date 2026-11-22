import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reading.dart';

class ReadingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Reading>> getReadings() {
    return _firestore
        .collection('fire-activity')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final rawTs = data['timestamp'];
        final DateTime parsedTime = rawTs is Timestamp
            ? rawTs.toDate()
            : DateTime.tryParse(rawTs?.toString() ?? '') ?? DateTime.now();

        return Reading(
          deviceId: data['deviceId']?.toString() ?? '',
          smoke: (data['smoke'] as num? ?? 0).toDouble(),
          temperature: (data['temperature'] as num? ?? 0).toDouble(),
          humidity: (data['humidity'] as num? ?? 0).toDouble(),
          status: data['status']?.toString() ?? 'Normal',
          timestamp: parsedTime,
        );
      }).toList();
    });
  }
}
