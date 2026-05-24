import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/services/nmea_parser.dart';

/// Gera uma sentença NMEA válida com checksum calculado automaticamente.
String _sentence(String data) {
  int cs = data.codeUnits.fold(0, (acc, c) => acc ^ c);
  return '\$$data*${cs.toRadixString(16).toUpperCase().padLeft(2, '0')}';
}

void main() {
  group('NmeaParser.validateChecksum', () {
    test('retorna true para sentença com checksum correto', () {
      final s = _sentence('GPRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A');
      expect(NmeaParser.validateChecksum(s), isTrue);
    });

    test('retorna false para checksum incorreto', () {
      final s = _sentence('GPRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A');
      final tampered = s.replaceAll(RegExp(r'\*[0-9A-F]+$'), '*FF');
      expect(NmeaParser.validateChecksum(tampered), isFalse);
    });

    test('retorna false quando não há *', () {
      expect(NmeaParser.validateChecksum(r'$GPRMC,143756.00,A'), isFalse);
    });

    test('retorna false para string vazia', () {
      expect(NmeaParser.validateChecksum(''), isFalse);
    });
  });

  group('NmeaParser.parseLatitude', () {
    test('latitude norte retorna positivo', () {
      final lat = NmeaParser.parseLatitude('2300.00000', 'N');
      expect(lat, closeTo(23.0, 1e-6));
    });

    test('latitude sul retorna negativo', () {
      final lat = NmeaParser.parseLatitude('2300.00000', 'S');
      expect(lat, closeTo(-23.0, 1e-6));
    });

    test('minutos convertidos corretamente (30min = 0.5 grau)', () {
      final lat = NmeaParser.parseLatitude('2330.00000', 'N');
      expect(lat, closeTo(23.5, 1e-6));
    });

    test('retorna null para string curta demais', () {
      expect(NmeaParser.parseLatitude('23', 'N'), isNull);
    });
  });

  group('NmeaParser.parseLongitude', () {
    test('longitude oeste retorna negativo', () {
      final lon = NmeaParser.parseLongitude('04600.00000', 'W');
      expect(lon, closeTo(-46.0, 1e-6));
    });

    test('longitude leste retorna positivo', () {
      final lon = NmeaParser.parseLongitude('04600.00000', 'E');
      expect(lon, closeTo(46.0, 1e-6));
    });

    test('retorna null para string curta demais', () {
      expect(NmeaParser.parseLongitude('046', 'W'), isNull);
    });
  });

  group('NmeaParser.parseDateTime', () {
    test('converte hora e data NMEA para DateTime UTC', () {
      final dt = NmeaParser.parseDateTime('143756.00', '010526');
      expect(dt, equals(DateTime.utc(2026, 5, 1, 14, 37, 56, 0)));
    });

    test('retorna null para timeStr curta', () {
      expect(NmeaParser.parseDateTime('14', '010526'), isNull);
    });

    test('retorna null para dateStr curta', () {
      expect(NmeaParser.parseDateTime('143756.00', '01'), isNull);
    });

    test('converte milissegundos corretamente', () {
      final dt = NmeaParser.parseDateTime('143756.50', '010526');
      expect(dt?.millisecond, equals(500));
    });
  });

  group('NmeaParser.parseLine', () {
    late NmeaParser parser;

    setUp(() => parser = NmeaParser());

    test('retorna Position para GPRMC válido e ativo', () {
      final line = _sentence(
          'GPRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A');
      final pos = parser.parseLine(line);

      expect(pos, isNotNull);
      expect(pos!.latitude, closeTo(-23.0, 1e-4));
      expect(pos.longitude, closeTo(-46.6315, 1e-3));
      expect(pos.speed, closeTo(14.52 * 0.514444, 0.01));
      expect(pos.heading, closeTo(90.0, 1e-6));
      expect(pos.timestamp, equals(DateTime.utc(2026, 5, 1, 14, 37, 56)));
    });

    test('retorna null para GPRMC com status V (void — sem fix)', () {
      final line = _sentence(
          'GPRMC,143756.00,V,2300.00000,S,04637.89000,W,0.00,0.00,010526,,,N');
      expect(parser.parseLine(line), isNull);
    });

    test('retorna null para checksum incorreto', () {
      final line = _sentence(
              'GPRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A')
          .replaceAll(RegExp(r'\*[0-9A-F]+$'), '*00');
      expect(parser.parseLine(line), isNull);
    });

    test('retorna null para GPGGA (atualiza altitude, mas não emite Position)', () {
      final line = _sentence(
          'GPGGA,143756.00,2300.00000,S,04637.89000,W,1,08,0.9,500.0,M,0.0,M,,');
      expect(parser.parseLine(line), isNull);
    });

    test('altitude de GPGGA é usada em GPRMC subsequente', () {
      final altLine = _sentence(
          'GPGGA,143756.00,2300.00000,S,04637.89000,W,1,08,0.9,500.0,M,0.0,M,,');
      final posLine = _sentence(
          'GPRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A');
      parser.parseLine(altLine); // alimenta altitude
      final pos = parser.parseLine(posLine);
      expect(pos?.altitude, closeTo(500.0, 1e-6));
    });

    test('retorna null para linha vazia', () {
      expect(parser.parseLine(''), isNull);
    });

    test(r'retorna null para linha sem $', () {
      expect(parser.parseLine('GPRMC,143756.00,A'), isNull);
    });

    test('suporta GNRMC (variante multi-constelação)', () {
      final line = _sentence(
          'GNRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A');
      expect(parser.parseLine(line), isNotNull);
    });
  });

  group('NmeaParser.transformLines', () {
    test('emite Position para cada linha GPRMC válida', () async {
      final parser = NmeaParser();
      final line = _sentence(
          'GPRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A');
      final stream = Stream.fromIterable([line, line]);

      final positions = await parser.transformLines(stream).toList();
      expect(positions.length, equals(2));
    });

    test('ignora linhas inválidas e emite apenas as válidas', () async {
      final parser = NmeaParser();
      final valid = _sentence(
          'GPRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A');
      final stream = Stream.fromIterable(['lixo', '', valid, 'outra_linha_invalida']);

      final positions = await parser.transformLines(stream).toList();
      expect(positions.length, equals(1));
    });

    test('linhas com espaços/\\r são trimadas corretamente', () async {
      final parser = NmeaParser();
      final line = _sentence(
          'GPRMC,143756.00,A,2300.00000,S,04637.89000,W,14.52,90.00,010526,,,A');
      final stream = Stream.fromIterable(['  $line\r']);

      final positions = await parser.transformLines(stream).toList();
      expect(positions.length, equals(1));
    });
  });
}
