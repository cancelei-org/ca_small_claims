import { Controller } from '@hotwired/stimulus';

// Handles toggling between wizard and traditional form views
// Persists preference in localStorage
export default class extends Controller {
  static targets = [
    'wizardContainer',
    'traditionalContainer',
    'toggle',
    'skipFilledLabel',
    'skipFilledCheckbox'
  ];

  static values = {
    mode: { type: String, default: 'wizard' },
    storageKey: { type: String, default: 'formViewMode' }
  };

  connect() {
    // Restore preference from localStorage
    const savedMode = localStorage.getItem(this.storageKeyValue);

    if (savedMode && (savedMode === 'wizard' || savedMode === 'traditional')) {
      this.modeValue = savedMode;
    }

    this.applyMode();
    this.updateToggle();
  }

  toggle(event) {
    // If triggered by a checkbox/toggle input
    if (event.target.type === 'checkbox') {
      this.modeValue = event.target.checked ? 'wizard' : 'traditional';
    } else {
      // Toggle between modes
      this.modeValue = this.modeValue === 'wizard' ? 'traditional' : 'wizard';
    }

    localStorage.setItem(this.storageKeyValue, this.modeValue);
    this.applyMode();
    this.updateToggle();
  }

  applyMode() {
    const isWizard = this.modeValue === 'wizard';

    // Sync form data before switching views to ensure both views show same values
    this.syncFormData();

    if (this.hasWizardContainerTarget) {
      this.wizardContainerTarget.classList.toggle('hidden', !isWizard);
    }

    if (this.hasTraditionalContainerTarget) {
      this.traditionalContainerTarget.classList.toggle('hidden', isWizard);
    }

    // Update skip-filled toggle state
    if (this.hasSkipFilledLabelTarget) {
      this.skipFilledLabelTarget.classList.toggle('opacity-50', !isWizard);
    }
    if (this.hasSkipFilledCheckboxTarget) {
      this.skipFilledCheckboxTarget.disabled = !isWizard;
    }

    // Dispatch event for other controllers to react
    this.dispatch('modeChanged', { detail: { mode: this.modeValue } });
  }

  // Sync form data between wizard and traditional views
  // Both views have separate inputs with same names - we need to copy values between them
  syncFormData() {
    const isWizard = this.modeValue === 'wizard';
    const sourceContainer = isWizard
      ? this.traditionalContainerTarget
      : this.wizardContainerTarget;
    const targetContainer = isWizard
      ? this.wizardContainerTarget
      : this.traditionalContainerTarget;

    if (!sourceContainer || !targetContainer) {
      return;
    }

    // Get all form inputs from source container
    const sourceInputs = sourceContainer.querySelectorAll(
      "input:not([type='hidden']), select, textarea"
    );

    sourceInputs.forEach(sourceInput => {
      const name = sourceInput.name;

      if (!name) {
        return;
      }

      // Find matching input in target container
      const targetInput = targetContainer.querySelector(`[name="${name}"]`);

      if (!targetInput) {
        return;
      }

      // Copy value based on input type
      if (sourceInput.type === 'checkbox' || sourceInput.type === 'radio') {
        targetInput.checked = sourceInput.checked;
      } else {
        targetInput.value = sourceInput.value;
      }
    });
  }

  updateToggle() {
    if (this.hasToggleTarget) {
      this.toggleTarget.checked = this.modeValue === 'wizard';
    }
  }

  // Programmatically set mode
  setWizardMode() {
    this.modeValue = 'wizard';
    localStorage.setItem(this.storageKeyValue, this.modeValue);
    this.applyMode();
    this.updateToggle();
  }

  setTraditionalMode() {
    this.modeValue = 'traditional';
    localStorage.setItem(this.storageKeyValue, this.modeValue);
    this.applyMode();
    this.updateToggle();
  }

  // Handle skip filled toggle - reload page with parameter
  toggleSkipFilled(event) {
    const skipFilled = event.target.checked;
    const url = new URL(window.location);

    if (skipFilled) {
      url.searchParams.set('skip_filled', 'true');
    } else {
      url.searchParams.delete('skip_filled');
    }

    // Use Turbo to navigate if available, otherwise standard navigation
    if (window.Turbo) {
      window.Turbo.visit(url.toString());
    } else {
      window.location.href = url.toString();
    }
  }
}
