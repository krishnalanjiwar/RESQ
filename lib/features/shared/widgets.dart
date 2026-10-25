import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Square, white-bordered box: the basic card of the operational UI.
class Boxed extends StatelessWidget {
  const Boxed({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.thick = false});

  final Widget child;
  final EdgeInsets padding;
  final bool thick;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: ResqTheme.white, width: thick ? 2 : 1)),
        child: Padding(padding: padding, child: child),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 13)),
          ),
          ?trailing,
        ]),
      );
}

/// "LABEL ........ VALUE" status line. Meaning is always carried by text.
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xB3FFFFFF)))),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400)),
          ),
        ]),
      );
}

/// Bracketed action button, e.g. `[ ACCEPT ]`. Primary = filled white.
class ActionButton extends StatelessWidget {
  const ActionButton(this.label, {super.key, required this.onPressed, this.primary = false, this.dense = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = Text('[ $label ]', textAlign: TextAlign.center, style: TextStyle(fontSize: dense ? 11 : 13));
    final size = dense ? const Size(48, 40) : const Size(48, 56);
    return primary
        ? FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(minimumSize: size), child: text)
        : OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(minimumSize: size), child: text);
  }
}

/// Persistent banner for anything simulated. Simulation is never shown as reality.
class SimulationBanner extends StatelessWidget {
  const SimulationBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        color: ResqTheme.white,
        child: Text('■ SIMULATION — $text',
            style: const TextStyle(color: ResqTheme.black, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

/// Text-only score bar, e.g. `████████░░ 82%` (no colour dependence).
String scoreBar(double v, {int width = 10}) {
  final clamped = v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
  final filled = (clamped * width).round();
  return '${'█' * filled}${'░' * (width - filled)} ${(clamped * 100).round()}%';
}

String ago(int ms, int nowMs) {
  final s = ((nowMs - ms) / 1000).round();
  if (s < 0) return 'just now';
  if (s < 60) return '${s}s ago';
  if (s < 3600) return '${s ~/ 60}m ago';
  return '${s ~/ 3600}h ago';
}

Future<bool> confirm(BuildContext context, String title, String body, {String yes = 'CONFIRM'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: const RoundedRectangleBorder(side: BorderSide(color: ResqTheme.white)),
      backgroundColor: ResqTheme.black,
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: Text(body, style: const TextStyle(fontSize: 13)),
      actions: [
        ActionButton('CANCEL', dense: true, onPressed: () => Navigator.pop(ctx, false)),
        ActionButton(yes, dense: true, primary: true, onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return result ?? false;
}

void notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: ResqTheme.black)),
      backgroundColor: ResqTheme.white,
      shape: const RoundedRectangleBorder(),
    ));
}
