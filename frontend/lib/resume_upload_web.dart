// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

class ResumeUpload {
  const ResumeUpload({required this.fileName, required this.dataUrl});

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
];

bool _isAllowedResume(html.File file) {
  final lowerName = file.name.toLowerCase();
  if (_allowedExtensions.any(lowerName.endsWith)) return true;
  return file.type == 'application/pdf' ||
      file.type.startsWith('image/') ||
      file.type.contains('word');
}

Future<ResumeUpload?> pickResumeFile() async {
  final completer = Completer<ResumeUpload?>();
  final input = html.FileUploadInputElement()
    ..accept =
        '.pdf,.doc,.docx,.jpg,.jpeg,.png,application/pdf,image/*,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completer.complete(null);
      return;
    }
    if (!_isAllowedResume(file)) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      final result = reader.result;
      completer.complete(
        result is String
            ? ResumeUpload(fileName: file.name, dataUrl: result)
            : null,
      );
    });
    reader.onError.first.then((_) => completer.complete(null));
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
