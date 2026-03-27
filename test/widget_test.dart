import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imposter_game/main.dart';

void main() {
  testWidgets('shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ImpostorApp()));
    await tester.pumpAndSettle();

    expect(find.text('IMPOSTOR'), findsOneWidget);
    expect(find.text('Juego Rápido'), findsOneWidget);
  });
}
