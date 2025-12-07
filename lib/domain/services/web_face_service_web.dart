/// Web Face Service - Dart ↔ JavaScript 인터롭
/// 웹 플랫폼에서 TensorFlow.js 기반 얼굴 감지 및 블러 처리
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// JavaScript 함수 바인딩
@JS('FaceBlurWeb.detectFacesWeb')
external JSPromise<JSString> _detectFacesWeb(JSString base64ImageData);

@JS('FaceBlurWeb.blurFacesWeb')
external JSPromise<JSString> _blurFacesWeb(
  JSString base64ImageData,
  JSString rectsJson,
  JSBoolean isCircle,
);

@JS('FaceBlurWeb.initFaceDetector')
external JSPromise<JSAny?> _initFaceDetector();

@JS('FaceBlurWeb.isModelReady')
external JSBoolean _isModelReady();

/// 웹 플랫폼용 얼굴 감지 서비스
class WebFaceService {
  static bool _initialized = false;

  /// TensorFlow.js 모델 초기화
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _initFaceDetector().toDart;
      _initialized = true;
      debugPrint('[WebFaceService] Initialized successfully');
    } catch (e) {
      debugPrint('[WebFaceService] Initialization error: $e');
    }
  }

  /// 모델 로딩 상태 확인
  static bool get isReady => _isModelReady().toDart;

  /// 이미지에서 얼굴 감지
  /// [imageBytes] - PNG/JPEG 이미지 바이트
  /// 반환: 감지된 얼굴 영역의 Rect 리스트
  static Future<List<Rect>> detectFaces(Uint8List imageBytes) async {
    try {
      final base64Data = base64Encode(imageBytes);
      final resultJson = await _detectFacesWeb(base64Data.toJS).toDart;
      final List<dynamic> faces = jsonDecode(resultJson.toDart);

      return faces.map((face) {
        return Rect.fromLTWH(
          (face['x'] as num).toDouble(),
          (face['y'] as num).toDouble(),
          (face['width'] as num).toDouble(),
          (face['height'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[WebFaceService] Face detection error: $e');
      return [];
    }
  }

  /// 얼굴 영역에 블러 적용
  /// [imageBytes] - 원본 이미지 바이트
  /// [rects] - 블러 처리할 영역 리스트
  /// [isCircle] - 원형 블러 여부
  /// 반환: 블러 처리된 이미지 바이트
  static Future<Uint8List?> blurFaces({
    required Uint8List imageBytes,
    required List<Rect> rects,
    required bool isCircle,
  }) async {
    try {
      final base64Data = base64Encode(imageBytes);

      final rectsData = rects
          .map(
            (r) => {
              'x': r.left.toInt(),
              'y': r.top.toInt(),
              'width': r.width.toInt(),
              'height': r.height.toInt(),
            },
          )
          .toList();

      final rectsJson = jsonEncode(rectsData);

      final resultBase64 = await _blurFacesWeb(
        base64Data.toJS,
        rectsJson.toJS,
        isCircle.toJS,
      ).toDart;

      return base64Decode(resultBase64.toDart);
    } catch (e) {
      debugPrint('[WebFaceService] Blur error: $e');
      return null;
    }
  }
}
