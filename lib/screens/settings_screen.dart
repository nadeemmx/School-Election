import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/gradient_button.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/restore_service.dart';
import '../services/candidate_service.dart';
import '../theme/app_theme.dart';
import 'export/export_results_screen.dart';
import 'import_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isResetting = false;
  double _progress = 0.0;
  String _progressMessage = '';
  String? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _lastBackupTime = BackupService.getLastBackupTime();
  }

  Future<void> _backupData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup Data'),
        content: const Text(
          'This will export all candidates, votes, photos, and settings into a ZIP file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GradientButton(
            label: 'Start Backup',
            onPressed: () => Navigator.pop(ctx, true),
            expanded: false,
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isBackingUp = true;
      _progress = 0.0;
      _progressMessage = 'Starting...';
    });

    try {
      print('[SettingsScreen] =============== BACKUP FLOW STARTED ===============');
      print('[SettingsScreen] Platform: ${Platform.operatingSystem}');

      final backupResult = await BackupService.performBackup(
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = 0.8 * progress;
              _progressMessage = message;
            });
          }
        },
      );

      if (!mounted) return;

      print('[SettingsScreen] Backup created: filename=${backupResult.filename}, '
          'zipBytes.length=${backupResult.zipBytes.length}');

      if (backupResult.zipBytes.isEmpty) {
        throw Exception('Backup ZIP is empty (0 bytes) - creation failed');
      }
      print('[SettingsScreen] ZIP bytes verified: ${backupResult.zipBytes.length} bytes > 0 ✓');

      setState(() {
        _progress = 0.85;
        _progressMessage = 'Choosing save location...';
      });

      String finalPath;
      bool savedViaSaf = false;

      print('[SettingsScreen] Attempting save to user location...');
      final savedPath = await BackupService.saveToUserLocation(
        backupResult.zipBytes,
        backupResult.filename,
      );

      if (savedPath != null) {
        finalPath = savedPath;
        savedViaSaf = true;
        if (!mounted) return;
        print('[SettingsScreen] Save returned path: $finalPath');

        // On desktop platforms (Windows, macOS, Linux), dart:io can access any path
        // so we verify the file exists immediately
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          print('[SettingsScreen] Desktop platform: verifying file on disk...');
          final savedFile = File(finalPath);
          final fileExists = savedFile.existsSync();
          final fileSize = fileExists ? savedFile.lengthSync() : 0;
          print('[SettingsScreen] File exists: $fileExists');
          print('[SettingsScreen] File size: $fileSize bytes');

          if (!fileExists) {
            throw Exception('File was not saved at: $finalPath (exists=false)');
          }
          if (fileSize == 0) {
            throw Exception('File is empty (0 bytes) at: $finalPath');
          }
          print('[SettingsScreen] Desktop file verification passed ✓');
        } else {
          // On Android 10+, dart:io cannot access scoped storage paths.
          // The native Java code already confirmed the write via ContentResolver.
          print('[SettingsScreen] Mobile platform: trusting native write (skipping dart:io verify) ✓');
        }
      } else {
        print('[SettingsScreen] User location save returned null, falling back to app documents...');
        if (mounted) {
          setState(() {
            _progressMessage = 'Saving to app storage...';
          });
        }
        finalPath = await BackupService.saveToAppDocuments(
          backupResult.zipBytes,
          backupResult.filename,
        );
        final savedFile = File(finalPath);
        if (!savedFile.existsSync()) {
          throw Exception('Fallback save: file not found at: $finalPath');
        }
        if (savedFile.lengthSync() == 0) {
          throw Exception('Fallback save: file is 0 bytes at: $finalPath');
        }
        print('[SettingsScreen] Fallback save verified: ${savedFile.lengthSync()} bytes ✓');
      }

      // Step C: Clean up temp directory now that save is confirmed
      print('[SettingsScreen] Cleaning up temp dir...');
      await backupResult.cleanupTempDir();

      if (!mounted) return;

      setState(() {
        _isBackingUp = false;
        _lastBackupTime = BackupService.getLastBackupTime();
      });

      print('[SettingsScreen] Backup complete! Final path: $finalPath');

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.secondaryGreen, size: 28),
              SizedBox(width: 10),
              Text('Backup Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Backup saved to:',
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
                  finalPath,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!savedViaSaf) ...[
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
    } catch (e, stack) {
      print('[SettingsScreen] BACKUP FAILED: $e');
      print('[SettingsScreen] STACK: $stack');
      if (!mounted) return;
      setState(() {
        _isBackingUp = false;
      });
      _showError('Backup failed: ${e.toString()}');
    }
  }

  Future<void> _restoreData() async {
    final warning = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data'),
        content: Text(
          'This will REPLACE all current data with the backup.\n\n'
          'An automatic backup of current data will be created before restoring.\n\n'
          'Proceed?',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GradientButton(
            label: 'Restore',
            gradient: [AppTheme.warningOrange, AppTheme.warningOrange],
            onPressed: () => Navigator.pop(ctx, true),
            expanded: false,
          ),
        ],
      ),
    );

    if (warning != true || !mounted) return;

    String? zipPath;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'Select backup ZIP file',
      );

      if (result == null || result.files.isEmpty) return;
      zipPath = result.files.single.path;
    } catch (_) {
      _showError('Could not open file picker.');
      return;
    }

    if (zipPath == null || !File(zipPath).existsSync()) {
      _showError('Selected file does not exist.');
      return;
    }

    setState(() {
      _isRestoring = true;
      _progress = 0.0;
      _progressMessage = 'Starting restore...';
    });

    try {
      final restoreResult = await RestoreService.performRestore(
        zipPath,
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
        _isRestoring = false;
      });

      if (restoreResult.success) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.secondaryGreen, size: 28),
                SizedBox(width: 10),
                Text('Restore Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _restoreStat('Candidates', restoreResult.candidatesRestored),
                _restoreStat('Votes', restoreResult.votesRestored),
                _restoreStat('Photos', restoreResult.photosRestored),
                const SizedBox(height: 10),
                Text(
                  restoreResult.message,
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
                label: 'OK',
                onPressed: () => Navigator.pop(ctx),
                expanded: false,
              ),
            ],
          ),
        );
      } else {
        _showError(restoreResult.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
      });
      _showError('Restore failed: ${e.toString()}');
    }
  }

  Future<void> _resetElection() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Election'),
        content: const Text(
          'This will reset ALL votes to 0 and clear all voting records.\n\n'
          'All candidates, photos, school name, and positions will be preserved.\n\n'
          'This action CANNOT be undone. Take a backup first if needed.\n\n'
          'Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GradientButton(
            label: 'Reset Election',
            gradient: [AppTheme.errorRed, AppTheme.warningOrange],
            onPressed: () => Navigator.pop(ctx, true),
            expanded: false,
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isResetting = true);

    try {
      await CandidateService.resetElection();

      if (!mounted) return;

      setState(() => _isResetting = false);

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.secondaryGreen, size: 28),
              SizedBox(width: 10),
              Text('Election Reset'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All votes have been reset to 0.',
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                '${CandidateService.totalCandidates} candidates preserved.',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textGrey),
              ),
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResetting = false);
      _showError('Reset failed: ${e.toString()}');
    }
  }

  Widget _restoreStat(String label, int count) {
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
    final isBusy = _isBackingUp || _isRestoring;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (isBusy) ...[
            _buildProgressSection(),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('Data Management'),
          const SizedBox(height: 14),
          _buildBackupCard(),
          const SizedBox(height: 16),
          _buildRestoreCard(),
          const SizedBox(height: 16),
          _buildResetCard(),
          const SizedBox(height: 16),
          _buildImportCard(),
          const SizedBox(height: 16),
          _buildExportCard(),
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

  Widget _buildBackupCard() {
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
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.backup_rounded,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup Data',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Export all data to a ZIP file',
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
            if (_lastBackupTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: AppTheme.secondaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Last backup: $_lastBackupTime',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.secondaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: _isBackingUp ? 'Backing up...' : 'Backup Data',
                icon: Icons.backup_rounded,
                onPressed: _isBackingUp ? null : _backupData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreCard() {
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
                    color: AppTheme.warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.restore_page_rounded,
                    color: AppTheme.warningOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restore Data',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Restore from a previous backup ZIP file',
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
                color: AppTheme.warningOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppTheme.warningOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current data will be automatically backed up before restoring. '
                      'If anything goes wrong, your original data will be recovered.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: _isRestoring ? 'Restoring...' : 'Restore Data',
                icon: Icons.restore_page_rounded,
                gradient: [AppTheme.warningOrange, AppTheme.warningOrange],
                onPressed: _isRestoring ? null : _restoreData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetCard() {
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
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.restart_alt_rounded,
                    color: AppTheme.errorRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset Election',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Clear all votes, keep candidates',
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
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppTheme.errorRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resets all votes to 0. Candidates, photos, school name, and positions are preserved. This action cannot be undone.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: _isResetting ? 'Resetting...' : 'Reset Election',
                icon: Icons.restart_alt_rounded,
                gradient: [AppTheme.errorRed, AppTheme.warningOrange],
                onPressed: _isResetting ? null : _resetElection,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard() {
    final votingLocked = CandidateService.hasVotingStarted();
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
                    color: AppTheme.secondaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: votingLocked
                      ? const Icon(
                          Icons.lock_rounded,
                          color: AppTheme.textGrey,
                          size: 24,
                        )
                      : const Icon(
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
                        'Bulk Import',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: votingLocked ? AppTheme.textGrey : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        votingLocked
                            ? 'Locked - voting has started'
                            : 'Import 100s of candidates from a ZIP file',
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
            if (!votingLocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppTheme.secondaryPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ZIP must contain candidates.csv and an optional photos/ folder. '
                        'Candidates will be added to existing data.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: votingLocked ? 'Locked' : 'Import Candidates',
                icon: votingLocked ? Icons.lock_rounded : Icons.download_rounded,
                gradient: votingLocked
                    ? [AppTheme.textGrey, AppTheme.textGrey]
                    : [AppTheme.secondaryPurple, AppTheme.primaryBlue],
                onPressed: votingLocked || _isBackingUp || _isRestoring
                    ? null
                    : () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const ImportScreen()),
                        );
                        if (result == true && mounted) {
                          setState(() {});
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard() {
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
                    color: AppTheme.secondaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.file_download_rounded,
                    color: AppTheme.secondaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Results',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Export election results to Excel, PDF, or ZIP',
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
                color: AppTheme.secondaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppTheme.secondaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Supports .xlsx, .pdf, and .zip formats. All data is read from the current election database.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'Export Results',
                icon: Icons.file_download_rounded,
                gradient: [AppTheme.secondaryGreen, const Color(0xFF16A34A)],
                onPressed: _isBackingUp || _isRestoring
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ExportResultsScreen()),
                        ),
              ),
            ),
          ],
        ),
      ),
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
            'Storage',
            'Hive Database',
            Icons.storage_rounded,
          ),
          const Divider(height: 24),
          _infoRow(
            'Candidates',
            '${CandidateServiceEx.totalCandidates} registered',
            Icons.people_rounded,
          ),
          const Divider(height: 24),
          _infoRow(
            'Total Votes',
            '${CandidateServiceEx.totalVotesCast} cast',
            Icons.how_to_vote_rounded,
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

class CandidateServiceEx {
  static int get totalCandidates {
    try {
      return CandidateService.totalCandidates;
    } catch (_) {
      return 0;
    }
  }

  static int get totalVotesCast {
    try {
      return CandidateService.totalVotes;
    } catch (_) {
      return 0;
    }
  }
}
