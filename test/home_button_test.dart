import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/ui/widgets.dart';

void main() {
  testWidgets('Bouton « Menu principal » : retour à l\'accueil, absent sur '
      'l\'accueil', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    Widget page(String t, {Future<bool> Function()? confirm}) => Scaffold(
        appBar: AppBar(
            title: Text(t), actions: [HomeButton(confirm: confirm)]));
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: page('A')));
    expect(find.byKey(const ValueKey('home')), findsNothing);
    nav.currentState!.push(MaterialPageRoute(builder: (_) => page('B')));
    await tester.pumpAndSettle();
    var ok = false;
    nav.currentState!.push(MaterialPageRoute(
        builder: (_) => page('C', confirm: () async => ok)));
    await tester.pumpAndSettle();
    // refusé : on reste
    await tester.tap(find.byKey(const ValueKey('home')));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
    ok = true;
    await tester.tap(find.byKey(const ValueKey('home')));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
  });
}
