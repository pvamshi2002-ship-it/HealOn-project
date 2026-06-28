// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

class ReimbursementUpload {
  const ReimbursementUpload({required this.fileName, required this.dataUrl});

  final String fileName;
  final String dataUrl;
}

Future<ReimbursementUpload?> pickReimbursementPdf() async {
  final completer = Completer<ReimbursementUpload?>();
  final input = html.FileUploadInputElement()..accept = 'application/pdf,.pdf';

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completer.complete(null);
      return;
    }
    if (file.type != 'application/pdf' &&
        !file.name.toLowerCase().endsWith('.pdf')) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      final result = reader.result;
      completer.complete(
        result is String
            ? ReimbursementUpload(fileName: file.name, dataUrl: result)
            : null,
      );
    });
    reader.onError.first.then((_) => completer.complete(null));
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
