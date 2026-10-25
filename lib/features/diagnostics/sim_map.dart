import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/geo.dart';
import '../../sim/simulator.dart';

/// Monochrome map of the simulated city. Shapes, not colours, carry meaning:
/// square = victim (filled = open SOS), circle = responder (filled = engaged),
/// dot = relay, diamond = authority, X = attacker; dashed line = partition.
class SimMap extends StatelessWidget {
  const SimMap({super.key, required this.sim, required this.version});

  final Simulator sim;
  final int version;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: ResqTheme.white)),
          child: CustomPaint(painter: _SimPainter(sim, version)),
        ),
      );
}

class _SimPainter extends CustomPainter {
  _SimPainter(this.sim, this.version);

  final Simulator sim;
  final int version;

  static const double spanM = 2000;

  Offset _project(GeoPoint p, Size size) {
    final dx = sim.center.distanceTo(GeoPoint(sim.center.lat, p.lng)) * (p.lng < sim.center.lng ? -1 : 1);
    final dy = sim.center.distanceTo(GeoPoint(p.lat, sim.center.lng)) * (p.lat < sim.center.lat ? 1 : -1);
    return Offset(size.width / 2 + dx / spanM * size.width, size.height / 2 + dy / spanM * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = ResqTheme.white;
    final stroke = Paint()
      ..color = ResqTheme.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final faint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 0.8;
    final mPerPx = spanM / size.width;

    // Hazard zones as seen by the observer node (from signed reports, not ground truth).
    for (final z in sim.observer.node.hazardZones) {
      final c = _project(z.center, size);
      canvas.drawCircle(c, z.radiusM / mPerPx, stroke);
      _label(canvas, '${z.kind.label} ${(z.confidence * 100).round()}%', c.translate(-20, -z.radiusM / mPerPx - 12), 9);
    }

    final byKey = {for (final n in sim.nodes) n.key: n};
    for (final (a, b) in sim.radio.links) {
      final na = byKey[a], nb = byKey[b];
      if (na == null || nb == null) continue;
      canvas.drawLine(_project(na.position, size), _project(nb.position, size), faint);
    }

    if (sim.partitioned) {
      final x = size.width / 2;
      for (var y = 0.0; y < size.height; y += 12) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 6), white..strokeWidth = 2);
      }
      _label(canvas, 'PARTITION', Offset(x + 4, 4), 10);
    }

    // Assignment lines from the observer's reconciled view.
    final states = sim.observer.node.states;
    final engaged = <String>{};
    for (final st in states.values) {
      if (st.primary == null || !st.isActive) continue;
      final responder = sim.nodes.where((n) => n.node.selfId == st.primary).firstOrNull;
      final sos = sim.observer.node.sosRecords.where((s) => s.id == st.sosId).firstOrNull;
      final target = sos?.approxPoint;
      if (responder == null || target == null) continue;
      engaged.add(responder.key);
      canvas.drawLine(_project(responder.position, size), _project(target, size), white..strokeWidth = 2);
    }
    final openOrigins = {
      for (final s in sim.observer.node.sosRecords)
        if (states[s.id]?.isOpen ?? false) s.origin,
    };

    for (final n in sim.nodes) {
      final p = _project(n.position, size);
      switch (n.kind) {
        case SimKind.victim:
          final r = Rect.fromCenter(center: p, width: 10, height: 10);
          canvas.drawRect(r, openOrigins.contains(n.node.selfId) ? white : stroke);
        case SimKind.responder:
          canvas.drawCircle(p, 5.5, engaged.contains(n.key) ? white : stroke);
        case SimKind.relay:
          canvas.drawCircle(p, 2.5, white);
        case SimKind.authority:
          final path = Path()
            ..moveTo(p.dx, p.dy - 7)
            ..lineTo(p.dx + 7, p.dy)
            ..lineTo(p.dx, p.dy + 7)
            ..lineTo(p.dx - 7, p.dy)
            ..close();
          canvas.drawPath(path, stroke);
        case SimKind.attacker:
          canvas.drawLine(p.translate(-6, -6), p.translate(6, 6), white..strokeWidth = 2);
          canvas.drawLine(p.translate(-6, 6), p.translate(6, -6), white..strokeWidth = 2);
      }
      if (n.kind != SimKind.relay) _label(canvas, n.label, p.translate(7, -4), 8);
    }

    // Scale bar: 500 m.
    final bar = 500 / mPerPx;
    canvas.drawLine(Offset(8, size.height - 10), Offset(8 + bar, size.height - 10), white..strokeWidth = 2);
    _label(canvas, '500 m', Offset(8, size.height - 24), 9);
  }

  void _label(Canvas canvas, String text, Offset at, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: ResqTheme.white, fontSize: fontSize, fontFamily: ResqTheme.fontFamily)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: max(60, fontSize * 20));
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SimPainter old) => old.version != version || !identical(old.sim, sim);
}
