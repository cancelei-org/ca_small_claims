import { Controller } from '@hotwired/stimulus';
import { csrfToken } from 'utilities/csrf';
import { DEBOUNCE_DELAYS, createDebouncedHandler } from 'utilities/debounce';

// Handles form auto-save functionality with optimized debounce
export default class extends Controller {
  static targets = ['status', 'form'];
  static values = {
    saveUrl: String,
    debounceDelay: { type: Number, default: DEBOUNCE_DELAYS.FAST } // Reduced from NORMAL for faster feedback
  };

  connect() {
    this.pendingChanges = false;
    this.debouncedSave = createDebouncedHandler(() => this.save());
    console.log('Form controller connected');
  }

  disconnect() {
    this.debouncedSave.cancel();
  }

  fieldChanged(_event) {
    this.pendingChanges = true;
    this.updateStatus('saving');
    this.debouncedSave.call(this.debounceDelayValue);
  }

  async save() {
    if (!this.pendingChanges) {
      return;
    }

    const form = this.hasFormTarget ? this.formTarget : this.element;
    const formData = new FormData(form);

    try {
      const response = await fetch(this.saveUrlValue || form.action, {
        method: 'PATCH',
        body: formData,
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken()
        }
      });

      if (response.ok) {
        this.pendingChanges = false;
        this.updateStatus('saved');

        // Dispatch event for PDF preview controller to refresh
        document.dispatchEvent(
          new CustomEvent('form:saved', {
            detail: { formId: form.id, timestamp: Date.now() }
          })
        );
      } else {
        this.updateStatus('error');
        console.error('Save failed:', response.statusText);
      }
    } catch (error) {
      this.updateStatus('error');
      console.error('Save error:', error);
    }
  }

  updateStatus(status) {
    // Update all status targets (wizard and traditional views may both exist)
    const statusElements = this.hasStatusTarget ? this.statusTargets : [];

    if (statusElements.length === 0) {
      return;
    }

    let html = '';

    switch (status) {
      case 'saving':
        html = `
          <span class="text-base-content/50">
            <svg class="inline w-4 h-4 mr-1 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Saving...
          </span>
        `;
        break;
      case 'saved':
        html = `
          <span class="text-success">
            <svg class="inline w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
            </svg>
            Saved just now
          </span>
        `;
        break;
      case 'error':
        html = `
          <span class="text-error">
            <svg class="inline w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            Save failed
          </span>
        `;
        break;
      default:
        break;
    }

    statusElements.forEach(el => (el.innerHTML = html));
  }

  // Warn user before leaving with unsaved changes
  beforeUnload(event) {
    if (this.pendingChanges) {
      event.preventDefault();
      event.returnValue = '';
    }
  }
}
