import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';

void main() {
  test('Track armazena id e nome obrigatórios', () {
    const track = Track(id: '1', name: 'Interlagos');

    expect(track.id, equals('1'));
    expect(track.name, equals('Interlagos'));
  });

  test('Track tem lastSession nulo por padrão', () {
    const track = Track(id: '1', name: 'Interlagos');

    expect(track.lastSession, isNull);
  });

  test('Track armazena lastSession quando fornecido', () {
    final date = DateTime(2026, 4, 10);
    final track = Track(id: '2', name: 'Granja Viana', lastSession: date);

    expect(track.lastSession, equals(date));
  });

  test('Track com id diferente são pistas distintas', () {
    const t1 = Track(id: 'a', name: 'Pista A');
    const t2 = Track(id: 'b', name: 'Pista A');

    expect(t1.id, isNot(equals(t2.id)));
  });

  test('Track aceita nome com caracteres especiais e acentos', () {
    const track = Track(id: '3', name: 'Kartódromo São Paulo');

    expect(track.name, equals('Kartódromo São Paulo'));
  });
}
