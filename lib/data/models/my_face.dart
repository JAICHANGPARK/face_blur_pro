import 'dart:ui';

/// 얼굴 또는 블러 영역을 나타내는 클래스
class MyFace {
  final Rect boundingBox;

  /// 수동으로 추가된 영역인지 여부
  final bool isManual;

  MyFace(this.boundingBox, {this.isManual = false});
}

enum BlurShape { rectangle, circle }
