import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/candidate.dart';
import '../theme/app_theme.dart';
import 'photo_avatar.dart';

class CandidateCard extends StatelessWidget {
  final CandidateModel candidate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CandidateCard({
    super.key,
    required this.candidate,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          PhotoAvatar(
            photoPath: candidate.photoPath,
            initials: candidate.initials,
            backgroundColor: candidate.photoColor,
            size: 56,
            borderRadius: 18,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                const SizedBox(height: 4),
                _infoChip(Icons.work_outline, candidate.position),
                const SizedBox(height: 2),
                _infoChip(Icons.school_outlined, '${candidate.className} - ${candidate.section}'),
                const SizedBox(height: 2),
                _infoChip(Icons.badge_outlined, 'Roll: ${candidate.rollNumber}'),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconBtn(Icons.edit_rounded, AppTheme.primaryBlue, onEdit),
              const SizedBox(height: 8),
              _iconBtn(Icons.delete_rounded, AppTheme.errorRed, onDelete),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textGrey),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textGrey)),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback? onTap) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
