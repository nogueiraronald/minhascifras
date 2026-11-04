import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<bool> saveFileToDevice(
  String fileName,
  Uint8List bytes, {
  String? mimeType,
}) async {
  final ext =
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  final isPdf = ext == 'pdf';
  final path = await FilePicker.platform.saveFile(
    dialogTitle: isPdf ? 'Salvar Cartão em PDF' : 'Salvar Arquivo',
    fileName: fileName,
    type: ext.isNotEmpty ? FileType.custom : FileType.any,
    allowedExtensions: ext.isNotEmpty ? [ext] : null,
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

