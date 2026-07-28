/// Formats an amount using the Indian Cr/L/K abbreviation scheme
/// (1 Cr = 1,00,00,000; 1 L = 1,00,000; 1 K = 1,000).
///
/// This one function replaces ~8 near-identical copy-pasted
/// `_formatAmount`/`_formatCurrency` methods that had drifted into three
/// slightly different variants (₹ prefix or not, a space before the unit
/// or not, differing null fallbacks). The parameters below reproduce each
/// of those exact variants so every call site keeps its existing output.
String formatIndianAmount(
  dynamic amount, {
  String prefix = '',
  bool spaceBeforeUnit = false,
  String nullFallback = '0.00',
  int baseDecimals = 2,
}) {
  if (amount == null) return '$prefix$nullFallback';
  final value = amount is String
      ? (double.tryParse(amount) ?? 0)
      : (amount as num).toDouble();
  final sep = spaceBeforeUnit ? ' ' : '';

  if (value >= 10000000) {
    return '$prefix${(value / 10000000).toStringAsFixed(2)}${sep}Cr';
  } else if (value >= 100000) {
    return '$prefix${(value / 100000).toStringAsFixed(2)}${sep}L';
  } else if (value >= 1000) {
    return '$prefix${(value / 1000).toStringAsFixed(2)}${sep}K';
  }
  return '$prefix${value.toStringAsFixed(baseDecimals)}';
}
