import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// RESQ's own icon set: original SVGs on a 24 px grid with a consistent 2 px
/// rounded stroke (Material-proportioned, no emoji, no icon font). Colour is
/// applied at render time, so every icon follows the theme.
abstract final class ResqIcons {
  static const String _o = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" '
      'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">';
  static const String _c = '</svg>';

  // ---- Mesh & radio ----
  static const String mesh = '$_o' '<circle cx="12" cy="12" r="2" fill="#000"/><path d="M8.5 8.5a5 5 0 0 0 0 7"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/>'
      '<path d="M5.6 5.6a9 9 0 0 0 0 12.8"/><path d="M18.4 5.6a9 9 0 0 1 0 12.8"/>' '$_c';
  static const String meshOff = '$_o' '<circle cx="12" cy="12" r="2" fill="#000"/><path d="M8.5 8.5a5 5 0 0 0 0 7"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/>'
      '<path d="M3 3l18 18"/>' '$_c';
  static const String bluetooth = '$_o' '<path d="M7 7l10 10-5 4V3l5 4L7 17"/>' '$_c';
  static const String peers = '$_o' '<circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="18" cy="18" r="2.5"/>'
      '<path d="M8.3 11l7.4-3.8M8.3 13l7.4 3.8"/>' '$_c';

  // ---- Status ----
  static const String warning = '$_o' '<path d="M12 3l9.5 17h-19z"/><path d="M12 10v4"/><circle cx="12" cy="17" r="0.6" fill="#000"/>' '$_c';
  static const String info = '$_o' '<circle cx="12" cy="12" r="9"/><path d="M12 11v6"/><circle cx="12" cy="7.5" r="0.6" fill="#000"/>' '$_c';
  static const String check = '$_o' '<path d="M5 12.5l4.5 4.5L19 7.5"/>' '$_c';
  static const String checkCircle = '$_o' '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l3 3 5-6"/>' '$_c';
  static const String close = '$_o' '<path d="M6 6l12 12M18 6L6 18"/>' '$_c';
  static const String clock = '$_o' '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>' '$_c';
  static const String battery = '$_o' '<rect x="3" y="7" width="16" height="10" rx="2"/><path d="M22 11v2"/><path d="M6 10v4M9 10v4"/>' '$_c';
  static const String batteryLow = '$_o' '<rect x="3" y="7" width="16" height="10" rx="2"/><path d="M22 11v2"/><path d="M6 10v4"/>' '$_c';
  static const String location = '$_o' '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>' '$_c';
  static const String locationOff = '$_o' '<path d="M8.2 4.2A7 7 0 0 1 19 9.5c0 2-1 4-2.3 5.8M14.6 18.4C13.3 19.9 12 21 12 21s-7-6.2-7-11.5c0-.9.2-1.8.5-2.6"/><path d="M3 3l18 18"/>' '$_c';

  // ---- People & roles ----
  static const String person = '$_o' '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>' '$_c';
  static const String lifebuoy = '$_o' '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/><path d="M5.6 5.6l3.6 3.6M14.8 14.8l3.6 3.6M18.4 5.6l-3.6 3.6M9.2 14.8l-3.6 3.6"/>' '$_c';
  static const String flask = '$_o' '<path d="M9 3h6M10 3v6l-5.5 9.5A2 2 0 0 0 6.2 21h11.6a2 2 0 0 0 1.7-2.5L14 9V3"/><path d="M7.5 15h9"/>' '$_c';
  static const String group = '$_o' '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14a6.5 6.5 0 0 1 3.5 6"/>' '$_c';

  // ---- Trust & security ----
  static const String shield = '$_o' '<path d="M12 3l8 3v6c0 4.5-3.4 8.2-8 9-4.6-.8-8-4.5-8-9V6z"/>' '$_c';
  static const String shieldCheck = '$_o' '<path d="M12 3l8 3v6c0 4.5-3.4 8.2-8 9-4.6-.8-8-4.5-8-9V6z"/><path d="M8.5 12l2.5 2.5 4.5-5"/>' '$_c';
  static const String shieldAlert = '$_o' '<path d="M12 3l8 3v6c0 4.5-3.4 8.2-8 9-4.6-.8-8-4.5-8-9V6z"/><path d="M12 8v5"/><circle cx="12" cy="16" r="0.6" fill="#000"/>' '$_c';
  static const String lock = '$_o' '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>' '$_c';
  static const String unlock = '$_o' '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 7.5-1.9"/>' '$_c';
  static const String key = '$_o' '<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M17 6l3 3M14.5 8.5l2 2"/>' '$_c';
  static const String fingerprint = '$_o' '<path d="M6.5 7A7 7 0 0 1 19 11.5v1"/><path d="M5 11.5a7 7 0 0 0 .5 2.5"/><path d="M8.5 19A9 9 0 0 1 8 11.5a4 4 0 0 1 8 0v1.5"/>'
      '<path d="M12 11.5V14a8 8 0 0 0 2 5"/><path d="M16 16.5a10 10 0 0 0 .8 2.5"/>' '$_c';

  // ---- Needs & hazards ----
  static const String medical = '$_o' '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M12 8v8M8 12h8"/>' '$_c';
  static const String water = '$_o' '<path d="M3 9c2 0 2-1.5 4.5-1.5S9.5 9 12 9s2.5-1.5 4.5-1.5S18.5 9 21 9"/>'
      '<path d="M3 14c2 0 2-1.5 4.5-1.5S9.5 14 12 14s2.5-1.5 4.5-1.5S18.5 14 21 14"/>'
      '<path d="M3 19c2 0 2-1.5 4.5-1.5S9.5 19 12 19s2.5-1.5 4.5-1.5S18.5 19 21 19"/>' '$_c';
  static const String flame = '$_o' '<path d="M12 21a6 6 0 0 0 6-6c0-4-3-6-4-10-1.5 2-2 3.5-2 5-1-1-1.5-2-1.5-3C8 9 6 12 6 15a6 6 0 0 0 6 6z"/>' '$_c';
  static const String building = '$_o' '<rect x="5" y="3" width="14" height="18" rx="1"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M10 21v-4h4v4"/>' '$_c';
  static const String box = '$_o' '<path d="M3 7.5L12 3l9 4.5v9L12 21l-9-4.5z"/><path d="M3 7.5l9 4.5 9-4.5M12 12v9"/>' '$_c';
  static const String home = '$_o' '<path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M10 20v-5h4v5"/>' '$_c';
  static const String route = '$_o' '<circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="6" r="2.5"/><path d="M8.5 18H15a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h6.5"/>' '$_c';
  static const String hazard = '$_o' '<path d="M12 3l9.5 17h-19z"/><path d="M8 16h8"/>' '$_c';
  static const String help = '$_o' '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.5V14"/><circle cx="12" cy="17" r="0.6" fill="#000"/>' '$_c';

  // ---- Actions & navigation ----
  static const String send = '$_o' '<path d="M21 3L10 14"/><path d="M21 3l-7 18-4-7-7-4z"/>' '$_c';
  static const String chevronRight = '$_o' '<path d="M9 5l7 7-7 7"/>' '$_c';
  static const String arrowBack = '$_o' '<path d="M20 12H4"/><path d="M10 6l-6 6 6 6"/>' '$_c';
  static const String refresh = '$_o' '<path d="M20 11a8 8 0 0 0-14.9-3.5M4 4v4h4"/><path d="M4 13a8 8 0 0 0 14.9 3.5M20 20v-4h-4"/>' '$_c';
  static const String play = '$_o' '<path d="M7 4.5v15L19 12z"/>' '$_c';
  static const String pause = '$_o' '<path d="M8 5v14M16 5v14"/>' '$_c';
  static const String step = '$_o' '<path d="M5 5v14l9-7z"/><path d="M18 5v14"/>' '$_c';
  static const String status = '$_o' '<path d="M4 6h16M4 12h16M4 18h10"/>' '$_c';
  static const String map = '$_o' '<path d="M3 6l6-3 6 3 6-3v15l-6 3-6-3-6 3z"/><path d="M9 3v15M15 6v15"/>' '$_c';
  static const String trash = '$_o' '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>' '$_c';
  static const String split = '$_o' '<path d="M12 3v18" stroke-dasharray="2 3"/><circle cx="6" cy="9" r="2"/><circle cx="18" cy="15" r="2"/>' '$_c';
  static const String bolt = '$_o' '<path d="M13 3L5 13h6l-1 8 8-10h-6z"/>' '$_c';
  static const String target = '$_o' '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1" fill="#000"/>' '$_c';
  static const String badge = '$_o' '<circle cx="12" cy="9" r="6"/><path d="M8.5 13.8L7 21l5-2.5 5 2.5-1.5-7.2"/>' '$_c';

  // ---- Emergencies (quick picks) ----
  static const String earthquake = '$_o' '<path d="M3 21h18"/><path d="M5 21V10l4-3v14M15 21V7l4 3v11"/><path d="M12 3l-1.5 4 2.5 2-2 4 1.5 3"/>' '$_c';
  static const String bandage = '$_o' '<rect x="2.5" y="8" width="19" height="8" rx="4" transform="rotate(-45 12 12)"/><path d="M10.5 10.5h.01M13.5 13.5h.01M10.5 13.5h.01M13.5 10.5h.01"/>' '$_c';
  static const String heartPulse = '$_o' '<path d="M20.5 8.5c0 5-8.5 11.5-8.5 11.5S3.5 13.5 3.5 8.5a4.5 4.5 0 0 1 8.5-2 4.5 4.5 0 0 1 8.5 2z"/><path d="M6 12h3l1.5-2.5 2.5 5 1.5-2.5H18"/>' '$_c';
  static const String gas = '$_o' '<path d="M7 21h10"/><rect x="7" y="7" width="10" height="14" rx="2"/><path d="M10 7V4h4v3"/><path d="M12 11c-1.5 1.6-1.5 3.4 0 4.5 1.5-1.1 1.5-2.9 0-4.5z"/>' '$_c';
  static const String child = '$_o' '<circle cx="9" cy="5" r="2"/><circle cx="16.5" cy="9" r="1.6"/><path d="M9 8v6M9 21v-7M6 11h6M16.5 12v4M16.5 21v-5M14.5 14h4"/>' '$_c';

  // ---- Maps ----
  static const String external = '$_o' '<path d="M14 4h6v6"/><path d="M20 4l-9 9"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>' '$_c';
  static const String flag = '$_o' '<path d="M5 21V4"/><path d="M5 4h11l-2 4 2 4H5"/>' '$_c';
}

/// Renders a [ResqIcons] SVG in the current icon colour (or [color]).
class AppIcon extends StatelessWidget {
  const AppIcon(this.svg, {super.key, this.size = 24, this.color, this.semanticLabel});

  final String svg;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
