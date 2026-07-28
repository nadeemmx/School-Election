import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../components/gradient_button.dart';
import '../../services/candidate_service.dart';
import '../../services/export/export_service.dart';
import '../../theme/app_theme.dart';

class ExportResultsScreen extends StatefulWidget {
  const ExportResultsScreen({super.key});

  @override
  State<ExportResultsScreen> createState() => _ExportResultsScreenState();
}

class _ExportResultsScreenState extends State<ExportResultsScreen> {
  bool _isExporting = false;
  double _progress = 0.0;
  String _progressMessage = '';

  bool get _hasData => CandidateService.totalCandidates > 0;

  Future<void> _exportExcel() => _export(ExportFormat.excel);
  Future<void> _exportPdf() => _export(ExportFormat.pdf);
  Future<void> _exportZip() => _export(ExportFormat.zip);

  Future<void> _export(ExportFormat format) async {
    if (!_hasData) {
      _showNoDataDialog();
      return;
    }

    setState(() {
      _isExporting = true;
      _progress = 0.0;
      _progressMessage = 'Starting export...';
    });

    try {
      final files = await ExportService.generateAll(
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

      setState(() {
        _progress = 0.9;
        _progressMessage = 'Choosing save location...';
      });

      final bytes = files[format]!;
      final filename = ExportService.formatFilename(format);

      String finalPath;
      bool savedViaDialog = false;

      final savedPath = await ExportService.saveToUserLocation(
        bytes: bytes,
        filename: filename,
      );

      if (savedPath != null) {
        finalPath = savedPath.path;
        savedViaDialog = true;

        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          final savedFile = File(finalPath);
          if (!savedFile.existsSync()) {
            throw Exception('File was not saved at: $finalPath');
          }
          if (savedFile.lengthSync() == 0) {
            throw Exception('File is empty at: $finalPath');
          }
        }
      } else {
        setState(() => _progressMessage = 'Saving to app storage...');
        finalPath = await ExportService.saveToAppDocuments(bytes, filename);
      }

      if (!mounted) return;

      setState(() {
        _isExporting = false;
        _progress = 1.0;
      });

      _showSuccessDialog(finalPath, savedViaDialog);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      _showError('Export failed: ${e.toString()}');
    }
  }

  void _showNoDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.warningOrange, size: 28),
            SizedBox(width: 10),
            Text('No Data'),
          ],
        ),
        content: Text(
          'No election data available.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
        ),
        actions: [
          GradientButton(
            label: 'OK',
            onPressed: () => Navigator.pop(ctx),
            expanded: false,
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String path, bool savedViaDialog) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.secondaryGreen, size: 28),
            SizedBox(width: 10),
            Text('Export Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File saved to:',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                path,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!savedViaDialog) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.warningOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved to app storage. Use a file manager to copy the file.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          GradientButton(
            label: 'OK',
            onPressed: () => Navigator.pop(ctx),
            expanded: false,
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
      appBar: AppBar(
        title: Text(
          'Export Results',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: const Color(0xFFF7F8FC),
        foregroundColor: AppTheme.textDark,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (_isExporting) ...[
            _buildProgressSection(),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('Choose Format'),
          const SizedBox(height: 14),
          _buildExcelCard(),
          const SizedBox(height: 16),
          _buildPdfCard(),
          const SizedBox(height: 16),
          _buildZipCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('Information'),
          const SizedBox(height: 14),
          _buildInfoCard(),
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
              value: _progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.9),
              ),
              minHeight: 6,
            ),
          ),
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
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
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
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildExportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String formatLabel,
    required List<Color> buttonGradient,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, size: 16, color: AppTheme.textGrey),
                  const SizedBox(width: 8),
                  Text(
                    formatLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: _isExporting ? 'Exporting...' : 'Export $title',
                icon: Icons.download_rounded,
                gradient: buttonGradient,
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExcelCard() {
    return _buildExportCard(
      title: 'Excel',
      description: 'Generate a professional Excel workbook with election results',
      icon: Icons.table_chart_rounded,
      iconColor: const Color(0xFF22C55E),
      iconBg: const Color(0xFF22C55E).withValues(alpha: 0.1),
      formatLabel: 'Election_Results_YYYYMMDD_HHMM.xlsx',
      buttonGradient: [const Color(0xFF22C55E), const Color(0xFF16A34A)],
      onPressed: _isExporting ? null : _exportExcel,
    );
  }

  Widget _buildPdfCard() {
    return _buildExportCard(
      title: 'PDF',
      description: 'Generate a printable PDF report of election results',
      icon: Icons.picture_as_pdf_rounded,
      iconColor: AppTheme.errorRed,
      iconBg: AppTheme.errorRed.withValues(alpha: 0.1),
      formatLabel: 'Election_Report_YYYYMMDD_HHMM.pdf',
      buttonGradient: [AppTheme.errorRed, const Color(0xFFDC2626)],
      onPressed: _isExporting ? null : _exportPdf,
    );
  }

  Widget _buildZipCard() {
    return _buildExportCard(
      title: 'All Results (ZIP)',
      description: 'Export Excel, PDF, and JSON results in a single ZIP archive',
      icon: Icons.folder_zip_rounded,
      iconColor: AppTheme.warningOrange,
      iconBg: AppTheme.warningOrange.withValues(alpha: 0.1),
      formatLabel: 'Election_Results_YYYYMMDD_HHMM.zip  •  Contains .xlsx, .pdf, .json',
      buttonGradient: AppTheme.primaryGradient,
      onPressed: _isExporting ? null : _exportZip,
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            'Candidates',
            '${CandidateService.totalCandidates} registered',
            Icons.people_rounded,
          ),
          const Divider(height: 24),
          _infoRow(
            'Total Votes',
            '${CandidateService.totalVotes} cast',
            Icons.how_to_vote_rounded,
          ),
          const Divider(height: 24),
          _infoRow(
            'Positions',
            '${CandidateService.positions.length} positions',
            Icons.work_rounded,
          ),
          const SizedBox(height: 12),
          if (!_hasData)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.warningOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No election data available.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textGrey),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}