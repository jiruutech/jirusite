import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Spirit-level budget health widget.
///
/// Shows a horizontal "level tube" with an animated bubble that
/// repositions based on how much of the budget has been spent:
///   - Centered      → on budget  (Level Green)
///   - Drifted right → trending over (Ochre Dust)
///   - At right edge → over budget (Rebar Rust)
class LevelWidget extends StatefulWidget {
  const LevelWidget({
    super.key,
    required this.spent,
    this.budget,
    this.showLabel = true,
    this.height = 48,
  });

  /// Total budget. If null the widget shows an indeterminate state.
  final double? budget;

  /// Amount already spent.
  final double spent;

  /// Whether to show the text label below the tube.
  final bool showLabel;

  /// Total widget height (tube + optional label).
  final double height;

  @override
  State<LevelWidget> createState() => _LevelWidgetState();
}

class _LevelWidgetState extends State<LevelWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _bubblePos; // 0.0 = leftmost, 1.0 = rightmost

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Initialize with a constant so _buildAnimation can safely read .value
    _bubblePos = const AlwaysStoppedAnimation<double>(0.5);
    _bubblePos = _buildAnimation(_targetPosition);
    _controller.forward();
  }

  @override
  void didUpdateWidget(LevelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spent != widget.spent ||
        oldWidget.budget != widget.budget) {
      _bubblePos = _buildAnimation(_targetPosition);
      _controller
        ..reset()
        ..forward();
    }
  }

  /// Maps budget health to a 0..1 position value.
  /// 0.5 = perfectly centred (on budget).
  double get _targetPosition {
    final b = widget.budget;
    if (b == null || b <= 0) return 0.5;
    // normalised variance: 0 → fully left, 0.5 → center, 1 → fully right
    final ratio = widget.spent / b; // 0..2+
    return ((ratio - 0.5) * 2).clamp(-1.0, 1.0) * 0.5 + 0.5;
  }

  Color get _bubbleColor {
    final t = _targetPosition;
    if (t < 0.6) return AppColors.levelGreen;
    if (t < 0.85) return AppColors.ochreDust;
    return AppColors.rebarRust;
  }

  String get _semanticLabel {
    final t = _targetPosition;
    if (t < 0.6) return 'Budget status: on track';
    if (t < 0.85) return 'Budget status: warning';
    return 'Budget status: over budget';
  }

  Animation<double> _buildAnimation(double target) => Tween<double>(
        begin: _bubblePos.value,
        end: target,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: _semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            child: disableAnimations
                ? CustomPaint(
                    painter: _LevelPainter(
                      position: _targetPosition,
                      bubbleColor: _bubbleColor,
                    ),
                    child: const SizedBox.expand(),
                  )
                : AnimatedBuilder(
                    animation: _bubblePos,
                    builder: (_, __) => CustomPaint(
                      painter: _LevelPainter(
                        position: _bubblePos.value,
                        bubbleColor: _bubbleColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 4),
            Text(
              _semanticLabel.replaceFirst('Budget status: ', ''),
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  const _LevelPainter({
    required this.position,
    required this.bubbleColor,
  });

  /// 0.0 = full left, 1.0 = full right, 0.5 = center.
  final double position;
  final Color bubbleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    const tubeHeight = 14.0;
    const bubbleRadius = 8.0;
    const endCapWidth = 10.0;
    const tickWidth = 1.5;
    const borderWidth = 1.5;
    const tubeRadius = Radius.circular(7);

    final tubePaint = Paint()
      ..color = AppColors.concrete.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.blueprintInk.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final bubblePaint = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill;

    final tickPaint = Paint()
      ..color = AppColors.blueprintInk.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tickWidth;

    final labelPaint = TextPainter(textDirection: TextDirection.ltr);

    final tubeTop = (h - tubeHeight) / 2;
    final tubeRect = Rect.fromLTWH(
        endCapWidth, tubeTop, w - endCapWidth * 2, tubeHeight);
    final tubeRRect = RRect.fromRectAndRadius(tubeRect, tubeRadius);

    // 1. Tube background
    canvas.drawRRect(tubeRRect, tubePaint);

    // 2. Center tick marks
    final centerX = w / 2;
    canvas.drawLine(
      Offset(centerX - 1.5, tubeTop + 3),
      Offset(centerX - 1.5, tubeTop + tubeHeight - 3),
      tickPaint,
    );
    canvas.drawLine(
      Offset(centerX + 1.5, tubeTop + 3),
      Offset(centerX + 1.5, tubeTop + tubeHeight - 3),
      tickPaint,
    );

    // 3. Tube border
    canvas.drawRRect(tubeRRect, borderPaint);

    // 4. Bubble position
    final bubbleRange = tubeRect.width - bubbleRadius * 2 - 4;
    final bubbleX =
        tubeRect.left + bubbleRadius + 2 + bubbleRange * position.clamp(0.0, 1.0);
    final bubbleCenter = Offset(bubbleX, h / 2);

    // Shadow under bubble
    canvas.drawCircle(
      bubbleCenter + const Offset(0.5, 0.5),
      bubbleRadius - 1,
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    // Bubble fill
    canvas.drawCircle(bubbleCenter, bubbleRadius - 1, bubblePaint);
    // Bubble border
    canvas.drawCircle(
      bubbleCenter,
      bubbleRadius - 1,
      Paint()
        ..color = bubbleColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 5. "L" end cap (left)
    labelPaint
      ..text = TextSpan(
        text: 'L',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.blueprintInk.withValues(alpha: 0.6),
        ),
      )
      ..layout();
    labelPaint.paint(
        canvas, Offset(1, h / 2 - labelPaint.height / 2));

    // 6. "R" end cap (right)
    labelPaint
      ..text = TextSpan(
        text: 'R',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.blueprintInk.withValues(alpha: 0.6),
        ),
      )
      ..layout();
    labelPaint.paint(
        canvas,
        Offset(w - endCapWidth + 1, h / 2 - labelPaint.height / 2));
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.position != position || old.bubbleColor != bubbleColor;
}
