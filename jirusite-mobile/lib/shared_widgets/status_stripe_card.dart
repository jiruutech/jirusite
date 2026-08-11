import 'package:flutter/material.dart';
import '../app/theme.dart';

/// A Card with a coloured 3px left border stripe.
///
/// The stripe fills the full height of the card's content.
/// Used throughout the app to signal budget health / expense type at a glance.
class StatusStripeCard extends StatelessWidget {
  const StatusStripeCard({
    super.key,
    required this.stripeColor,
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.elevation = 1,
  });

  final Color stripeColor;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.blueprintInk.withValues(alpha: 0.07),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: stripeColor.withValues(alpha: 0.08),
            highlightColor: stripeColor.withValues(alpha: 0.04),
            // IntrinsicHeight lets the stripe Container match the child's
            // natural height without needing a finite height from above.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 3px coloured left stripe — fills child height via IntrinsicHeight
                  SizedBox(
                    width: 3,
                    child: ColoredBox(color: stripeColor),
                  ),
                  // Main content
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
