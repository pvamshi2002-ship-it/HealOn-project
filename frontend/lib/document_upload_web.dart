// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

class DocumentUpload {
  const DocumentUpload({required this.fileName, required this.dataUrl});

  final String fileName;
  final String dataUrl;
}

const _allowedExtensions = [
  '.pdf',
  '.doc',
  '.docx',
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
];

bool _isAllowedDocument(html.File file) {
  final lowerName = file.name.toLowerCase();
  if (_allowedExtensions.any(lowerName.endsWith)) {
    return true;
  }
  return file.type.startsWith('image/') || file.type == 'application/pdf';
}

Future<DocumentUpload?> pickEmployeeDocument() async {
  final completer = Completer<DocumentUpload?>();
  final input = html.FileUploadInputElement()
    ..accept =
        '.pdf,.doc,.docx,.jpg,.jpeg,.png,.webp,application/pdf,image/*';

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completer.complete(null);
      return;
    }
    if (!_isAllowedDocument(file)) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      final result = reader.result;
      completer.complete(
        result is String
            ? DocumentUpload(fileName: file.name, dataUrl: result)
            : null,
      );
    });
    reader.onError.first.then((_) => completer.complete(null));
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
