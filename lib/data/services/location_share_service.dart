import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';

class DecryptedLocation {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final bool isMocked;
  final int? battery;

  const DecryptedLocation({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.isMocked = false,
    this.battery,
  });
}

class GeofenceAlertEvent {
  final String eventId;
  final String uid;
  final String senderName;
  final String fenceName;
  final String action; // 'enter' | 'exit'
  final double lat;
  final double lng;
  final DateTime timestamp;

  const GeofenceAlertEvent({
    required this.eventId,
    required this.uid,
    required this.senderName,
    required this.fenceName,
    required this.action,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  bool get isEnter => action == 'enter';
  bool get isExit => action == 'exit';
}

/// Dịch vụ chia sẻ tọa độ E2EE theo chu kỳ (mỗi 30s) và cảnh báo Geofence realtime.
class LocationShareService {
  final CryptoService _crypto;
  final FirebaseFirestore? _customFirestore;
  final Duration throttleDuration;

  DateTime? _lastPublishedTime;
  DateTime? get lastPublishedTime => _lastPublishedTime;

  LocationShareService({
    CryptoService? cryptoService,
    FirebaseFirestore? firestore,
    this.throttleDuration = const Duration(seconds: 30),
  })  : _crypto = cryptoService ?? CryptoService(),
        _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// Kiểm tra có thỏa mãn điều kiện throttle (mỗi 30s) hay không.
  bool canPublish(DateTime now) {
    if (_lastPublishedTime == null) return true;
    return now.difference(_lastPublishedTime!) >= throttleDuration;
  }

  /// Mã hóa và đẩy vị trí lên Firestore: `locations/{uid}`.
  /// Bỏ qua nếu chưa đủ 30 giây kể từ lần gửi trước (trừ khi [force] = true).
  Future<bool> publishLocation({
    required String uid,
    required double lat,
    required double lng,
    required bool isMocked,
    int? battery,
    required SecretKey key,
    bool force = false,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    if (!force && !canPublish(currentTime)) {
      return false; // Throttled
    }

    final encryptedPos = await _crypto.encryptLocationPayload(
      lat: lat,
      lng: lng,
      key: key,
    );

    try {
      final Map<String, dynamic> data = {
        'uid': uid,
        'encryptedPos': encryptedPos,
        'updatedAt': FieldValue.serverTimestamp(),
        'isMocked': isMocked,
      };
      if (battery != null) {
        data['battery'] = battery;
      }
      await _firestore.collection('locations').doc(uid).set(data);
      _lastPublishedTime = currentTime;
      return true;
    } catch (e) {
      debugPrint('[LocationShareService] publishLocation failed: $e');
      return false;
    }
  }

  /// Giải mã một document vị trí lấy từ Firestore `locations/{uid}`.
  Future<DecryptedLocation> decryptLocationDoc({
    required Map<String, dynamic> docData,
    required SecretKey key,
  }) async {
    final encryptedPos = docData['encryptedPos'] as String;
    final isMocked = docData['isMocked'] as bool? ?? false;
    final battery = (docData['battery'] as num?)?.toInt();

    final payload = await _crypto.decryptLocationPayload(
      encryptedBase64: encryptedPos,
      key: key,
    );

    final lat = (payload['lat'] as num).toDouble();
    final lng = (payload['lng'] as num).toDouble();
    final tsMillis = (payload['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

    return DecryptedLocation(
      lat: lat,
      lng: lng,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tsMillis),
      isMocked: isMocked,
      battery: battery,
    );
  }

  /// Mã hóa và đăng tải sự kiện Geofence lên `geofence_events/{eventId}`.
  Future<void> publishGeofenceEvent({
    required String eventId,
    required String uid,
    required String senderName,
    required String fenceName,
    required String action, // 'enter' | 'exit'
    required double lat,
    required double lng,
    required SecretKey key,
  }) async {
    final encryptedEvent = await _crypto.encryptLocationPayload(
      lat: lat,
      lng: lng,
      key: key,
    );

    try {
      await _firestore.collection('geofence_events').doc(eventId).set({
        'eventId': eventId,
        'uid': uid,
        'senderName': senderName,
        'fenceName': fenceName,
        'action': action,
        'encryptedEvent': encryptedEvent,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[LocationShareService] publishGeofenceEvent failed: $e');
    }
  }

  /// Giải mã sự kiện Geofence từ Firestore doc.
  Future<GeofenceAlertEvent> decryptGeofenceDoc({
    required Map<String, dynamic> docData,
    required SecretKey key,
  }) async {
    final eventId = docData['eventId'] as String? ?? '';
    final uid = docData['uid'] as String? ?? '';
    final senderName = docData['senderName'] as String? ?? 'Người thân';
    final fenceName = docData['fenceName'] as String? ?? 'Vùng an toàn';
    final action = docData['action'] as String? ?? 'enter';
    final encryptedEvent = docData['encryptedEvent'] as String? ?? '';

    double lat = 0.0;
    double lng = 0.0;
    DateTime timestamp = DateTime.now();

    if (encryptedEvent.isNotEmpty) {
      try {
        final payload = await _crypto.decryptLocationPayload(
          encryptedBase64: encryptedEvent,
          key: key,
        );
        lat = (payload['lat'] as num).toDouble();
        lng = (payload['lng'] as num).toDouble();
        final ts = (payload['timestamp'] as num?)?.toInt();
        if (ts != null) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
        }
      } catch (_) {}
    }

    return GeofenceAlertEvent(
      eventId: eventId,
      uid: uid,
      senderName: senderName,
      fenceName: fenceName,
      action: action,
      lat: lat,
      lng: lng,
      timestamp: timestamp,
    );
  }
}
