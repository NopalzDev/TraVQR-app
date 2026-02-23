import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  static const String _notificationKey = 'notifications_enabled';

  /// Check if notifications are enabled
  /// Returns true by default (notifications enabled)
  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationKey) ?? true;
  }

  /// Set notification preference
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationKey, enabled);
  }
}
