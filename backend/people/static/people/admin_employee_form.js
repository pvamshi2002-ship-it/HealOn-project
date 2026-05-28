(function () {
  function ready(callback) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', callback);
    } else {
      callback();
    }
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

  ready(setupDisplayNameAutofill);
})();
