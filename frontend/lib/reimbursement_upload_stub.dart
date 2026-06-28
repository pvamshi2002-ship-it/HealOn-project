class ReimbursementUpload {
  const ReimbursementUpload({required this.fileName, required this.dataUrl});

  final String fileName;
  final String dataUrl;
}

Future<ReimbursementUpload?> pickReimbursementPdf() async => null;
