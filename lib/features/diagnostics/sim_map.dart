import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/geo.dart';
import '../../sim/simulator.dart';

/// Map of the simulated city. Colour and shape both carry meaning (legend
/// below the map): victims are squares, responders circles, relays dots,
/// the authority a diamond, attackers crosses.
class SimMap extends StatelessWidget {
  const SimMap({super.key, required this.sim, required this.version});

  final Simulator sim;
  final int version;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(
            color: cs.surfaceContainerHigh,
            child: CustomPaint(painter: _SimPainter(sim, version, cs, Theme.of(context).textTheme.labelSmall!)),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        _Legend(color: cs.error, label: 'Victim', square: true),
        _Legend(color: cs.primary, label: 'Responder'),
        _Legend(color: cs.outline, label: 'Relay', small: true),
        _Legend(color: cs.tertiary, label: 'Authority', square: true),
        _Legend(color: cs.onSurface, label: 'Attacker'),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.square = false, this.small = false});

  final Color color;
  final String label;
  final bool square;
  final bool small;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: small ? 6 : 10,
          height: small ? 6 : 10,
          decoration: BoxDecoration(
            color: color,
            shape: square ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: square ? BorderRadius.circular(2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class _SimPainter extends CustomPainter {
  _SimPainter(this.sim, this.version, this.cs, this.labelStyle);

  final Simulator sim;
  final int version;
  final ColorScheme cs;
  final TextStyle labelStyle;

  static const double spanM = 2000;

  Offset _project(GeoPoint p, Size size) {
    final dx = sim.center.distanceTo(GeoPoint(sim.center.lat, p.lng)) * (p.lng < sim.center.lng ? -1 : 1);
    final dy = sim.center.distanceTo(GeoPoint(p.lat, sim.center.lng)) * (p.lat < sim.center.lat ? 1 : -1);
    return Offset(size.width / 2 + dx / spanM * size.width, size.height / 2 + dy / spanM * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mPerPx = spanM / size.width;
    Paint fill(Color c) => Paint()..color = c;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    // Hazard zones as the observer node knows them (from signed reports).
    for (final z in sim.observer.node.hazardZones) {
      final c = _project(z.center, size);
      final r = z.radiusM / mPerPx;
      canvas.drawCircle(c, r, fill(cs.error.withValues(alpha: 0.10 + 0.15 * z.confidence)));
      canvas.drawCircle(c, r, stroke(cs.error.withValues(alpha: 0.6), 1.5));
      _label(canvas, '${z.kind.label.toLowerCase()} ${(z.confidence * 100).round()}%', c.translate(-24, -r - 14), cs.error);
    }

    final byKey = {for (final n in sim.nodes) n.key: n};
    final linkPaint = stroke(cs.outlineVariant, 1);
    for (final (a, b) in sim.radio.links) {
      final na = byKey[a], nb = byKey[b];
      if (na == null || nb == null) continue;
      canvas.drawLine(_project(na.position, size), _project(nb.position, size), linkPaint);
    }

    if (sim.partitioned) {
      final x = size.width / 2;
      final p = stroke(cs.onSurface, 2);
      for (var y = 0.0; y < size.height; y += 14) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 7), p);
      }
      _label(canvas, 'network split', Offset(x + 6, 6), cs.onSurface);
    }

    // Assignments from the observer's reconciled view.
    final states = sim.observer.node.states;
    final engaged = <String>{};
    for (final st in states.values) {
      if (st.primary == null || !st.isActive) continue;
      final responder = sim.nodes.where((n) => n.node.selfId == st.primary).firstOrNull;
      final sos = sim.observer.node.sosRecords.where((s) => s.id == st.sosId).firstOrNull;
      final target = sos?.approxPoint;
      if (responder == null || target == null) continue;
      engaged.add(responder.key);
      canvas.drawLine(_project(responder.position, size), _project(target, size), stroke(cs.primary, 2.5));
    }
    final openOrigins = {
      for (final s in sim.observer.node.sosRecords)
        if (states[s.id]?.isOpen ?? false) s.origin,
    };

    for (final n in sim.nodes) {
      final p = _project(n.position, size);
      switch (n.kind) {
        case SimKind.victim:
          final r = RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 12, height: 12), const Radius.circular(3));
          canvas.drawRRect(r, openOrigins.contains(n.node.selfId) ? fill(cs.error) : stroke(cs.error, 2));
        case SimKind.responder:
          canvas.drawCircle(p, 6.5, engaged.contains(n.key) ? fill(cs.primary) : stroke(cs.primary, 2));
        case SimKind.relay:
          canvas.drawCircle(p, 3, fill(cs.outline));
        case SimKind.authority:
          final path = Path()
            ..moveTo(p.dx, p.dy - 8)
            ..lineTo(p.dx + 8, p.dy)
            ..lineTo(p.dx, p.dy + 8)
            ..lineTo(p.dx - 8, p.dy)
            ..close();
          canvas.drawPath(path, fill(cs.tertiary));
        case SimKind.attacker:
          final s = stroke(cs.onSurface, 2.5);
          canvas.drawLine(p.translate(-6, -6), p.translate(6, 6), s);
          canvas.drawLine(p.translate(-6, 6), p.translate(6, -6), s);
      }
      if (n.kind != SimKind.relay) _label(canvas, n.label, p.translate(8, -5), cs.onSurfaceVariant);
    }

    final bar = 500 / mPerPx;
    final scale = stroke(cs.onSurfaceVariant, 2);
    canvas.drawLine(Offset(10, size.height - 12), Offset(10 + bar, size.height - 12), scale);
    _label(canvas, '500 m', Offset(10, size.height - 28), cs.onSurfaceVariant);
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle.copyWith(color: color, fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: max(60, 200));
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SimPainter old) => old.version != version || !identical(old.sim, sim) || old.cs != cs;
}
