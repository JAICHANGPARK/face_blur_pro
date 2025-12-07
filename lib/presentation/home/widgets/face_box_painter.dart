import 'package:flutter/material.dart';
import 'package:my_app/data/models/my_face.dart';

/// 얼굴 박스 및 수동 영역을 그리는 CustomPainter
class FaceBoxPainter extends CustomPainter {
  final List<MyFace> faces;
  final Set<int> selectedIndices;
  final double scaleFactor;
  final bool showOutlines;
  final BlurShape blurShape;

  /// 현재 그리고 있는 영역 (그리기 모드에서 사용)
  final Rect? currentDrawRect;

  FaceBoxPainter({
    required this.faces,
    required this.selectedIndices,
    required this.scaleFactor,
    required this.showOutlines,
    required this.blurShape,
    this.currentDrawRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 기존 얼굴 박스 그리기
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
        // 선택된 영역: 초록색
        paint.color = Colors.greenAccent;
        paint.strokeWidth = 2.5;

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
        // 미선택 영역: 자동 감지(빨강) vs 수동 추가(파랑)
        if (face.isManual) {
          paint.color = Colors.blueAccent.withValues(alpha: 0.8);
        } else {
          paint.color = Colors.redAccent.withValues(alpha: 0.6);
        }
        paint.strokeWidth = 2.0;
        canvas.drawRect(transformedRect, paint);
      }
    }

    // 현재 그리고 있는 영역 표시 (점선 스타일)
    if (currentDrawRect != null) {
      final drawRect = Rect.fromLTWH(
        currentDrawRect!.left * scaleFactor,
        currentDrawRect!.top * scaleFactor,
        currentDrawRect!.width * scaleFactor,
        currentDrawRect!.height * scaleFactor,
      );

      final drawPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.purpleAccent
        ..strokeWidth = 2.5;

      // 채우기
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.purpleAccent.withValues(alpha: 0.15);

      if (blurShape == BlurShape.circle) {
        canvas.drawOval(drawRect, fillPaint);
        canvas.drawOval(drawRect, drawPaint);
      } else {
        canvas.drawRect(drawRect, fillPaint);
        canvas.drawRect(drawRect, drawPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceBoxPainter oldDelegate) {
    return oldDelegate.selectedIndices.length != selectedIndices.length ||
        oldDelegate.scaleFactor != scaleFactor ||
        oldDelegate.faces != faces ||
        oldDelegate.showOutlines != showOutlines ||
        oldDelegate.blurShape != blurShape ||
        oldDelegate.currentDrawRect != currentDrawRect;
  }
}
