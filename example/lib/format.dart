String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const List<String> units = <String>['KB', 'MB', 'GB'];
  double value = bytes / 1024;
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

String formatDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
