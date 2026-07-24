import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ZipService {
  static Future<void> createZip(String sourceDir, String outputPath) async {
    final archive = Archive();
    await _addDirectoryToArchive(archive, Directory(sourceDir), '');
    final encoded = ZipEncoder().encode(archive)!;
    await File(outputPath).writeAsBytes(encoded);
  }

  static Future<void> _addDirectoryToArchive(
      Archive archive, Directory dir, String basePath) async {
    await for (final entity in dir.list()) {
      if (entity is File) {
        final data = await entity.readAsBytes();
        final name = basePath.isEmpty
            ? p.basename(entity.path)
            : '$basePath/${p.basename(entity.path)}';
        archive.addFile(ArchiveFile(name, data.length, data));
      } else if (entity is Directory) {
        final dirName = p.basename(entity.path);
        final newBase = basePath.isEmpty ? dirName : '$basePath/$dirName';
        await _addDirectoryToArchive(archive, entity, newBase);
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

  static void extractZipSync(String zipPath, String outputDir) {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      if (file.isFile) {
        final outPath = '$outputDir/${file.name}';
        final outFile = File(outPath);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
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
