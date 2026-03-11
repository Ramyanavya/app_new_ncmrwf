import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyLoginTime = 'login_timestamp';
  static const _sessionDuration = Duration(days: 14); // Change to Duration(days: 7) for 1 week

  /// Returns true if logged in AND session is still valid
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getString(_keyLoginTime);

    if (savedTime == null) return false;

    final loginTime = DateTime.parse(savedTime);
    final difference = DateTime.now().difference(loginTime);

    if (difference > _sessionDuration) {
      await logout(); // Auto-clear expired session
      return false;
    }

    return true;
  }

  /// Call this on successful login
  static Future<void> saveLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoginTime, DateTime.now().toIso8601String());
  }

  /// Call this on manual logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoginTime);
  }

  /// Returns true if a session existed but has now expired
  static Future<bool> wasSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getString(_keyLoginTime);

    if (savedTime == null) return false;

    final loginTime = DateTime.parse(savedTime);
    return DateTime.now().difference(loginTime) > _sessionDuration;
  }
}