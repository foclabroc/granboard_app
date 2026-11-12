import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/ui/share_sheet.dart';
import 'package:granboard_proto/ui/theme.dart';

void main() {
  testWidgets('Partager l\'appli : QR code sans débordement', (tester) async {
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () => showShareSheet(c),
                    child: const Text('go'))))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('share-qr')), findsOneWidget);
    expect(find.text('PARTAGER FOCLABOARD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
