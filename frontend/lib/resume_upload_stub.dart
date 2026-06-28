class ResumeUpload {
  const ResumeUpload({required this.fileName, required this.dataUrl});

  final String fileName;
  final String dataUrl;
}

Future<ResumeUpload?> pickResumeFile() async => null;
