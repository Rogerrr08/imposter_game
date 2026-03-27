import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:imposter_game/main.dart';

void main() {
  testWidgets('shows the home screen', (WidgetTester tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Imposter Game',
      packageName: 'com.impostergame.imposter_game',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );

    await tester.pumpWidget(const ProviderScope(child: ImpostorApp()));
    await tester.pumpAndSettle();

    expect(find.text('IMPOSTOR'), findsOneWidget);
    expect(find.text('Juego Rápido'), findsOneWidget);
    expect(find.text('v1.0.0 (1)'), findsOneWidget);
  });
}
