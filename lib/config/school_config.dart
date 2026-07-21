import 'package:hive_flutter/hive_flutter.dart';

class SchoolConfig {
  static const String _boxName = 'app_config';

  static String schoolName = 'Gondia Public School';
  static String academicYear = 'School Council Election 2026-27';
  static String? logoUrl;

  static Future<void> initialize() async {
    final box = await Hive.openBox(_boxName);
    schoolName = box.get('schoolName', defaultValue: schoolName) as String;
    academicYear = box.get('academicYear', defaultValue: academicYear) as String;
    logoUrl = box.get('logoUrl') as String?;
  }
}
