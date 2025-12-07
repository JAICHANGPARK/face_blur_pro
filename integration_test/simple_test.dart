import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/presentation/home/home_screen.dart';
import 'package:my_app/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    await tester.pumpWidget(const HomeScreen());
    expect(find.text('Face Blur Pro'), findsOneWidget);
  });
}
