import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:school_election_fe/config/school_config.dart';
import 'package:school_election_fe/main.dart';
import 'package:school_election_fe/models/candidate.dart';
import 'package:school_election_fe/services/candidate_service.dart';

void main() {
  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(dir.path);
    Hive.registerAdapter(CandidateModelAdapter());
    await CandidateService.initialize();
    await SchoolConfig.initialize();
  });

  tearDown(() async {
    try {
      await Hive.close();
    } catch (_) {}
  });

  testWidgets('App should render splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SchoolElectionApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SCHOOL'), findsOneWidget);
    expect(find.text('ELECTION'), findsOneWidget);
    expect(find.text('MANAGEMENT SYSTEM'), findsOneWidget);
    expect(find.text('Your Vote. Your Voice.'), findsOneWidget);

    // Advance past all timers to avoid pending timer error
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
