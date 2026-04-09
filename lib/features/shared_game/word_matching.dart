import '../../utils/text_normalize.dart';

/// Verifica si el guess del impostor coincide con la palabra secreta.
/// Soporta match exacto (normalizado) y match por apellido para nombres compuestos.
bool matchesSecretWord(String guess, String secretWord) {
  final normalizedGuess = normalizeText(guess);
  final normalizedSecret = normalizeText(secretWord);

  if (normalizedGuess == normalizedSecret) {
    return true;
  }

  if (!_canMatchBySurname(secretWord)) {
    return false;
  }

  final secretTokens = normalizedSecret
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList();

  if (secretTokens.length < 2) {
    return false;
  }

  return normalizedGuess == secretTokens.last;
}

bool _canMatchBySurname(String secretWord) {
  final normalizedSecret = normalizeText(secretWord);

  for (final allowedWord in surnameMatchAllowedWords) {
    if (normalizeText(allowedWord) == normalizedSecret) {
      return true;
    }
  }

  return false;
}

const Set<String> surnameMatchAllowedWords = {
  'Harry Potter',
  'Mickey Mouse',
  'Darth Vader',
  'Taylor Swift',
  'Indiana Jones',
  'Buzz Lightyear',
  'Lionel Messi',
  'LeBron James',
  'Usain Bolt',
  'Michael Jordan',
  'Cristiano Ronaldo',
  'Serena Williams',
  'Rafael Nadal',
  'Tiger Woods',
  'Simone Biles',
  'Kylian Mbappe',
  'Mike Tyson',
  'Lewis Hamilton',
  'Stephen Curry',
  'Zinedine Zidane',
  'Roger Federer',
  'Muhammad Ali',
  'Erling Haaland',
};
