import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../config/school_config.dart';
import '../../models/candidate.dart';
import '../../services/candidate_service.dart';
import 'excel_export_service.dart';
import 'pdf_export_service.dart';
import 'zip_export_service.dart';

enum ExportFormat { excel, pdf, zip }

class ExportResult {
  final String path;
  final String filename;

  const ExportResult({required this.path, required this.filename});
}

class ExportService {
  static Future<Map<ExportFormat, Uint8List>> generateAll({
    void Function(double progress, String message)? onProgress,
  }) async {
    onProgress?.call(0.0, 'Reading election data...');

    final candidates = CandidateService.getAll();
    final positions = CandidateService.positions;

    final winners = <String, CandidateModel>{};
    for (final position in positions) {
      final posCandidates = CandidateService.getByPosition(position);
      if (posCandidates.isEmpty) continue;
      final winner = posCandidates.reduce((a, b) => a.votes > b.votes ? a : b);
      if (winner.votes > 0) {
        winners[position] = winner;
      }
    }

    final configBox = Hive.box('app_config');
    final schoolName = configBox.get('schoolName', defaultValue: SchoolConfig.schoolName) as String;
    final academicYear = configBox.get('academicYear', defaultValue: SchoolConfig.academicYear) as String;
    final logoUrl = configBox.get('logoUrl') as String? ?? SchoolConfig.logoUrl;

    onProgress?.call(0.2, 'Generating Excel workbook...');
    final excelBytes = ExcelExportService.generate(
      schoolName: schoolName,
      academicYear: academicYear,
      candidates: candidates,
      positions: positions,
      winners: winners,
    );

    onProgress?.call(0.5, 'Generating PDF report...');
    final pdfBytes = await PdfExportService.generate(
      schoolName: schoolName,
      academicYear: academicYear,
      logoPath: logoUrl,
      candidates: candidates,
      positions: positions,
      winners: winners,
    );

    onProgress?.call(0.8, 'Creating ZIP archive...');
    final zipBytes = ZipExportService.createZip(
      schoolName: schoolName,
      academicYear: academicYear,
      candidates: candidates,
      positions: positions,
      winners: winners,
      excelBytes: excelBytes,
      pdfBytes: pdfBytes,
    );

    onProgress?.call(1.0, 'Export complete!');
    return {
      ExportFormat.excel: excelBytes,
      ExportFormat.pdf: pdfBytes,
      ExportFormat.zip: zipBytes,
    };
  }

  static Future<ExportResult?> saveToUserLocation({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final tempDir = Directory.systemTemp;
        final tempPath = p.join(tempDir.path, filename);
        await File(tempPath).writeAsBytes(bytes);

        final tempFile = File(tempPath);
        if (!tempFile.existsSync()) {
          throw Exception('Failed to write temp file to: $tempPath');
        }

        final result = await file_picker.FilePicker.platform.saveFile(
          fileName: filename,
        );

        if (result != null && result.isNotEmpty) {
          await tempFile.copy(result);
          final savedFile = File(result);
          if (!savedFile.existsSync()) {
            throw Exception('File was not saved at: $result');
          }
          return ExportResult(path: result, filename: filename);
        }
        return null;
      } else {
        final result = await file_picker.FilePicker.platform.saveFile(
          fileName: filename,
          bytes: bytes,
        );
        if (result != null && result.isNotEmpty) {
          return ExportResult(path: result, filename: filename);
        }
        return null;
      }
    } catch (e) {
      print('[ExportService] saveToUserLocation error: $e');
      return null;
    }
  }

  static Future<String> saveToAppDocuments(Uint8List bytes, String filename) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(documentsDir.path, 'Exports'));
    if (!exportDir.existsSync()) {
      await exportDir.create(recursive: true);
    }
    final filePath = p.join(exportDir.path, filename);
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  static String formatFilename(ExportFormat format) {
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    switch (format) {
      case ExportFormat.excel:
        return 'Election_Results_$dateStr.xlsx';
      case ExportFormat.pdf:
        return 'Election_Report_$dateStr.pdf';
      case ExportFormat.zip:
        return 'Election_Results_$dateStr.zip';
    }
  }
}