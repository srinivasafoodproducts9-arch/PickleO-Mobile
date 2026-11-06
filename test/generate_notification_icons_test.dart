import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate clean notification PNGs across densities', () async {
    final densities = {
      'drawable-mdpi': 24,
      'drawable-hdpi': 36,
      'drawable-xhdpi': 48,
      'drawable-xxhdpi': 72,
      'drawable-xxxhdpi': 96,
    };

    for (final entry in densities.entries) {
      final folder = entry.key;
      final size = entry.value.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final scale = size / 24.0;

      // 1. Lid Knob
      final knobRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(10.5 * scale, 2.0 * scale, 3.0 * scale, 1.5 * scale),
        Radius.circular(0.8 * scale),
      );
      canvas.drawRRect(knobRect, paint);

      // 2. Lid Rim
      final rimRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(5.5 * scale, 4.0 * scale, 13.0 * scale, 2.8 * scale),
        Radius.circular(1.2 * scale),
      );
      canvas.drawRRect(rimRect, paint);

      // 3. Jar Body with transparent inner cutout
      final bodyPath = Path();
      bodyPath.addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(4.5 * scale, 8.0 * scale, 15.0 * scale, 13.5 * scale),
        topLeft: Radius.circular(2.0 * scale),
        topRight: Radius.circular(2.0 * scale),
        bottomLeft: Radius.circular(4.5 * scale),
        bottomRight: Radius.circular(4.5 * scale),
      ));

      // Cutout in center: Leaf motif
      final cutoutPath = Path();
      final centerX = 12.0 * scale;
      final topY = 11.5 * scale;
      final bottomY = 18.0 * scale;

      cutoutPath.moveTo(centerX, topY);
      cutoutPath.quadraticBezierTo(
        centerX - 2.8 * scale,
        14.5 * scale,
        centerX,
        bottomY,
      );
      cutoutPath.quadraticBezierTo(
        centerX + 2.8 * scale,
        14.5 * scale,
        centerX,
        topY,
      );
      cutoutPath.close();

      final finalPath = Path.combine(
        PathOperation.difference,
        bodyPath,
        cutoutPath,
      );

      canvas.drawPath(finalPath, paint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(entry.value, entry.value);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = Directory('android/app/src/main/res/$folder');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('${dir.path}/ic_notification.png');
      file.writeAsBytesSync(bytes);
      expect(file.existsSync(), isTrue);
    }
  });
}
