import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/candidate.dart';
import '../../services/candidate_service.dart';
import '../backup/zip_service.dart';
import 'csv_parser.dart';
import 'import_models.dart';

class ImportService {
  static const _uuid = Uuid();

  static ImportSummary? parseZip(String zipPath) {
    final tempDir = Directory.systemTemp.createTempSync('school_election_import_');

    try {
      ZipService.extractZipSync(zipPath, tempDir.path);

      debugPrint('[ImportService] Extracted ZIP to: ${tempDir.path}');
      final entities = tempDir.listSync(recursive: true);
      for (final e in entities) {
        if (e is File) {
          debugPrint('[ImportService]   ${p.relative(e.path, from: tempDir.path)} (${e.lengthSync()} bytes)');
        } else if (e is Directory) {
          debugPrint('[ImportService]   ${p.relative(e.path, from: tempDir.path)}/');
        }
      }

      File? csvFile;
      Directory? photosDir;

      for (final e in tempDir.listSync()) {
        if (e is File && _isCsvFile(e)) {
          csvFile = e;
        } else if (e is Directory && p.basename(e.path) == 'photos') {
          photosDir = e;
        }
      }

      if (csvFile == null) {
        debugPrint('[ImportService] No CSV file found in ZIP');
        return null;
      }

      debugPrint('[ImportService] Found CSV: ${csvFile.path}');
      debugPrint('[ImportService] Found photos dir: ${photosDir?.path}');

      final summary = CsvParser.parse(csvFile, photosDir ?? Directory(tempDir.path));

      if (summary == null) {
        debugPrint('[ImportService] CSV parsing returned null');
      } else {
        debugPrint('[ImportService] Parsed ${summary.totalRows} rows, '
            '${summary.validCount} valid, '
            '${summary.errorCount} errors, '
            '${summary.warningCount} warnings');
      }

      return summary;
    } catch (e, stack) {
      debugPrint('[ImportService] Parse error: $e\n$stack');
      return null;
    } finally {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  static Future<ImportResult> performImport(
    String zipPath,
    ImportSummary summary, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final tempDir = Directory.systemTemp.createTempSync('school_election_import_');

    try {
      debugPrint('[ImportService] === performImport started ===');
      debugPrint('[ImportService] zipPath=$zipPath');
      debugPrint('[ImportService] validRows=${summary.rows.where((r) => r.isValid).length}');
      debugPrint('[ImportService] totalRows=${summary.totalRows}');

      onProgress?.call(0.0, 'Extracting ZIP...');
      ZipService.extractZipSync(zipPath, tempDir.path);
      debugPrint('[ImportService] ZIP extracted to ${tempDir.path}');

      onProgress?.call(0.1, 'Creating safety snapshot...');
      final snapshot = await _createSnapshot();
      debugPrint('[ImportService] Snapshot created with ${snapshot.candidates.length} existing candidates');

      Directory? photosDir;
      for (final e in tempDir.listSync()) {
        if (e is Directory && p.basename(e.path) == 'photos') {
          photosDir = e;
        }
      }
      debugPrint('[ImportService] Photos dir: ${photosDir?.path}');

      onProgress?.call(0.2, 'Importing candidates...');
      final validRows = summary.rows.where((r) => r.isValid).toList();
      final candidatesBox = Hive.box<CandidateModel>('candidates');
      int created = 0;

      debugPrint('[ImportService] Candidate box type: ${candidatesBox.runtimeType}');
      debugPrint('[ImportService] Candidate box length before: ${candidatesBox.length}');

      final List<String> createdIds = [];
      for (final row in validRows) {
        final id = _uuid.v4();
        final candidate = CandidateModel(
          id: id,
          name: row.name,
          position: row.resolvedPosition!,
          className: row.resolvedClass!,
          section: row.section,
          rollNumber: row.rollNumber,
          photoPath: null,
          votes: 0,
        );
        debugPrint('[ImportService] Import row ${created + 1}/${validRows.length}: '
            'Creating id=$id name="${candidate.name}" pos="${candidate.position}" '
            'class="${candidate.className}" section="${candidate.section}" '
            'roll="${candidate.rollNumber}"');

        await candidatesBox.put(id, candidate);
        debugPrint('[ImportService]   Hive put SUCCESS for id=$id');

        createdIds.add(id);
        created++;

        if (created % 10 == 0 || created == validRows.length) {
          final progress = 0.2 + (created / validRows.length) * 0.4;
          onProgress?.call(progress,
              'Imported $created / ${validRows.length} candidates...');
        }
      }

      debugPrint('[ImportService] All $created candidates saved to Hive');
      debugPrint('[ImportService] Candidate box length after: ${candidatesBox.length}');

      onProgress?.call(0.6, 'Copying photos...');
      final appDir = await getApplicationDocumentsDirectory();
      final appPhotosDir = p.join(appDir.path, 'imported_photos');
      final photosDirObj = Directory(appPhotosDir);
      if (!photosDirObj.existsSync()) {
        await photosDirObj.create(recursive: true);
        debugPrint('[ImportService] Created app photos dir: $appPhotosDir');
      }

      int photosCopied = 0;
      if (photosDir != null) {
        debugPrint('[ImportService] Photos dir exists: ${photosDir.existsSync()}');
        debugPrint('[ImportService] Photos dir contents: ${photosDir.listSync().length} files');

        for (int i = 0; i < validRows.length; i++) {
          final row = validRows[i];
          if (row.matchedPhotoFile == null) {
            debugPrint('[ImportService]   Photo $i/${validRows.length}: no photo reference for ${row.name}');
            continue;
          }

          final source = File(p.join(photosDir.path, row.matchedPhotoFile!));
          debugPrint('[ImportService]   Photo $i/${validRows.length}: source="${source.path}" '
              'exists=${source.existsSync()}');

          if (!source.existsSync()) {
            debugPrint('[ImportService]   SKIP: source photo file does not exist');
            continue;
          }

          final ext = p.extension(row.matchedPhotoFile!);
          final destName = '${_uuid.v4()}$ext';
          final dest = File(p.join(appPhotosDir, destName));
          try {
            await source.copy(dest.path);
            debugPrint('[ImportService]   Copied to: ${dest.path}');

            final candidate = candidatesBox.get(createdIds[i]);
            if (candidate != null) {
              candidate.photoPath = dest.path;
              await candidatesBox.put(createdIds[i], candidate);
              debugPrint('[ImportService]   Updated candidate photoPath: ${dest.path}');
              photosCopied++;
            } else {
              debugPrint('[ImportService]   ERROR: candidate not found in Hive for id=${createdIds[i]}');
            }
          } catch (e) {
            debugPrint('[ImportService]   ERROR copying photo: $e');
          }
        }
      } else {
        debugPrint('[ImportService] WARNING: photosDir is null, no photos to copy');
      }

      debugPrint('[ImportService] Photos copied: $photosCopied');

      onProgress?.call(0.9, 'Verifying import...');

      final finalCount = candidatesBox.values.length;
      final expected = snapshot.candidates.length + validRows.length;

      debugPrint('[ImportService] Verification: finalCount=$finalCount expected=$expected '
          'snapshot=${snapshot.candidates.length} validRows=${validRows.length}');

      if (finalCount != expected) {
        debugPrint('[ImportService] VERIFICATION FAILED. Rolling back...');
        await _rollback(snapshot);
        return ImportResult(
          success: false,
          message:
              'Import verification failed: expected $expected candidates, '
              'got $finalCount. Rolled back.',
          errors: ['Count mismatch'],
        );
      }

      onProgress?.call(1.0, 'Import complete!');

      debugPrint('[ImportService] === performImport SUCCESS ===');
      debugPrint('[ImportService] Hive count after import: ${candidatesBox.length}');
      debugPrint('[ImportService] CandidateService.getAll() count: ${CandidateService.getAll().length}');

      return ImportResult(
        success: true,
        message:
            'Successfully imported $created candidates with $photosCopied photos.',
        candidatesCreated: created,
        photosCopied: photosCopied,
      );
    } catch (e, stack) {
      debugPrint('[ImportService] Import error: $e\n$stack');
      return ImportResult(
        success: false,
        message: 'Import failed: $e',
        errors: [e.toString()],
      );
    } finally {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
          debugPrint('[ImportService] Temp dir cleaned up');
        } catch (_) {}
      }
    }
  }

  static bool _isCsvFile(File file) {
    final name = p.basename(file.path).toLowerCase();
    return name.endsWith('.csv');
  }

  static Future<ImportSnapshot> _createSnapshot() async {
    final candidates = CandidateService.getAll();
    return ImportSnapshot(
      candidates: candidates.map((c) => c.copyWith()).toList(),
    );
  }

  static Future<void> _rollback(ImportSnapshot snapshot) async {
    try {
      final box = Hive.box<CandidateModel>('candidates');
      await box.clear();
      for (final c in snapshot.candidates) {
        await box.put(c.id, c);
      }
    } catch (e) {
      debugPrint('[ImportService] Rollback failed: $e');
    }
  }
}
