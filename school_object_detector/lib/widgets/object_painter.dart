import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ObjectPainter extends CustomPainter {
  final List<Map<String, dynamic>> objects;
  final Size imageSize;
  final CameraLensDirection lensDirection;

  ObjectPainter(this.objects, this.imageSize, this.lensDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.red;

    final Paint textBgPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    for (var object in objects) {
      final box = object["box"]; 
      
      final double x1 = box[0];
      final double y1 = box[1];
      final double x2 = box[2];
      final double y2 = box[3];
      
      final double scaleX = size.width / imageSize.width;
      final double scaleY = size.height / imageSize.height;

      double left = x1 * scaleX;
      double top = y1 * scaleY;
      double right = x2 * scaleX;
      double bottom = y2 * scaleY;

      if (lensDirection == CameraLensDirection.front) {
        double temp = left;
        left = size.width - right;
        right = size.width - temp;
      }

      final Rect rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, paint);

      final String label = "${object['tag']} ${(box[4] * 100).toStringAsFixed(0)}%";
      
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();

      double textY = top - 24;
      if (textY < 0) textY = top + 4;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, textY, textPainter.width + 12, 24),
          const Radius.circular(4),
        ),
        textBgPaint,
      );

      textPainter.paint(canvas, Offset(left + 6, textY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}