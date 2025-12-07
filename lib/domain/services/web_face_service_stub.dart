/// Web Face Service Stub - 네이티브 플랫폼용 스텁
///
/// 이 파일은 네이티브 플랫폼에서 컴파일될 때 사용됩니다.
/// 실제 구현은 web_face_service_web.dart에 있으며,
/// 조건부 임포트를 통해 웹에서만 사용됩니다.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 네이티브 플랫폼용 스텁 클래스
class WebFaceService {
  static Future<void> initialize() async {
    debugPrint('[WebFaceService] Not available on native platform');
  }

  static bool get isReady => false;

  static Future<List<Rect>> detectFaces(Uint8List imageBytes) async {
    throw UnsupportedError(
      'WebFaceService is not available on native platform',
    );
  }

  static Future<Uint8List?> blurFaces({
    required Uint8List imageBytes,
    required List<Rect> rects,
    required bool isCircle,
  }) async {
    throw UnsupportedError(
      'WebFaceService is not available on native platform',
    );
  }
}
