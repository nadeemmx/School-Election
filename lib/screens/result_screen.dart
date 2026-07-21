import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/candidate.dart';
import '../services/candidate_service.dart';
import '../theme/app_theme.dart';
import '../utils/password_provider.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/photo_avatar.dart';

class ResultScreen extends StatefulWidget {
  final PasswordProvider provider;
  const ResultScreen({super.key, required this.provider});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<CandidateModel> _candidates = [];

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  void _loadCandidates() {
    setState(() => _candidates = CandidateService.getAll());
  }

  Map<String, CandidateModel> _getWinners() {
    final winners = <String, CandidateModel>{};
    for (final position in CandidateService.positions) {
      final candidates = CandidateService.getByPosition(position);
      if (candidates.isEmpty) continue;
      final winner = candidates.reduce((a, b) => a.votes > b.votes ? a : b);
      if (winner.votes > 0) {
        winners[position] = winner;
      }
    }
    return winners;
  }

  List<CandidateModel> get _sortedCandidates {
    final sorted = List<CandidateModel>.from(_candidates);
    sorted.sort((a, b) {
      final positions = CandidateService.positions;
      final aIdx = positions.indexOf(a.position);
      final bIdx = positions.indexOf(b.position);
      if (aIdx != bIdx) return aIdx.compareTo(bIdx);
      return b.votes.compareTo(a.votes);
    });
    return sorted;
  }

  int get _maxVotes {
    if (_candidates.isEmpty) return 1;
    return _candidates.map((c) => c.votes).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, size: 56, color: AppTheme.textGrey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('No election data available',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              Text('Add candidates and start voting to see results here.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textGrey)),
            ],
          ),
        ),
      );
    }

    final winners = _getWinners();
    final allWinnersHaveVotes = winners.isNotEmpty;
    final maxVotes = _maxVotes;
    final sortedCandidates = _sortedCandidates;

    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildSummaryCard(winners),
              if (allWinnersHaveVotes) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Winners'),
                const SizedBox(height: 14),
                ...winners.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildWinnerCard(entry.key, entry.value),
                )),
              ],
              const SizedBox(height: 24),
              _buildSectionHeader('All Candidates'),
              const SizedBox(height: 14),
              ...sortedCandidates.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildCandidateRow(c, maxVotes, winners.values.contains(c)),
              )),
            ],
          ),
          if (allWinnersHaveVotes)
            IgnorePointer(
              ignoring: true,
              child: ConfettiOverlay(
                show: true,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'Election Results',
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          widget.provider.reset();
          Navigator.pop(context);
        },
      ),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: const Color(0xFFF7F8FC),
      foregroundColor: AppTheme.textDark,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
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
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, CandidateModel> winners) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D1B69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Election Summary',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _StatItem(icon: Icons.people_rounded, label: 'Candidates', value: '${CandidateService.totalCandidates}')),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(child: _StatItem(icon: Icons.how_to_vote_rounded, label: 'Total Votes', value: '${CandidateService.totalVotes}')),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(child: _StatItem(icon: Icons.work_rounded, label: 'Positions', value: '${CandidateService.positions.length}')),
            ],
          ),
          if (winners.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              '${winners.length} Position${winners.length > 1 ? 's' : ''} ${winners.length > 1 ? 'have' : 'has'} been decided',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWinnerCard(String position, CandidateModel candidate) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade50,
            Colors.orange.shade50,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.goldBorder.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.warningOrange.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  PhotoAvatar(
                    photoPath: candidate.photoPath,
                    initials: candidate.initials,
                    backgroundColor: candidate.photoColor,
                    size: 56,
                    borderRadius: 16,
                  ),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.amber, Colors.orange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            candidate.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.amber, Colors.orange],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        position,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${candidate.className} • Section ${candidate.section}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textGrey,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${candidate.votes}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'votes',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateRow(CandidateModel candidate, int maxVotes, bool isWinner) {
    final voteRatio = maxVotes > 0 ? candidate.votes / maxVotes : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          PhotoAvatar(
            photoPath: candidate.photoPath,
            initials: candidate.initials,
            backgroundColor: candidate.photoColor,
            size: 44,
            borderRadius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        candidate.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isWinner
                            ? Colors.amber.withValues(alpha: 0.1)
                            : AppTheme.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isWinner) ...[
                            Icon(Icons.emoji_events_rounded, size: 10, color: Colors.amber.shade700),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            candidate.position,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isWinner ? Colors.amber.shade700 : AppTheme.primaryBlue.withValues(alpha: 0.8),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${candidate.className} • Section ${candidate.section} • Roll ${candidate.rollNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textGrey,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: voteRatio,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isWinner ? Colors.amber.shade600 : AppTheme.primaryBlue,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${candidate.votes} vote${candidate.votes == 1 ? '' : 's'}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isWinner ? Colors.amber.shade700 : AppTheme.textDark,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white60, height: 1.1),
        ),
      ],
    );
  }
}
