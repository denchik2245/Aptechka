abstract final class GtinParser {
  static String? parse(String rawValue) {
    var value = rawValue.trim();
    if (value.startsWith(']d2')) value = value.substring(3);

    if (RegExp(r'^\d{13}$').hasMatch(value)) {
      return '0$value';
    }
    if (RegExp(r'^\d{14}$').hasMatch(value)) {
      return value;
    }

    final applicationIdentifier = RegExp(r'(?:^|\u001d)01(\d{14})')
        .firstMatch(value);
    if (applicationIdentifier != null) return applicationIdentifier.group(1);

    final compactMatch = RegExp(r'^01(\d{14})').firstMatch(value);
    return compactMatch?.group(1);
  }
}
