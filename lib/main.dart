import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/school_config.dart';
import 'models/candidate.dart';
import 'services/candidate_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(CandidateModelAdapter());
  await CandidateService.initialize();
  await SchoolConfig.initialize();
  runApp(const SchoolElectionApp());
}

class SchoolElectionApp extends StatelessWidget {
  const SchoolElectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Election Voting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
