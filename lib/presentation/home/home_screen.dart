import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:my_app/data/models/my_face.dart';
import 'package:my_app/domain/services/image_processing_service.dart';
import 'package:my_app/domain/services/tutorial_service.dart';
import 'package:my_app/presentation/home/widgets/face_box_painter.dart';
import 'package:my_app/l10n/app_localizations.dart';

import 'package:my_app/main.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ImageProcessingService _imageProcessingService =
      ImageProcessingService();

  final TransformationController _transformationController =
      TransformationController();

  Uint8List? _originalBytes;

  Uint8List? _currentBytes;

  ui.Image? _decodedImage;

  List<MyFace> _faces = [];

  final Set<int> _selectedIndices = {};

  bool _isProcessing = false;

  bool _showOutlines = true;

  BlurShape _blurShape = BlurShape.rectangle;

  // 수동 그리기 모드
  bool _isDrawingMode = false;
  Offset? _drawStartPoint;
  Rect? _currentDrawRect;
  double _currentScaleFactor = 1.0;

  // Tutorial Keys
  final GlobalKey _openPhotoKey = GlobalKey();
  final GlobalKey _blurButtonKey = GlobalKey();
  final GlobalKey _shapeButtonKey = GlobalKey();
  final GlobalKey _drawingButtonKey = GlobalKey();
  final GlobalKey _saveButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // 튜토리얼 확인 (화면 빌드 후 실행)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final bool isShown = await TutorialService.isTutorialShown();
    if (!isShown && mounted) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    final localizations = AppLocalizations.of(context)!;

    // 타겟 정의
    List<TargetFocus> targets = [];

    // 1. 사진 열기 버튼
    targets.add(
      TargetFocus(
        identify: "openPhoto",
        keyTarget: _openPhotoKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    localizations.tutorialOpenPhoto,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 이미지가 아직 로드되지 않은 상태에서 튜토리얼을 시작하므로,
    // 이미지가 로드된 후에 보여져야 할 요소들은
    // 사용자가 이미지를 불러온 후에 추가적인 튜토리얼을 보여주거나,
    // 설명만 하고 넘어가는 방식을 택해야 합니다.
    // 여기서는 주요 기능의 위치를 미리 알려주는 방식으로 구성합니다.

    // 2. 그리기 모드 버튼
    // (초기 상태에서도 버튼은 보이지만 비활성화 되어 있을 수 있음.
    // 하지만 UI 위치를 알려주는 것이 목적이므로 포함)
    targets.add(
      TargetFocus(
        identify: "drawingMode",
        keyTarget: _drawingButtonKey, // 그리기 버튼 키
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    localizations.tutorialDrawMode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 3. 블러 모양 변경 버튼
    targets.add(
      TargetFocus(
        identify: "blurShape",
        keyTarget: _shapeButtonKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    localizations.tutorialBlurShape,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 4. 블러 실행 버튼
    targets.add(
      TargetFocus(
        identify: "applyBlur",
        keyTarget: _blurButtonKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    localizations.tutorialApplyBlur,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 5. 저장 버튼
    targets.add(
      TargetFocus(
        identify: "saveButton",
        keyTarget: _saveButtonKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    localizations.tutorialSave,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: localizations.tutorialSkip,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        TutorialService.setTutorialShown();
      },
      onClickTarget: (target) {
        // 타겟 클릭 시 동작 (필요 시 구현)
      },
      onSkip: () {
        TutorialService.setTutorialShown();
        return true;
      },
      onClickOverlay: (target) {
        // 오버레이 클릭 시 다음으로 넘어감 (기본값)
      },
    ).show(context: context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _transformationController.dispose();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _transformationController.value != Matrix4.identity()) {
        setState(() {
          _transformationController.value = Matrix4.identity();
        });
      }
    });
  }

  Future<void> _pickAndDetect() async {
    setState(() => _isProcessing = true);

    final result = await _imageProcessingService.pickAndDetectFaces();

    if (result != null) {
      if (!mounted) return;

      setState(() {
        _originalBytes = result.bytes;

        _currentBytes = result.bytes;

        _decodedImage = result.decodedImage;

        _faces = result.faces;

        _selectedIndices.clear();

        _transformationController.value = Matrix4.identity();

        _showOutlines = true;
      });
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _resetImage() async {
    if (_originalBytes == null) return;

    final originalDecoded = await decodeImageFromList(_originalBytes!);

    setState(() {
      _currentBytes = _originalBytes;

      _decodedImage = originalDecoded;

      _selectedIndices.clear();

      _transformationController.value = Matrix4.identity();
    });
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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.blurComplete)),
      );
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _shareImage() async {
    await _imageProcessingService.shareImage(_currentBytes);
  }

  Future<void> _saveToGallery() async {
    final success = await _imageProcessingService.saveImage(_currentBytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? AppLocalizations.of(context)!.saveSuccess
                : AppLocalizations.of(context)!.saveFailure,
          ),
        ),
      );
    }
  }

  void _zoom(bool zoomIn) {
    final matrix = _transformationController.value.clone();

    final double scaleFactor = zoomIn ? 1.2 : 0.8;

    matrix.multiply(Matrix4.diagonal3Values(scaleFactor, scaleFactor, 1.0));

    _transformationController.value = matrix;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _faces.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.clear();

        for (int i = 0; i < _faces.length; i++) {
          _selectedIndices.add(i);
        }
      }
    });
  }

  void _handleTap(TapUpDetails details, double scaleFactor) {
    if (_faces.isEmpty) return;

    final double localX = details.localPosition.dx / scaleFactor;
    final double localY = details.localPosition.dy / scaleFactor;

    for (int i = 0; i < _faces.length; i++) {
      if (_faces[i].boundingBox.contains(Offset(localX, localY))) {
        setState(() {
          if (_selectedIndices.contains(i)) {
            _selectedIndices.remove(i);
          } else {
            _selectedIndices.add(i);
          }
        });
        break;
      }
    }
  }

  // 수동 그리기 시작
  void _startDrawing(DragStartDetails details) {
    setState(() {
      _drawStartPoint = details.localPosition / _currentScaleFactor;
      _currentDrawRect = null;
    });
  }

  // 그리기 업데이트 (실시간 미리보기)
  void _updateDrawing(DragUpdateDetails details) {
    if (_drawStartPoint == null) return;

    final currentPoint = details.localPosition / _currentScaleFactor;
    setState(() {
      _currentDrawRect = Rect.fromPoints(_drawStartPoint!, currentPoint);
    });
  }

  // 그리기 완료
  void _endDrawing(DragEndDetails details) {
    if (_currentDrawRect != null &&
        _currentDrawRect!.width.abs() > 10 &&
        _currentDrawRect!.height.abs() > 10) {
      // 정규화된 Rect 생성 (음수 width/height 방지)
      final normalizedRect = Rect.fromLTRB(
        _currentDrawRect!.left < _currentDrawRect!.right
            ? _currentDrawRect!.left
            : _currentDrawRect!.right,
        _currentDrawRect!.top < _currentDrawRect!.bottom
            ? _currentDrawRect!.top
            : _currentDrawRect!.bottom,
        _currentDrawRect!.left > _currentDrawRect!.right
            ? _currentDrawRect!.left
            : _currentDrawRect!.right,
        _currentDrawRect!.top > _currentDrawRect!.bottom
            ? _currentDrawRect!.top
            : _currentDrawRect!.bottom,
      );

      setState(() {
        _faces.add(MyFace(normalizedRect, isManual: true));
        _selectedIndices.add(_faces.length - 1); // 자동 선택
      });
    }

    setState(() {
      _drawStartPoint = null;
      _currentDrawRect = null;
    });
  }

  // 수동 영역 삭제
  void _deleteManualRegion(int index) {
    if (index < 0 || index >= _faces.length) return;
    if (!_faces[index].isManual) return; // 자동 감지된 건 삭제 불가

    setState(() {
      _faces.removeAt(index);
      _selectedIndices.remove(index);
      // 인덱스 재조정
      final newSelected = <int>{};
      for (final i in _selectedIndices) {
        if (i > index) {
          newSelected.add(i - 1);
        } else {
          newSelected.add(i);
        }
      }
      _selectedIndices.clear();
      _selectedIndices.addAll(newSelected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllSelected =
        _faces.isNotEmpty && _selectedIndices.length == _faces.length;

    final bool hasImage = _currentBytes != null;

    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: Text(
          localizations.appTitle,

          style: const TextStyle(color: Colors.black),
        ),

        backgroundColor: Colors.white,

        elevation: 1,

        actions: [
          DropdownButton<Locale>(
            value: Localizations.localeOf(context),

            icon: const Icon(Icons.language, color: Colors.black),

            onChanged: (Locale? newLocale) {
              if (newLocale != null) {
                MyApp.of(context)?.changeLanguage(newLocale);
              }
            },

            items: const [
              DropdownMenuItem(value: Locale('en'), child: Text("English")),

              DropdownMenuItem(value: Locale('ja'), child: Text("日本語")),

              DropdownMenuItem(value: Locale('ko'), child: Text("한국어")),
            ],
          ),

          if (hasImage) ...[
            IconButton(
              key: _shapeButtonKey,
              icon: Icon(
                _blurShape == BlurShape.circle
                    ? Icons.circle
                    : Icons.crop_square,

                color: Colors.black,
              ),

              onPressed: () {
                setState(() {
                  _blurShape = _blurShape == BlurShape.circle
                      ? BlurShape.rectangle
                      : BlurShape.circle;
                });
              },

              tooltip: localizations.toggleBlurShape,
            ),

            IconButton(
              icon: Icon(
                _showOutlines ? Icons.visibility : Icons.visibility_off,

                color: _showOutlines ? Colors.blueAccent : Colors.grey,
              ),

              onPressed: () {
                setState(() => _showOutlines = !_showOutlines);
              },

              tooltip: localizations.toggleOutlines,
            ),

            // 그리기 모드 토글 버튼
            IconButton(
              key: _drawingButtonKey,
              icon: Icon(
                _isDrawingMode ? Icons.edit_off : Icons.edit,
                color: _isDrawingMode ? Colors.purpleAccent : Colors.black,
              ),
              onPressed: () {
                setState(() => _isDrawingMode = !_isDrawingMode);
              },
              tooltip: _isDrawingMode ? '그리기 모드 종료' : '수동 영역 추가',
            ),
            IconButton(
              onPressed: _resetImage,
              icon: const Icon(Icons.refresh, color: Colors.black),
              tooltip: localizations.reset,
            ),

            IconButton(
              onPressed: _shareImage,

              icon: const Icon(Icons.share, color: Colors.black),

              tooltip: localizations.share,
            ),

            IconButton(
              key: _saveButtonKey,
              onPressed: _saveToGallery,

              icon: const Icon(Icons.save_alt, color: Colors.black),

              tooltip: localizations.save,
            ),
          ],
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: !hasImage
                ? Center(
                    child: Text(
                      localizations.uploadPrompt,

                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (_decodedImage == null) return const SizedBox();

                          final double screenW = constraints.maxWidth;

                          final double screenH = constraints.maxHeight;

                          final double imgW = _decodedImage!.width.toDouble();

                          final double imgH = _decodedImage!.height.toDouble();

                          final double screenRatio = screenW / screenH;

                          final double imgRatio = imgW / imgH;

                          double renderedW, renderedH;

                          if (screenRatio > imgRatio) {
                            renderedH = screenH;

                            renderedW = screenH * imgRatio;
                          } else {
                            renderedW = screenW;

                            renderedH = screenW / imgRatio;
                          }

                          final double scaleFactor = renderedW / imgW;
                          // 현재 scaleFactor 저장 (그리기 모드용)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_currentScaleFactor != scaleFactor) {
                              _currentScaleFactor = scaleFactor;
                            }
                          });

                          return InteractiveViewer(
                            // 그리기 모드에서는 줌/팬 비활성화
                            panEnabled: !_isDrawingMode,
                            scaleEnabled: !_isDrawingMode,
                            transformationController: _transformationController,

                            minScale: 0.5,

                            maxScale: 10.0,

                            boundaryMargin: const EdgeInsets.all(50),

                            child: Center(
                              child: SizedBox(
                                width: renderedW,

                                height: renderedH,

                                child: GestureDetector(
                                  // 그리기 모드일 때는 드래그 제스처 사용
                                  onPanStart: _isDrawingMode
                                      ? _startDrawing
                                      : null,
                                  onPanUpdate: _isDrawingMode
                                      ? _updateDrawing
                                      : null,
                                  onPanEnd: _isDrawingMode ? _endDrawing : null,
                                  // 그리기 모드가 아닐 때만 탭 처리
                                  onTapUp: _isDrawingMode
                                      ? null
                                      : (details) =>
                                            _handleTap(details, scaleFactor),
                                  // 길게 눌러서 수동 영역 삭제
                                  onLongPressStart: (details) {
                                    final double localX =
                                        details.localPosition.dx / scaleFactor;
                                    final double localY =
                                        details.localPosition.dy / scaleFactor;
                                    for (int i = 0; i < _faces.length; i++) {
                                      if (_faces[i].isManual &&
                                          _faces[i].boundingBox.contains(
                                            Offset(localX, localY),
                                          )) {
                                        _deleteManualRegion(i);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('수동 영역이 삭제되었습니다'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                        break;
                                      }
                                    }
                                  },

                                  child: Stack(
                                    children: [
                                      Image.memory(
                                        _currentBytes!,

                                        width: renderedW,

                                        height: renderedH,

                                        fit: BoxFit.fill,

                                        gaplessPlayback: true,
                                      ),

                                      CustomPaint(
                                        size: Size(renderedW, renderedH),

                                        painter: FaceBoxPainter(
                                          faces: _faces,
                                          selectedIndices: _selectedIndices,
                                          scaleFactor: scaleFactor,
                                          showOutlines: _showOutlines,
                                          blurShape: _blurShape,
                                          currentDrawRect: _currentDrawRect,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      if (_isProcessing)
                        Container(
                          color: Colors.black45,

                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),

                      Positioned(
                        right: 20,

                        bottom: 20,

                        child: Column(
                          children: [
                            FloatingActionButton(
                              heroTag: "zoom_in",

                              mini: true,

                              onPressed: () => _zoom(true),

                              backgroundColor: Colors.white,

                              child: const Icon(Icons.add, color: Colors.black),
                            ),

                            const SizedBox(height: 10),

                            FloatingActionButton(
                              heroTag: "zoom_out",

                              mini: true,

                              onPressed: () => _zoom(false),

                              backgroundColor: Colors.white,

                              child: const Icon(
                                Icons.remove,

                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          Container(
            padding: const EdgeInsets.all(16),

            color: Colors.white,

            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: _openPhotoKey,
                    onPressed: _isProcessing ? null : _pickAndDetect,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(localizations.openPhotoButton),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                // 전체 선택 버튼 (이미지가 있을 때만 표시)
                if (hasImage && _faces.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _toggleSelectAll,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      side: BorderSide(
                        color: isAllSelected ? Colors.green : Colors.grey,
                      ),
                    ),
                    child: Text(
                      isAllSelected
                          ? localizations.deselectAll
                          : localizations.selectAll,
                      style: TextStyle(
                        color: isAllSelected ? Colors.green : Colors.grey[700],
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton.icon(
                    key: _blurButtonKey,
                    onPressed: (_isProcessing || _selectedIndices.isEmpty)
                        ? null
                        : _blurSelectedFaces,
                    icon: const Icon(Icons.blur_on),
                    label: Text(
                      "${localizations.applyBlurButton} (${_selectedIndices.length})",
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
