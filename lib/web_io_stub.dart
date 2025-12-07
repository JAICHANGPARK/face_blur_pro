import 'dart:typed_data';

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
}

class File {
  final String path;
  File(this.path);
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<void> writeAsBytes(List<int> bytes) async {}
  Directory get parent => Directory('');
}

class Directory {
  final String path;
  Directory(this.path);
  Future<bool> exists() async => true;
  Future<void> create({bool recursive = false}) async {}
}
