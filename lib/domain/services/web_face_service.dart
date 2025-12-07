/// Web Face Service - 조건부 임포트
///
/// 웹 플랫폼에서는 `web_face_service_web.dart`를 사용하고,
/// 네이티브 플랫폼에서는 `web_face_service_stub.dart`를 사용합니다.
library;

export 'web_face_service_stub.dart'
    if (dart.library.js_interop) 'web_face_service_web.dart';
