import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool show;

  const ConfettiOverlay({
    super.key,
    required this.child,
    required this.show,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.show) _controller.repeat();
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.repeat();
    } else if (!widget.show && oldWidget.show) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.show)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  progress: _controller.value,
                  random: _random,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Random random;

  _ConfettiPainter({required this.progress, required this.random});

  @override
  void paint(Canvas canvas, Size size) {
    final paints = [
      Paint()..color = Colors.amber,
      Paint()..color = Colors.blue.shade300,
      Paint()..color = Colors.green.shade300,
      Paint()..color = Colors.pink.shade300,
      Paint()..color = Colors.purple.shade300,
      Paint()..color = Colors.orange.shade300,
    ];

    for (var i = 0; i < 40; i++) {
      final seed = i * 137.508;
      final x = ((seed * 1.3 + progress * 200) % size.width);
      final y = ((seed * 0.7 + progress * 400) % (size.height + 100)) - 50;
      final rotation = (seed + progress * 360) % 360;
      final paint = paints[i % paints.length];

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation * pi / 180);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 6, height: 4),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
