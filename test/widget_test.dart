import 'package:flutter_test/flutter_test.dart';

import 'package:soundscape_access/main.dart';

void main() {
  testWidgets('app shows the single screen with Start button',
      (tester) async {
    await tester.pumpWidget(const SoundscapeApp());
    // Let the splash transition complete to HomeScreen
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Soundscape Access'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Vibrate on sounds'), findsOneWidget);
  });
}
