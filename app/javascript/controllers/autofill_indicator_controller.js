import { Controller } from '@hotwired/stimulus';

/**
 * Autofill Indicator Controller
 *
 * Shows visual feedback when a field has been auto-populated from:
 * - User profile data
 * - Previous form submissions (e.g., "from SC-100")
 *
 * Features:
 * - Displays "Auto-filled" badge/pill next to field
 * - Shows source information (Profile or form code)
 * - Provides "Edit" and "Clear" quick actions
 * - Tracks original vs modified state
 */
export default class extends Controller {
  static targets = ['input', 'badge', 'wrapper'];

  static values = {
    source: String, // 'profile' or form code like 'SC-100'
    sourceLabel: String, // Human-readable label like "Your name" or "Plaintiff Name"
    originalValue: String, // The original auto-filled value
    fieldName: String // Field name for event dispatching
  };

  connect() {
    this.isModified = false;
    this.wasCleared = false;

    // Track the original value if we have an input
    if (this.hasInputTarget && this.originalValueValue) {
      this.boundHandleInput = this.handleInput.bind(this);
      this.inputTarget.addEventListener('input', this.boundHandleInput);

      // Add autofill styling to the input
      this.addAutofillStyling();
    }

    // Listen for manual autofill application
    this.boundHandleAutofillApplied = this.handleAutofillApplied.bind(this);
    this.element.addEventListener(
      'autofill:applied',
      this.boundHandleAutofillApplied
    );
  }

  disconnect() {
    if (this.hasInputTarget && this.boundHandleInput) {
      this.inputTarget.removeEventListener('input', this.boundHandleInput);
    }
    this.element.removeEventListener(
      'autofill:applied',
      this.boundHandleAutofillApplied
    );
    this.removeAutofillStyling();
  }

  /**
   * Handle manual autofill application from autofill_controller
   */
  handleAutofillApplied(event) {
    const { value, source, label } = event.detail;

    this.sourceValue = source;
    this.sourceLabelValue = label;
    this.originalValueValue = value;
    this.isModified = false;
    this.wasCleared = false;

    this.addAutofillStyling();
    this.updateBadgeContent();
    this.updateBadgeState();

    if (this.hasBadgeTarget) {
      this.badgeTarget.classList.remove('hidden');
    }
  }

  updateBadgeContent() {
    if (!this.hasBadgeTarget) {
      return;
    }

    let sourceText = this.sourceValue;

    if (this.sourceValue === 'profile') {
      sourceText = 'Profile';
    } else if (this.sourceValue === 'previous_submission') {
      sourceText = 'Previous Form';
    }

    this.badgeTarget.innerHTML = `
      <span class="flex items-center gap-1">
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
        Auto-filled from ${sourceText}
      </span>
      <div class="flex gap-1 ml-2 border-l border-primary/20 pl-2">
        <button type="button" data-action="click->autofill-indicator#edit" class="hover:text-primary-focus underline">Edit</button>
        <button type="button" data-action="click->autofill-indicator#clear" class="hover:text-error underline">Clear</button>
      </div>
    `;
  }

  /**
   * Handle input changes to track modification state
   */
  handleInput() {
    const currentValue = this.inputTarget.value;
    const wasModified = this.isModified;

    this.isModified = currentValue !== this.originalValueValue;

    // Update badge state if modification status changed
    if (wasModified !== this.isModified) {
      this.updateBadgeState();
    }
  }

  /**
   * Update the badge to reflect current state
   */
  updateBadgeState() {
    if (!this.hasBadgeTarget) {
      return;
    }

    if (this.isModified) {
      this.badgeTarget.classList.add('autofill-badge-modified');
      this.badgeTarget.setAttribute('data-modified', 'true');
    } else {
      this.badgeTarget.classList.remove('autofill-badge-modified');
      this.badgeTarget.setAttribute('data-modified', 'false');
    }
  }

  /**
   * Enable editing of the auto-filled field
   * Focuses the input and selects the text for easy editing
   */
  edit(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.hasInputTarget) {
      this.inputTarget.focus();
      this.inputTarget.select();

      // Show toast notification
      this.showToast('Field is now editable', 'info');
    }
  }

  /**
   * Clear the auto-filled value
   */
  clear(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.hasInputTarget) {
      // Store current value for potential undo
      const previousValue = this.inputTarget.value;

      // Clear the field
      this.inputTarget.value = '';
      this.wasCleared = true;
      this.isModified = true;

      // Trigger events for other controllers (auto-save, validation)
      this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }));
      this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }));

      // Remove autofill styling
      this.removeAutofillStyling();

      // Hide the badge
      if (this.hasBadgeTarget) {
        this.badgeTarget.classList.add('hidden');
      }

      // Dispatch custom event for tracking
      this.dispatch('cleared', {
        detail: {
          fieldName: this.fieldNameValue,
          previousValue,
          source: this.sourceValue
        }
      });

      // Show toast notification
      this.showToast('Auto-filled value cleared', 'info');

      // Focus the input
      this.inputTarget.focus();
    }
  }

  /**
   * Restore the original auto-filled value
   */
  restore(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }

    if (this.hasInputTarget && this.originalValueValue) {
      this.inputTarget.value = this.originalValueValue;
      this.isModified = false;
      this.wasCleared = false;

      // Trigger events
      this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }));
      this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }));

      // Restore styling
      this.addAutofillStyling();

      // Show the badge
      if (this.hasBadgeTarget) {
        this.badgeTarget.classList.remove('hidden');
      }

      this.updateBadgeState();
      this.showToast('Original value restored', 'success');
    }
  }

  /**
   * Add autofill highlight styling to the input
   */
  addAutofillStyling() {
    if (this.hasInputTarget) {
      this.inputTarget.classList.add('autofill-highlighted');
    }
    if (this.hasWrapperTarget) {
      this.wrapperTarget.classList.add('autofill-field-wrapper');
    }
  }

  /**
   * Remove autofill highlight styling from the input
   */
  removeAutofillStyling() {
    if (this.hasInputTarget) {
      this.inputTarget.classList.remove('autofill-highlighted');
    }
    if (this.hasWrapperTarget) {
      this.wrapperTarget.classList.remove('autofill-field-wrapper');
    }
  }

  /**
   * Show details about the auto-fill source
   */
  showDetails(event) {
    event.preventDefault();
    event.stopPropagation();

    const sourceType =
      this.sourceValue === 'profile'
        ? 'your Profile'
        : `form ${this.sourceValue}`;
    const sourceLabel = this.sourceLabelValue
      ? ` (${this.sourceLabelValue})`
      : '';
    const message = `This field was auto-filled from ${sourceType}${sourceLabel}`;

    this.showToast(message, 'info');
  }

  /**
   * Helper to show toast notifications
   */
  showToast(message, type = 'info') {
    document.dispatchEvent(
      new CustomEvent('toast:show', {
        detail: { message, type }
      })
    );
  }

  /**
   * Get the source display text for the badge
   */
  get sourceDisplayText() {
    if (this.sourceValue === 'profile') {
      return 'Profile';
    }

    return this.sourceValue; // Form code like "SC-100"
  }

  /**
   * Check if the field has been modified from its original value
   */
  get hasBeenModified() {
    return this.isModified;
  }

  /**
   * Get current field state for summary purposes
   */
  getFieldState() {
    return {
      fieldName: this.fieldNameValue,
      source: this.sourceValue,
      sourceLabel: this.sourceLabelValue,
      originalValue: this.originalValueValue,
      currentValue: this.hasInputTarget ? this.inputTarget.value : null,
      isModified: this.isModified,
      wasCleared: this.wasCleared
    };
  }
}
