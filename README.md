# Face Blur Pro

Face Blur Pro is a cross-platform Flutter application designed to enhance privacy by detecting and blurring faces in images. It demonstrates a powerful hybrid architecture, leveraging on-device ML for mobile and a Rust-based backend for desktop performace.

## ✨ Key Features

*   **Cross-Platform Support**: Runs smoothly on Android, iOS, macOS, Windows, and Linux.
*   **Hybrid Face Detection**:
    *   **Mobile (Android/iOS)**: Utilizes Google ML Kit for fast, efficient on-device detection.
    *   **Desktop (macOS/Windows/Linux)**: Powered by a Rust backend using `tract-onnx` and the `version-RFB-640.onnx` model for robust detection.
*   **Privacy-First**: All processing is performed locally on your device. No images are ever uploaded to the cloud.
*   **Rust-Powered Image Processing**: Uses the `image` crate in Rust for high-performance pixel manipulation and blurring.
*   **Flexible Blurring**: Choose between **Rectangular** or **Circular** blur shapes to suit your aesthetic needs.
*   **Share & Save**: Easily save your edited images to the gallery or share them directly with other apps.

## 🛠️ Tech Stack

*   **Frontend**: [Flutter](https://flutter.dev/) (Dart)
*   **Backend**: [Rust](https://www.rust-lang.org/)
*   **Bridge**: [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) connects Dart and Rust.
*   **Mobile ML**: `google_mlkit_face_detection`
*   **Desktop ML**: `tract-onnx` (ONNX Runtime in pure Rust)
*   **Image Processing**: `image` crate (Rust)

## 🚀 Installation & Setup

### Prerequisites

Ensure you have the following installed on your system:

1.  **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install)
2.  **Rust Toolchain**: [Install Rust](https://www.rust-lang.org/tools/install)
3.  **C++ Build Tools**:
    *   **macOS**: Xcode (install via App Store or `xcode-select --install`)
    *   **Windows**: Visual Studio 2022 with "Desktop development with C++" workload.
    *   **Linux**: `build-essential`, `pkg-config`, `libgtk-3-dev` (depending on your distro).

### Steps

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/jaichangpark/face_blur_pro.git
    cd face_blur_pro
    ```

2.  **Install Flutter Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the App**:
    Connect your device or start a simulator/emulator, then run:
    ```bash
    flutter run
    ```
    *Note: The `flutter_rust_bridge` code generation usually happens automatically during the build process. If you encounter issues, refer to the project's `rust_builder` setup or run the codegen command if configured.*

## 📱 Usage Guide

1.  **Pick an Image**: Tap the **Gallery** icon to select a photo from your device.
2.  **Detect Faces**: The app will automatically run face detection. Detected faces will be highlighted with red boxes.
3.  **Select Faces**: Tap on any red box to select that face for blurring. Selected faces will turn **Green**.
4.  **Choose Blur Style**: Toggle between **Circle** and **Rectangle** icons in the bottom toolbar to change the blur shape.
5.  **Apply Blur**: Tap the **Blur** button (droplet icon). The selected areas will be blurred visually.
6.  **Save/Share**:
    *   Tap the **Save** icon (disk) to save the image to your gallery.
    *   Tap the **Share** icon to send the image to another app.

## 📂 Project Structure

*   `lib/`: Flutter (Dart) code for UI and app logic.
    *   `main.dart`: Entry point and main screen logic.
    *   `src/rust/`: Generated bridge code.
*   `rust/`: Rust code for heavy lifting.
    *   `src/api/simple.rs`: Core logic for face detection (Desktop) and image blurring.
*   `assets/models/`: ONNX models used for desktop face detection.

## 📄 License

This project is open-source. See the LICENSE file for details.
