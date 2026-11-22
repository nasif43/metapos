import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metapos/main.dart';
import 'package:metapos/presentation/screens/login/session_login_screen.dart';

void main() {
  testWidgets('MetaPosApp smoke test - mounts and renders SessionLoginScreen on root',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MetaPosApp(),
      ),
    );

    // Initial frame
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify SessionLoginScreen is mounted
    expect(find.byType(SessionLoginScreen), findsOneWidget);
    expect(find.text('পয়েন্ট অব সেল'), findsOneWidget);
  });
}
