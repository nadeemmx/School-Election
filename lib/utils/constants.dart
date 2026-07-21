import '../constants/positions.dart' show ElectionPositions;

class AppConstants {
  AppConstants._();

  static const String appName = 'School Election Voting';
  static const String subtitle = 'Secure • Simple • Transparent';
  static const String version = 'Version 1.0';

  // NOTE: In production, this should be loaded from a secure configuration
  // source (environment variables, encrypted storage, or backend API).
  // Hardcoding passwords in source code is a security risk.
  static const String defaultPassword = 'Gondia@123';

  /// Delegates to ElectionPositions.all as the single source of truth.
  static List<String> get positions => ElectionPositions.all;

  static const List<String> classes = [
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
  ];

  static const List<String> sections = ['A', 'B', 'C'];

  static const double cardRadius = 18;
  static const double buttonRadius = 14;
  static const double padding = 16;
}
