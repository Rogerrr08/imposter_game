/// Normalizes text for flexible matching: strips diacritics, lowercases,
/// removes special characters, and singularizes tokens.
String normalizeText(String value) {
  final normalized = _stripDiacritics(value.toLowerCase().trim())
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final tokens = normalized
      .split(' ')
      .where((token) => token.isNotEmpty)
      .map(_singularizeToken)
      .toList();

  return tokens.join(' ');
}

String _singularizeToken(String token) {
  if (token.length > 4 && token.endsWith('es')) {
    return token.substring(0, token.length - 2);
  }
  if (token.length > 3 && token.endsWith('s')) {
    return token.substring(0, token.length - 1);
  }
  return token;
}

String _stripDiacritics(String value) {
  const replacements = <String, String>{
    '\u00E1': 'a', '\u00E0': 'a', '\u00E2': 'a', '\u00E4': 'a', '\u00E3': 'a',
    '\u00E9': 'e', '\u00E8': 'e', '\u00EA': 'e', '\u00EB': 'e',
    '\u00ED': 'i', '\u00EC': 'i', '\u00EE': 'i', '\u00EF': 'i',
    '\u00F3': 'o', '\u00F2': 'o', '\u00F4': 'o', '\u00F6': 'o', '\u00F5': 'o',
    '\u00FA': 'u', '\u00F9': 'u', '\u00FB': 'u', '\u00FC': 'u',
    '\u00F1': 'n',
  };

  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}
