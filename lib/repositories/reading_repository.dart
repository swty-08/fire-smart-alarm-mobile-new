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
            final rawTimestamp = data['timestamp'];
            final parsedTimestamp = rawTimestamp is Timestamp
                ? rawTimestamp.toDate()
                : DateTime.now();

            return Reading(
              deviceId: data['deviceId']?.toString() ?? '',
              smoke: ((data['smoke'] ?? 0) as num).toDouble(),
              temperature: ((data['temperature'] ?? 0) as num).toDouble(),
              humidity: ((data['humidity'] ?? 0) as num).toDouble(),
              status: data['status']?.toString() ?? 'Normal',
              timestamp: parsedTimestamp,
            );
          }).toList();
        });
  }
}
