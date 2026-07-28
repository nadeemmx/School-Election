import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import '../../models/candidate.dart';
import '../../services/candidate_service.dart';

class ZipExportService {
  static Uint8List createZip({
    required String schoolName,
    required String academicYear,
    required List<CandidateModel> candidates,
    required List<String> positions,
    required Map<String, CandidateModel> winners,
    required Uint8List excelBytes,
    required Uint8List pdfBytes,
  }) {
    final archive = Archive();
    final dateFormat = DateFormat('MMMM dd, yyyy');

    archive.addFile(ArchiveFile('Election_Results.xlsx', excelBytes.length, excelBytes));
    archive.addFile(ArchiveFile('Election_Report.pdf', pdfBytes.length, pdfBytes));

    final jsonStr = const JsonEncoder.withIndent('  ').convert(_buildResultsJson(
      schoolName: schoolName,
      academicYear: academicYear,
      candidates: candidates,
      positions: positions,
      winners: winners,
      dateFormat: dateFormat,
    ));
    final jsonBytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile('results.json', jsonBytes.length, jsonBytes));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? []);
  }

  static Map<String, dynamic> _buildResultsJson({
    required String schoolName,
    required String academicYear,
    required List<CandidateModel> candidates,
    required List<String> positions,
    required Map<String, CandidateModel> winners,
    required DateFormat dateFormat,
  }) {
    final totalVotes = candidates.fold(0, (sum, c) => sum + c.votes);
    final sorted = List<CandidateModel>.from(candidates);
    sorted.sort((a, b) {
      final pos = CandidateService.positions;
      final aIdx = pos.indexOf(a.position);
      final bIdx = pos.indexOf(b.position);
      if (aIdx != bIdx) return aIdx.compareTo(bIdx);
      return b.votes.compareTo(a.votes);
    });

    return {
      'schoolName': schoolName,
      'academicYear': academicYear,
      'generatedDate': dateFormat.format(DateTime.now()),
      'summary': {
        'totalCandidates': candidates.length,
        'totalVotes': totalVotes,
        'totalPositions': positions.length,
      },
      'winners': winners.map((position, candidate) => MapEntry(position, {
        'name': candidate.name,
        'rollNumber': candidate.rollNumber,
        'class': candidate.className,
        'section': candidate.section,
        'votes': candidate.votes,
      })),
      'candidates': sorted.map((c) => {
        'name': c.name,
        'rollNumber': c.rollNumber,
        'class': c.className,
        'section': c.section,
        'position': c.position,
        'votes': c.votes,
        'isWinner': winners.values.any((w) => w.id == c.id),
      }).toList(),
    };
  }
}