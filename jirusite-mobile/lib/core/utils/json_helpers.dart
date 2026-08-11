/// Safe helpers for parsing API JSON responses where PostgreSQL decimal/numeric
/// columns are serialised as strings (e.g. "5000000.00" instead of 5000000.0).
library;

double? parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double parseDoubleOrZero(dynamic v) => parseDouble(v) ?? 0.0;

int? parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

int parseIntOrZero(dynamic v) => parseInt(v) ?? 0;
