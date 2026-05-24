import 'package:geolocator/geolocator.dart';

/// Parser de sentenças NMEA 0183.
///
/// Recebe linhas completas (String) e converte para [Position].
/// O bufferização de bytes → linhas é responsabilidade do lado nativo
/// (Kotlin), que emite cada linha via EventChannel.
///
/// Sentenças suportadas:
/// - `$GPRMC` / `$GNRMC` — posição, velocidade, heading, timestamp
/// - `$GPGGA` / `$GNGGA` — altitude e qualidade do fix (complementar)
class NmeaParser {
  double _lastAltitude = 0.0;

  /// Transforma um stream de linhas NMEA em um stream de [Position].
  Stream<Position> transformLines(Stream<String> lines) async* {
    await for (final line in lines) {
      final pos = parseLine(line.trim());
      if (pos != null) yield pos;
    }
  }

  /// Parseia uma linha NMEA completa. Retorna `null` se inválida ou sem fix.
  Position? parseLine(String line) {
    if (line.isEmpty || !line.startsWith('\$')) return null;
    if (!validateChecksum(line)) return null;

    final withoutChecksum =
        line.contains('*') ? line.substring(0, line.lastIndexOf('*')) : line;
    final fields = withoutChecksum.split(',');
    if (fields.isEmpty) return null;

    final type = fields[0].substring(1);

    if (type == 'GPRMC' || type == 'GNRMC') return _parseGprmc(fields);
    if (type == 'GPGGA' || type == 'GNGGA') _updateAltitude(fields);
    return null;
  }

  Position? _parseGprmc(List<String> fields) {
    if (fields.length < 10) return null;
    if (fields[2] != 'A') return null; // A=active, V=void
    if (fields[3].isEmpty || fields[5].isEmpty) return null;

    final lat = parseLatitude(fields[3], fields[4]);
    final lon = parseLongitude(fields[5], fields[6]);
    if (lat == null || lon == null) return null;

    final speedKnots = double.tryParse(fields[7]) ?? 0.0;
    final heading = double.tryParse(fields[8]) ?? 0.0;
    final timestamp = parseDateTime(fields[1], fields[9]);
    if (timestamp == null) return null;

    return Position(
      latitude: lat,
      longitude: lon,
      timestamp: timestamp,
      speed: speedKnots * 0.514444, // knots → m/s
      heading: heading,
      altitude: _lastAltitude,
      accuracy: 5.0,
      altitudeAccuracy: 1.0,
      headingAccuracy: 1.0,
      speedAccuracy: 0.1,
    );
  }

  void _updateAltitude(List<String> fields) {
    // $GPGGA: index 6 = fix quality (0 = no fix), index 9 = altitude
    if (fields.length < 10) return;
    if (fields[6].isEmpty || fields[6] == '0') return;
    final alt = double.tryParse(fields[9]);
    if (alt != null) {
      _lastAltitude = alt;
    }
  }

  /// Converte latitude NMEA (`DDMM.MMMM`, `N`/`S`) para graus decimais.
  static double? parseLatitude(String value, String direction) {
    if (value.length < 4) return null;
    final degrees = double.tryParse(value.substring(0, 2));
    final minutes = double.tryParse(value.substring(2));
    if (degrees == null || minutes == null) return null;
    final decimal = degrees + minutes / 60.0;
    return direction == 'S' ? -decimal : decimal;
  }

  /// Converte longitude NMEA (`DDDMM.MMMM`, `E`/`W`) para graus decimais.
  static double? parseLongitude(String value, String direction) {
    if (value.length < 5) return null;
    final degrees = double.tryParse(value.substring(0, 3));
    final minutes = double.tryParse(value.substring(3));
    if (degrees == null || minutes == null) return null;
    final decimal = degrees + minutes / 60.0;
    return direction == 'W' ? -decimal : decimal;
  }

  /// Converte hora (`HHMMSS.ss`) e data (`DDMMYY`) NMEA para [DateTime] UTC.
  static DateTime? parseDateTime(String timeStr, String dateStr) {
    if (timeStr.length < 6 || dateStr.length < 6) return null;
    final h = int.tryParse(timeStr.substring(0, 2));
    final m = int.tryParse(timeStr.substring(2, 4));
    final s = int.tryParse(timeStr.substring(4, 6));
    final day = int.tryParse(dateStr.substring(0, 2));
    final month = int.tryParse(dateStr.substring(2, 4));
    final year = int.tryParse(dateStr.substring(4, 6));
    if (h == null || m == null || s == null ||
        day == null || month == null || year == null) {
      return null;
    }
    int ms = 0;
    if (timeStr.length > 7 && timeStr[6] == '.') {
      final frac = timeStr.substring(7).padRight(3, '0').substring(0, 3);
      ms = int.tryParse(frac) ?? 0;
    }
    return DateTime.utc(2000 + year, month, day, h, m, s, ms);
  }

  /// Valida o checksum XOR de uma sentença NMEA.
  ///
  /// Checksum = XOR de todos os bytes entre `$` e `*` (exclusive).
  static bool validateChecksum(String sentence) {
    final star = sentence.lastIndexOf('*');
    if (star < 1 || star + 2 >= sentence.length) return false;
    final data = sentence.substring(1, star);
    final expected = int.tryParse(sentence.substring(star + 1, star + 3), radix: 16);
    if (expected == null) return false;
    int calc = 0;
    for (final c in data.codeUnits) {
      calc ^= c;
    }
    return calc == expected;
  }
}
