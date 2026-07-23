import '../../models/candidate.dart';

class ImportRow {
  final int rowNumber;
  final String name;
  final String rawPosition;
  final String? resolvedPosition;
  final String rawClass;
  final String? resolvedClass;
  final String section;
  final String rollNumber;
  final String? photoRef;
  final String? matchedPhotoFile;
  final List<ImportIssue> issues;

  const ImportRow({
    required this.rowNumber,
    required this.name,
    required this.rawPosition,
    this.resolvedPosition,
    required this.rawClass,
    this.resolvedClass,
    required this.section,
    required this.rollNumber,
    this.photoRef,
    this.matchedPhotoFile,
    this.issues = const [],
  });

  bool get isValid =>
      resolvedPosition != null &&
      resolvedClass != null &&
      issues.every((i) => i.severity != ImportIssueSeverity.error);

  bool get hasWarningsOnly =>
      issues.isNotEmpty && issues.every((i) => i.severity == ImportIssueSeverity.warning);
}

class ImportIssue {
  final String field;
  final String message;
  final ImportIssueSeverity severity;

  const ImportIssue({
    required this.field,
    required this.message,
    this.severity = ImportIssueSeverity.error,
  });
}

enum ImportIssueSeverity { error, warning }

class ImportSummary {
  final int totalRows;
  final int validCount;
  final int errorCount;
  final int warningCount;
  final int photoMatchCount;
  final int photoMissingCount;
  final List<ImportRow> rows;

  int get candidateCount => rows.where((r) => r.isValid).length;

  const ImportSummary({
    required this.totalRows,
    required this.validCount,
    required this.errorCount,
    required this.warningCount,
    required this.photoMatchCount,
    required this.photoMissingCount,
    required this.rows,
  });
}

class ImportResult {
  final bool success;
  final String message;
  final int candidatesCreated;
  final int photosCopied;
  final List<String> errors;

  const ImportResult({
    required this.success,
    required this.message,
    this.candidatesCreated = 0,
    this.photosCopied = 0,
    this.errors = const [],
  });
}

class ImportSnapshot {
  final List<CandidateModel> candidates;

  const ImportSnapshot({required this.candidates});
}
