import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../../models/candidate.dart';
import '../../services/candidate_service.dart';

class ExcelExportService {
  static Uint8List generate({
    required String schoolName,
    required String academicYear,
    required List<CandidateModel> candidates,
    required List<String> positions,
    required Map<String, CandidateModel> winners,
  }) {
    final excel = Excel.createExcel();
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final generatedDate = dateFormat.format(DateTime.now());

    _buildSummarySheet(excel, schoolName, academicYear, candidates, positions, generatedDate);
    _buildWinnersSheet(excel, winners);
    _buildCandidatesSheet(excel, candidates, winners);

    final saved = excel.save();
    return Uint8List.fromList(saved ?? []);
  }

  static void _buildSummarySheet(
    Excel excel,
    String schoolName,
    String academicYear,
    List<CandidateModel> candidates,
    List<String> positions,
    String generatedDate,
  ) {
    final sheet = excel['Election Summary'];
    sheet.setColumnWidth(0, 28);
    sheet.setColumnWidth(1, 50);

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontFamily: 'Calibri',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final labelStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: 'Calibri',
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final valueStyle = CellStyle(
      fontSize: 11,
      fontFamily: 'Calibri',
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('B1'));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('Election Summary');
    titleCell.cellStyle = headerStyle;

    final labels = [
      'School Name',
      'Academic Year',
      'Election Date',
      'Total Candidates',
      'Total Votes',
      'Total Positions',
      'Generated Date',
    ];

    final values = [
      schoolName,
      academicYear,
      generatedDate,
      candidates.length.toString(),
      candidates.fold(0, (sum, c) => sum + c.votes).toString(),
      positions.length.toString(),
      generatedDate,
    ];

    for (int i = 0; i < labels.length; i++) {
      final row = i + 2;
      final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      labelCell.value = TextCellValue(labels[i]);
      labelCell.cellStyle = labelStyle;

      final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      valueCell.value = TextCellValue(values[i]);
      valueCell.cellStyle = valueStyle;
    }
  }

  static void _buildWinnersSheet(
    Excel excel,
    Map<String, CandidateModel> winners,
  ) {
    final sheet = excel['Winners'];
    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 28);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 12);

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: 'Calibri',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromInt(0xFF3B82F6),
    );

    final cellStyle = CellStyle(
      fontSize: 11,
      fontFamily: 'Calibri',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = ['Position', 'Winner Name', 'Class', 'Section', 'House', 'Votes'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    int row = 1;
    for (final entry in winners.entries) {
      final c = entry.value;
      final cells = [
        entry.key,
        c.name,
        c.className,
        c.section,
        '',
        c.votes.toString(),
      ];
      for (int i = 0; i < cells.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        cell.value = TextCellValue(cells[i]);
        cell.cellStyle = cellStyle;
      }
      row++;
    }
  }

  static void _buildCandidatesSheet(
    Excel excel,
    List<CandidateModel> candidates,
    Map<String, CandidateModel> winners,
  ) {
    final sheet = excel['All Candidates'];
    sheet.setColumnWidth(0, 28);
    sheet.setColumnWidth(1, 16);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 12);
    sheet.setColumnWidth(7, 12);

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: 'Calibri',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromInt(0xFF3B82F6),
    );

    final cellStyle = CellStyle(
      fontSize: 11,
      fontFamily: 'Calibri',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final winnerCellStyle = CellStyle(
      fontSize: 11,
      fontFamily: 'Calibri',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: ExcelColor.fromInt(0xFF22C55E),
      bold: true,
    );

    final headers = ['Candidate Name', 'Roll Number', 'Class', 'Section', 'House', 'Position', 'Votes', 'Winner'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    final sorted = List<CandidateModel>.from(candidates);
    sorted.sort((a, b) {
      final positions = CandidateService.positions;
      final aIdx = positions.indexOf(a.position);
      final bIdx = positions.indexOf(b.position);
      if (aIdx != bIdx) return aIdx.compareTo(bIdx);
      return b.votes.compareTo(a.votes);
    });

    for (int row = 0; row < sorted.length; row++) {
      final c = sorted[row];
      final isWinner = winners.values.contains(c);
      final cells = [
        c.name,
        c.rollNumber,
        c.className,
        c.section,
        '',
        c.position,
        c.votes.toString(),
        isWinner ? 'Yes' : 'No',
      ];
      for (int i = 0; i < cells.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row + 1));
        cell.value = TextCellValue(cells[i]);
        cell.cellStyle = (i == 7 && isWinner) ? winnerCellStyle : cellStyle;
      }
    }
  }
}