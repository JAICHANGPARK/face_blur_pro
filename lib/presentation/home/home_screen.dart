import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:my_app/data/models/my_face.dart';
import 'package:my_app/domain/services/image_processing_service.dart';
import 'package:my_app/presentation/home/widgets/face_box_painter.dart';
import 'package:my_app/l10n/app_localizations.dart';

import 'package:my_app/main.dart';



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



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

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

          SnackBar(content: Text(AppLocalizations.of(context)!.blurComplete)));

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

          content: Text(success

              ? AppLocalizations.of(context)!.saveSuccess

              : AppLocalizations.of(context)!.saveFailure),

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

              onPressed: _saveToGallery,

              icon: const Icon(Icons.save_alt, color: Colors.black),

              tooltip: localizations.save,

            ),

            TextButton(

              onPressed: _toggleSelectAll,

              child: Text(isAllSelected

                  ? localizations.deselectAll

                  : localizations.selectAll),

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



                          return InteractiveViewer(

                            transformationController: _transformationController,

                            minScale: 0.5,

                            maxScale: 10.0,

                            boundaryMargin: const EdgeInsets.all(50),

                            child: Center(

                              child: SizedBox(

                                width: renderedW,

                                height: renderedH,

                                child: GestureDetector(

                                  onTapUp: (details) =>

                                      _handleTap(details, scaleFactor),

                                  child: Stack(

                                    children: [

                                      Image.memory(

                                        _currentBytes!,

                                        width: renderedW,

                                        height: renderedH,

                                        fit: BoxFit.contain,

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

                              child:

                                  const Icon(Icons.add, color: Colors.black),

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

                const SizedBox(width: 10),

                Expanded(

                  child: ElevatedButton.icon(

                    onPressed: (_isProcessing || _selectedIndices.isEmpty)

                        ? null

                        : _blurSelectedFaces,

                    icon: const Icon(Icons.blur_on),

                    label: Text(

                        "${localizations.applyBlurButton} (${_selectedIndices.length})"),

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


