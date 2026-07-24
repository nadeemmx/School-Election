import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../config/school_config.dart';
import '../../services/candidate_service.dart';
import 'backup_models.dart';
import 'photo_backup_service.dart';
import 'zip_service.dart';

class BackupResult {
  final String tempDirPath;
  final String tempZipPath;
  final Uint8List zipBytes;
  final String filename;

  const BackupResult({
    required this.tempDirPath,
    required this.tempZipPath,
    required this.zipBytes,
    required this.filename,
  });

  Future<void> cleanupTempDir() async {
    final dir = Directory(tempDirPath);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
      print('[BackupService] Cleaned up temp dir: $tempDirPath');
    }
  }
}

class BackupService {
  static String? _lastBackupPath;

  static String? get lastBackupPath => _lastBackupPath;

  static Future<BackupResult> performBackup({
    void Function(double progress, String message)? onProgress,
  }) async {
    print('[BackupService] =============== BACKUP STARTED ===============');
    print('[BackupService] Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    print('[BackupService] Temp dir: ${Directory.systemTemp.path}');

    onProgress?.call(0.0, 'Initializing backup...');

    final tempDir = await Directory.systemTemp.createTemp('school_election_backup_');
    print('[BackupService] Created temp dir: ${tempDir.path}');

    final backupDir = Directory(p.join(tempDir.path, 'backup'));
    final photosDir = Directory(p.join(backupDir.path, 'photos'));

    try {
      await backupDir.create(recursive: true);
      await photosDir.create(recursive: true);
      print('[BackupService] Backup dir: ${backupDir.path}');
      print('[BackupService] Photos dir: ${photosDir.path}');

      onProgress?.call(0.1, 'Reading candidates...');
      final candidates = CandidateService.getAll();
      print('[BackupService] Candidates read: ${candidates.length}');

      onProgress?.call(0.2, 'Backing up photos...');
      final photoFiles = await PhotoBackupService.copyPhotosToBackup(
        candidates,
        photosDir.path,
      );
      print('[BackupService] Photos backed up: ${photoFiles.length}');

      onProgress?.call(0.4, 'Reading votes...');
      final voteBox = Hive.box('votes');
      final List<BackupVote> backupVotes = [];
      for (final key in voteBox.keys) {
        backupVotes.add(BackupVote(key: key.toString(), value: voteBox.get(key)));
      }
      print('[BackupService] Votes read: ${backupVotes.length}');

      onProgress?.call(0.5, 'Reading configuration...');
      final configBox = Hive.box('app_config');
      final backupConfig = BackupConfig(
        schoolName: configBox.get('schoolName', defaultValue: SchoolConfig.schoolName) as String,
        academicYear: configBox.get('academicYear', defaultValue: SchoolConfig.academicYear) as String,
        logoUrl: configBox.get('logoUrl') as String? ?? SchoolConfig.logoUrl,
      );
      print('[BackupService] Config read: school=${backupConfig.schoolName}');

      onProgress?.call(0.6, 'Creating backup manifest...');
      final now = DateTime.now();
      final backupData = BackupData(
        version: 1,
        createdAt: now.toIso8601String(),
        candidates: candidates.map((c) => BackupCandidate(
          id: c.id,
          name: c.name,
          position: c.position,
          className: c.className,
          section: c.section,
          rollNumber: c.rollNumber,
          photoFile: photoFiles[c.id],
          votes: c.votes,
          createdAt: c.createdAt.toIso8601String(),
        )).toList(),
        votes: backupVotes,
        appConfig: backupConfig,
      );

      onProgress?.call(0.7, 'Writing backup.json...');
      final backupJsonPath = p.join(backupDir.path, 'backup.json');
      final jsonEncoder = const JsonEncoder.withIndent('  ');
      await File(backupJsonPath).writeAsString(jsonEncoder.convert(backupData.toJson()));
      print('[BackupService] backup.json written: $backupJsonPath');

      final jsonFile = File(backupJsonPath);
      if (!jsonFile.existsSync()) {
        throw Exception('Failed to create backup.json at: $backupJsonPath');
      }
      print('[BackupService] backup.json size: ${jsonFile.lengthSync()} bytes');

      onProgress?.call(0.8, 'Creating ZIP archive...');
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(now);
      final zipFilename = 'SchoolElection_Backup_$dateStr.zip';
      final tempZipPath = p.join(tempDir.path, zipFilename);
      print('[BackupService] ZIP output path: $tempZipPath');

      print('[BackupService] Zipping directory: ${backupDir.path}');
      print('[BackupService] Contents to zip:');
      await for (final entity in backupDir.list(recursive: true)) {
        if (entity is File) {
          print('[BackupService]   File: ${p.relative(entity.path, from: backupDir.path)} (${entity.lengthSync()} bytes)');
        } else if (entity is Directory) {
          print('[BackupService]   Dir: ${p.relative(entity.path, from: backupDir.path)}/');
        }
      }

      await ZipService.createZip(backupDir.path, tempZipPath);
      print('[BackupService] ZIP created at: $tempZipPath');

      final zipFile = File(tempZipPath);
      if (!zipFile.existsSync()) {
        throw Exception('Failed to create ZIP at: $tempZipPath');
      }
      print('[BackupService] ZIP exists: true');
      print('[BackupService] ZIP size: ${zipFile.lengthSync()} bytes');

      if (zipFile.lengthSync() == 0) {
        throw Exception('ZIP file is empty (0 bytes) at: $tempZipPath');
      }

      final zipBytes = await zipFile.readAsBytes();
      print('[BackupService] ZIP bytes read: ${zipBytes.length}');

      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(zipBytes);
      final archiveFiles = archive.map((f) => f.name).toList();
      print('[BackupService] ZIP archive contents: $archiveFiles');

      if (!archiveFiles.any((name) => name == 'backup.json')) {
        throw Exception('ZIP is missing backup.json. Contents: $archiveFiles');
      }
      print('[BackupService] ZIP validation: backup.json present ✓');

      if (archiveFiles.any((name) => name.startsWith('photos/'))) {
        print('[BackupService] ZIP validation: photos/ present ✓');
      } else {
        print('[BackupService] ZIP validation: photos/ absent (no photos to back up)');
      }

      onProgress?.call(0.95, 'Storing backup timestamp...');
      final configBox2 = Hive.box('app_config');
      await configBox2.put('lastBackupTime', now.millisecondsSinceEpoch);
      print('[BackupService] Backup timestamp saved');

      onProgress?.call(1.0, 'Backup created!');
      print('[BackupService] =============== BACKUP GENERATED ===============');

      return BackupResult(
        tempDirPath: tempDir.path,
        tempZipPath: tempZipPath,
        zipBytes: zipBytes,
        filename: zipFilename,
      );
    } catch (e, stack) {
      print('[BackupService] ERROR during backup creation: $e');
      print('[BackupService] STACK: $stack');
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
        print('[BackupService] Cleaned up temp dir after error: ${tempDir.path}');
      }
      rethrow;
    }
  }

  static Future<String?> saveToUserLocation(Uint8List bytes, String filename) async {
    print('[BackupService] =============== SAVE TO USER LOCATION ===============');
    print('[BackupService] filename: $filename');
    print('[BackupService] bytes.length: ${bytes.length}');
    print('[BackupService] Platform: ${Platform.operatingSystem}');

    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        print('[BackupService] Using DESKTOP save strategy');

        final tempDir = Directory.systemTemp;
        print('[BackupService] System temp dir: ${tempDir.path}');

        final tempZipPath = p.join(tempDir.path, filename);
        print('[BackupService] Writing temp ZIP to: $tempZipPath');

        await File(tempZipPath).writeAsBytes(bytes);
        final tempFile = File(tempZipPath);
        print('[BackupService] Temp file exists: ${tempFile.existsSync()}');
        print('[BackupService] Temp file size: ${tempFile.lengthSync()} bytes');

        if (!tempFile.existsSync()) {
          throw Exception('Failed to write temp ZIP to: $tempZipPath');
        }

        print('[BackupService] Opening save dialog (without bytes - desktop mode)...');
        final result = await file_picker.FilePicker.platform.saveFile(
          fileName: filename,
        );
        print('[BackupService] Save dialog result: "$result"');

        if (result != null && result.isNotEmpty) {
          print('[BackupService] Copying temp ZIP to: $result');
          await tempFile.copy(result);

          final savedFile = File(result);
          print('[BackupService] Saved file exists: ${savedFile.existsSync()}');
          print('[BackupService] Saved file size: ${savedFile.lengthSync()} bytes');

          if (savedFile.existsSync() && savedFile.lengthSync() > 0) {
            _lastBackupPath = result;
            print('[BackupService] DESKTOP SAVE SUCCESS: $result');
            print('[BackupService] ===============================================');
            return result;
          } else {
            print('[BackupService] DESKTOP SAVE FAILED: file does not exist or is empty at: $result');
          }
        } else {
          print('[BackupService] User cancelled save dialog');
        }
        print('[BackupService] ===============================================');
        return null;
      } else {
        print('[BackupService] Using MOBILE save strategy (bytes via file_picker)');
        final result = await file_picker.FilePicker.platform.saveFile(
          fileName: filename,
          bytes: bytes,
        );
        print('[BackupService] saveToUserLocation: returned path="$result"');
        if (result != null && result.isNotEmpty) {
          _lastBackupPath = result;
          print('[BackupService] MOBILE SAVE SUCCESS: $result');
          print('[BackupService] ===============================================');
          return result;
        }
        print('[BackupService] saveToUserLocation: path was null or empty (user cancelled?)');
        print('[BackupService] ===============================================');
        return null;
      }
    } catch (e, stack) {
      print('[BackupService] saveToUserLocation: ERROR: $e');
      print('[BackupService] saveToUserLocation: STACK: $stack');
      print('[BackupService] ===============================================');
    }
    return null;
  }

  static Future<String> saveToAppDocuments(Uint8List bytes, String filename) async {
    print('[BackupService] =============== SAVE TO APP DOCUMENTS ===============');
    print('[BackupService] filename: $filename');
    print('[BackupService] bytes.length: ${bytes.length}');

    final documentsDir = await getApplicationDocumentsDirectory();
    print('[BackupService] Documents dir: ${documentsDir.path}');

    final backupDir = Directory(p.join(documentsDir.path, 'Backups'));
    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
      print('[BackupService] Created Backups dir: ${backupDir.path}');
    }
    print('[BackupService] Backup dir: ${backupDir.path}');

    final filePath = p.join(backupDir.path, filename);
    print('[BackupService] Writing to: $filePath');

    await File(filePath).writeAsBytes(bytes);

    final savedFile = File(filePath);
    print('[BackupService] File exists: ${savedFile.existsSync()}');
    print('[BackupService] File size: ${savedFile.lengthSync()} bytes');

    if (!savedFile.existsSync()) {
      throw Exception('App documents save failed - file not found at: $filePath');
    }
    if (savedFile.lengthSync() == 0) {
      throw Exception('App documents save failed - file is 0 bytes at: $filePath');
    }

    print('[BackupService] APP DOCUMENTS SAVE SUCCESS: $filePath');
    print('[BackupService] ===============================================');
    _lastBackupPath = filePath;
    return filePath;
  }

  static String? getLastBackupTime() {
    try {
      final configBox = Hive.box('app_config');
      final timestamp = configBox.get('lastBackupTime');
      if (timestamp == null) return null;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      return DateFormat('MMM dd, yyyy - HH:mm').format(date);
    } catch (_) {
      return null;
    }
  }
}
