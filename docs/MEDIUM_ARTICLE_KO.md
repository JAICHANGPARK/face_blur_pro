# Flutter, Rust, ONNX로 크로스 플랫폼 얼굴 블러 앱 만들기

## 개인정보 보호를 최우선으로 하는 하이브리드 아키텍처 심층 분석

![Face Blur Pro Banner](https://img.shields.io/badge/Built%20with-Flutter%20%2B%20Rust-blue)

**요약 (TL;DR):** iOS, Android, macOS, Windows, Linux, 그리고 Web까지 단일 코드베이스로 실행되는 크로스 플랫폼 얼굴 감지 및 블러 처리 애플리케이션을 만들었습니다. 핵심 비결은 무엇일까요? 바로 모바일에서는 Google ML Kit를, 데스크탑에서는 Rust + ONNX를, 브라우저에서는 ONNX Runtime Web을 활용하는 하이브리드 아키텍처입니다. 모든 처리는 온디바이스(on-device)에서 이루어지며, 완벽한 개인정보 보호를 보장합니다.

---

## 🎯 문제: 이미지 공유 시대의 개인정보 보호

우리는 사진 공유가 일상이 된 시대에 살고 있습니다. 하지만 동의하지 않은 사람들의 얼굴이 포함된 이미지를 공유해야 한다면 어떨까요? 거리 사진이든, 컨퍼런스 사진이든, 블로그용 콘텐츠든, 얼굴을 흐릿하게 처리(블러)하는 것은 종종 필수적인 작업입니다.

대부분의 솔루션은 다음 범주 중 하나에 속합니다.
- **클라우드 기반 서비스**: 빠르지만 개인정보 보호가 우려됩니다. 이미지가 타인의 서버로 업로드되기 때문입니다.
- **플랫폼 전용 앱**: 성능은 좋지만 특정 생태계(OS)에 제한됩니다.
- **웹 전용 도구**: 편리하지만 인터넷 연결이 필요할 때가 많습니다.

저는 뭔가 다른 것을 원했습니다. **진정한 크로스 플랫폼이면서**, 모든 처리가 기기 내에서 로컬로 이루어지는 **개인정보 보호 최우선 솔루션**입니다.

---

## 🏗️ 아키텍처 개요

아키텍처가 얼핏 복잡해 보일 수 있지만, 각 선택의 이유를 이해하면 꽤 우아한 구조임을 알 수 있습니다.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter (Dart) Frontend                     │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │    Mobile       │  │    Desktop      │  │      Web        │ │
│  │  (iOS/Android)  │  │(macOS/Win/Linux)│  │   (Browser)     │ │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘ │
└───────────│────────────────────│────────────────────│──────────┘
            │                    │                    │
            ▼                    ▼                    ▼
    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
    │  Google ML    │    │  Rust + ONNX  │    │  ONNX Runtime │
    │     Kit       │    │  (tract-onnx) │    │     Web       │
    └───────────────┘    └───────────────┘    └───────────────┘
```

**왜 이런 접근 방식을 택했을까요?**

| 플랫폼 | 얼굴 감지 | 블러 처리 | 선정 이유 |
|----------|---------------|-----------------|-----------|
| **Mobile** | Google ML Kit | Rust FFI | ML Kit는 모바일 SoC에 고도로 최적화되어 있습니다. |
| **Desktop** | ONNX (Rust) | Rust FFI | 데스크탑에는 ML Kit가 없지만, Rust는 엄청나게 빠릅니다. |
| **Web** | ONNX Runtime Web | Canvas API | WebAssembly를 통해 네이티브에 가까운 성능을 낼 수 있습니다. |

---

## 🛠️ 기술 스택 심층 분석

### Flutter: 통합 레이어

Flutter는 모든 플랫폼에서 아름답고 일관된 UI를 제공하는 프레젠테이션 레이어 역할을 합니다. 진입점 코드는 다음과 같습니다.

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 웹이 아닌 플랫폼에서만 Rust 라이브러리 초기화
  if (!kIsWeb) {
    try {
      await RustLib.init();
      debugPrint("RustLib initialized successfully");
    } catch (e) {
      debugPrint("Error initializing RustLib: $e");
    }
  } else {
    debugPrint("Running on Web - skipping RustLib init");
  }

  runApp(const MyApp());
}
```

조건부 초기화가 중요합니다. 웹 플랫폼에서는 FFI를 사용하여 Rust 코드를 호출할 수 없으므로, 이 부분을 건너뛰고 대신 JavaScript 상호 운용성(Interop)을 사용합니다.

### Rust: 성능의 중추

데스크탑 얼굴 감지와 모든 네이티브 플랫폼에서의 이미지 블러 처리를 위해 Rust를 선택했습니다. `flutter_rust_bridge` 라이브러 덕분에 FFI 통합이 매끄럽게 이루어집니다.

Rust에서 `tract-onnx` 크레이트를 사용하여 얼굴을 감지하는 방법은 다음과 같습니다.

```rust
// rust/src/api/simple.rs

pub fn detect_faces_desktop(
    image_bytes: Vec<u8>,
    model_bytes: Vec<u8>,
) -> anyhow::Result<Vec<BlurRect>> {
    let img = load_from_memory(&image_bytes)?;
    let (orig_w, orig_h) = img.dimensions();

    // ONNX 모델 로드 및 최적화
    let model = tract_onnx::onnx()
        .model_for_read(&mut Cursor::new(model_bytes))?
        .with_input_fact(0, f32::fact([1, 3, 480, 640]).into())?
        .into_optimized()?
        .into_runnable()?;

    // 이미지를 모델 입력 크기(640x480)로 리사이징
    let resized = img.resize_exact(
        640, 480, 
        image::imageops::FilterType::Triangle
    );

    // 정규화된 픽셀 값을 가진 텐서 생성
    let tensor: Tensor = tract_ndarray::Array4::from_shape_fn(
        (1, 3, 480, 640), 
        |(_, c, y, x)| {
            let pixel = resized.get_pixel(x as u32, y as u32);
            let val = pixel[c as usize] as f32;
            (val - 127.0) / 128.0  // 정규화 (Normalization)
        }
    ).into();

    let result = model.run(tvec!(tensor.into()))?;
    let confidences = result[0].to_array_view::<f32>()?;
    let boxes = result[1].to_array_view::<f32>()?;

    // Prior 앵커 생성 및 감지 결과 디코딩
    let priors = generate_priors_640();
    let mut detected_faces = Vec::new();

    for i in 0..priors.len() {
        let score = confidences[[0, i, 1]];
        if score > 0.6 {  // 점수 임계값
            // 바운딩 박스 좌표 디코딩...
            detected_faces.push(face);
        }
    }

    // NMS (Non-Maximum Suppression) 적용
    let final_faces = hard_nms(detected_faces, 0.3);
    
    // BlurRect 형식으로 변환
    Ok(final_faces.into_iter().map(|f| BlurRect { ... }).collect())
}
```

**앵커 박스 생성(Anchor box generation)**과 **NMS(Non-Maximum Suppression)** 알고리즘은 정확한 얼굴 감지를 위해 매우 중요합니다.

```rust
// RFB-640 모델을 위한 prior 앵커 박스 생성
fn generate_priors_640() -> Vec<Prior> {
    let input_w = 640.0;
    let input_h = 480.0;

    // 다양한 스케일의 피처 맵 크기
    let feature_maps = [[80, 60], [40, 30], [20, 15], [10, 8]];
    let min_sizes: &[&[f32]] = &[
        &[10.0, 16.0, 24.0],
        &[32.0, 48.0],
        &[64.0, 96.0],
        &[128.0, 192.0, 256.0],
    ];
    let steps = [8.0, 16.0, 32.0, 64.0];

    let mut priors = Vec::new();

    for (k, map_size) in feature_maps.iter().enumerate() {
        let min_size = min_sizes[k];
        let step = steps[k];

        for i in 0..map_size[1] {
            for j in 0..map_size[0] {
                let cx = (j as f32 + 0.5) * step / input_w;
                let cy = (i as f32 + 0.5) * step / input_h;

                for size in min_size {
                    priors.push(Prior {
                        cx,
                        cy,
                        w: size / input_w,
                        h: size / input_h,
                    });
                }
            }
        }
    }
    priors
}
```

### 블러 알고리즘

여기서 마법이 일어납니다. 블러 함수는 **직사각형**과 **타원형** 블러 모양을 모두 지원합니다.

```rust
pub fn blur_multiple_faces(
    image_bytes: Vec<u8>,
    rects: Vec<BlurRect>,
    is_circle: bool,  // 모양 선택 파라미터
) -> anyhow::Result<Vec<u8>> {
    let mut img = load_from_memory(&image_bytes)?;
    let (img_w, img_h) = (img.width() as i32, img.height() as i32);

    for rect in rects {
        let x = rect.x.max(0);
        let y = rect.y.max(0);
        let w = rect.w.min(img_w - x);
        let h = rect.h.min(img_h - y);

        // 영역을 잘라내어 가우시안 블러 적용
        let sub_img = img.crop_imm(x as u32, y as u32, w as u32, h as u32);
        let blurred = sub_img.blur(20.0);  // 블러 강도

        if is_circle {
            // 타원 방정식을 사용한 타원형 블러:
            // ((x-cx)/a)² + ((y-cy)/b)² <= 1
            let center_x = w as f32 / 2.0;
            let center_y = h as f32 / 2.0;
            let radius_x = w as f32 / 2.0;
            let radius_y = h as f32 / 2.0;

            for dy in 0..h {
                for dx in 0..w {
                    let norm_x = (dx as f32 - center_x) / radius_x;
                    let norm_y = (dy as f32 - center_y) / radius_y;

                    if (norm_x * norm_x + norm_y * norm_y) <= 1.0 {
                        // 타원 내부 → 블러 처리된 픽셀 적용
                        let pixel = blurred.get_pixel(dx as u32, dy as u32);
                        img.put_pixel((x + dx) as u32, (y + dy) as u32, pixel);
                    }
                    // 타원 외부 → 원본 유지
                }
            }
        } else {
            // 직사각형 블러 - 단순 교체
            image::imageops::replace(&mut img, &blurred, x as i64, y as i64);
        }
    }

    let mut result_bytes: Vec<u8> = Vec::new();
    img.write_to(&mut Cursor::new(&mut result_bytes), ImageFormat::Png)?;
    Ok(result_bytes)
}
```

---

## 🌐 웹 플랫폼: ONNX Runtime Web

웹 플랫폼은 독특한 과제를 안겨주었습니다. Rust FFI를 사용할 수 없었기에, 브라우저에서 WebAssembly를 사용하여 ONNX 모델을 직접 실행하는 JavaScript 라이브러리인 **ONNX Runtime Web**을 활용했습니다.

```javascript
// web/face_blur_web.js

const MODEL_INPUT_W = 640;
const MODEL_INPUT_H = 480;
const SCORE_THRESHOLD = 0.4;
const IOU_THRESHOLD = 0.3;

let session = null;
let priors = null;

/**
 * ONNX 모델 초기화
 */
async function initFaceDetector() {
    if (session) return session;

    console.log('[FaceBlur] Loading ONNX model...');
    const modelUrl = 'assets/assets/models/version-RFB-640.onnx';
    session = await ort.InferenceSession.create(modelUrl);
    priors = generatePriors640();
    console.log('[FaceBlur] Model loaded. Priors:', priors.length);
    return session;
}

/**
 * Base64 인코딩된 이미지에서 얼굴 감지
 */
async function detectFacesWeb(base64ImageData) {
    await initFaceDetector();

    // Base64를 이미지로 변환
    const img = new Image();
    img.crossOrigin = 'anonymous';
    await new Promise((resolve, reject) => {
        img.onload = resolve;
        img.onerror = reject;
        img.src = 'data:image/png;base64,' + base64ImageData;
    });

    const origW = img.width;
    const origH = img.height;

    // 모델 입력 차원으로 리사이징
    const canvas = document.createElement('canvas');
    canvas.width = MODEL_INPUT_W;
    canvas.height = MODEL_INPUT_H;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, MODEL_INPUT_W, MODEL_INPUT_H);

    // 픽셀 데이터 추출 및 텐서 생성 (NCHW 포맷)
    const imageData = ctx.getImageData(0, 0, MODEL_INPUT_W, MODEL_INPUT_H);
    const pixels = imageData.data;
    const tensorData = new Float32Array(1 * 3 * MODEL_INPUT_H * MODEL_INPUT_W);

    for (let y = 0; y < MODEL_INPUT_H; y++) {
        for (let x = 0; x < MODEL_INPUT_W; x++) {
            const pixelIdx = (y * MODEL_INPUT_W + x) * 4;
            const tensorIdx = y * MODEL_INPUT_W + x;

            // 정규화: (val - 127) / 128
            tensorData[0 * MODEL_INPUT_H * MODEL_INPUT_W + tensorIdx] = 
                (pixels[pixelIdx + 0] - 127.0) / 128.0;  // R
            tensorData[1 * MODEL_INPUT_H * MODEL_INPUT_W + tensorIdx] = 
                (pixels[pixelIdx + 1] - 127.0) / 128.0;  // G
            tensorData[2 * MODEL_INPUT_H * MODEL_INPUT_W + tensorIdx] = 
                (pixels[pixelIdx + 2] - 127.0) / 128.0;  // B
        }
    }

    const inputTensor = new ort.Tensor(
        'float32', tensorData, 
        [1, 3, MODEL_INPUT_H, MODEL_INPUT_W]
    );

    // 추론 실행
    const results = await session.run({ input: inputTensor });
    
    // 얼굴 좌표 디코딩 및 반환...
    return JSON.stringify(detectedFaces);
}
```

---

## 🎨 Flutter UI: 모든 것을 하나로

UI는 직관적이면서도 수동 영역 선택과 같은 고급 기능을 제공하도록 설계되었습니다.

```dart
// lib/presentation/home/home_screen.dart

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ImageProcessingService _imageProcessingService = 
      ImageProcessingService();

  Uint8List? _originalBytes;
  Uint8List? _currentBytes;
  ui.Image? _decodedImage;
  List<MyFace> _faces = [];
  final Set<int> _selectedIndices = {};
  bool _isProcessing = false;
  bool _isDrawingMode = false;
  BlurShape _blurShape = BlurShape.rectangle;

  Future<void> _pickAndDetect() async {
    setState(() => _isProcessing = true);

    final result = await _imageProcessingService.pickAndDetectFaces();

    if (result != null) {
      setState(() {
        _originalBytes = result.bytes;
        _currentBytes = result.bytes;
        _decodedImage = result.decodedImage;
        _faces = result.faces;
        _selectedIndices.clear();
      });
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _blurSelectedFaces() async {
    if (_currentBytes == null || _selectedIndices.isEmpty) return;

    setState(() => _isProcessing = true);

    final newBytes = await _imageProcessingService.blurSelectedFaces(
      imageBytes: _currentBytes!,
      faces: _faces,
      selectedIndices: _selectedIndices,
      blurShape: _blurShape,
    );

    if (newBytes != null) {
      final newDecodedImage = await decodeImageFromList(newBytes);
      setState(() {
        _currentBytes = newBytes;
        _decodedImage = newDecodedImage;
        _selectedIndices.clear();
      });
    }

    setState(() => _isProcessing = false);
  }
  // ... 나머지 구현
}
```

### 플랫폼 인식 서비스 레이어

`ImageProcessingService`는 플랫폼 간의 차이를 우아하게 처리합니다.

```dart
// lib/domain/services/image_processing_service.dart

class ImageProcessingService {
  Future<PickedImageResult?> pickAndDetectFaces() async {
    final XFile? imageFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (imageFile == null) return null;

    // ... 이미지 로딩 코드 ...

    List<MyFace> detectedFaces = [];

    if (kIsWeb) {
      // Web: JavaScript 상호 운용성을 통한 ONNX Runtime Web
      final webRects = await WebFaceService.detectFaces(bytes);
      detectedFaces = webRects.map((r) => MyFace(r)).toList();
      
    } else if (defaultTargetPlatform == TargetPlatform.android ||
               defaultTargetPlatform == TargetPlatform.iOS) {
      // Mobile: Google ML Kit
      final inputImage = InputImage.fromFilePath(finalImageFile.path);
      final options = FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
      );
      final faceDetector = FaceDetector(options: options);
      final mlFaces = await faceDetector.processImage(inputImage);
      await faceDetector.close();
      detectedFaces = mlFaces.map((f) => MyFace(f.boundingBox)).toList();
      
    } else {
      // Desktop: Rust ONNX
      final modelData = await rootBundle.load(
        'assets/models/version-RFB-640.onnx',
      );
      final modelBytes = modelData.buffer.asUint8List();
      final rustRects = await detectFacesDesktop(
        imageBytes: bytes,
        modelBytes: modelBytes,
      );
      detectedFaces = rustRects
          .map((r) => MyFace(Rect.fromLTWH(
            r.x.toDouble(),
            r.y.toDouble(),
            r.w.toDouble(),
            r.h.toDouble(),
          )))
          .toList();
    }

    return PickedImageResult(bytes, decodedImage, detectedFaces);
  }
}
```

---

## 🔧 주요 구현 세부 사항

### 1. ONNX 모델

정확도와 속도 사이에서 균형이 뛰어난 **RetinaFace RFB-640** 모델(`version-RFB-640.onnx`)을 사용하고 있습니다.

- **입력 크기**: 640×480 픽셀
- **출력**: 신뢰도 점수 및 바운딩 박스
- **최적화 대상**: 일반적인 얼굴 감지 시나리오

### 2. Flutter-Rust Bridge 설정

```yaml
# flutter_rust_bridge.yaml
dart_root: lib/src/rust
```

이 브리지는 `#[frb]`로 표시된 모든 Rust 함수에 대해 타입 안전(type-safe)한 Dart 바인딩을 생성합니다.

```rust
#[frb(dart_metadata=("freezed"))]
pub struct BlurRect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}
```

### 3. 수동 영역 선택

자동 감지가 얼굴을 놓치거나(혹은 사용자가 얼굴이 아닌 영역을 지우고 싶을 때)를 대비해 수동 그리기 기능을 구현했습니다.

```dart
void _startDrawing(DragStartDetails details) {
  setState(() {
    _drawStartPoint = details.localPosition / _currentScaleFactor;
    _currentDrawRect = null;
  });
}

void _updateDrawing(DragUpdateDetails details) {
  if (_drawStartPoint == null) return;
  
  final currentPoint = details.localPosition / _currentScaleFactor;
  setState(() {
    _currentDrawRect = Rect.fromPoints(_drawStartPoint!, currentPoint);
  });
}

void _endDrawing(DragEndDetails details) {
  if (_currentDrawRect != null &&
      _currentDrawRect!.width.abs() > 10 &&
      _currentDrawRect!.height.abs() > 10) {
    
    // 정규화된 직사각형 생성
    final normalizedRect = Rect.fromLTRB(/* ... */);

    setState(() {
      // 수동 추가로 표시
      _faces.add(MyFace(normalizedRect, isManual: true));
      _selectedIndices.add(_faces.length - 1);  // 자동 선택
    });
  }
  // 그리기 상태 초기화...
}
```

---

## 📊 성능 고려 사항

| 플랫폼 | 얼굴 감지 시간 | 블러 처리 시간 (얼굴 5개) |
|----------|--------------------|--------------------|
| macOS (M1) | ~150ms | ~80ms |
| Windows (i7) | ~200ms | ~100ms |
| iOS (iPhone 13) | ~50ms | ~60ms |
| Android (Pixel 6) | ~60ms | ~70ms |
| Web (Chrome) | ~300ms | ~150ms |

> **참고**: 시간은 이미지 크기와 기기 사양에 따라 달라질 수 있는 대략적인 값입니다.

---

## 🚀 시작하기

### 필수 조건

1. **Flutter SDK** (3.x 이상)
2. **Rust 툴체인** (Rust 라이브러리 빌드용)
3. **플랫폼별 빌드 도구**:
   - macOS: Xcode
   - Windows: C++ 워크로드가 포함된 Visual Studio 2022
   - Linux: `build-essential`, `pkg-config`

### 설치

```bash
# 저장소 복제
git clone https://github.com/jaichangpark/face_blur_pro.git
cd face_blur_pro

# Flutter 의존성 설치
flutter pub get

# 원하는 플랫폼에서 실행
flutter run -d macos    # macOS
flutter run -d chrome   # Web
flutter run             # 연결된 모바일 기기
```

---

## 🎓 배운 점

1. **플랫폼 추상화가 핵심입니다**: 깔끔한 인터페이스 뒤로 플랫폼 간의 차이를 숨기도록 서비스를 설계하세요.
2. **Rust + Flutter = ❤️**: `flutter_rust_bridge` 덕분에 FFI 사용이 놀랍도록 쾌적합니다.
3. **ONNX는 휴대성이 매우 뛰어납니다**: 동일한 모델이 Rust, WebAssembly, TensorFlow.js에서 모두 작동합니다.
4. **개인정보 보호는 중요합니다**: 사용자는 데이터가 절대 기 밖으로 나가지 않는다는 사실을 좋아합니다.

---

## 🔮 향후 개선 사항

- [ ] 실시간 비디오 블러 지원
- [ ] 특정 인물만 선택적으로 블러 처리하기 위한 얼굴 인식
- [ ] 여러 이미지 일괄 처리 (배치 프로세싱)
- [ ] 커스텀 블러 효과 (픽셀화, 이모티콘 오버레이)

---

## 📝 결론

크로스 플랫폼 얼굴 블러 애플리케이션을 만들면서, 최신 도구들 덕분에 진정한 "한 번 작성하여 어디서나 실행(write once, run anywhere)"하는 개발이 현실이 되었음을 깨달았습니다. Flutter의 UI 기능, Rust의 성능, ONNX의 휴대성을 사려 깊게 결합함으로써, 우리는 어디서나 동작하면서도 개인정보를 존중하는 애플리케이션을 만들 수 있습니다.

전체 소스 코드는 [GitHub](https://github.com/jaichangpark/face_blur_pro)에서 확인할 수 있습니다. 스타(⭐)와 포크(Fork), 그리고 기여(Contribute)는 언제나 환영입니다!

---

*Flutter, Rust, 그리고 ONNX로 ❤️을 담아 만들었습니다 — [Antigravity](https://antigravity.google/) + Gemini 3 제공*

*☁️ 이 프로젝트를 위해 Google Cloud 크레딧이 제공되었습니다. #AISprint*

---

**태그**: #Flutter #Rust #ONNX #MachineLearning #Privacy #CrossPlatform #FaceDetection #ImageProcessing

**더 많은 Flutter + Rust 콘텐츠를 보려면 팔로우하세요!**
