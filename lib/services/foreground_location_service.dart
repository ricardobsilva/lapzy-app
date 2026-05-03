import 'package:flutter/services.dart';

class ForegroundLocationService {
  static const _channel = MethodChannel('lapzy/foreground_service');

  static Future<void> start() => _channel.invokeMethod('start');
  static Future<void> stop() => _channel.invokeMethod('stop');
}
