import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq/ui/brand.dart';

/// Renders the in-app BrandMark (SVG) to build/brand_mark_check.png so it can
/// be compared with the launcher icon PNG, and checks it actually paints.
void main() {
  testWidgets('BrandMark renders the beacon-pin logo', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: RepaintBoundary(key: key, child: const BrandMark(size: 256))),
    ));
    // flutter_svg parses asynchronously.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    expect(bytes, isNotNull);
    File('build/brand_mark_check.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);

    // The centre of the beacon is coral and the tile background is blue.
    final raw = await tester.runAsync(() async {
      final image = await boundary.toImage();
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    int pixel(int x, int y) => raw!.getUint32((y * 256 + x) * 4);
    final beacon = pixel(128, (128 + (47 - 54 + 1.5) * 1.12 * 256 / 108).round());
    final corner = pixel(40, 40);
    expect(beacon >> 24 & 0xFF, greaterThan(200), reason: 'beacon red channel');
    expect(corner >> 8 & 0xFF, greaterThan(150), reason: 'tile blue channel');
  });
}
