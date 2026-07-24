import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/glass_card.dart';
import '../services/candidate_service.dart';
import '../theme/app_theme.dart';
import 'add_candidate_screen.dart';
import 'settings_screen.dart';
import 'voting_screen.dart';
import 'result_password_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _candidatesCount = 0;
  int _votesCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      _candidatesCount = CandidateService.totalCandidates;
      _votesCount = CandidateService.totalVotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPS, Gondia',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'Dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.secondaryGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Active',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings_rounded, size: 20),
                    color: AppTheme.primaryBlue,
                    onPressed: () => _navigate(context, const SettingsScreen()),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GlassCard(
              gradient: AppTheme.primaryGradient,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.how_to_vote_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Election',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'School Council Elections 2026',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cast your vote and make a difference!',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 14),
            _actionCard(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Add Candidate',
              subtitle: 'Register election candidates',
              gradient: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
              onTap: () => _navigate(context, const AddCandidateScreen()),
            ),
            const SizedBox(height: 12),
            _actionCard(
              icon: Icons.how_to_vote_rounded,
              title: 'Voting',
              subtitle: 'Start student voting',
              gradient: const [Color(0xFF22C55E), Color(0xFF10B981)],
              onTap: () => _navigate(context, const VotingScreen()),
            ),
            const SizedBox(height: 12),
            _actionCard(
              icon: Icons.bar_chart_rounded,
              title: 'Results',
              subtitle: 'View election results',
              gradient: const [Color(0xFFF59E0B), Color(0xFFF97316)],
              onTap: () => _navigate(context, const ResultPasswordScreen()),
            ),
            const SizedBox(height: 22),
            Text(
              'Quick Stats',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                StatCard(
                  icon: Icons.people_rounded,
                  label: 'Candidates',
                  value: '$_candidatesCount',
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 12),
                StatCard(
                  icon: Icons.how_to_vote_rounded,
                  label: 'Votes Cast',
                  value: '$_votesCount',
                  color: AppTheme.secondaryGreen,
                ),
                const SizedBox(width: 12),
                StatCard(
                  icon: Icons.work_rounded,
                  label: 'Positions',
                  value: '${CandidateService.positions.length}',
                  color: AppTheme.secondaryPurple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigate(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, animation, _, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    if (mounted) _refreshStats();
  }
}
