import { Controller } from '@hotwired/stimulus';

// Handles client-side validation feedback
export default class extends Controller {
  static targets = ['input', 'error'];

  connect() {
    this.element.setAttribute('novalidate', true);

    this.inputTargets.forEach(input => {
      input.addEventListener('blur', this.validateInput.bind(this));
      input.addEventListener('input', this.clearError.bind(this));
    });
  }

  disconnect() {
    this.inputTargets.forEach(input => {
      input.removeEventListener('blur', this.validateInput.bind(this));
      input.removeEventListener('input', this.clearError.bind(this));
    });
  }

  validateInput(event) {
    const input = event.target;

    if (!input.checkValidity()) {
      this.showError(input);
    }
  }

  clearError(event) {
    const input = event.target;

    input.classList.remove('input-error', 'textarea-error', 'select-error');

    // Remove invalid state for assistive technologies
    input.removeAttribute('aria-invalid');

    const errorId = input.getAttribute('aria-errormessage');

    if (errorId) {
      const errorElement = document.getElementById(errorId);

      if (errorElement) {
        errorElement.textContent = '';
        errorElement.classList.add('hidden');
      }
    }
  }

  showError(input) {
    input.classList.add(
      input.tagName === 'TEXTAREA'
        ? 'textarea-error'
        : input.tagName === 'SELECT'
          ? 'select-error'
          : 'input-error'
    );

    // Mark input as invalid for assistive technologies
    input.setAttribute('aria-invalid', 'true');

    const errorId =
      input.getAttribute('aria-errormessage') || `${input.id}-error`;
    const errorElement = document.getElementById(errorId);

    // If helper didn't generate error container, create one if possible?
    // The FormHelper `field_error_container` ensures it exists if used.

    if (errorElement) {
      errorElement.textContent = input.validationMessage;
      errorElement.classList.remove('hidden');

      // Add screen reader announcements for validation errors
      errorElement.setAttribute('aria-live', 'assertive');
      errorElement.setAttribute('role', 'alert');

      // Link the error to the input via aria-describedby
      const existingDescribedBy = input.getAttribute('aria-describedby');

      if (!existingDescribedBy?.includes(errorId)) {
        input.setAttribute(
          'aria-describedby',
          existingDescribedBy ? `${existingDescribedBy} ${errorId}` : errorId
        );
      }
    }
  }
}
