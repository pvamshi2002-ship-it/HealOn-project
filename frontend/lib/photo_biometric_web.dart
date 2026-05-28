// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class VerificationUpload {
  const VerificationUpload({required this.fileName, required this.dataUrl});

  final String fileName;
  final String dataUrl;
}

Future<String?> pickPhotoBiometric() async {
  final completer = Completer<String?>();
  html.MediaStream? stream;

  final overlay = html.DivElement()
    ..style.position = 'fixed'
    ..style.top = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.left = '0'
    ..style.zIndex = '999999'
    ..style.background = 'rgba(15, 23, 42, 0.72)'
    ..style.display = 'flex'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.padding = '20px';

  final panel = html.DivElement()
    ..style.width = 'min(92vw, 430px)'
    ..style.background = '#ffffff'
    ..style.borderRadius = '10px'
    ..style.boxShadow = '0 20px 45px rgba(0, 0, 0, 0.28)'
    ..style.padding = '16px'
    ..style.fontFamily = 'Arial, sans-serif';

  final title = html.DivElement()
    ..text = 'Photo biometric verification'
    ..style.fontSize = '18px'
    ..style.fontWeight = '700'
    ..style.color = '#1F2E5A'
    ..style.marginBottom = '10px';

  final video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..style.width = '100%'
    ..style.aspectRatio = '4 / 3'
    ..style.background = '#111827'
    ..style.borderRadius = '8px'
    ..style.objectFit = 'cover';

  final message = html.DivElement()
    ..text = 'Center your face and click Capture.'
    ..style.color = '#4B5563'
    ..style.fontSize = '13px'
    ..style.margin = '10px 0 14px';

  final actions = html.DivElement()
    ..style.display = 'flex'
    ..style.justifyContent = 'flex-end'
    ..style.gap = '10px';

  final cancelButton = html.ButtonElement()
    ..text = 'Cancel'
    ..style.padding = '10px 14px'
    ..style.border = '1px solid #D1D5DB'
    ..style.borderRadius = '7px'
    ..style.background = '#ffffff'
    ..style.cursor = 'pointer';

  final captureButton = html.ButtonElement()
    ..text = 'Capture'
    ..style.padding = '10px 16px'
    ..style.border = '0'
    ..style.borderRadius = '7px'
    ..style.background = '#1ABE8E'
    ..style.color = '#ffffff'
    ..style.fontWeight = '700'
    ..style.cursor = 'pointer';

  void close(String? result) {
    for (final track in stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    overlay.remove();
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  cancelButton.onClick.listen((_) => close(null));
  captureButton.onClick.listen((_) {
    if (video.videoWidth == 0 || video.videoHeight == 0) {
      message.text = 'Camera is still starting. Please try again.';
      return;
    }

    final canvas = html.CanvasElement(
      width: video.videoWidth,
      height: video.videoHeight,
    );
    canvas.context2D.drawImage(video, 0, 0);
    close(canvas.toDataUrl('image/jpeg', 0.86));
  });

  actions.children.addAll([cancelButton, captureButton]);
  panel.children.addAll([title, video, message, actions]);
  overlay.children.add(panel);
  html.document.body?.children.add(overlay);

  try {
    stream = await html.window.navigator.mediaDevices?.getUserMedia({
      'video': {'facingMode': 'user'},
      'audio': false,
    });
    if (stream == null) {
      message.text = 'Camera is not available in this browser.';
      captureButton.disabled = true;
    } else {
      video.srcObject = stream;
    }
  } catch (_) {
    message.text = 'Allow camera access to continue with biometric check.';
    captureButton.disabled = true;
  }

  return completer.future;
}

Future<VerificationUpload?> pickEmployeeVerificationUpload() async {
  final completer = Completer<VerificationUpload?>();
  final input = html.FileUploadInputElement()
    ..accept =
        'image/*,application/pdf,.pdf,.doc,.docx,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completer.complete(null);
      return;
    }

    final name = file.name.toLowerCase();
    final allowed =
        file.type.startsWith('image/') ||
        file.type == 'application/pdf' ||
        file.type == 'application/msword' ||
        file.type ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
        name.endsWith('.pdf') ||
        name.endsWith('.doc') ||
        name.endsWith('.docx');
    if (!allowed) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      final result = reader.result;
      completer.complete(
        result is String
            ? VerificationUpload(fileName: file.name, dataUrl: result)
            : null,
      );
    });
    reader.onError.first.then((_) => completer.complete(null));
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
