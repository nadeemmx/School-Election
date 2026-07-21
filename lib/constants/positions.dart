class ElectionPositions {
  ElectionPositions._();

  static const List<String> all = [
    'Head Boy',
    'Head Girl',
    'Sports Captain',
    'Cultural Captain',
    'Discipline Captain',
    'House Captain',
    'Cleanliness Captain',
    'Communication Captain',
    'Assembly Captain',
    'Sports Vice Captain',
    'School Prefect',
  ];

  /// Legacy position names that may exist in older databases
  /// but are no longer part of the active position list.
  static const List<String> legacy = [
    'Vice Captain',
  ];

  static bool isLegacy(String position) => legacy.contains(position);

  static bool isValid(String position) =>
      all.contains(position) || legacy.contains(position);

  static int compare(String a, String b) {
    final aIdx = all.indexOf(a);
    final bIdx = all.indexOf(b);
    if (aIdx == -1 && bIdx == -1) return a.compareTo(b);
    if (aIdx == -1) return 1;
    if (bIdx == -1) return -1;
    return aIdx.compareTo(bIdx);
  }

  static List<String> sorted(List<String> positions) {
    final list = List<String>.from(positions);
    list.sort(compare);
    return list;
  }
}
