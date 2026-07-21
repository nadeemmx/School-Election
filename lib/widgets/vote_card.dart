import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/candidate.dart';
import '../theme/app_theme.dart';
import 'photo_avatar.dart';

enum CardVoteState {
  active,
  loading,
  selected,
  locked,
}

class VoteCard extends StatefulWidget {
  final CandidateModel candidate;
  final CardVoteState voteState;
  final VoidCallback? onTap;
  final int index;

  const VoteCard({
    super.key,
    required this.candidate,
    required this.voteState,
    this.onTap,
    this.index = 0,
  });

  @override
  State<VoteCard> createState() => _VoteCardState();
}

class _VoteCardState extends State<VoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    Future.delayed(Duration(milliseconds: widget.index * 50 + 50), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isDisabled => widget.voteState == CardVoteState.loading ||
      widget.voteState == CardVoteState.locked;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: _buildCardContent(),
    );
  }

  Widget _buildCardContent() {
    final candidate = widget.candidate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: _isDisabled ? null : widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.voteState == CardVoteState.selected
                    ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                    : AppTheme.borderLight.withValues(alpha: 0.6),
                width: widget.voteState == CardVoteState.selected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Hero(
                    tag: 'candidate_photo_${candidate.id}',
                    child: PhotoAvatar(
                      photoPath: candidate.photoPath,
                      initials: candidate.initials,
                      backgroundColor: candidate.photoColor,
                      size: 60,
                      borderRadius: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          candidate.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _PositionChip(position: candidate.position),
                        const SizedBox(height: 5),
                        Text(
                          '${candidate.className} • ${candidate.section} • Roll ${candidate.rollNumber}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textGrey,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _VoteButton(
                    state: widget.voteState,
                    onPressed: _isDisabled ? null : widget.onTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionChip extends StatelessWidget {
  final String position;

  const _PositionChip({required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.1),
            AppTheme.secondaryPurple.withValues(alpha: 0.1),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_rounded,
            size: 10,
            color: AppTheme.primaryBlue.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            position,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue.withValues(alpha: 0.9),
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatefulWidget {
  final CardVoteState state;
  final VoidCallback? onPressed;

  const _VoteButton({required this.state, this.onPressed});

  @override
  State<_VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<_VoteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isInteractive => widget.state == CardVoteState.active ||
      widget.state == CardVoteState.selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _isInteractive ? (_) => _pulseController.forward() : null,
        onTapUp: _isInteractive
            ? (_) {
                _pulseController.reverse();
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: _isInteractive ? () => _pulseController.reverse() : null,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    final size = const Size(82, 42);
    BorderRadiusGeometry radius = BorderRadius.circular(12);

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: _buildGradient(),
        borderRadius: radius,
        boxShadow: [
          if (widget.state == CardVoteState.active)
            BoxShadow(
              color: AppTheme.secondaryGreen.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Center(child: _buildButtonContent()),
    );
  }

  LinearGradient _buildGradient() {
    switch (widget.state) {
      case CardVoteState.active:
        return const LinearGradient(
          colors: [AppTheme.secondaryGreen, Color(0xFF059669)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case CardVoteState.loading:
        return const LinearGradient(
          colors: [AppTheme.secondaryGreen, Color(0xFF059669)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case CardVoteState.selected:
        return const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case CardVoteState.locked:
        return LinearGradient(
          colors: [
            Colors.grey.shade300,
            Colors.grey.shade400,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }

  Widget _buildButtonContent() {
    switch (widget.state) {
      case CardVoteState.active:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 15),
            const SizedBox(width: 3),
            Text(
              'Vote',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        );
      case CardVoteState.loading:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        );
      case CardVoteState.selected:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 15),
            const SizedBox(width: 3),
            Text(
              'Selected',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        );
      case CardVoteState.locked:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 3),
            Text(
              'Locked',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        );
    }
  }
}
