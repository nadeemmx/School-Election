import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import '../../utils/constants.dart';
import 'import_models.dart';
import 'position_normalizer.dart';

class CsvParser {
  static const _headerAliases = <String, String>{
    'roll no': 'rollNumber',
    'rollno': 'rollNumber',
    'roll_number': 'rollNumber',
    'roll': 'rollNumber',
    'student name': 'name',
    'name': 'name',
    'student_name': 'name',
    'class': 'className',
    'classname': 'className',
    'class_name': 'className',
    'grade': 'className',
    'section': 'section',
    'sec': 'section',
    'position': 'position',
    'post': 'position',
    'photo': 'photoFile',
    'photo_file': 'photoFile',
    'photofile': 'photoFile',
    'picture': 'photoFile',
    'image': 'photoFile',
  };

  static const _validSections = ['A', 'B', 'C'];

  static ImportSummary? parse(File csvFile, Directory photosDir) {
    final content = csvFile.readAsStringSync();
    final rows = const CsvToListConverter(eol: '\n').convert(content);

    if (rows.isEmpty) {
      return null;
    }

    final headerRow = rows[0];
    final colMap = _mapColumns(headerRow);

    final needed = ['name', 'position', 'className', 'section'];
    final missing = needed.where((f) => colMap[f] == null).toList();
    if (missing.isNotEmpty) {
      return null;
    }

    final dataRows = rows.skip(1).toList();
    final parsedRows = <ImportRow>[];
    int errorCount = 0;
    int warningCount = 0;
    int photoMatchCount = 0;
    int photoMissingCount = 0;

    final photoFiles = <String>[];
    if (photosDir.existsSync()) {
      photoFiles.addAll(photosDir.listSync().whereType<File>().map((f) => p.basename(f.path)));
    }

    debugPrint('[CsvParser] Detected headers:');
    for (final entry in colMap.entries) {
      debugPrint('[CsvParser]   ${entry.key} → column ${entry.value}');
    }

    debugPrint('[CsvParser] Photo files found in photos/: ${photoFiles.length}');
    for (final pf in photoFiles) {
      debugPrint('[CsvParser]   photo: $pf');
    }

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final rowNum = i + 2;
      final issues = <ImportIssue>[];

      final name = _safeString(row, colMap['name']!);
      final rawPosition = _safeString(row, colMap['position']!);
      final rawClass = _safeString(row, colMap['className']!);
      final section = _safeString(row, colMap['section']!);
      final rollNumber = _safeString(row, colMap['rollNumber']);
      final photoRef = colMap['photoFile'] != null ? _safeString(row, colMap['photoFile']!) : null;

      if (name.isEmpty) {
        issues.add(const ImportIssue(field: 'Name', message: 'Name is empty'));
      }

      final (resolvedPosition, posIssue) = PositionNormalizer.normalize(rawPosition);
      if (posIssue != null) {
        issues.add(posIssue);
        if (posIssue.severity == ImportIssueSeverity.error) errorCount++;
        else warningCount++;
      }

      final (resolvedClass, classIssue) = _normalizeClass(rawClass);
      if (classIssue != null) {
        issues.add(classIssue);
        if (classIssue.severity == ImportIssueSeverity.error) errorCount++;
        else warningCount++;
      }

      if (section.isEmpty) {
        issues.add(const ImportIssue(field: 'Section', message: 'Section is empty'));
      } else if (!_validSections.contains(section.toUpperCase())) {
        issues.add(ImportIssue(
          field: 'Section',
          message: '"$section" is not valid. Valid: A, B, C',
          severity: ImportIssueSeverity.error,
        ));
      }

      if (rollNumber.isEmpty) {
        issues.add(const ImportIssue(field: 'Roll No', message: 'Roll number is empty'));
      }

      String? matchedPhoto;
      if (photoRef != null && photoRef.isNotEmpty) {
        matchedPhoto = _findPhoto(photoRef, photoFiles);
        if (matchedPhoto != null) {
          photoMatchCount++;
        } else {
          photoMissingCount++;
          warningCount++;
          issues.add(ImportIssue(
            field: 'Photo',
            message: 'Photo "$photoRef" not found in photos/ folder',
            severity: ImportIssueSeverity.warning,
          ));
        }
      }

      final rowErrors = issues.where((i) => i.severity == ImportIssueSeverity.error).length;
      errorCount += rowErrors;

      for (final issue in issues) {
        debugPrint('[CsvParser] Row $rowNum: [${issue.severity == ImportIssueSeverity.error ? "ERROR" : "WARN"}] '
            '${issue.field}: ${issue.message}');
      }
      debugPrint('[CsvParser] Row $rowNum: name="$name" pos="$rawPosition"→"$resolvedPosition" '
          'class="$rawClass"→"$resolvedClass" section="$section" roll="$rollNumber" '
          'photoRef="$photoRef" matchedPhoto="$matchedPhoto" '
          'result=${issues.where((i) => i.severity == ImportIssueSeverity.error).isEmpty ? "VALID" : "INVALID"}');

      parsedRows.add(ImportRow(
        rowNumber: rowNum,
        name: name,
        rawPosition: rawPosition,
        resolvedPosition: resolvedPosition,
        rawClass: rawClass,
        resolvedClass: resolvedClass,
        section: section.isEmpty ? '' : section.toUpperCase(),
        rollNumber: rollNumber,
        photoRef: photoRef,
        matchedPhotoFile: matchedPhoto,
        issues: issues,
      ));
    }

    final validCount = parsedRows.where((r) => r.isValid).length;

    return ImportSummary(
      totalRows: parsedRows.length,
      validCount: validCount,
      errorCount: errorCount,
      warningCount: warningCount,
      photoMatchCount: photoMatchCount,
      photoMissingCount: photoMissingCount,
      rows: parsedRows,
    );
  }

  static Map<String, int> _mapColumns(List<dynamic> headerRow) {
    final map = <String, int>{};
    for (int i = 0; i < headerRow.length; i++) {
      final raw = headerRow[i].toString().trim().toLowerCase();
      if (_headerAliases.containsKey(raw)) {
        map[_headerAliases[raw]!] = i;
      }
    }
    return map;
  }

  static String _safeString(List<dynamic> row, int? idx) {
    if (idx == null || idx >= row.length) return '';
    final val = row[idx];
    if (val == null) return '';
    return val.toString().trim();
  }

  static (String? resolved, ImportIssue? issue) _normalizeClass(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return (null, const ImportIssue(
        field: 'Class',
        message: 'Class is empty',
        severity: ImportIssueSeverity.error,
      ));
    }

    final prefixed = trimmed.startsWith('Class ') ? trimmed : 'Class $trimmed';

    if (AppConstants.classes.contains(prefixed)) {
      return (prefixed, trimmed != prefixed ? ImportIssue(
        field: 'Class',
        message: 'Normalized "$trimmed" → "$prefixed"',
        severity: ImportIssueSeverity.warning,
      ) : null);
    }

    return (null, ImportIssue(
      field: 'Class',
      message: '"$trimmed" is not a valid class. Valid: ${AppConstants.classes.join(", ")}',
      severity: ImportIssueSeverity.error,
    ));
  }

  static String? _findPhoto(String ref, List<String> photoFiles) {
    if (photoFiles.contains(ref)) return ref;

    final withoutExt = (String f) {
      final dot = f.lastIndexOf('.');
      return dot > 0 ? f.substring(0, dot) : f;
    };

    final refLower = ref.toLowerCase();

    for (final f in photoFiles) {
      if (f.toLowerCase() == refLower) return f;
      if (withoutExt(f).toLowerCase() == refLower) return f;
    }

    for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']) {
      final withExt = '$ref.$ext';
      if (photoFiles.contains(withExt)) return withExt;
      final lower = '$refLower.$ext';
      for (final f in photoFiles) {
        if (f.toLowerCase() == lower) return f;
      }
    }

    return null;
  }
}
