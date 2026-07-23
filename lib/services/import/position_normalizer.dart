import '../../constants/positions.dart';
import 'import_models.dart';

class PositionNormalizer {
  static const _knownSubstitutions = <String, String>{
    'assembly minister': 'Assembly Captain',
    'discipline minister': 'Discipline Captain',
    'culture captain': 'Cultural Captain',
    'cultural minister': 'Cultural Captain',
    'communication minister': 'Communication Captain',
    'cleanliness minister': 'Cleanliness Captain',
    'sports vice captain': 'Sports Vice Captain',
    'headboy': 'Head Boy',
    'head girl': 'Head Girl',
    'head boy': 'Head Boy',
    'headgirl': 'Head Girl',
    'sports captain': 'Sports Captain',
    'house captain': 'House Captain',
    'school prefect': 'School Prefect',
  };

  static (String? resolved, ImportIssue? issue) normalize(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return (null, const ImportIssue(
        field: 'Position',
        message: 'Position is empty',
        severity: ImportIssueSeverity.error,
      ));
    }

    if (ElectionPositions.all.contains(trimmed)) {
      return (trimmed, null);
    }

    if (ElectionPositions.legacy.contains(trimmed)) {
      return (trimmed, const ImportIssue(
        field: 'Position',
        message: 'Legacy position. Consider updating.',
        severity: ImportIssueSeverity.warning,
      ));
    }

    final key = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (_knownSubstitutions.containsKey(key)) {
      final resolved = _knownSubstitutions[key]!;
      return (resolved, ImportIssue(
        field: 'Position',
        message: 'Normalized "$trimmed" → "$resolved"',
        severity: ImportIssueSeverity.warning,
      ));
    }

    final fuzzy = _fuzzyMatch(trimmed);
    if (fuzzy != null) {
      return (fuzzy, ImportIssue(
        field: 'Position',
        message: 'Normalized "$trimmed" → "$fuzzy"',
        severity: ImportIssueSeverity.warning,
      ));
    }

    return (null, ImportIssue(
      field: 'Position',
      message: '"$trimmed" is not valid. Options: ${ElectionPositions.all.join(", ")}',
      severity: ImportIssueSeverity.error,
    ));
  }

  static String? _fuzzyMatch(String input) {
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    String? best;
    int bestScore = 0;

    for (final valid in ElectionPositions.all) {
      final score = _score(normalized, valid.toLowerCase());
      if (score > bestScore && score >= 60) {
        bestScore = score;
        best = valid;
      }
    }
    return best;
  }

  static int _score(String a, String b) {
    if (a == b) return 100;

    final aWords = a.split(' ');
    final bWords = b.split(' ');

    int matches = 0;
    for (final w in aWords) {
      if (bWords.contains(w)) {
        matches++;
      } else {
        for (final bw in bWords) {
          if (w.length >= 3 && bw.length >= 3) {
            final dist = _levenshtein(w, bw);
            if (dist <= 2) {
              matches++;
              break;
            }
          }
        }
      }
    }

    final denom = (aWords.length + bWords.length) / 2;
    if (denom == 0) return 0;
    return (matches / denom * 100).round();
  }

  static int _levenshtein(String a, String b) {
    final m = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) m[i][0] = i;
    for (int j = 0; j <= b.length; j++) m[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        m[i][j] = [
          m[i - 1][j] + 1,
          m[i][j - 1] + 1,
          m[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return m[a.length][b.length];
  }
}
