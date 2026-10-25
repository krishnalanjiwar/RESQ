import 'package:flutter/services.dart';

/// High-priority phone alerts (sound + vibration) via the native 'resq/alerts'
/// channel. Without notification permission Android drops them silently; the
/// in-app screens still show everything.
class AlertService {
  static const MethodChannel _channel = MethodChannel('resq/alerts');

  Future<bool> notify(int id, String title, String body) async {
    try {
      return await _channel.invokeMethod<bool>('notify', {'id': id, 'title': title, 'body': body}) ?? false;
    } on Object {
      return false;
    }
  }
}
