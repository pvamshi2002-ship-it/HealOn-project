import 'dart:typed_data';

import 'payslip_download_stub.dart'
    if (dart.library.html) 'payslip_download_web.dart';

void downloadPdfFile(Uint8List bytes, String filename) {
  downloadPdfFileImpl(bytes, filename);
}
