---
description: Flutter와 Rust를 사용하는 Face Blurring 프로젝트의 문맥과 아키텍처 규칙을 로드합니다.
---


# Project Context: Face Blurring App

당신은 `flutter_rust_bridge`를 사용하여 Flutter(UI)와 Rust(백엔드)가 결합된 크로스 플랫폼 애플리케이션을 개발하는 전문가 에이전트입니다.
이 프로젝트는 "이미지 내 얼굴 블러 처리(Face Blurring)" 기능을 제공합니다.

다음의 **아키텍처 규칙**과 **기술 스택**을 엄격히 준수하여 코드를 작성하고 질문에 답변하세요.

## 1. 프로젝트 개요 (Overview)
이 앱은 사용자가 갤러리에서 이미지를 선택하고, 얼굴을 감지하여, 선택된 얼굴에 블러 효과를 적용하는 기능을 제공합니다.

## 2. 핵심 아키텍처 (Architecture & Logic)
이 프로젝트는 플랫폼별로 얼굴 감지(Face Detection) 방식이 다른 **하이브리드 접근 방식**을 사용합니다.

### A. 얼굴 감지 (Face Detection)
- **모바일 (Android/iOS):** 
  - `google_mlkit_face_detection` 패키지를 사용합니다. (On-device ML)
- **데스크톱 (macOS/Linux/Windows):** 
  - Rust 백엔드를 사용합니다.
  - `tract-onnx` 크레이트와 사전 학습된 ONNX 모델(`version-RFB-640.onnx`)을 사용합니다.
  - 관련 함수: Rust 측의 `detect_faces_desktop` 호출.

### B. 이미지 블러링 (Image Blurring)
- 플랫폼과 무관하게 **모든 블러링 로직은 Rust에서 수행**됩니다.
- 이는 일관된 결과물을 보장하기 위함입니다.
- 통신: `flutter_rust_bridge`가 Flutter와 Rust 사이를 연결합니다.

## 3. 코드 구조 및 파일 위치 (Code Structure)
- **Flutter (UI & 앱 로직):** `lib/main.dart`
  - `_pickAndDetect` 함수: 플랫폼을 확인하고 적절한 감지 로직으로 분기합니다.
  - `_blurSelectedFaces` 함수: Rust의 블러링 함수를 호출합니다.
- **Rust (핵심 로직):** `rust/src/api/simple.rs`
  - `blur_multiple_faces` 함수: 이미지 바이트와 사각형 좌표를 받아 블러링을 수행합니다.
- **Bridge (생성된 코드):** `lib/src/rust` (직접 수정 금지)
- **설정 파일:** `flutter_rust_bridge.yaml`

## 4. 빌드 및 실행 (Build & Run)
- 의존성 설치: `flutter pub get`
- 앱 실행: `flutter run`
- 사전 요구사항: Flutter SDK, Rust toolchain

## 5. 에이전트 작업 지침 (Instructions)
1. **기능 수정 시:** UI 변경은 `lib/main.dart`, 이미지 처리 로직 변경은 `rust/src/api/simple.rs`를 참조하세요.
2. **플랫폼 분기:** 새로운 기능을 추가할 때도 모바일(ML Kit)과 데스크톱(Rust/ONNX)의 분기 로직을 유지해야 합니다.
3. **브리지 수정:** Rust 함수 시그니처가 변경되면 `flutter_rust_bridge`의 코드 생성(codegen)이 필요함을 인지하세요.

이 문맥을 바탕으로 다음 작업을 수행할 준비를 하세요.