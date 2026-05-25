(function () {
  function setButtonStyle(button, primary) {
    button.style.border = primary ? '0' : '1px solid #d1d5db';
    button.style.borderRadius = '6px';
    button.style.cursor = 'pointer';
    button.style.fontWeight = primary ? '700' : '600';
    button.style.padding = '9px 12px';
    button.style.background = primary ? '#417690' : '#ffffff';
    button.style.color = primary ? '#ffffff' : '#1f2937';
  }

  function buildCaptureControls(textarea) {
    if (textarea.dataset.photoCaptureReady === 'true') return;
    textarea.dataset.photoCaptureReady = 'true';
    textarea.style.display = 'none';

    var wrapper = document.createElement('div');
    wrapper.className = 'healon-photo-capture-widget';
    wrapper.style.display = 'grid';
    wrapper.style.gap = '10px';
    wrapper.style.maxWidth = '420px';

    var video = document.createElement('video');
    video.autoplay = true;
    video.muted = true;
    video.playsInline = true;
    video.style.width = '100%';
    video.style.aspectRatio = '4 / 3';
    video.style.objectFit = 'cover';
    video.style.background = '#111827';
    video.style.border = '1px solid #d1d5db';
    video.style.borderRadius = '8px';
    video.style.display = 'none';

    var preview = document.createElement('img');
    preview.alt = 'Employee verification photo preview';
    preview.style.width = '160px';
    preview.style.height = '120px';
    preview.style.objectFit = 'cover';
    preview.style.border = '1px solid #d1d5db';
    preview.style.borderRadius = '8px';
    preview.style.display = textarea.value ? 'block' : 'none';
    if (textarea.value) preview.src = textarea.value;

    var message = document.createElement('div');
    message.style.color = '#4b5563';
    message.style.fontSize = '13px';
    message.textContent = textarea.value
      ? 'Photo captured. Retake if needed.'
      : 'Allow camera access, center the face, then capture.';

    var actions = document.createElement('div');
    actions.style.display = 'flex';
    actions.style.gap = '8px';
    actions.style.flexWrap = 'wrap';

    var startButton = document.createElement('button');
    startButton.type = 'button';
    startButton.textContent = textarea.value ? 'Open Camera Again' : 'Take Photo';
    setButtonStyle(startButton, true);

    var captureButton = document.createElement('button');
    captureButton.type = 'button';
    captureButton.textContent = 'Capture Photo';
    captureButton.disabled = true;
    captureButton.style.display = 'none';
    setButtonStyle(captureButton, true);

    var recaptureButton = document.createElement('button');
    recaptureButton.type = 'button';
    recaptureButton.textContent = 'Recapture Photo';
    recaptureButton.style.display = textarea.value ? 'inline-block' : 'none';
    setButtonStyle(recaptureButton, false);

    actions.appendChild(startButton);
    actions.appendChild(captureButton);
    actions.appendChild(recaptureButton);
    wrapper.appendChild(video);
    wrapper.appendChild(preview);
    wrapper.appendChild(message);
    wrapper.appendChild(actions);
    textarea.parentNode.insertBefore(wrapper, textarea);

    var stream = null;

    function stopCamera() {
      if (!stream) return;
      stream.getTracks().forEach(function (track) {
        track.stop();
      });
      stream = null;
    }

    function showCamera() {
      video.style.display = 'block';
      preview.style.display = 'none';
      captureButton.style.display = 'inline-block';
      captureButton.disabled = true;
      startButton.disabled = true;
      recaptureButton.style.display = 'none';
      message.textContent = 'Opening camera...';
    }

    function showCapturedState() {
      video.style.display = 'none';
      preview.style.display = 'block';
      captureButton.style.display = 'none';
      captureButton.disabled = true;
      startButton.disabled = false;
      startButton.textContent = 'Open Camera Again';
      recaptureButton.style.display = 'inline-block';
    }

    function requestCamera(constraints) {
      return navigator.mediaDevices.getUserMedia(constraints);
    }

    function startCamera() {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        message.textContent =
          'Camera capture is not available in this browser. Use Chrome or Edge on localhost/HTTPS.';
        return;
      }

      stopCamera();
      showCamera();
      requestCamera({ video: { facingMode: 'user' }, audio: false })
        .catch(function () {
          return requestCamera({ video: true, audio: false });
        })
        .then(function (mediaStream) {
          stream = mediaStream;
          video.srcObject = mediaStream;
          captureButton.disabled = false;
          message.textContent = 'Camera ready. Capture the employee photo.';
        })
        .catch(function (error) {
          video.style.display = 'none';
          captureButton.style.display = 'none';
          startButton.disabled = false;
          recaptureButton.style.display = textarea.value ? 'inline-block' : 'none';
          preview.style.display = textarea.value ? 'block' : 'none';
          message.textContent =
            'Camera did not open. Allow camera permission in the browser, close other apps using the camera, then try again.';
          if (window.console && error) {
            console.warn('HealOn admin photo capture failed:', error);
          }
        });
    }

    startButton.addEventListener('click', startCamera);
    recaptureButton.addEventListener('click', startCamera);

    captureButton.addEventListener('click', function () {
      if (!video.videoWidth || !video.videoHeight) {
        message.textContent = 'Camera is still starting. Please try again.';
        return;
      }
      var canvas = document.createElement('canvas');
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      canvas.getContext('2d').drawImage(video, 0, 0);
      var dataUrl = canvas.toDataURL('image/jpeg', 0.86);
      textarea.value = dataUrl;
      preview.src = dataUrl;
      message.textContent = 'Photo captured for check-in/check-out verification.';
      stopCamera();
      showCapturedState();
      textarea.dispatchEvent(new Event('change', { bubbles: true }));
    });
  }

  function initialize() {
    document.querySelectorAll('textarea.healon-photo-capture').forEach(buildCaptureControls);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize);
  } else {
    initialize();
  }
})();
