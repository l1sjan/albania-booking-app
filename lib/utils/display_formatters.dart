final _thousandsPattern = RegExp(r'(\d)(?=(\d{3})+(?!\d))');

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatCurrency(double value, String currency) {
  final number = formatNumber(value);
  return switch (currency.toUpperCase()) {
    'ALL' => '$number Lek',
    'USD' => '\$$number',
    'EUR' => '$number EUR',
    _ => '$number ${currency.toUpperCase()}',
  };
}

String formatNumber(double value) {
  final raw = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  final parts = raw.split('.');
  final whole = parts.first.replaceAllMapped(
    _thousandsPattern,
    (match) => '${match[1]},',
  );
  return parts.length == 1 ? whole : '$whole.${parts[1]}';
}

String formatDate(DateTime value) {
  return '${_monthNames[value.month - 1]} ${value.day}, ${value.year}';
}

String formatMonthYear(DateTime value) {
  return '${_monthNames[value.month - 1]} ${value.year}';
}

String formatDateRange(DateTime start, DateTime end) {
  return '${formatDate(start)} - ${formatDate(end)}';
}

String formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
