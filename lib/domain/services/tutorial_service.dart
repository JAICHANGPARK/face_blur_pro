import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing tutorial/onboarding state
class TutorialService {
  static const String _keyTutorialShown = 'tutorial_shown';

  /// Check if the tutorial has been shown before
  static Future<bool> isTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTutorialShown) ?? false;
  }

  /// Mark the tutorial as shown
  static Future<void> setTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialShown, true);
  }

  /// Reset tutorial state (for testing or settings)
  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialShown, false);
  }
}
