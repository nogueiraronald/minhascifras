import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<bool> saveFileToDevice(String fileName, Uint8List bytes) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Salvar ZIP',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['zip'],
    bytes: bytes,
  );
  if (path == null) return false;
  final desktop = (defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux);
  if (desktop) {
    await File(path).writeAsBytes(bytes);
  }
  return true;
}
