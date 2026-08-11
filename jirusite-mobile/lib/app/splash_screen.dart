import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../shared_widgets/level_widget.dart';

/// Animated splash screen.
///
/// Sequence (1.5 s total, respects MediaQuery.disableAnimations):
///   0 ms  – Chalk background appears
/// 150 ms  – Blueprint Ink grid sweeps left→right
/// 350 ms  – "JIRU" + "Cost" wordmark fades in
/// 650 ms  – Level bubble draws in and settles with slight overshoot
/// 1500 ms – onComplete() is called → caller navigates to main app
///
/// If disableAnimations is true, shows the static fallback immediately and
/// calls onComplete after a short delay so consumers can still navigate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  /// Called once the animation sequence finishes.
  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation controller for the grid sweep (reveals grid left→right)
  late final AnimationController _gridCtrl;
  // Animation controller for wordmark fade-in
  late final AnimationController _wordCtrl;
  // Animation controller for level bubble settle (spring overshoot)
  late final AnimationController _bubbleCtrl;

  late final Animation<double> _gridReveal;
  late final Animation<double> _wordOpacity;
  late final Animation<double> _bubbleProgress;

  @override
  void initState() {
    super.initState();

    _gridCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _wordCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _bubbleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _gridReveal = CurvedAnimation(parent: _gridCtrl, curve: Curves.easeIn);
    _wordOpacity = CurvedAnimation(parent: _wordCtrl, curve: Curves.easeIn);
    _bubbleProgress = CurvedAnimation(
      parent: _bubbleCtrl,
      curve: Curves.elasticOut,
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Check disableAnimations after first frame (context available then)
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final disable = MediaQuery.of(context).disableAnimations;
    if (disable) {
      // Static fallback: show for 300 ms then complete
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) widget.onComplete();
      return;
    }

    // 150 ms: grid sweep
    await _gridCtrl.forward();
    // 200 ms: wordmark fade
    await _wordCtrl.forward();
    // 300 ms: bubble settle
    await _bubbleCtrl.forward();
    // hold for a moment
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _gridCtrl.dispose();
    _wordCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chalk,
      body: Stack(
        children: [
          // ── Grid layer ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: _gridReveal,
            builder: (_, __) => CustomPaint(
              painter: _GridPainter(revealProgress: _gridReveal.value),
              child: const SizedBox.expand(),
            ),
          ),

          // ── Wordmark + Level widget ─────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_wordOpacity, _bubbleProgress]),
              builder: (context, __) => Opacity(
                opacity: _wordOpacity.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wordmark: JIRU + Cost
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'JIRU',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: AppColors.blueprintInk,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Cost',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w400,
                            color: AppColors.safetyOrange,
                            letterSpacing: 1,
                            // slight italic for contrast
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Level widget bubble settles to center (0.5)
                    SizedBox(
                      width: 200,
                      child: LevelWidget(
                        // Animate from 0 spent → on-budget (bubble centres)
                        spent: 50 * _bubbleProgress.value,
                        budget: 100,
                        showLabel: false,
                        height: 36,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Tagline
                    const Text(
                      'Construction Cost Tracking',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws thin grid lines on the Chalk background, revealed left→right.
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.revealProgress});

  /// 0.0 = no grid visible, 1.0 = full grid visible
  final double revealProgress;

  @override
  void paint(Canvas canvas, Size size) {
    if (revealProgress <= 0) return;

    final paint = Paint()
      ..color = AppColors.blueprintInk.withValues(alpha: 0.07)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 28.0;
    final revealX = size.width * revealProgress;

    // Clip to reveal region
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, revealX, size.height));

    // Vertical lines
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.revealProgress != revealProgress;
}
