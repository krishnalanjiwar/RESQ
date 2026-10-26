import 'package:flutter/services.dart';

/// High-priority phone alerts (sound + vibration) via the native 'resq/alerts'
/// channel. Without notification permission Android drops them silently; the
/// in-app screens still show everything.
class AlertService {
  static const MethodChannel _channel = MethodChannel('resq/alerts');

  Future<bool> notify(int id, String title, String body) => _call('notify', {'id': id, 'title': title, 'body': body});

  /// Alarm that keeps ringing until [stopRing]. With [tapStops] tapping the
  /// notification also silences it; otherwise only an in-app action does.
  Future<bool> ring(int id, String title, String body, {bool tapStops = true}) =>
      _call('ring', {'id': id, 'title': title, 'body': body, 'tapStops': tapStops});

  Future<bool> stopRing(int id) => _call('stopRing', {'id': id});

  Future<bool> _call(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on Object {
      return false;
    }
  }
}
