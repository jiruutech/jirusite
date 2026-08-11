import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/utils/currency.dart';

/// A dense, reusable row showing a cost code's budget vs. actual spend.
///
/// Used on the Project Overview tab, and can be embedded inside PO and
/// Schedule screens without duplicating the variance-colour logic.
///
/// Layout (56px tall row):
///   [Cost code name]  [proportional bar]  [spent / budget mono]
///
/// The bar fill colour follows the three-zone palette:
///   < 85%  → Level Green (on track)
///   85–100% → Ochre Dust (warning)
///   > 100%  → Rebar Rust (over budget)
class CostCodeVarianceRow extends StatelessWidget {
  const CostCodeVarianceRow({
    super.key,
    required this.name,
    required this.budgeted,
    required this.spent,
    this.showDivider = true,
  });

  final String name;
  final double budgeted;
  final double spent;

  /// Draw a 0.5px bottom divider (omit on the last row).
  final bool showDivider;

  /// Variance ratio: spent / budgeted. Clamped to 0..1.5 for display.
  double get _ratio => budgeted > 0 ? (spent / budgeted).clamp(0.0, 1.5) : 0.0;

  /// Variance percentage for display, e.g. "+6.2%" or "–4.1%"
  String get _varianceLabel {
    if (budgeted <= 0) return '';
    final pct = ((spent - budgeted) / budgeted * 100);
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  Color get _fillColor {
    if (_ratio < 0.85) return AppColors.levelGreen;
    if (_ratio <= 1.0) return AppColors.ochreDust;
    return AppColors.rebarRust;
  }

  Color get _varianceColor {
    if (_ratio < 0.85) return AppColors.levelGreen;
    if (_ratio <= 1.0) return AppColors.ochreDust;
    return AppColors.rebarRust;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '$name: spent ${formatEtb(spent)} of budget ${formatEtb(budgeted)}, $_varianceLabel',
      child: Container(
        height: 56,
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.concrete,
                    width: 0.5,
                  ),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // ── Cost code name ──────────────────────────────────────────
              SizedBox(
                width: 100,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),

              // ── Proportional bar ────────────────────────────────────────
              Expanded(
                child: _VarianceBar(
                  ratio: _ratio.clamp(0.0, 1.0),
                  fillColor: _fillColor,
                ),
              ),
              const SizedBox(width: 10),

              // ── spent / budgeted + variance % ───────────────────────────
              SizedBox(
                width: 112,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${formatEtbCompact(spent)} / ${formatEtbCompact(budgeted)}',
                      style: AppTextStyles.numeric.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                    ),
                    if (_varianceLabel.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        _varianceLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _varianceColor,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VarianceBar extends StatelessWidget {
  const _VarianceBar({required this.ratio, required this.fillColor});

  final double ratio; // 0.0..1.0 clamped
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, __) {
        return Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.concrete.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
