/// Hằng số toàn cục của ứng dụng.
class AppConstants {
  AppConstants._();

  // ---- Firestore collections ----
  static const String users = 'users';
  static const String circles = 'circles';
  static const String locations = 'locations';
  static const String sosEvents = 'sosEvents';
  static const String shareCodes = 'shareCodes';
  static const String auditLogs = 'auditLogs';
  static const String geofences = 'geofences';

  // ---- Sub-collection / field paths ----
  static const String members = 'members';
  static const String pings = 'pings';
  static const String publicKey = 'publicKey';
  static const String settings = 'settings';
  static const String sharingEnabled = 'sharingEnabled';

  // ---- Storage keys (flutter_secure_storage) ----
  static const String keyRefreshToken = 'refresh_token';
  static const String keyIdentityPrivate = 'identity_private_key';
  static const String keySessionKeys = 'session_keys';

  // ---- Sharing / location ----
  static const Duration locationInterval = Duration(seconds: 10);
  static const double locationDistanceFilterMeters = 20;
  static const Duration locationHistoryRetention = Duration(days: 1);

  // ---- SOS ----
  static const Duration sosCooldown = Duration(seconds: 30);
  static const Duration sosHoldDuration = Duration(seconds: 2);
  static const Duration sosExpiresAfter = Duration(minutes: 30);
  static const int sosAudioSeconds = 15;

  // ---- Share code ----
  static const int shareCodeLength = 6;
  static const Duration shareCodeDefaultTtl = Duration(minutes: 30);
  static const Duration shareCodeMaxTtl = Duration(hours: 24);

  // ---- Security ----
  static const int maxLoginAttempts = 5;
  static const Duration loginLockout = Duration(minutes: 15);
  static const int maxShareCodeAttempts = 5;
}
