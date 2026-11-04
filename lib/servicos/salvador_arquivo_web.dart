// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> saveFileToDevice(
  String fileName,
  Uint8List bytes, {
  String? mimeType,
}) async {
  try {
    final type = mimeType ??
        (fileName.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : fileName.toLowerCase().endsWith('.zip')
                ? 'application/zip'
                : 'application/octet-stream');
    final blob = html.Blob([bytes], type);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}

