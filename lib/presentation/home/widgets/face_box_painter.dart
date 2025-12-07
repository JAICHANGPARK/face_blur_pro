import 'package:flutter/material.dart';
import 'package:my_app/data/models/my_face.dart';

class FaceBoxPainter extends CustomPainter {
  final List<MyFace> faces;
  final Set<int> selectedIndices;
  final double scaleFactor;
  final bool showOutlines;
  final BlurShape blurShape;

  FaceBoxPainter({
    required this.faces,
    required this.selectedIndices,
    required this.scaleFactor,
    required this.showOutlines,
    required this.blurShape,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < faces.length; i++) {
      final face = faces[i];
      final rect = face.boundingBox;
      final bool isSelected = selectedIndices.contains(i);

      if (!isSelected && !showOutlines) {
        continue;
      }

      final transformedRect = Rect.fromLTWH(
        rect.left * scaleFactor,
        rect.top * scaleFactor,
        rect.width * scaleFactor,
        rect.height * scaleFactor,
      );

      final paint = Paint()..style = PaintingStyle.stroke;

      if (isSelected) {
        paint.color = Colors.greenAccent;
        paint.strokeWidth = 2.5 / scaleFactor;

        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.greenAccent.withValues(alpha: 0.2);

        if (blurShape == BlurShape.circle) {
          canvas.drawOval(transformedRect, fillPaint);
          canvas.drawOval(transformedRect, paint);
        } else {
          canvas.drawRect(transformedRect, fillPaint);
          canvas.drawRect(transformedRect, paint);
        }
      } else {
        paint.color = Colors.redAccent.withValues(alpha: 0.6);
        paint.strokeWidth = 2.0 / scaleFactor;
        canvas.drawRect(transformedRect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceBoxPainter oldDelegate) {
    return oldDelegate.selectedIndices.length != selectedIndices.length ||
        oldDelegate.scaleFactor != scaleFactor ||
        oldDelegate.faces != faces ||
        oldDelegate.showOutlines != showOutlines ||
        oldDelegate.blurShape != blurShape;
  }
}
