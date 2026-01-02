import { Controller } from '@hotwired/stimulus';
import { showToast } from 'utils/toast';

// Handles switching between Wizard and Traditional form views

// Persists preference in localStorage
// Warns users before switching with unsaved changes
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
    storageKey: { type: String, default: 'formViewMode' },
    warnOnUnsaved: { type: Boolean, default: true }
  };

  connect() {
    // Restore preference from localStorage
    const savedMode = localStorage.getItem(this.storageKeyValue);

    if (savedMode && (savedMode === 'wizard' || savedMode === 'traditional')) {
      this.modeValue = savedMode;
    }

    this.applyMode();
    this.updateToggle();

    // Bind beforeunload handler for page leave warning
    this.handleBeforeUnload = this.handleBeforeUnload.bind(this);
    window.addEventListener('beforeunload', this.handleBeforeUnload);

    // Listen for form changes to track unsaved state
    this.handleFormInput = this.handleFormInput.bind(this);
    this.element.addEventListener('input', this.handleFormInput);
    this.element.addEventListener('change', this.handleFormInput);

    // Listen for successful saves to clear unsaved state
    this.handleFormSaved = this.handleFormSaved.bind(this);
    document.addEventListener('form:saved', this.handleFormSaved);

    this.hasUnsavedChanges = false;
  }

  disconnect() {
    window.removeEventListener('beforeunload', this.handleBeforeUnload);
    this.element.removeEventListener('input', this.handleFormInput);
    this.element.removeEventListener('change', this.handleFormInput);
    document.removeEventListener('form:saved', this.handleFormSaved);
  }

  handleFormInput() {
    this.hasUnsavedChanges = true;
  }

  handleFormSaved() {
    this.hasUnsavedChanges = false;
  }

  handleBeforeUnload(event) {
    if (this.warnOnUnsavedValue && this.hasUnsavedChanges) {
      event.preventDefault();
      // Modern browsers ignore custom message but require returnValue
      event.returnValue = '';
    }
  }

  toggle(event) {
    // Check for unsaved changes before switching
    if (this.warnOnUnsavedValue && this.hasUnsavedChanges) {
      const confirmed = this.confirmModeSwitch();

      if (!confirmed) {
        // Revert the toggle if user cancels
        event.preventDefault();
        this.updateToggle();

        return;
      }
    }

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

  /**
   * Show confirmation dialog for switching modes with unsaved changes
   * @returns {boolean} True if user confirms, false otherwise
   */
  confirmModeSwitch() {
    // Use native confirm for unsaved changes warning
    // eslint-disable-next-line no-alert -- Intentional for critical data loss warning
    const confirmed = window.confirm(
      'You have unsaved changes. Switching views may cause data loss. ' +
        'Your changes will be synced, but some formatting may be lost.\n\n' +
        'Continue switching?'
    );

    if (confirmed) {
      // Show toast notification
      showToast('Switching view mode...', 'info', 2000);
    }

    return confirmed;
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
