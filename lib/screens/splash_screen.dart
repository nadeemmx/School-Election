import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/school_config.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;

  late Animation<double> _taglineFade;

  late List<Animation<double>> _cardAnimations;

  late Animation<double> _illustrationFade;

  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOutBack),
    );
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.15, 0.45, curve: Curves.easeOutCubic),
          ),
        );
    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.40, curve: Curves.easeIn),
    );

    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.55, curve: Curves.easeIn),
    );

    _cardAnimations = List.generate(4, (i) {
      final start = 0.45 + i * 0.05;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start,
          (start + 0.10).clamp(0, 1),
          curve: Curves.easeOutCubic,
        ),
      );
    });

    _illustrationFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 0.80, curve: Curves.easeIn),
    );

    _progressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 0.95, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 3500));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final isTablet = width > 600;
    final hPadding = width * 0.06;
    final logoSize = (width * 0.18).clamp(60.0, 110.0);
    final schoolNameSize = (width * 0.045).clamp(16.0, 26.0);
    final yearSize = (width * 0.035).clamp(12.0, 17.0);
    final mainTitleSize = (width * 0.11).clamp(34.0, 58.0);
    final subTitleSize = (width * 0.04).clamp(13.0, 19.0);
    final taglineSize = (width * 0.035).clamp(12.0, 16.0);
    final cardTitleSize = (width * 0.03).clamp(11.0, 14.0);
    final sectionGap = height * 0.025;
    final largeGap = height * 0.045;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: height * 0.20,
                child: AnimatedBuilder(
                  animation: _illustrationFade,
                  builder: (_, _) => Opacity(
                    opacity: 0.12 * _illustrationFade.value,
                    child: CustomPaint(
                      painter: _SchoolBuildingPainter(),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 520 : width - hPadding * 2,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: height * 0.04),
                          _buildSchoolLogo(logoSize),
                          SizedBox(height: sectionGap * 0.8),
                          _buildSchoolName(schoolNameSize),
                          SizedBox(height: 4),
                          _buildAcademicYear(yearSize),
                          SizedBox(height: largeGap),
                          SlideTransition(
                            position: _titleSlide,
                            child: FadeTransition(
                              opacity: _titleFade,
                              child: _buildMainTitle(
                                mainTitleSize,
                                subTitleSize,
                              ),
                            ),
                          ),
                          SizedBox(height: sectionGap * 0.8),
                          FadeTransition(
                            opacity: _taglineFade,
                            child: _buildTagline(taglineSize),
                          ),
                          SizedBox(height: sectionGap),
                          _buildFeatureCards(width, cardTitleSize),
                          SizedBox(height: largeGap * 0.6),
                          _buildLoadingIndicator(),
                          SizedBox(height: height * 0.04),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolLogo(double size) {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withAlpha(70),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child:
              SchoolConfig.logoUrl != null && SchoolConfig.logoUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.28),
                  child: Image.network(
                    SchoolConfig.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildLogoIcon(size),
                  ),
                )
              : _buildLogoIcon(size),
        ),
      ),
    );
  }

  Widget _buildLogoIcon(double size) {
    return Icon(Icons.school_rounded, size: size * 0.5, color: Colors.white);
  }

  Widget _buildSchoolName(double fontSize) {
    return FadeTransition(
      opacity: _logoFade,
      child: Text(
        SchoolConfig.schoolName.toUpperCase(),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
          letterSpacing: 2.5,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildAcademicYear(double fontSize) {
    return FadeTransition(
      opacity: _logoFade,
      child: Text(
        SchoolConfig.academicYear,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMainTitle(double mainSize, double subSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SCHOOL',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: mainSize,
            fontWeight: FontWeight.w200,
            height: 1.05,
            color: const Color(0xFF1E3A8A),
            letterSpacing: 1,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'ELECTION',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: mainSize,
              fontWeight: FontWeight.w200,
              height: 1.05,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        ),
        SizedBox(height: mainSize * 0.15),
        Text(
          'MANAGEMENT SYSTEM',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: subSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
            letterSpacing: 3,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTagline(double fontSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your Vote. Your Voice.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: fontSize * 1.1,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E3A8A),
            letterSpacing: 0.5,
            height: 1.3,
          ),
        ),
        SizedBox(height: fontSize * 0.3),
        Text(
          'Choose the Leaders of Tomorrow',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF64748B),
            letterSpacing: 0.3,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards(double screenWidth, double titleSize) {
    final features = [
      (icon: Icons.shield_rounded, title: 'Secure\nVoting'),
      (icon: Icons.how_to_vote_rounded, title: 'One Student,\nOne Vote'),
      (icon: Icons.bar_chart_rounded, title: 'Fair &\nTransparent'),
      (icon: Icons.verified_rounded, title: 'Trusted by\nSchools'),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: features[0].icon,
                  title: features[0].title,
                  titleSize: titleSize,
                  animation: _cardAnimations[0],
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: _buildFeatureCard(
                  icon: features[1].icon,
                  title: features[1].title,
                  titleSize: titleSize,
                  animation: _cardAnimations[1],
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.03),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: features[2].icon,
                  title: features[2].title,
                  titleSize: titleSize,
                  animation: _cardAnimations[2],
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: _buildFeatureCard(
                  icon: features[3].icon,
                  title: features[3].title,
                  titleSize: titleSize,
                  animation: _cardAnimations[3],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required double titleSize,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withAlpha(12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withAlpha(18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: const Color(0xFF1E3A8A), size: 22),
                ),
                SizedBox(height: titleSize * 0.7),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (_, _) => Opacity(
        opacity: _progressAnim.value,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    Container(color: const Color(0xFFE2E8F0)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressAnim.value,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF6D28D9)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Loading',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolBuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cw = size.width;
    final ch = size.height;

    final baseY = ch * 0.92;
    final roofPeakY = ch * 0.08;
    final roofBaseY = ch * 0.32;
    final leftWall = cw * 0.15;
    final rightWall = cw * 0.85;

    final roofPath = Path()
      ..moveTo(cw * 0.08, roofBaseY)
      ..lineTo(cw * 0.5, roofPeakY)
      ..lineTo(cw * 0.92, roofBaseY);
    canvas.drawPath(roofPath, paint);

    final bodyPath = Path()
      ..moveTo(leftWall, roofBaseY)
      ..lineTo(leftWall, baseY)
      ..lineTo(rightWall, baseY)
      ..lineTo(rightWall, roofBaseY);
    canvas.drawPath(bodyPath, paint);

    final towerPath = Path()
      ..moveTo(cw * 0.46, roofBaseY)
      ..lineTo(cw * 0.46, roofPeakY + ch * 0.04)
      ..lineTo(cw * 0.54, roofPeakY + ch * 0.04)
      ..lineTo(cw * 0.54, roofBaseY);
    canvas.drawPath(towerPath, paint);

    canvas.drawCircle(
      Offset(cw * 0.5, roofPeakY + ch * 0.04 + cw * 0.025),
      cw * 0.022,
      paint,
    );

    final pillarPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final pillarCount = 4;
    final pillarSpacing = (rightWall - leftWall) / pillarCount;
    for (int i = 1; i < pillarCount; i++) {
      final x = leftWall + pillarSpacing * i;
      canvas.drawLine(Offset(x, roofBaseY), Offset(x, baseY), pillarPaint);
    }

    final windowPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final windowW = (pillarSpacing * 0.5).clamp(4.0, 20.0);
    final windowH = windowW * 1.3;
    for (int i = 0; i < pillarCount; i++) {
      final cx = leftWall + pillarSpacing * i + pillarSpacing / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, roofBaseY + (baseY - roofBaseY) * 0.35),
            width: windowW,
            height: windowH,
          ),
          const Radius.circular(2),
        ),
        windowPaint,
      );
      canvas.drawLine(
        Offset(cx, roofBaseY + (baseY - roofBaseY) * 0.35 - windowH / 2),
        Offset(cx, roofBaseY + (baseY - roofBaseY) * 0.35 + windowH / 2),
        windowPaint,
      );
      canvas.drawLine(
        Offset(cx - windowW / 2, roofBaseY + (baseY - roofBaseY) * 0.35),
        Offset(cx + windowW / 2, roofBaseY + (baseY - roofBaseY) * 0.35),
        windowPaint,
      );
    }

    final doorPath = Path()
      ..moveTo(cw * 0.5 - cw * 0.05, baseY)
      ..lineTo(cw * 0.5 - cw * 0.05, roofBaseY + (baseY - roofBaseY) * 0.72)
      ..arcToPoint(
        Offset(cw * 0.5 + cw * 0.05, roofBaseY + (baseY - roofBaseY) * 0.72),
        radius: Radius.circular(cw * 0.05),
      )
      ..lineTo(cw * 0.5 + cw * 0.05, baseY);
    canvas.drawPath(doorPath, paint);

    canvas.drawLine(
      Offset(cw * 0.5, baseY),
      Offset(cw * 0.5, roofBaseY + (baseY - roofBaseY) * 0.72),
      paint..strokeWidth = 1.0,
    );
    paint.strokeWidth = 1.5;

    final groundPath = Path()
      ..moveTo(0, baseY)
      ..lineTo(cw, baseY);
    canvas.drawPath(groundPath, paint);

    canvas.drawLine(
      Offset(cw * 0.04, baseY + ch * 0.02),
      Offset(cw * 0.12, baseY + ch * 0.02),
      paint,
    );
    canvas.drawLine(
      Offset(cw * 0.88, baseY + ch * 0.02),
      Offset(cw * 0.96, baseY + ch * 0.02),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
