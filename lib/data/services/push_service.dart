import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Dịch vụ tích hợp thông báo đẩy Firebase Cloud Messaging (FCM)
/// cho nhận cảnh báo khẩn cấp và Geofence ngay cả khi ứng dụng đang chạy nền.
class PushService {
  final FirebaseMessaging? _customFcm;
  final FirebaseFirestore? _customFirestore;

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  PushService({
    FirebaseMessaging? firebaseMessaging,
    FirebaseFirestore? firestore,
  })  : _customFcm = firebaseMessaging,
        _customFirestore = firestore;

  FirebaseMessaging get _fcm => _customFcm ?? FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// Yêu cầu quyền và thiết lập các listeners cho FCM.
  Future<void> initialize({
    required String? currentUserUid,
    void Function(RemoteMessage message)? onForegroundMessage,
  }) async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[PushService] User permission status: ${settings.authorizationStatus}');

      // ignore: deprecated_member_use
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null && currentUserUid != null) {
        await saveTokenToFirestore(currentUserUid, _fcmToken!);
      }

      _tokenRefreshSub?.cancel();
      // ignore: deprecated_member_use
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        if (currentUserUid != null) {
          await saveTokenToFirestore(currentUserUid, newToken);
        }
      });

      _messageSub?.cancel();
      _messageSub = FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[PushService] Received foreground message: ${message.messageId}');
        onForegroundMessage?.call(message);
      });
    } catch (e) {
      debugPrint('[PushService] FCM init skipped/failed (offline/test mode): $e');
    }
  }

  /// Cập nhật token FCM của thiết bị vào document `users/{uid}`
  Future<void> saveTokenToFirestore(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PushService] Save token failed: $e');
    }
  }

  void dispose() {
    _messageSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}
