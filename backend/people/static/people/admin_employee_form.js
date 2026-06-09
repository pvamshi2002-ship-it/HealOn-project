(function () {
  function ready(callback) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', callback);
    } else {
      callback();
    }
  }

  function isEmployeeAdminPage() {
    return (
      /\/admin\/auth\/user\/(?:add|\d+\/change)\/?$/.test(location.pathname) ||
      /\/admin\/people\/userprofile\/\d+\/change\/?$/.test(location.pathname)
    );
  }

  function fieldValue(id) {
    var field = document.getElementById(id);
    return field ? field.value.trim() : '';
  }

  function setupDisplayNameAutofill() {
    var firstName = document.getElementById('id_first_name');
    var lastName = document.getElementById('id_last_name');
    var displayName = document.getElementById('id_display_name');
    if (!firstName || !lastName || !displayName) return;

    var lastGenerated = displayName.value.trim();
    var manuallyEdited = false;

    function generatedName() {
      return [firstName.value.trim(), lastName.value.trim()]
        .filter(Boolean)
        .join(' ');
    }

    function syncDisplayName() {
      var nextName = generatedName();
      if (!manuallyEdited || displayName.value.trim() === lastGenerated) {
        displayName.value = nextName;
        lastGenerated = nextName;
      }
    }

    displayName.addEventListener('input', function () {
      manuallyEdited = displayName.value.trim() !== lastGenerated;
      if (!displayName.value.trim()) {
        manuallyEdited = false;
      }
    });
    firstName.addEventListener('input', syncDisplayName);
    lastName.addEventListener('input', syncDisplayName);
    syncDisplayName();
  }

  function collectValidationProblems(isAddPage) {
    var problems = [];
    if (!fieldValue('id_display_name')) {
      problems.push({ message: 'Display name is required.', fieldId: 'id_display_name' });
    }
    if (!fieldValue('id_username')) {
      problems.push({ message: 'Username is required.', fieldId: 'id_username' });
    }
    if (!fieldValue('id_email')) {
      problems.push({ message: 'Email is required.', fieldId: 'id_email' });
    }
    if (isAddPage) {
      if (!fieldValue('id_password1') || !fieldValue('id_password2')) {
        problems.push({ message: 'Password and confirmation are required.', fieldId: 'id_password1' });
      } else if (fieldValue('id_password1') !== fieldValue('id_password2')) {
        problems.push({
          message: 'Password and confirmation must match.',
          fieldId: 'id_password2',
        });
      }
    }
    var photo = fieldValue('id_profile_photo_biometric');
    if (!photo) {
      problems.push({
        message: 'Employee verification photo is required. Use Take Photo or Upload Photo.',
        fieldId: 'id_profile_photo_biometric',
      });
    } else if (!photo.startsWith('data:image/') || photo.indexOf(',') === -1) {
      problems.push({
        message: 'Employee verification photo must be captured or uploaded as an image.',
        fieldId: 'id_profile_photo_biometric',
      });
    }
    return problems;
  }

  function focusFirstProblem(problems) {
    if (!problems.length) return;
    var target = document.getElementById(problems[0].fieldId);
    if (!target) return;
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });
    if (typeof target.focus === 'function') {
      target.focus();
    }
    var widget = target.parentElement && target.parentElement.querySelector('.healon-photo-capture-widget');
    if (widget) {
      var message = widget.querySelector('div');
      if (message) {
        message.style.color = '#b91c1c';
        message.style.fontWeight = '600';
        message.textContent = problems[0].message;
      }
    }
  }

  function setupSaveValidation() {
    if (!isEmployeeAdminPage()) return;

    var form =
      document.getElementById('user_form') ||
      document.querySelector('#content-main form') ||
      document.querySelector('form');
    if (!form) return;

    var isAddPage = /\/admin\/auth\/user\/add\/?$/.test(location.pathname);

    form.addEventListener('submit', function (event) {
      var submitter = event.submitter;
      var action = submitter && submitter.name ? submitter.name : '_save';
      if (action !== '_save' && action !== '_continue' && action !== '_addanother') {
        return;
      }

      var problems = collectValidationProblems(isAddPage);
      if (!problems.length) {
        return;
      }

      event.preventDefault();
      window.alert(
        'Employee was not saved.\n\n' +
          problems.map(function (problem) {
            return '- ' + problem.message;
          }).join('\n'),
      );
      focusFirstProblem(problems);
    });
  }

  function setupSaveSuccessPopup() {
    if (!isEmployeeAdminPage()) return;

    var successNode =
      document.querySelector('.messagelist .success') ||
      document.querySelector('.alert-success') ||
      document.querySelector('[class*="success"]');

    if (!successNode) return;

    var text = (successNode.textContent || '').trim();
    if (!text || !/successfully/i.test(text)) return;

    window.alert(text);
  }

  function setupServerErrorVisibility() {
    if (!isEmployeeAdminPage()) return;
    var errorList = document.querySelector('.messagelist .error, .alert-danger');
    if (errorList) {
      errorList.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }

  ready(function () {
    setupDisplayNameAutofill();
    setupSaveValidation();
    setupSaveSuccessPopup();
    setupServerErrorVisibility();
  });
})();
