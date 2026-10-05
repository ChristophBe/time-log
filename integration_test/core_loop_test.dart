import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_log/src/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SPEC §12's integration suite: the core loop on a real database, on a real
/// device.
///
/// **This has never been run.** There is no Xcode, no Android SDK and no
/// desktop toolchain on the machine it was written on, so it is analysed but
/// unexecuted — which is exactly the thing an integration test exists to catch,
/// and worth knowing before trusting it. Run it with:
///
///     flutter test integration_test -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('start, switch, and the running entry survives a rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TimeLogApp()));
    await tester.pumpAndSettle();

    // Start something.
    await tester.enterText(find.byKey(const Key('start-field')), 'Writing');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-button')));
    await tester.pumpAndSettle();
    expect(find.text('Writing'), findsWidgets);

    // Switch to something else: SPEC §4.4 says the handover leaves no gap.
    await tester.enterText(find.byKey(const Key('start-field')), 'Email');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('stopped Writing'), findsOneWidget);

    // History has both of them.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Writing'), findsOneWidget);

    // And the running one is still running after a full rebuild, because a
    // running entry is nothing but a stored startUtc (SPEC §9.1).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const ProviderScope(child: TimeLogApp()));
    await tester.pumpAndSettle();
    expect(find.textContaining('since'), findsOneWidget);
  });
}
