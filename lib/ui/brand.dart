import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// RES-Q brand system: colours, the logo mark and the wordmark.
///
/// The mark is a location pin with a coral beacon (the SOS signal) broadcasting
/// radio arcs: "my location, shared with nearby phones". Geometry is defined on
/// the 108-unit Android adaptive-icon grid and shared with the launcher icon.
abstract final class Brand {
  static const String name = 'RES-Q';
  static const String tagline = 'Help travels phone to phone.';

  static const Color blue = Color(0xFF1A73E8);
  static const Color blueDeep = Color(0xFF174EA6);
  static const Color beacon = Color(0xFFFF6B5E);
  static const Color signalRed = Color(0xFFD93025);
  static const Color ink = Color(0xFF0B1B33);

  // Google-style four-colour accents, used on white.
  static const Color gBlue = Color(0xFF1A73E8);
  static const Color gRed = Color(0xFFD93025);
  static const Color gYellow = Color(0xFFF9AB00);
  static const Color gGreen = Color(0xFF1E8E3E);
  static const List<Color> rainbow = [gBlue, gRed, gYellow, gGreen];

  /// Beacon pin: a location pin with a coral beacon, broadcasting radio arcs
  /// (outer arcs tinted so the signal fades outward). Identical geometry to
  /// res/drawable/ic_launcher_foreground.xml and scripts/brand/render_icons.py.
  static const String _glyph =
      '<path d="M75.28 30.37A27 27 0 0 1 75.28 63.63M32.72 30.37A27 27 0 0 0 32.72 63.63" '
      'fill="none" stroke="#B4CDF5" stroke-width="5" stroke-linecap="round"/>'
      '<path d="M69.37 34.99A19.5 19.5 0 0 1 69.37 59.01M38.63 34.99A19.5 19.5 0 0 0 38.63 59.01" '
      'fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>'
      '<path d="M41.01 54.5L54 77L66.99 54.5A15 15 0 1 0 41.01 54.5Z" fill="#FFFFFF"/>'
      '<circle cx="54" cy="47" r="6.5" fill="#FF6B5E"/>';

  /// Full app icon: gradient tile with the glyph scaled to fill it.
  static const String markSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">'
      '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0" stop-color="#1A73E8"/><stop offset="1" stop-color="#174EA6"/></linearGradient></defs>'
      '<rect width="108" height="108" rx="30" fill="url(#g)"/>'
      '<g transform="translate(54 55.68) scale(1.12) translate(-54 -54)">$_glyph</g></svg>';
}

/// The RES-Q logo mark (app icon tile).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        Brand.markSvg,
        width: size,
        height: size,
        semanticsLabel: 'RES-Q logo',
      );
}

/// "RES-Q" wordmark: heavy Inter, red hyphen, blue Q. With [rainbow], each
/// letter takes one of the four brand accents.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 28, this.onDark = false, this.rainbow = false});

  final double fontSize;
  final bool onDark;
  final bool rainbow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.02 * fontSize,
      height: 1.0,
      color: onDark ? Colors.white : cs.onSurface,
    );
    return Semantics(
      label: Brand.name,
      excludeSemantics: true,
      child: Text.rich(TextSpan(style: base, children: rainbow
          ? const [
              TextSpan(text: 'R', style: TextStyle(color: Brand.gBlue)),
              TextSpan(text: 'E', style: TextStyle(color: Brand.gRed)),
              TextSpan(text: 'S', style: TextStyle(color: Brand.gYellow)),
              TextSpan(text: '-', style: TextStyle(color: Color(0xFF9AA0A6))),
              TextSpan(text: 'Q', style: TextStyle(color: Brand.gGreen)),
            ]
          : [
        const TextSpan(text: 'RES'),
        TextSpan(text: '-', style: TextStyle(color: onDark ? Brand.beacon : Brand.signalRed)),
        TextSpan(text: 'Q', style: TextStyle(color: onDark ? Colors.white : Brand.blue)),
            ])),
    );
  }
}

/// Logo mark + wordmark lockup.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 36, this.onDark = false});

  final double markSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        BrandMark(size: markSize),
        SizedBox(width: markSize * 0.3),
        Wordmark(fontSize: markSize * 0.62, onDark: onDark),
      ]);
}

/// Thin four-colour strip: the brand's signature accent line.
class RainbowBar extends StatelessWidget {
  const RainbowBar({super.key, this.height = 4});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Row(children: [for (final c in Brand.rainbow) Expanded(child: ColoredBox(color: c))]),
      );
}
