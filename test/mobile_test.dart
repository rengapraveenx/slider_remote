import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slider_remote/mobile/mobile_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'dev.flutter.pigeon.wakelock_plus.WakelockPlusApi',
  );

  setUp(() {
    // Mock WakelockPlus platform channel if strictly needed,
    // but usually plugins often fallback or can be mocked via setMockMethodCallHandler
    // For WakelockPlus, it might use Pigeon.
    // Let's see if we hit missing plugin exception.

    // Attempt to mock the channel just in case, though the channel name might vary by version.
    // Inspecting wakelock_plus source would reveal it uses 'dev.flutter.pigeon.wakelock_plus.WakelockPlusApi' or strictly messages.
    // However, simplest is to check if it crashes.

    // Mock generic platform channels that might be called
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('MobileApp shows connect screen initially', (
    WidgetTester tester,
  ) async {
    // We expect WakelockPlus.enable() to be called.

    await tester.pumpWidget(const MobileApp());
    await tester.pumpAndSettle();

    // expect(find.text('Slider Remote Client'), findsOneWidget); // Title is not rendered text
    expect(find.text('Slider Remote'), findsOneWidget);
    expect(find.text('Enter Host IP or Scan QR'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
