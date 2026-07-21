import 'dart:io';
import 'package:archive/archive_io.dart';

class ZipService {
  static Future<void> createZip(String sourceDir, String outputPath) async {
    final encoder = ZipFileEncoder();
    encoder.create(outputPath);
    await _addDirectory(encoder, Directory(sourceDir), '');
    await encoder.close();
  }

  static Future<void> _addDirectory(
      ZipFileEncoder encoder, Directory dir, String basePath) async {
    await for (final entity in dir.list()) {
      if (entity is File) {
        if (basePath.isEmpty) {
          await encoder.addFile(entity);
        } else {
          await encoder.addFile(entity, '$basePath/${entity.uri.pathSegments.last}');
        }
      } else if (entity is Directory) {
        await _addDirectory(
            encoder, entity, entity.uri.pathSegments.last);
      }
    }
  }

  static Future<void> extractZip(String zipPath, String outputDir) async {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      if (file.isFile) {
        final outPath = '$outputDir/${file.name}';
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
  }

  static bool isValidZip(String zipPath) {
    try {
      final bytes = File(zipPath).readAsBytesSync();
      ZipDecoder().decodeBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }
}
