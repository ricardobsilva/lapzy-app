import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/race_session_repository.dart';
import '../repositories/track_repository.dart';
import 'telemetry_service.dart';

class ExportService {
  /// Exporta os dados de uma sessão específica (ou todas se [sessionId] for null).
  /// Grava um JSON indentado no diretório externo do app e retorna o caminho.
  static Future<String> export({String? sessionId}) async {
    final allSessions = RaceSessionRepository().sessions;
    final allTracks = TrackRepository().tracks;

    final sessions = sessionId != null
        ? allSessions.where((s) => s.id == sessionId).toList()
        : allSessions;

    final trackIds = sessions.map((s) => s.trackId).toSet();
    final tracks = allTracks.where((t) => trackIds.contains(t.id)).toList();

    final prefs = await SharedPreferences.getInstance();

    final allTelemSessions = await TelemetryService.instance.querySessions();
    final telemSessions = sessionId != null
        ? allTelemSessions.where((s) => s['id'] == sessionId).toList()
        : allTelemSessions;

    final telemPositions = <String, dynamic>{};
    final telemEvents = <String, dynamic>{};
    for (final s in telemSessions) {
      final sid = s['id'] as String;
      telemPositions[sid] = await TelemetryService.instance.queryPositions(sid);
      telemEvents[sid] = await TelemetryService.instance.queryEvents(sid);
    }

    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': '1.0.0+13',
      'session_id': ?sessionId,
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'raw_prefs': {
        'lapzy_sessions_v1': prefs.getString('lapzy_sessions_v1'),
        'lapzy_tracks_v1': prefs.getString('lapzy_tracks_v1'),
      },
      'telemetry': {
        'sessions': telemSessions,
        'positions': telemPositions,
        'events': telemEvents,
      },
    };

    final dir = await getExternalStorageDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '-');
    final suffix = sessionId != null ? '_${sessionId.substring(0, 8)}' : '_all';
    final file = File('${dir!.path}/lapzy_export${suffix}_$ts.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    debugPrint('[LAPZY/EXPORT] Arquivo gerado: ${file.path}');
    return file.path;
  }
}
