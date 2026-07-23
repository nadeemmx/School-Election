import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/gradient_button.dart';
import '../components/glass_card.dart';
import '../services/import/import_models.dart';
import '../services/import/import_service.dart';
import '../theme/app_theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isImporting = false;
  bool _isParsing = false;
  double _progress = 0.0;
  String _progressMessage = '';
  String? _zipPath;
  ImportSummary? _summary;

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Select candidate import ZIP file',
    );

    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null || !File(path).existsSync()) return;

    setState(() {
      _isParsing = true;
      _progressMessage = 'Parsing ZIP file...';
      _zipPath = path;
      _summary = null;
    });

    try {
      final summary = await Future(() => ImportService.parseZip(path));

      if (!mounted) return;

      if (summary == null) {
        _showError(
          'Could not parse the ZIP file. '
          'Make sure it contains a candidates.csv file.',
        );
        setState(() {
          _isParsing = false;
          _zipPath = null;
        });
        return;
      }

      setState(() {
        _isParsing = false;
        _summary = summary;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to parse ZIP: $e');
      setState(() {
        _isParsing = false;
        _zipPath = null;
      });
    }
  }

  Future<void> _confirmImport() async {
    if (_zipPath == null || _summary == null) return;

    final validCount = _summary!.rows.where((r) => r.isValid).length;
    if (validCount == 0) {
      _showError('No valid rows to import. Fix the errors and try again.');
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Candidates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to import $validCount candidates.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              'This will ADD to existing candidates (not replace).',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 8),
            Text(
              'A safety snapshot will be created for rollback.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GradientButton(
            label: 'Import',
            onPressed: () => Navigator.pop(ctx, true),
            expanded: false,
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    setState(() {
      _isImporting = true;
      _progress = 0.0;
      _progressMessage = 'Starting import...';
    });

    try {
      final result = await ImportService.performImport(
        _zipPath!,
        _summary!,
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _progressMessage = message;
            });
          }
        },
      );

      if (!mounted) return;

      if (result.success) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.secondaryGreen, size: 28),
                SizedBox(width: 10),
                Text('Import Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statRow('Candidates created', result.candidatesCreated),
                _statRow('Photos copied', result.photosCopied),
                const SizedBox(height: 10),
                Text(
                  result.message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.secondaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              GradientButton(
                label: 'Done',
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                expanded: false,
              ),
            ],
          ),
        );
      } else {
        _showError(result.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Import failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Widget _statRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.secondaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$label: $count',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorRed, size: 28),
            SizedBox(width: 10),
            Text('Error'),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
        ),
        actions: [
          GradientButton(
            label: 'OK',
            gradient: [AppTheme.errorRed, AppTheme.errorRed],
            onPressed: () => Navigator.pop(ctx),
            expanded: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Candidates')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (_isImporting || _isParsing) ...[
            _buildProgressSection(),
            const SizedBox(height: 24),
          ],
          _buildFilePickerSection(),
          if (_summary != null && !_isImporting && !_isParsing) ...[
            const SizedBox(height: 24),
            _buildSummarySection(),
            const SizedBox(height: 20),
            _buildPreviewTable(),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _progressMessage,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _isParsing ? null : _progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.9),
              ),
              minHeight: 6,
            ),
          ),
          if (!_isParsing) ...[
            const SizedBox(height: 6),
            Text(
              '${(_progress * 100).toInt()}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilePickerSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: AppTheme.secondaryPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Candidate Import',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _zipPath != null
                          ? _zipPath!.split('/').last
                          : 'Select a ZIP file to import',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_zipPath == null)
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'Select ZIP File',
                icon: Icons.folder_open_rounded,
                onPressed: _pickAndParse,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final summary = _summary!;
    final validRows = summary.rows.where((r) => r.isValid).toList();
    final skipCount = summary.totalRows - validRows.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            if (summary.errorCount > 0)
              AppTheme.warningOrange.withValues(alpha: 0.15)
            else
              AppTheme.secondaryGreen.withValues(alpha: 0.1),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: summary.errorCount > 0
              ? AppTheme.warningOrange.withValues(alpha: 0.3)
              : AppTheme.secondaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: summary.errorCount > 0
                      ? AppTheme.warningOrange.withValues(alpha: 0.15)
                      : AppTheme.secondaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  summary.errorCount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: summary.errorCount > 0
                      ? AppTheme.warningOrange
                      : AppTheme.secondaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${summary.totalRows} candidates',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${validRows.length} valid · ${skipCount} skipped · '
                      '${summary.photoMatchCount} photos matched',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryChip(
                '${summary.photoMatchCount}',
                'Photos',
                AppTheme.secondaryGreen,
              ),
              const SizedBox(width: 8),
              _summaryChip(
                '${summary.warningCount}',
                'Warnings',
                AppTheme.warningOrange,
              ),
              const SizedBox(width: 8),
              _summaryChip(
                '${summary.errorCount}',
                'Errors',
                AppTheme.errorRed,
              ),
            ],
          ),
          if (validRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: validRows.length == 1
                    ? 'Import 1 Candidate'
                    : 'Import $validRows Candidates',
                icon: Icons.download_rounded,
                onPressed: _confirmImport,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTable() {
    final summary = _summary!;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppTheme.primaryGradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Preview',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...summary.rows.map((row) => _buildRowPreview(row)),
        ],
      ),
    );
  }

  Widget _buildRowPreview(ImportRow row) {
    final hasErrors = row.issues.any((i) => i.severity == ImportIssueSeverity.error);
    final hasWarnings = row.issues.any((i) => i.severity == ImportIssueSeverity.warning);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasErrors
            ? AppTheme.errorRed.withValues(alpha: 0.05)
            : hasWarnings
                ? AppTheme.warningOrange.withValues(alpha: 0.05)
                : AppTheme.secondaryGreen.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasErrors
              ? AppTheme.errorRed.withValues(alpha: 0.2)
              : hasWarnings
                  ? AppTheme.warningOrange.withValues(alpha: 0.2)
                  : AppTheme.secondaryGreen.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#${row.rowNumber}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.resolvedPosition ?? row.rawPosition,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: row.resolvedPosition != null
                    ? AppTheme.textDark
                    : AppTheme.errorRed,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              row.resolvedClass ?? row.rawClass,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textGrey,
              ),
            ),
          ),
          Icon(
            row.matchedPhotoFile != null
                ? Icons.image_rounded
                : Icons.image_not_supported_outlined,
            size: 16,
            color: row.matchedPhotoFile != null
                ? AppTheme.secondaryGreen
                : AppTheme.textGrey,
          ),
          const SizedBox(width: 4),
          Icon(
            hasErrors
                ? Icons.error_rounded
                : hasWarnings
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
            size: 16,
            color: hasErrors
                ? AppTheme.errorRed
                : hasWarnings
                    ? AppTheme.warningOrange
                    : AppTheme.secondaryGreen,
          ),
        ],
      ),
    );
  }
}
