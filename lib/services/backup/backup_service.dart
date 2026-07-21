import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
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
    print('[BackupService] === Starting backup ===');

    onProgress?.call(0.0, 'Initializing backup...');

    final tempDir = await Directory.systemTemp.createTemp('school_election_backup_');
    print('[BackupService] Step 1: Created temp dir: ${tempDir.path}');

    final backupDir = Directory(p.join(tempDir.path, 'backup'));
    final photosDir = Directory(p.join(backupDir.path, 'photos'));

    try {
      await backupDir.create(recursive: true);
      await photosDir.create(recursive: true);
      print('[BackupService] Step 2: Created backup dirs: ${backupDir.path}');

      onProgress?.call(0.1, 'Reading candidates...');
      final candidates = CandidateService.getAll();
      print('[BackupService] Step 3: Read ${candidates.length} candidates');

      onProgress?.call(0.2, 'Backing up photos...');
      final photoFiles = await PhotoBackupService.copyPhotosToBackup(
        candidates,
        photosDir.path,
      );
      print('[BackupService] Step 4: Copied ${photoFiles.length} photos to ${photosDir.path}');

      onProgress?.call(0.4, 'Reading votes...');
      final voteBox = Hive.box('votes');
      final List<BackupVote> backupVotes = [];
      for (final key in voteBox.keys) {
        backupVotes.add(BackupVote(key: key.toString(), value: voteBox.get(key)));
      }
      print('[BackupService] Step 5: Read ${backupVotes.length} votes');

      onProgress?.call(0.5, 'Reading configuration...');
      final configBox = Hive.box('app_config');
      final backupConfig = BackupConfig(
        schoolName: configBox.get('schoolName', defaultValue: SchoolConfig.schoolName) as String,
        academicYear: configBox.get('academicYear', defaultValue: SchoolConfig.academicYear) as String,
        logoUrl: configBox.get('logoUrl') as String? ?? SchoolConfig.logoUrl,
      );
      print('[BackupService] Step 6: Read config: school=${backupConfig.schoolName}');

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
      print('[BackupService] Step 7: Written backup.json at: $backupJsonPath');

      final jsonFile = File(backupJsonPath);
      if (!jsonFile.existsSync()) {
        throw Exception('Failed to create backup.json at: $backupJsonPath');
      }
      print('[BackupService] Step 7a: backup.json verified, size=${jsonFile.lengthSync()} bytes');

      onProgress?.call(0.8, 'Creating ZIP archive...');
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(now);
      final zipFilename = 'SchoolElection_Backup_$dateStr.zip';
      final tempZipPath = p.join(tempDir.path, zipFilename);

      // List all files in backup dir before creating ZIP
      print('[BackupService] Pre-ZIP: backupDir=${backupDir.path}');
      print('[BackupService] Pre-ZIP: backup.json exists=${File(backupJsonPath).existsSync()}, '
          'size=${File(backupJsonPath).lengthSync()}');
      print('[BackupService] Pre-ZIP: photosDir exists=${Directory(photosDir.path).existsSync()}');
      print('[BackupService] Pre-ZIP: enumerating files...');
      await for (final entity in backupDir.list(recursive: true)) {
        if (entity is File) {
          print('[BackupService] Pre-ZIP: File: ${entity.path} (${entity.lengthSync()} bytes)');
        } else if (entity is Directory) {
          print('[BackupService] Pre-ZIP: Dir: ${entity.path}');
        }
      }

      // Assert state before ZIP creation
      final preJsonFile = File(backupJsonPath);
      if (!preJsonFile.existsSync()) {
        throw Exception('PRE-ZIP ASSERTION FAILED: backup.json does not exist at: $backupJsonPath');
      }
      if (preJsonFile.lengthSync() == 0) {
        throw Exception('PRE-ZIP ASSERTION FAILED: backup.json is empty (0 bytes) at: $backupJsonPath');
      }
      final prePhotosDir = Directory(photosDir.path);
      if (!prePhotosDir.existsSync()) {
        print('[BackupService] Pre-ZIP: photos dir does not exist (no photos to back up)');
      }
      print('[BackupService] Pre-ZIP: All assertions passed ✓');

      await ZipService.createZip(backupDir.path, tempZipPath);
      print('[BackupService] Step 8: ZIP created at: $tempZipPath');

      final zipFile = File(tempZipPath);
      if (!zipFile.existsSync()) {
        throw Exception('Failed to create ZIP at: $tempZipPath');
      }
      print('[BackupService] Step 8a: ZIP exists, size=${zipFile.lengthSync()} bytes');

      if (zipFile.lengthSync() == 0) {
        throw Exception('ZIP file is empty (0 bytes) at: $tempZipPath');
      }

      final zipBytes = await zipFile.readAsBytes();
      print('[BackupService] Step 8b: Read ZIP bytes: ${zipBytes.length} bytes');

      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(zipBytes);
      final archiveFiles = archive.map((f) => f.name).toList();
      print('[BackupService] Step 8c: ZIP contents: $archiveFiles');

      if (!archiveFiles.any((name) => name == 'backup.json')) {
        throw Exception('ZIP is missing backup.json. Contents: $archiveFiles');
      }
      print('[BackupService] Step 8d: Verified backup.json in ZIP ✓');

      if (!archiveFiles.any((name) => name.startsWith('photos/'))) {
        print('[BackupService] Step 8e: WARNING - No photos folder in ZIP');
      } else {
        print('[BackupService] Step 8e: photos folder present in ZIP ✓');
      }

      onProgress?.call(0.95, 'Storing backup timestamp...');
      final configBox2 = Hive.box('app_config');
      await configBox2.put('lastBackupTime', now.millisecondsSinceEpoch);
      print('[BackupService] Step 9: Backup timestamp saved');

      onProgress?.call(1.0, 'Backup created!');
      print('[BackupService] Step 10: Backup creation complete');

      return BackupResult(
        tempDirPath: tempDir.path,
        tempZipPath: tempZipPath,
        zipBytes: zipBytes,
        filename: zipFilename,
      );
    } catch (e) {
      print('[BackupService] ERROR during backup creation: $e');
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
        print('[BackupService] Cleaned up temp dir after error: ${tempDir.path}');
      }
      rethrow;
    }
  }

  static Future<String?> saveToUserLocation(Uint8List bytes, String filename) async {
    print('[BackupService] saveToUserLocation: filename=$filename, bytes.length=${bytes.length}');
    try {
      final path = await FilePickerSave.saveFile(bytes: bytes, fileName: filename);
      print('[BackupService] saveToUserLocation: returned path="$path"');
      if (path != null && path.isNotEmpty) {
        _lastBackupPath = path;
        print('[BackupService] saveToUserLocation: SUCCESS - file saved at: $path');
        return path;
      }
      print('[BackupService] saveToUserLocation: path was null or empty (user cancelled?)');
    } catch (e, stack) {
      print('[BackupService] saveToUserLocation: ERROR: $e');
      print('[BackupService] saveToUserLocation: STACK: $stack');
    }
    return null;
  }

  static Future<String> saveToAppDocuments(Uint8List bytes, String filename) async {
    print('[BackupService] saveToAppDocuments: filename=$filename, bytes.length=${bytes.length}');
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'Backups'));
    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
      print('[BackupService] Created backup dir: ${backupDir.path}');
    }
    final filePath = p.join(backupDir.path, filename);
    print('[BackupService] saveToAppDocuments: writing to: $filePath');
    await File(filePath).writeAsBytes(bytes);

    final savedFile = File(filePath);
    if (!savedFile.existsSync()) {
      throw Exception('Fallback save failed - file not found at: $filePath');
    }
    if (savedFile.lengthSync() == 0) {
      throw Exception('Fallback save failed - file is 0 bytes at: $filePath');
    }
    print('[BackupService] saveToAppDocuments: SUCCESS, size=${savedFile.lengthSync()} bytes');
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

class FilePickerSave {
  static Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    print('[FilePickerSave] saveFile: calling platform.saveFile(fileName=$fileName)');
    final result = await file_picker.FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: bytes,
    );
    print('[FilePickerSave] saveFile: result="$result"');
    return result;
  }
}
