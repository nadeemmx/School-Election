import 'package:hive_flutter/hive_flutter.dart';
import '../constants/positions.dart';
import '../models/candidate.dart';

class CandidateService {
  static const _boxName = 'candidates';

  static Future<void> initialize() async {
    await Hive.openBox<CandidateModel>(_boxName);
    await Hive.openBox('votes');
  }

  static Box<CandidateModel> get _box => Hive.box<CandidateModel>(_boxName);

  static List<CandidateModel> getAll() {
    return _box.values.toList();
  }

  static List<CandidateModel> getByPosition(String position) {
    return _box.values.where((c) => c.position == position).toList();
  }

  static List<String> get positions {
    final pos = _box.values.map((c) => c.position).toSet().toList();
    pos.sort(ElectionPositions.compare);
    return pos;
  }

  static CandidateModel? getById(String id) {
    return _box.get(id);
  }

  static Future<void> add(CandidateModel candidate) async {
    await _box.put(candidate.id, candidate);
  }

  static Future<void> update(CandidateModel candidate) async {
    await _box.put(candidate.id, candidate);
  }

  static Future<void> delete(String id) async {
    await _box.delete(id);
  }

  static Future<void> incrementVotes(String id) async {
    final candidate = _box.get(id);
    if (candidate != null) {
      candidate.votes++;
      await _box.put(id, candidate);
    }
  }

  static bool hasVotedFor(String candidateId) {
    final voteBox = Hive.box('votes');
    return voteBox.get(candidateId, defaultValue: false) as bool;
  }

  static bool hasPositionBeenVoted(String position) {
    final voteBox = Hive.box('votes');
    return voteBox.get('position_$position', defaultValue: false) as bool;
  }

  static Future<void> markVoted(String candidateId) async {
    final voteBox = Hive.box('votes');
    await voteBox.put(candidateId, true);
  }

  static Future<void> markPositionVoted(String position) async {
    final voteBox = Hive.box('votes');
    await voteBox.put('position_$position', true);
  }

  static Future<void> clearAllVotes() async {
    final voteBox = Hive.box('votes');
    await voteBox.clear();
  }

  static int get totalVotes {
    return _box.values.fold(0, (sum, c) => sum + c.votes);
  }

  static int get totalCandidates => _box.length;

  static CandidateModel? get winningCandidate {
    final all = _box.values;
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a.votes > b.votes ? a : b);
  }

  static int get maxVotes {
    final all = _box.values;
    if (all.isEmpty) return 1;
    return all.map((c) => c.votes).reduce((a, b) => a > b ? a : b);
  }

  static CandidateModel? getPositionWinner(String position) {
    final candidates = getByPosition(position);
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.votes > b.votes ? a : b);
  }
}
