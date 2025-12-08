# Building a Cross-Platform Face Blur App with Flutter, Rust, and ONNX

## A Deep Dive into Hybrid Architecture for Privacy-First Image Processing

![Face Blur Pro Banner](https://img.shields.io/badge/Built%20with-Flutter%20%2B%20Rust-blue)

**TL;DR:** I built a cross-platform face detection and blurring application that runs on iOS, Android, macOS, Windows, Linux, and Web — all from a single codebase. The secret sauce? A hybrid architecture that leverages Google ML Kit for mobile, Rust + ONNX for desktop, and ONNX Runtime Web for browsers. All processing happens on-device, ensuring complete privacy.

---

## 🎯 The Problem: Privacy in the Age of Image Sharing

We live in an era where sharing photos is second nature. But what happens when you want to share an image that contains faces of people who haven't consented? Whether it's a street photography shot, a conference photo, or content for your blog, blurring faces is often a necessity.

Most solutions fall into one of these categories:
- **Cloud-based services**: Fast but privacy-concerning — your images get uploaded to someone else's servers
- **Platform-specific apps**: Great but limited to one ecosystem
- **Web-only tools**: Convenient but often require internet connectivity

I wanted something different: **a truly cross-platform, privacy-first solution** where all processing happens locally on the device.

---

## 🏗️ Architecture Overview

The architecture might look complex at first glance, but it's actually quite elegant once you understand the reasoning behind each choice:

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

**Why this approach?**

| Platform | Face Detection | Blur Processing | Rationale |
|----------|---------------|-----------------|-----------|
| **Mobile** | Google ML Kit | Rust FFI | ML Kit is highly optimized for mobile SoCs |
| **Desktop** | ONNX (Rust) | Rust FFI | No ML Kit on desktop, but Rust is blazingly fast |
| **Web** | ONNX Runtime Web | Canvas API | WebAssembly enables near-native performance |

---

## 🛠️ Tech Stack Deep Dive

### Flutter: The Unifying Layer

Flutter serves as the presentation layer, providing a beautiful, consistent UI across all platforms. Here's the entry point:

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Rust library only on non-web platforms
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

The conditional initialization is crucial — on web platforms, we can't use FFI to call Rust code, so we skip it entirely and rely on JavaScript interop instead.

### Rust: The Performance Backbone

For desktop face detection and image blurring across all native platforms, I chose Rust. The `flutter_rust_bridge` library makes the FFI integration seamless.

Here's how face detection works in Rust using the `tract-onnx` crate:

```rust
// rust/src/api/simple.rs

pub fn detect_faces_desktop(
    image_bytes: Vec<u8>,
    model_bytes: Vec<u8>,
) -> anyhow::Result<Vec<BlurRect>> {
    let img = load_from_memory(&image_bytes)?;
    let (orig_w, orig_h) = img.dimensions();

    // Load and optimize the ONNX model
    let model = tract_onnx::onnx()
        .model_for_read(&mut Cursor::new(model_bytes))?
        .with_input_fact(0, f32::fact([1, 3, 480, 640]).into())?
        .into_optimized()?
        .into_runnable()?;

    // Resize image to model input dimensions (640x480)
    let resized = img.resize_exact(
        640, 480, 
        image::imageops::FilterType::Triangle
    );

    // Create tensor with normalized pixel values
    let tensor: Tensor = tract_ndarray::Array4::from_shape_fn(
        (1, 3, 480, 640), 
        |(_, c, y, x)| {
            let pixel = resized.get_pixel(x as u32, y as u32);
            let val = pixel[c as usize] as f32;
            (val - 127.0) / 128.0  // Normalization
        }
    ).into();

    let result = model.run(tvec!(tensor.into()))?;
    let confidences = result[0].to_array_view::<f32>()?;
    let boxes = result[1].to_array_view::<f32>()?;

    // Generate prior anchors and decode detections
    let priors = generate_priors_640();
    let mut detected_faces = Vec::new();

    for i in 0..priors.len() {
        let score = confidences[[0, i, 1]];
        if score > 0.6 {  // Score threshold
            // Decode bounding box coordinates...
            detected_faces.push(face);
        }
    }

    // Apply Non-Maximum Suppression
    let final_faces = hard_nms(detected_faces, 0.3);
    
    // Convert to BlurRect format
    Ok(final_faces.into_iter().map(|f| BlurRect { ... }).collect())
}
```

The **anchor box generation** and **Non-Maximum Suppression (NMS)** algorithms are critical for accurate face detection:

```rust
// Generate prior anchor boxes for the RFB-640 model
fn generate_priors_640() -> Vec<Prior> {
    let input_w = 640.0;
    let input_h = 480.0;

    // Feature map sizes at different scales
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

### The Blur Algorithm

Here's where the magic happens — the blur function supports both **rectangular** and **elliptical** blur shapes:

```rust
pub fn blur_multiple_faces(
    image_bytes: Vec<u8>,
    rects: Vec<BlurRect>,
    is_circle: bool,  // Shape selection parameter
) -> anyhow::Result<Vec<u8>> {
    let mut img = load_from_memory(&image_bytes)?;
    let (img_w, img_h) = (img.width() as i32, img.height() as i32);

    for rect in rects {
        let x = rect.x.max(0);
        let y = rect.y.max(0);
        let w = rect.w.min(img_w - x);
        let h = rect.h.min(img_h - y);

        // Crop the region and apply Gaussian blur
        let sub_img = img.crop_imm(x as u32, y as u32, w as u32, h as u32);
        let blurred = sub_img.blur(20.0);  // Blur intensity

        if is_circle {
            // Elliptical blur using the equation:
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
                        // Inside ellipse → apply blurred pixel
                        let pixel = blurred.get_pixel(dx as u32, dy as u32);
                        img.put_pixel((x + dx) as u32, (y + dy) as u32, pixel);
                    }
                    // Outside ellipse → keep original
                }
            }
        } else {
            // Rectangular blur - simple replacement
            image::imageops::replace(&mut img, &blurred, x as i64, y as i64);
        }
    }

    let mut result_bytes: Vec<u8> = Vec::new();
    img.write_to(&mut Cursor::new(&mut result_bytes), ImageFormat::Png)?;
    Ok(result_bytes)
}
```

---

## 🌐 Web Platform: ONNX Runtime Web

The web platform posed unique challenges. We can't use FFI, so I turned to **ONNX Runtime Web** — a JavaScript library that runs ONNX models directly in the browser using WebAssembly.

```javascript
// web/face_blur_web.js

const MODEL_INPUT_W = 640;
const MODEL_INPUT_H = 480;
const SCORE_THRESHOLD = 0.4;
const IOU_THRESHOLD = 0.3;

let session = null;
let priors = null;

/**
 * Initialize the ONNX model
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
 * Detect faces in a Base64-encoded image
 */
async function detectFacesWeb(base64ImageData) {
    await initFaceDetector();

    // Convert Base64 to Image
    const img = new Image();
    img.crossOrigin = 'anonymous';
    await new Promise((resolve, reject) => {
        img.onload = resolve;
        img.onerror = reject;
        img.src = 'data:image/png;base64,' + base64ImageData;
    });

    const origW = img.width;
    const origH = img.height;

    // Resize to model input dimensions
    const canvas = document.createElement('canvas');
    canvas.width = MODEL_INPUT_W;
    canvas.height = MODEL_INPUT_H;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, MODEL_INPUT_W, MODEL_INPUT_H);

    // Extract pixel data and create tensor (NCHW format)
    const imageData = ctx.getImageData(0, 0, MODEL_INPUT_W, MODEL_INPUT_H);
    const pixels = imageData.data;
    const tensorData = new Float32Array(1 * 3 * MODEL_INPUT_H * MODEL_INPUT_W);

    for (let y = 0; y < MODEL_INPUT_H; y++) {
        for (let x = 0; x < MODEL_INPUT_W; x++) {
            const pixelIdx = (y * MODEL_INPUT_W + x) * 4;
            const tensorIdx = y * MODEL_INPUT_W + x;

            // Normalize: (val - 127) / 128
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

    // Run inference
    const results = await session.run({ input: inputTensor });
    
    // Decode and return face coordinates...
    return JSON.stringify(detectedFaces);
}
```

---

## 🎨 The Flutter UI: Bringing It All Together

The UI is designed to be intuitive while providing power-user features like manual region selection:

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
  // ... rest of the implementation
}
```

### Platform-Aware Service Layer

The `ImageProcessingService` elegantly handles the platform differences:

```dart
// lib/domain/services/image_processing_service.dart

class ImageProcessingService {
  Future<PickedImageResult?> pickAndDetectFaces() async {
    final XFile? imageFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (imageFile == null) return null;

    // ... image loading code ...

    List<MyFace> detectedFaces = [];

    if (kIsWeb) {
      // Web: ONNX Runtime Web via JavaScript interop
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

## 🔧 Key Implementation Details

### 1. The ONNX Model

I'm using the **RetinaFace RFB-640** model (`version-RFB-640.onnx`), which offers a great balance between accuracy and speed:

- **Input size**: 640×480 pixels
- **Output**: Confidence scores and bounding boxes
- **Optimized for**: General face detection scenarios

### 2. Flutter-Rust Bridge Configuration

```yaml
# flutter_rust_bridge.yaml
dart_root: lib/src/rust
```

The bridge generates type-safe Dart bindings for all Rust functions marked with `#[frb]`:

```rust
#[frb(dart_metadata=("freezed"))]
pub struct BlurRect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}
```

### 3. Manual Region Selection

For cases where automatic detection misses faces (or users want to blur non-face regions), I implemented a manual drawing feature:

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
    
    // Create normalized rectangle
    final normalizedRect = Rect.fromLTRB(/* ... */);

    setState(() {
      // Mark as manually added
      _faces.add(MyFace(normalizedRect, isManual: true));
      _selectedIndices.add(_faces.length - 1);  // Auto-select
    });
  }
  // Reset drawing state...
}
```

---

## 📊 Performance Considerations

| Platform | Face Detection Time | Blur Time (5 faces) |
|----------|--------------------|--------------------|
| macOS (M1) | ~150ms | ~80ms |
| Windows (i7) | ~200ms | ~100ms |
| iOS (iPhone 13) | ~50ms | ~60ms |
| Android (Pixel 6) | ~60ms | ~70ms |
| Web (Chrome) | ~300ms | ~150ms |

> **Note**: Times are approximate and vary based on image size and device specifications.

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.x or higher)
2. **Rust toolchain** (for building the Rust library)
3. **Platform-specific build tools**:
   - macOS: Xcode
   - Windows: Visual Studio 2022 with C++ workload
   - Linux: `build-essential`, `pkg-config`

### Installation

```bash
# Clone the repository
git clone https://github.com/jaichangpark/face_blur_pro.git
cd face_blur_pro

# Install Flutter dependencies
flutter pub get

# Run on your preferred platform
flutter run -d macos    # macOS
flutter run -d chrome   # Web
flutter run             # Connected mobile device
```

---

## 🎓 Lessons Learned

1. **Platform abstraction is key**: Design your services to hide platform differences behind clean interfaces
2. **Rust + Flutter = ❤️**: The `flutter_rust_bridge` makes FFI surprisingly pleasant
3. **ONNX is incredibly portable**: The same model runs in Rust, WebAssembly, and TensorFlow.js
4. **Privacy matters**: Users appreciate knowing their data never leaves their device

---

## 🔮 Future Improvements

- [ ] Real-time video blur support
- [ ] Face recognition to selectively blur specific people
- [ ] Batch processing for multiple images
- [ ] Custom blur effects (pixelation, emoji overlay)

---

## 📝 Conclusion

Building a cross-platform face blur application taught me that modern tooling has made true "write once, run anywhere" development a reality. By thoughtfully combining Flutter's UI capabilities with Rust's performance and ONNX's portability, we can create privacy-respecting applications that work everywhere.

The complete source code is available on [GitHub](https://github.com/jaichangpark/face_blur_pro). Feel free to star ⭐, fork, and contribute!

---

*Built with ❤️ using Flutter, Rust, and ONNX — powered by [Antigravity](https://antigravity.google/) + Gemini 3*

*☁️ Google Cloud credits are provided for this project. #AISprint*

---

**Tags**: #Flutter #Rust #ONNX #MachineLearning #Privacy #CrossPlatform #FaceDetection #ImageProcessing

**Follow me for more Flutter + Rust content!**
