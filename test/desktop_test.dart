import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:slider_remote/desktop/desktop_app.dart';
import 'package:slider_remote/desktop/server/server.dart';

class MockSlideServer extends Mock implements SlideServer {}

void main() {
  late MockSlideServer mockServer;

  setUp(() {
    mockServer = MockSlideServer();
    // Default stubs
    when(() => mockServer.getLocalIp()).thenAnswer((_) async => '192.168.1.10');
    when(() => mockServer.start()).thenAnswer((_) async {});
    when(() => mockServer.stop()).thenAnswer((_) async {});
    when(
      () => mockServer.clientCountStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockServer.commandStream,
    ).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('DesktopApp starts and shows server info', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      DesktopApp(
        onToggleTheme: () {},
        isDarkMode: true,
        themeMode: ThemeMode.dark,
        server: mockServer,
      ),
    );

    // Verify loading state or initial state
    await tester.pumpAndSettle();

    verify(() => mockServer.start()).called(1);
    expect(find.text('Server Running'), findsOneWidget);
    expect(find.text('192.168.1.10'), findsOneWidget);
    expect(find.text('Scan to Connect'), findsOneWidget);
  });
}
