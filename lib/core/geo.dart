import 'dart:math';

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  static const double _earthRadiusM = 6371000;

  double distanceTo(GeoPoint other) {
    final dLat = _rad(other.lat - lat);
    final dLng = _rad(other.lng - lng);
    final a = pow(sin(dLat / 2), 2) + cos(_rad(lat)) * cos(_rad(other.lat)) * pow(sin(dLng / 2), 2);
    return 2 * _earthRadiusM * asin(min(1, sqrt(a)));
  }

  double bearingTo(GeoPoint other) {
    final y = sin(_rad(other.lng - lng)) * cos(_rad(other.lat));
    final x = cos(_rad(lat)) * sin(_rad(other.lat)) - sin(_rad(lat)) * cos(_rad(other.lat)) * cos(_rad(other.lng - lng));
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  /// Point displaced by [eastM]/[northM] metres (small-distance approximation).
  GeoPoint offset(double eastM, double northM) => GeoPoint(
        lat + (northM / _earthRadiusM) * 180 / pi,
        lng + (eastM / (_earthRadiusM * cos(_rad(lat)))) * 180 / pi,
      );

  Map<String, Object?> toJson() => {'lat': _round(lat), 'lng': _round(lng)};

  static GeoPoint? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'], lng = json['lng'];
    if (lat is! num || lng is! num) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return GeoPoint(lat.toDouble(), lng.toDouble());
  }

  static double _round(double v) => (v * 1e5).roundToDouble() / 1e5;

  @override
  String toString() => '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
}

double _rad(double deg) => deg * pi / 180;

String compassPoint(double bearing) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return points[((bearing + 22.5) % 360 ~/ 45)];
}

String formatDistance(double metres) =>
    metres < 1000 ? '${metres.round()} m' : '${(metres / 1000).toStringAsFixed(1)} km';

/// True if segment [a]→[b] passes within [radiusM] of [center].
/// Uses a local equirectangular projection; accurate for city-scale distances.
bool segmentIntersectsCircle(GeoPoint a, GeoPoint b, GeoPoint center, double radiusM) {
  final k = cos(_rad(center.lat));
  (double, double) project(GeoPoint p) =>
      (_rad(p.lng - center.lng) * k * GeoPoint._earthRadiusM, _rad(p.lat - center.lat) * GeoPoint._earthRadiusM);
  final (ax, ay) = project(a);
  final (bx, by) = project(b);
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return sqrt(cx * cx + cy * cy) <= radiusM;
}

const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Geohash of [p]. Precision 5 is a ~5 km cell: coarse enough to share with relays.
String geohash(GeoPoint p, {int precision = 5}) {
  var latLo = -90.0, latHi = 90.0, lngLo = -180.0, lngHi = 180.0;
  final out = StringBuffer();
  var bit = 0, ch = 0, even = true;
  while (out.length < precision) {
    if (even) {
      final mid = (lngLo + lngHi) / 2;
      if (p.lng >= mid) {
        ch = (ch << 1) | 1;
        lngLo = mid;
      } else {
        ch <<= 1;
        lngHi = mid;
      }
    } else {
      final mid = (latLo + latHi) / 2;
      if (p.lat >= mid) {
        ch = (ch << 1) | 1;
        latLo = mid;
      } else {
        ch <<= 1;
        latHi = mid;
      }
    }
    even = !even;
    if (++bit == 5) {
      out.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}

/// Centre of a geohash cell, or null if malformed.
GeoPoint? geohashCenter(String hash) {
  var latLo = -90.0, latHi = 90.0, lngLo = -180.0, lngHi = 180.0;
  var even = true;
  for (final c in hash.split('')) {
    final idx = _base32.indexOf(c);
    if (idx < 0) return null;
    for (var mask = 16; mask > 0; mask >>= 1) {
      final on = idx & mask != 0;
      if (even) {
        final mid = (lngLo + lngHi) / 2;
        if (on) {
          lngLo = mid;
        } else {
          lngHi = mid;
        }
      } else {
        final mid = (latLo + latHi) / 2;
        if (on) {
          latLo = mid;
        } else {
          latHi = mid;
        }
      }
      even = !even;
    }
  }
  return GeoPoint((latLo + latHi) / 2, (lngLo + lngHi) / 2);
}
