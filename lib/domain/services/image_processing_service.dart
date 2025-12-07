import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/data/models/my_face.dart';
import 'package:my_app/domain/services/web_face_service.dart';
import 'package:my_app/src/rust/api/simple.dart';
import 'dart:io' if (dart.library.html) 'package:my_app/web_io_stub.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

class PickedImageResult {
  final Uint8List bytes;
  final ui.Image decodedImage;
  final List<MyFace> faces;

  PickedImageResult(this.bytes, this.decodedImage, this.faces);
}

class ImageProcessingService {
  final ImagePicker _picker = ImagePicker();

  Future<PickedImageResult?> pickAndDetectFaces() async {
    final XFile? imageFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (imageFile == null) return null;

    try {
      dynamic finalImageFile;
      Uint8List bytes;

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        finalImageFile = await FlutterExifRotation.rotateImage(
          path: imageFile.path,
        );
        bytes = await finalImageFile.readAsBytes();
      } else {
        if (!kIsWeb) {
          finalImageFile = File(imageFile.path);
          bytes = await finalImageFile.readAsBytes();
        } else {
          finalImageFile = null;
          bytes = await imageFile.readAsBytes();
        }
      }

      // 웹에서 디코딩 오류가 발생할 수 있으므로 try-catch로 감싸고
      // instantiateImageCodec 대신 직접 ImmutableBuffer 사용
      ui.Image decodedImage;
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        decodedImage = frame.image;
      } catch (e) {
        debugPrint('Image decode error, trying fallback: $e');
        // Fallback: ImmutableBuffer 사용
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final codec = await descriptor.instantiateCodec();
        final frame = await codec.getNextFrame();
        decodedImage = frame.image;
      }

      List<MyFace> detectedFaces = [];

      if (kIsWeb) {
        // Web: TensorFlow.js 기반 얼굴 감지
        final webRects = await WebFaceService.detectFaces(bytes);
        detectedFaces = webRects.map((r) => MyFace(r)).toList();
      } else if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // Mobile: ML Kit 기반 얼굴 감지
        final inputImage = InputImage.fromFilePath(finalImageFile.path);
        final options = FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        );
        final faceDetector = FaceDetector(options: options);
        final mlFaces = await faceDetector.processImage(inputImage);
        await faceDetector.close();
        detectedFaces = mlFaces.map((f) => MyFace(f.boundingBox)).toList();
      } else {
        // Desktop: Rust ONNX 기반 얼굴 감지
        final modelData = await rootBundle.load(
          'assets/models/version-RFB-640.onnx',
        );
        final modelBytes = modelData.buffer.asUint8List();
        final rustRects = await detectFacesDesktop(
          imageBytes: bytes,
          modelBytes: modelBytes,
        );
        detectedFaces = rustRects
            .map(
              (r) => MyFace(
                Rect.fromLTWH(
                  r.x.toDouble(),
                  r.y.toDouble(),
                  r.w.toDouble(),
                  r.h.toDouble(),
                ),
              ),
            )
            .toList();
      }

      return PickedImageResult(bytes, decodedImage, detectedFaces);
    } catch (e) {
      debugPrint("Error picking and detecting faces: $e");
      return null;
    }
  }

  Future<Uint8List?> blurSelectedFaces({
    required Uint8List imageBytes,
    required List<MyFace> faces,
    required Set<int> selectedIndices,
    required BlurShape blurShape,
  }) async {
    if (selectedIndices.isEmpty) return null;

    try {
      final List<Rect> rectsToBlur = [];
      for (int index in selectedIndices) {
        rectsToBlur.add(faces[index].boundingBox);
      }

      if (kIsWeb) {
        // Web: Canvas API 기반 블러 처리
        return await WebFaceService.blurFaces(
          imageBytes: imageBytes,
          rects: rectsToBlur,
          isCircle: blurShape == BlurShape.circle,
        );
      } else {
        // Native: Rust 기반 블러 처리
        final List<BlurRect> rectsToSend = rectsToBlur
            .map(
              (r) => BlurRect(
                x: r.left.toInt(),
                y: r.top.toInt(),
                w: r.width.toInt(),
                h: r.height.toInt(),
              ),
            )
            .toList();

        return await blurMultipleFaces(
          imageBytes: imageBytes,
          rects: rectsToSend,
          isCircle: blurShape == BlurShape.circle,
        );
      }
    } catch (e) {
      debugPrint("Blur Error: $e");
      return null;
    }
  }

  Future<void> shareImage(Uint8List? imageBytes) async {
    if (imageBytes == null) return;
    try {
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                imageBytes,
                mimeType: 'image/png',
                name: 'face_blur.png',
              ),
            ],
            text: '블러 처리된 이미지입니다.',
          ),
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/shared_face_blur.png');
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsBytes(imageBytes);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: '블러 처리된 이미지입니다.'),
        );
      }
    } catch (e) {
      debugPrint("Share Error: $e");
    }
  }

  Future<bool> saveImage(Uint8List? imageBytes) async {
    if (imageBytes == null) return false;

    try {
      if (kIsWeb) {
        final String fileName =
            'face_blur_${DateTime.now().millisecondsSinceEpoch}.png';
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
        );
        if (result != null) {
          final XFile textFile = XFile.fromData(
            imageBytes,
            mimeType: 'image/png',
            name: fileName,
          );
          await textFile.saveTo(result.path);
          return true;
        }
        return false;
      } else if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          var status = await Permission.storage.status;
          if (!status.isGranted) await Permission.storage.request();
        }
        final result = await SaverGallery.saveImage(
          Uint8List.fromList(imageBytes),
          quality: 100,
          fileName: "face_blur_${DateTime.now().millisecondsSinceEpoch}",
          androidRelativePath: "Pictures/FaceBlurApp",
          skipIfExists: false,
        );
        return result.isSuccess == true;
      } else {
        final String fileName =
            'face_blur_${DateTime.now().millisecondsSinceEpoch}.png';
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
        );
        if (result != null) {
          final Uint8List fileData = Uint8List.fromList(imageBytes);
          final XFile textFile = XFile.fromData(
            fileData,
            mimeType: 'image/png',
            name: fileName,
          );
          await textFile.saveTo(result.path);
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      return false;
    }
  }
}
