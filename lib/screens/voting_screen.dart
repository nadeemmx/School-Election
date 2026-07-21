import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/gradient_button.dart';
import '../models/candidate.dart';
import '../services/candidate_service.dart';
import '../session/voting_session.dart';
import '../theme/app_theme.dart';
import '../widgets/vote_card.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key});

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  List<CandidateModel> _candidates = [];
  VotingSession? _session;
  bool _isVoting = false;
  bool _voteSubmitted = false;
  String _searchQuery = '';
  String? _selectedPosition;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _candidates = CandidateService.getAll();
    _session = VotingSession(CandidateService.positions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCandidate(CandidateModel candidate) {
    if (_isVoting || _voteSubmitted || _session == null) return;
    setState(() {
      if (_session!.isCandidateSelected(candidate.id, candidate.position)) {
        _session!.deselect(candidate.position);
      } else {
        _session!.select(candidate.position, candidate.id);
      }
    });
  }

  void _submitVote() {
    final selections = _session?.allSelections ?? {};
    if (selections.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.how_to_vote_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Confirm Votes',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Review selections for this student.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  children: selections.entries.map((entry) {
                    final name = _getCandidateName(entry.value);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: AppTheme.secondaryGreen,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textGrey,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (selections.length < (_session?.totalPositions ?? 0)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${(_session?.totalPositions ?? 0) - selections.length} position(s) skipped',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textGrey,
                      side: BorderSide(color: AppTheme.borderLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    label: 'Submit All Votes',
                    icon: Icons.how_to_vote_rounded,
                    gradient: const [
                      AppTheme.secondaryGreen,
                      Color(0xFF059669),
                    ],
                    onPressed: () {
                      Navigator.pop(ctx);
                      _castVote(selections);
                    },
                    expanded: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getCandidateName(String id) {
    final idx = _candidates.indexWhere((c) => c.id == id);
    return idx >= 0 ? _candidates[idx].name : 'Unknown';
  }

  Future<void> _castVote(Map<String, String> selections) async {
    if (_isVoting) return;
    setState(() => _isVoting = true);

    try {
      for (final entry in selections.entries) {
        await CandidateService.incrementVotes(entry.value);
      }
      _candidates = CandidateService.getAll();
      if (mounted) {
        setState(() {
          _isVoting = false;
          _voteSubmitted = true;
        });
        _showSuccess();
      }
    } catch (e) {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.secondaryGreen,
                      Color(0xFF059669),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryGreen.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Votes Submitted!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All votes have been recorded successfully.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'Next Student',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.pop(ctx);
                  _nextStudent();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStudent() {
    setState(() {
      _session!.reset();
      _voteSubmitted = false;
    });
  }

  List<CandidateModel> get _filteredCandidates {
    var result = _candidates.where((c) {
      if (_searchQuery.isNotEmpty &&
          !c.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedPosition != null && c.position != _selectedPosition) {
        return false;
      }
      return true;
    }).toList();
    result.sort((a, b) {
      final positions = CandidateService.positions;
      final aIdx = positions.indexOf(a.position);
      final bIdx = positions.indexOf(b.position);
      return aIdx.compareTo(bIdx);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildPositionFilters(),
            Expanded(child: _buildCandidateList()),
          ],
        ),
      ),
      bottomNavigationBar: _voteSubmitted
          ? _buildNextStudentBar()
          : _buildSubmitBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.textDark,
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voting',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'Select candidates for each position',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textGrey,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              _SecureBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppTheme.textDark,
        ),
        decoration: InputDecoration(
          hintText: 'Search candidate...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textGrey.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.textGrey.withValues(alpha: 0.7),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.textGrey,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppTheme.borderLight.withValues(alpha: 0.6),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppTheme.borderLight.withValues(alpha: 0.6),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionFilters() {
    final positions = CandidateService.positions;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: positions.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FilterChip(
                    label: 'All',
                    isSelected: _selectedPosition == null,
                    onTap: () => setState(() => _selectedPosition = null),
                  );
                }
                final position = positions[index - 1];
                final isSelected = _selectedPosition == position;
                return _FilterChip(
                  label: position,
                  isSelected: isSelected,
                  onTap: () =>
                      setState(() => _selectedPosition = isSelected ? null : position),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateList() {
    final filtered = _filteredCandidates;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppTheme.textGrey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No candidates match "$_searchQuery"'
                  : 'No candidates available',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedPosition != null) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final candidate = filtered[index];
          return _buildCardForCandidate(candidate, index);
        },
      );
    }

    final grouped = <String, List<CandidateModel>>{};
    for (final c in filtered) {
      grouped.putIfAbsent(c.position, () => []).add(c);
    }
    final positions = grouped.keys.toList();

    int globalIndex = 0;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: positions.length + filtered.length,
      itemBuilder: (context, index) {
        int localIdx = 0;
        for (final pos in positions) {
          final items = grouped[pos]!;
          if (localIdx == index) {
            return _buildPositionSectionHeader(pos);
          }
          localIdx++;
          for (final candidate in items) {
            if (localIdx == index) {
              return _buildCardForCandidate(candidate, globalIndex++);
            }
            localIdx++;
          }
        }
        return null;
      },
    );
  }

  Widget _buildPositionSectionHeader(String position) {
    final selected = _session?.isPositionSelected(position) ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            position,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey,
              letterSpacing: 0.3,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Selected',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
          const Spacer(),
          Container(
            height: 1,
            width: 60,
            color: AppTheme.borderLight.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCardForCandidate(CandidateModel candidate, int index) {
    final selected =
        _session?.isCandidateSelected(candidate.id, candidate.position) ?? false;
    final locked = !selected &&
        (_session?.isPositionSelected(candidate.position) ?? false);
    final isLoading = _isVoting && selected;

    CardVoteState voteState;
    if (isLoading) {
      voteState = CardVoteState.loading;
    } else if (selected) {
      voteState = CardVoteState.selected;
    } else if (locked) {
      voteState = CardVoteState.locked;
    } else {
      voteState = CardVoteState.active;
    }

    return VoteCard(
      key: ValueKey(candidate.id),
      candidate: candidate,
      voteState: voteState,
      index: index,
      onTap: (_isVoting || _voteSubmitted)
          ? null
          : () => _selectCandidate(candidate),
    );
  }

  Widget _buildSubmitBar() {
    final selected = _session?.selectedCount ?? 0;
    final total = _session?.totalPositions ?? 0;

    return Container(
      padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textGrey,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$selected / $total Positions',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GradientButton(
              label: 'Submit Vote',
              icon: Icons.how_to_vote_rounded,
              onPressed: selected > 0 ? _submitVote : null,
              expanded: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStudentBar() {
    return Container(
      padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: GradientButton(
            label: 'Next Student',
            icon: Icons.arrow_forward_rounded,
            gradient: const [
              AppTheme.primaryBlue,
              AppTheme.secondaryPurple,
            ],
            onPressed: _nextStudent,
          ),
        ),
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.secondaryGreen,
            Color(0xFF059669),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'Secure',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppTheme.borderLight.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textGrey,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
