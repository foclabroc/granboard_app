import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';

void main() {
  test('Erreurs de connexion lisibles, sans le détail de Flutter Blue Plus',
      () {
    expect(
        BoardService.connectError(Exception(
            'FlutterBluePlusException | connect | fbp-code: 1 | Timed out after 15s')),
        'Cible introuvable : allume-la et rapproche-toi');
    expect(BoardService.connectError(Exception('Bluetooth adapter is off')),
        'Bluetooth coupé : active-le puis reconnecte');
    expect(BoardService.connectError(Exception('xyz')),
        'Connexion à la cible impossible');
    expect(BoardService.connectError(Exception('xyz')),
        isNot(contains('Flutter')));
  });
}
