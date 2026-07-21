import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../models/candidate.dart';
import '../../services/candidate_service.dart';

class PhotoBackupService {
  static const _uuid = Uuid();

  static Future<Map<String, String>> copyPhotosToBackup(
      List<CandidateModel> candidates, String photosDir) async {
    final photoDir = Directory(photosDir);
    if (!photoDir.existsSync()) {
      await photoDir.create(recursive: true);
    }

    final Map<String, String> candidatePhotoMap = {};

    for (final candidate in candidates) {
      if (candidate.photoPath == null || candidate.photoPath!.isEmpty) {
        continue;
      }

      final sourceFile = File(candidate.photoPath!);
      if (!sourceFile.existsSync()) {
        continue;
      }

      final extension = p.extension(candidate.photoPath!);
      final photoFilename = '${_uuid.v4()}$extension';
      final destFile = File(p.join(photosDir, photoFilename));

      try {
        await sourceFile.copy(destFile.path);
        candidatePhotoMap[candidate.id] = photoFilename;
      } catch (_) {
        // Skip if copy fails
      }
    }

    return candidatePhotoMap;
  }

  static Future<Map<String, String>> restorePhotos(
    Map<String, String> photoFiles,
    String photosSourceDir,
    String appPhotosDir,
  ) async {
    final appPhotosDirObj = Directory(appPhotosDir);
    if (!appPhotosDirObj.existsSync()) {
      await appPhotosDirObj.create(recursive: true);
    }

    final Map<String, String> restoreMap = {};

    for (final entry in photoFiles.entries) {
      final candidateId = entry.key;
      final photoFilename = entry.value;

      if (photoFilename.isEmpty) continue;

      final sourceFile = File(p.join(photosSourceDir, photoFilename));
      if (!sourceFile.existsSync()) continue;

      final destFile = File(p.join(appPhotosDir, photoFilename));
      try {
        await sourceFile.copy(destFile.path);
        restoreMap[candidateId] = destFile.path;
      } catch (_) {
        // Skip if copy fails
      }
    }

    return restoreMap;
  }

  static Future<List<CandidateModel>> getCandidatesWithPhotoPaths() async {
    return CandidateService.getAll();
  }
}
