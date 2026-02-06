import { Controller } from '@hotwired/stimulus';

/**
 * Validation Controller
 * Handles client-side real-time validation with debouncing
 *
 * Features:
 * - Validates on blur (immediate)
 * - Validates on input (debounced 300ms)
 * - Shows inline error messages
 * - Provides format hints for specific field types
 * - Dispatches events for wizard integration
 */
export default class extends Controller {
  static targets = ['input', 'error', 'form'];
  static values = {
    debounceMs: { type: Number, default: 300 }
  };

  // Format hints for common field types
  static formatHints = {
    tel: 'Format: (555) 555-5555',
    email: 'Format: email@example.com',
    date: 'Format: MM/DD/YYYY',
    currency: 'Format: $0.00'
  };

  connect() {
    this.element.setAttribute('novalidate', true);
    this.debounceTimers = new Map();

    // Find all inputs in the form
    const inputs = this.element.querySelectorAll(
      'input:not([type="hidden"]):not([type="submit"]), textarea, select'
    );

    inputs.forEach(input => {
      input.addEventListener('blur', this.handleBlur.bind(this));
      input.addEventListener('input', this.handleInput.bind(this));
      input.addEventListener('change', this.handleChange.bind(this));
    });

    // Listen for wizard navigation attempts
    this.element.addEventListener(
      'wizard:beforeNext',
      this.handleBeforeNext.bind(this)
    );
  }

  disconnect() {
    // Clear all debounce timers
    this.debounceTimers.forEach(timer => clearTimeout(timer));
    this.debounceTimers.clear();
  }

  /**
   * Immediate validation on blur
   */
  handleBlur(event) {
    const input = event.target;

    this.validateInput(input);
  }

  /**
   * Debounced validation on input
   */
  handleInput(event) {
    const input = event.target;

    // Clear existing error immediately when typing
    if (input.value.length > 0) {
      this.clearError(input);
    }

    // Debounce validation while typing
    if (this.debounceTimers.has(input)) {
      clearTimeout(this.debounceTimers.get(input));
    }

    const timer = setTimeout(() => {
      this.validateInput(input);
      this.debounceTimers.delete(input);
    }, this.debounceMsValue);

    this.debounceTimers.set(input, timer);
  }

  /**
   * Immediate validation on change (for selects, etc.)
   */
  handleChange(event) {
    const input = event.target;

    if (input.tagName === 'SELECT') {
      this.validateInput(input);
    }
  }

  /**
   * Prevent wizard advance if current card has validation errors
   */
  handleBeforeNext(event) {
    const { currentIndex } = event.detail || {};

    // Find the current wizard card by index
    const wizardCards = this.element.querySelectorAll(
      '[data-wizard-target="card"]'
    );
    const currentCard = wizardCards[currentIndex];

    if (!currentCard) {
      return;
    }

    const inputs = currentCard.querySelectorAll(
      'input:not([type="hidden"]), textarea, select'
    );

    let hasErrors = false;

    inputs.forEach(input => {
      if (!this.validateInput(input)) {
        hasErrors = true;
      }
    });

    if (hasErrors) {
      event.preventDefault();
      this.showErrorSummary(currentCard);

      // Focus first invalid input
      const firstInvalid = currentCard.querySelector('[aria-invalid="true"]');

      if (firstInvalid) {
        firstInvalid.focus();
      }
    } else {
      this.hideErrorSummary(currentCard);
    }
  }

  /**
   * Show a summary of all errors at the top of the container
   */
  showErrorSummary(container) {
    let summary = container.querySelector('[data-validation-target="summary"]');

    if (!summary) {
      // Create summary element if it doesn't exist
      summary = document.createElement('div');
      summary.setAttribute('data-validation-target', 'summary');
      summary.className =
        'alert alert-error shadow-sm mb-6 flex-col items-start gap-1';

      // In traditional form, put it at the top of the content area if possible
      const contentArea = container.querySelector('.p-6.space-y-8');

      if (contentArea) {
        contentArea.prepend(summary);
      } else {
        container.prepend(summary);
      }
    }

    const invalidInputs = container.querySelectorAll('[aria-invalid="true"]');
    const errorCount = invalidInputs.length;

    if (errorCount === 0) {
      summary.classList.add('hidden');

      return;
    }

    summary.innerHTML = `
      <div class="flex items-center gap-2 font-bold">
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
        <span>There are ${errorCount} error${errorCount > 1 ? 's' : ''} that need your attention</span>
      </div>
      <ul class="list-disc list-inside ml-8 text-sm opacity-90">
        ${Array.from(invalidInputs)
          .map(input => {
            const label = this.getLabelText(input);

            return `<li><a href="#${input.id}" class="hover:underline">${label}</a></li>`;
          })
          .join('')}
      </ul>
    `;

    summary.classList.remove('hidden');
    summary.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  hideErrorSummary(container) {
    const summary = container.querySelector(
      '[data-validation-target="summary"]'
    );

    if (summary) {
      summary.classList.add('hidden');
    }
  }

  getLabelText(input) {
    // Try to find label by 'for' attribute
    const labelId = input.id;
    const label = document.querySelector(`label[for="${labelId}"]`);

    if (label) {
      // Remove help icons/text from label text if present
      const cleanLabel = label.cloneNode(true);

      cleanLabel
        .querySelectorAll('.tooltip-icon, .tooltip-hint, .label-text-alt')
        .forEach(el => el.remove());

      return cleanLabel.textContent.trim();
    }

    // Fallback to placeholder or name
    return input.placeholder || input.name || 'This field';
  }

  /**
   * Validate a single input and return validity
   */
  validateInput(input) {
    if (!input.checkValidity()) {
      this.showError(input);
      this.dispatchValidationEvent(input, false);

      return false;
    }
    this.clearError(input);
    this.dispatchValidationEvent(input, true);

    return true;
  }

  /**
   * Validate all inputs in the form and show summary
   */
  validateAll() {
    const inputs = this.element.querySelectorAll(
      'input:not([type="hidden"]):not([type="submit"]), textarea, select'
    );

    let allValid = true;
    let firstInvalid = null;

    inputs.forEach(input => {
      if (!this.validateInput(input)) {
        allValid = false;
        if (!firstInvalid) {
          firstInvalid = input;
        }
      }
    });

    if (!allValid) {
      this.showErrorSummary(this.element);
      if (firstInvalid) {
        firstInvalid.focus();
      }
    } else {
      this.hideErrorSummary(this.element);
    }

    return allValid;
  }

  /**
   * Clear error state from an input
   */
  clearError(input) {
    input.classList.remove('input-error', 'textarea-error', 'select-error');
    input.removeAttribute('aria-invalid');

    const errorElement = this.getErrorElement(input);

    if (errorElement) {
      errorElement.textContent = '';
      errorElement.classList.add('hidden');
    }
  }

  /**
   * Show error state on an input
   */
  showError(input) {
    // Add error styling
    let errorClass = 'input-error';

    if (input.tagName === 'TEXTAREA') {
      errorClass = 'textarea-error';
    } else if (input.tagName === 'SELECT') {
      errorClass = 'select-error';
    }

    input.classList.add(errorClass);
    input.setAttribute('aria-invalid', 'true');

    // Get or create error element
    const errorElement = this.getErrorElement(input);

    if (errorElement) {
      // Get custom error message or browser default
      const message = this.getErrorMessage(input);

      errorElement.textContent = message;
      errorElement.classList.remove('hidden');
      errorElement.setAttribute('aria-live', 'assertive');
      errorElement.setAttribute('role', 'alert');
    }
  }

  /**
   * Get the error element for an input
   */
  getErrorElement(input) {
    // First check aria-errormessage
    const errorId = input.getAttribute('aria-errormessage');

    if (errorId) {
      return document.getElementById(errorId);
    }

    // Fallback to aria-describedby
    const describedBy = input.getAttribute('aria-describedby');

    if (describedBy) {
      const ids = describedBy.split(' ');

      for (const id of ids) {
        const el = document.getElementById(id);

        if (el && el.classList.contains('field-error')) {
          return el;
        }
      }
    }

    // Last resort: look for sibling error element
    const wrapper = input.closest('.form-control');

    return wrapper?.querySelector('.field-error');
  }

  /**
   * Get custom error message with format hint and retry suggestions
   */
  getErrorMessage(input) {
    let message = '';
    const fieldHelp = this.getFieldHelp(input);
    const retrySuggestions = this.getRetrySuggestions(input);

    // Required field empty
    if (input.validity.valueMissing) {
      message = 'This field is required';
    }
    // Type mismatch (email, url, etc.)
    else if (input.validity.typeMismatch) {
      const hint =
        fieldHelp?.format_hint || this.constructor.formatHints[input.type];

      message = hint ? `Invalid format. ${hint}` : input.validationMessage;
    }
    // Pattern mismatch
    else if (input.validity.patternMismatch) {
      const hint = fieldHelp?.format_hint;

      message = hint
        ? `Please match the format: ${hint}`
        : input.title || 'Please match the requested format';
    }
    // Range errors
    else if (input.validity.rangeOverflow) {
      message = `Value must be ${input.max} or less`;
    } else if (input.validity.rangeUnderflow) {
      message = `Value must be ${input.min} or more`;
    }
    // Length errors
    else if (input.validity.tooShort) {
      message = `Minimum ${input.minLength} characters required`;
    } else if (input.validity.tooLong) {
      message = `Maximum ${input.maxLength} characters allowed`;
    } else {
      message = input.validationMessage;
    }

    // Add retry suggestion if available
    if (retrySuggestions.length > 0 && !input.validity.valueMissing) {
      const suggestion = this.findMatchingSuggestion(
        input.value,
        retrySuggestions
      );

      if (suggestion) {
        message += `. Hint: ${suggestion}`;
      }
    }

    return message;
  }

  getFieldHelp(input) {
    try {
      return JSON.parse(input.dataset.fieldHelp || '{}');
    } catch {
      return {};
    }
  }

  getRetrySuggestions(input) {
    try {
      return JSON.parse(input.dataset.retrySuggestions || '[]');
    } catch {
      return [];
    }
  }

  findMatchingSuggestion(value, suggestions) {
    // Simple heuristic: if it looks like a common mistake
    // This could be expanded with regex matching from the YAML
    if (typeof suggestions === 'string') {
      return suggestions;
    }

    // If it's the array of objects from YAML
    if (Array.isArray(suggestions)) {
      // For now just return the first one as a generic hint if we can't match specifically
      // In a real app, we might have regex in the YAML to match the mistake
      const [first] = suggestions;

      return typeof first === 'string' ? first : first.suggestion;
    }

    return null;
  }

  /**
   * Dispatch validation event for other controllers
   */
  dispatchValidationEvent(input, isValid) {
    const event = new CustomEvent('validation:change', {
      bubbles: true,
      detail: {
        input,
        valid: isValid,
        fieldName: input.name || input.id
      }
    });

    this.element.dispatchEvent(event);
  }
}
