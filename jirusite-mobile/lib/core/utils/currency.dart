import 'package:intl/intl.dart';

final _etbFormat = NumberFormat('#,##0.##', 'en_US');

/// Format a number as Ethiopian Birr — always explicit ETB suffix.
/// e.g. 125000 → "125,000 ETB"
String formatEtb(num? amount) {
  if (amount == null) return '— ETB';
  return '${_etbFormat.format(amount)} ETB';
}

/// Compact format for charts / summaries: 1,250,000 → "1.25M ETB"
String formatEtbCompact(num? amount) {
  if (amount == null) return '— ETB';
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(2)}M ETB';
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K ETB';
  return '${_etbFormat.format(amount)} ETB';
}

double budgetHealthPercent(double? budget, double? spent) {
  if (budget == null || budget == 0) return 0;
  return ((spent ?? 0) / budget).clamp(0, 2);
}
