class VotingSession {
  final Map<String, String?> _selectedByPosition = {};
  final List<String> _positions;

  String? studentRollNumber;
  String? studentId;

  VotingSession(this._positions) {
    for (final pos in _positions) {
      _selectedByPosition[pos] = null;
    }
  }

  void select(String position, String candidateId) {
    _selectedByPosition[position] = candidateId;
  }

  void deselect(String position) {
    _selectedByPosition[position] = null;
  }

  String? getSelected(String position) => _selectedByPosition[position];

  bool isPositionSelected(String position) => _selectedByPosition[position] != null;

  bool isCandidateSelected(String candidateId, String position) =>
      _selectedByPosition[position] == candidateId;

  int get selectedCount =>
      _selectedByPosition.values.where((v) => v != null).length;

  int get totalPositions => _positions.length;

  Map<String, String> get allSelections => Map.fromEntries(
    _selectedByPosition.entries
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!)),
  );

  void reset() {
    for (final key in _selectedByPosition.keys) {
      _selectedByPosition[key] = null;
    }
    studentRollNumber = null;
    studentId = null;
  }
}
