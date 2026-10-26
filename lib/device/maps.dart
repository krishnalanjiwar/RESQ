import 'package:flutter/services.dart';

import '../core/geo.dart';

/// Opens coordinates in Google Maps (or any map app / the web) through the
/// native 'resq/alerts' channel. Returns false if nothing could open them.
abstract final class MapLauncher {
  static const MethodChannel _channel = MethodChannel('resq/alerts');

  static Future<bool> open(GeoPoint point, {String label = 'SOS location'}) async {
    try {
      return await _channel.invokeMethod<bool>('openMap', {'lat': point.lat, 'lng': point.lng, 'label': label}) ?? false;
    } on Object {
      return false;
    }
  }
}
