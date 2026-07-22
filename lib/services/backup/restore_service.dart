import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../config/school_config.dart';
import '../../models/candidate.dart';
import '../../services/candidate_service.dart';
import 'backup_models.dart';
import 'photo_backup_service.dart';
import 'zip_service.dart';

class RestoreResult {
  final bool success;
  final String message;
  final int candidatesRestored;
  final int votesRestored;
  final int photosRestored;

  const RestoreResult({
    required this.success,
    required this.message,
    this.candidatesRestored = 0,
    this.votesRestored = 0,
    this.photosRestored = 0,
  });
}

class EmergencyBackup {
  final List<CandidateModel> candidates;
  final Map<String, dynamic> votes;
  final Map<String, dynamic> config;

  const EmergencyBackup({
    required this.candidates,
    required this.votes,
    required this.config,
  });
}

class RestoreService {
  static Future<RestoreResult> performRestore(
    String zipPath, {
    void Function(double progress, String message)? onProgress,
  }) async {
    EmergencyBackup? emergencyBackup;
    final tempDir =
        await Directory.systemTemp.createTemp('school_election_restore_');

    try {
      onProgress?.call(0.0, 'Creating emergency backup...');
      emergencyBackup = await _createEmergencyBackup();

      onProgress?.call(0.05, 'Validating ZIP file...');
      if (!ZipService.isValidZip(zipPath)) {
        return const RestoreResult(
          success: false,
          message: 'Invalid or corrupted ZIP file.',
        );
      }

      onProgress?.call(0.1, 'Extracting backup...');
      await ZipService.extractZip(zipPath, tempDir.path);

      // ── Debug: log exact ZIP structure ──
      debugPrint('[RestoreService] Extracted ZIP at: ${tempDir.path}');
      final extractedEntities = tempDir.listSync(recursive: true);
      for (final entity in extractedEntities) {
        if (entity is File) {
          debugPrint('[RestoreService]   ${p.relative(entity.path, from: tempDir.path)}');
        } else if (entity is Directory) {
          debugPrint('[RestoreService]   ${p.relative(entity.path, from: tempDir.path)}/');
        }
      }

      // ── Detect backup structure format ──
      //   Nested (legacy): backup/backup.json, backup/photos/*
      //   Flat (current):  backup.json, photos/*
      final nestedBackupDir = Directory(p.join(tempDir.path, 'backup'));
      late final Directory backupDir;
      late final Directory photosDir;

      if (nestedBackupDir.existsSync()) {
        debugPrint('[RestoreService] Detected nested backup structure (backup/ subdirectory)');
        backupDir = nestedBackupDir;
      } else {
        debugPrint('[RestoreService] Detected flat backup structure (root level)');
        backupDir = tempDir;
      }
      photosDir = Directory(p.join(backupDir.path, 'photos'));

      onProgress?.call(0.15, 'Reading backup manifest...');
      final backupJsonFile = File(p.join(backupDir.path, 'backup.json'));
      if (!backupJsonFile.existsSync()) {
        return const RestoreResult(
          success: false,
          message: 'Invalid backup: backup.json not found.',
        );
      }

      final jsonStr = await backupJsonFile.readAsString();
      final Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        return RestoreResult(
          success: false,
          message: 'Invalid JSON in backup file: $e',
        );
      }

      final backupData = BackupData.fromJson(jsonData);

      onProgress?.call(0.25, 'Validating candidate data...');
      final validationError = _validateBackupData(backupData);
      if (validationError != null) {
        return RestoreResult(
          success: false,
          message: validationError,
        );
      }

      onProgress?.call(0.35, 'Validating photo files...');
      final photoFilesValid = _validatePhotoFiles(
        backupData.candidates,
        photosDir.path,
      );
      if (!photoFilesValid) {
        return RestoreResult(
          success: false,
          message:
              'Backup is missing some photo files required by candidates.',
        );
      }

      onProgress?.call(0.45, 'Restoring candidates...');
      await _restoreCandidates(backupData.candidates);

      onProgress?.call(0.6, 'Restoring votes...');
      await _restoreVotes(backupData.votes);

      onProgress?.call(0.7, 'Restoring configuration...');
      await _restoreConfig(backupData.appConfig);

      onProgress?.call(0.8, 'Restoring photos...');
      final photoFiles = <String, String>{};
      for (final c in backupData.candidates) {
        if (c.photoFile != null && c.photoFile!.isNotEmpty) {
          photoFiles[c.id] = c.photoFile!;
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      final appPhotosDir = p.join(appDir.path, 'restored_photos');

      final restoredPhotoPaths = await PhotoBackupService.restorePhotos(
        photoFiles,
        photosDir.path,
        appPhotosDir,
      );

      onProgress?.call(0.9, 'Updating photo paths...');
      await _updatePhotoPaths(restoredPhotoPaths);

      onProgress?.call(0.95, 'Verifying restored data...');
      final verificationError = await _verifyRestore(
        backupData,
        restoredPhotoPaths,
      );
      if (verificationError != null) {
        await _rollback(emergencyBackup);
        return RestoreResult(
          success: false,
          message: 'Verification failed: $verificationError. Data rolled back.',
        );
      }

      onProgress?.call(1.0, 'Restore complete!');

      return RestoreResult(
        success: true,
        message: 'All data restored successfully!',
        candidatesRestored: backupData.candidates.length,
        votesRestored: backupData.votes.length,
        photosRestored: restoredPhotoPaths.length,
      );
    } catch (e, stack) {
      debugPrint('Restore error: $e\n$stack');
      if (emergencyBackup != null) {
        await _rollback(emergencyBackup);
      }
      return RestoreResult(
        success: false,
        message: 'Restore failed: ${e.toString()}. Data has been rolled back.',
      );
    } finally {
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  static String? _validateBackupData(BackupData data) {
    if (data.candidates.isEmpty) {
      return 'Backup contains no candidates.';
    }

    for (int i = 0; i < data.candidates.length; i++) {
      final c = data.candidates[i];
      if (c.id.isEmpty) {
        return 'Candidate #${i + 1} has an empty ID.';
      }
      if (c.name.isEmpty) {
        return 'Candidate #${i + 1} has an empty name.';
      }
      if (c.position.isEmpty) {
        return 'Candidate #${i + 1} has an empty position.';
      }
      if (c.className.isEmpty) {
        return 'Candidate #${i + 1} has an empty class.';
      }
      if (c.section.isEmpty) {
        return 'Candidate #${i + 1} has an empty section.';
      }
      if (c.rollNumber.isEmpty) {
        return 'Candidate #${i + 1} has an empty roll number.';
      }
      if (c.createdAt.isEmpty) {
        return 'Candidate #${i + 1} has no creation timestamp.';
      }
    }

    if (data.appConfig.schoolName.isEmpty) {
      return 'Backup is missing the school name configuration.';
    }

    return null;
  }

  static bool _validatePhotoFiles(
    List<BackupCandidate> candidates,
    String photosDirPath,
  ) {
    final photosDir = Directory(photosDirPath);
    if (!photosDir.existsSync()) {
      // No photos directory means no photos to validate
      return candidates.where((c) => c.photoFile != null).isEmpty;
    }

    for (final c in candidates) {
      if (c.photoFile == null || c.photoFile!.isEmpty) continue;
      final photoFile = File(p.join(photosDirPath, c.photoFile!));
      if (!photoFile.existsSync()) {
        return false;
      }
      if (photoFile.lengthSync() == 0) {
        return false;
      }
    }
    return true;
  }

  static Future<EmergencyBackup> _createEmergencyBackup() async {
    final candidates = CandidateService.getAll();

    final voteBox = Hive.box('votes');
    final Map<String, dynamic> votes = {};
    for (final key in voteBox.keys) {
      votes[key.toString()] = voteBox.get(key);
    }

    final configBox = Hive.box('app_config');
    final Map<String, dynamic> config = {};
    for (final key in configBox.keys) {
      config[key.toString()] = configBox.get(key);
    }

    return EmergencyBackup(
      candidates: candidates.map((c) => c.copyWith()).toList(),
      votes: votes,
      config: config,
    );
  }

  static Future<void> _restoreCandidates(
      List<BackupCandidate> backupCandidates) async {
    final box = await Hive.openBox<CandidateModel>('candidates');
    await box.clear();

    for (final c in backupCandidates) {
      final candidate = CandidateModel(
        id: c.id,
        name: c.name,
        position: c.position,
        className: c.className,
        section: c.section,
        rollNumber: c.rollNumber,
        photoPath: null,
        votes: c.votes,
        createdAt: DateTime.tryParse(c.createdAt) ?? DateTime.now(),
      );
      await box.put(c.id, candidate);
    }
  }

  static Future<void> _restoreVotes(List<BackupVote> backupVotes) async {
    final voteBox = await Hive.openBox('votes');
    await voteBox.clear();

    for (final v in backupVotes) {
      await voteBox.put(v.key, v.value);
    }
  }

  static Future<void> _restoreConfig(BackupConfig config) async {
    final configBox = await Hive.openBox('app_config');
    await configBox.clear();

    await configBox.put('schoolName', config.schoolName);
    await configBox.put('academicYear', config.academicYear);
    if (config.logoUrl != null) {
      await configBox.put('logoUrl', config.logoUrl);
    }

    SchoolConfig.schoolName = config.schoolName;
    SchoolConfig.academicYear = config.academicYear;
    SchoolConfig.logoUrl = config.logoUrl;
  }

  static Future<void> _updatePhotoPaths(
      Map<String, String> restoredPhotoPaths) async {
    final box = Hive.box<CandidateModel>('candidates');

    for (final entry in restoredPhotoPaths.entries) {
      final candidate = box.get(entry.key);
      if (candidate != null) {
        candidate.photoPath = entry.value;
        await box.put(entry.key, candidate);
      }
    }
  }

  static Future<String?> _verifyRestore(
    BackupData backupData,
    Map<String, String> restoredPhotoPaths,
  ) async {
    final box = Hive.box<CandidateModel>('candidates');
    final restoredCandidates = box.values.toList();

    if (restoredCandidates.length != backupData.candidates.length) {
      return 'Candidate count mismatch: expected ${backupData.candidates.length}, got ${restoredCandidates.length}';
    }

    for (final c in backupData.candidates) {
      final restored = box.get(c.id);
      if (restored == null) {
        return 'Candidate ${c.id} (${c.name}) is missing after restore';
      }
      if (restored.name != c.name) {
        return 'Candidate ${c.id} name mismatch: expected "${c.name}", got "${restored.name}"';
      }
      if (restored.votes != c.votes) {
        return 'Candidate ${c.id} votes mismatch: expected ${c.votes}, got ${restored.votes}';
      }
    }

    final voteBox = Hive.box('votes');
    if (voteBox.length != backupData.votes.length) {
      return 'Vote count mismatch: expected ${backupData.votes.length}, got ${voteBox.length}';
    }

    for (final v in backupData.votes) {
      final restoredValue = voteBox.get(v.key);
      if (restoredValue == null) {
        return 'Vote entry "${v.key}" is missing after restore';
      }
    }

    final configBox = Hive.box('app_config');
    final restoredSchoolName =
        configBox.get('schoolName', defaultValue: '') as String;
    if (restoredSchoolName != backupData.appConfig.schoolName) {
      return 'School name mismatch after restore';
    }

    for (final entry in restoredPhotoPaths.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) {
        return 'Restored photo for candidate ${entry.key} does not exist';
      }
    }

    for (final c in backupData.candidates) {
      if (restoredPhotoPaths.containsKey(c.id)) {
        final restored = box.get(c.id);
        if (restored == null || restored.photoPath == null) {
          return 'Candidate ${c.id} photo path is null after restore';
        }
        final photoFile = File(restored.photoPath!);
        if (!photoFile.existsSync()) {
          return 'Candidate ${c.id} photo file missing at ${restored.photoPath}';
        }
      }
    }

    return null;
  }

  static Future<void> _rollback(EmergencyBackup backup) async {
    try {
      final candidateBox = await Hive.openBox<CandidateModel>('candidates');
      await candidateBox.clear();
      for (final c in backup.candidates) {
        await candidateBox.put(c.id, c);
      }

      final voteBox = await Hive.openBox('votes');
      await voteBox.clear();
      for (final entry in backup.votes.entries) {
        await voteBox.put(entry.key, entry.value);
      }

      final configBox = await Hive.openBox('app_config');
      await configBox.clear();
      for (final entry in backup.config.entries) {
        await configBox.put(entry.key, entry.value);
      }

      SchoolConfig.schoolName =
          backup.config['schoolName'] as String? ?? SchoolConfig.schoolName;
      SchoolConfig.academicYear =
          backup.config['academicYear'] as String? ?? SchoolConfig.academicYear;
      SchoolConfig.logoUrl = backup.config['logoUrl'] as String?;
    } catch (e) {
      debugPrint('Rollback failed: $e');
    }
  }
}
