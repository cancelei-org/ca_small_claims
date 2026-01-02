import { Controller } from '@hotwired/stimulus';
import { csrfToken } from 'utilities/csrf';
import { DEBOUNCE_DELAYS, createDebouncedHandler } from 'utilities/debounce';
import { StatusIndicator } from 'utils/status_indicator';

// Handles user profile form updates

export default class extends Controller {
  static targets = ['status'];
  static values = {
    url: String,
    debounceDelay: { type: Number, default: DEBOUNCE_DELAYS.NORMAL }
  };

  connect() {
    this.debouncedSave = createDebouncedHandler(() => this.performSave());

    // Initialize status indicator with badge format
    const statusEl = this.hasStatusTarget
      ? this.statusTarget
      : document.getElementById('profile-status');

    if (statusEl) {
      this.status = new StatusIndicator(statusEl, { format: 'badge' });
    }
  }

  disconnect() {
    this.debouncedSave.cancel();
  }

  save() {
    this.status?.saving();
    this.debouncedSave.call(this.debounceDelayValue);
  }

  performSave() {
    const form = this.element;
    const formData = new FormData(form);

    fetch(this.urlValue, {
      method: 'PATCH',
      body: formData,
      headers: {
        Accept: 'text/vnd.turbo-stream.html'
      }
    })
      .then(response => {
        if (response.ok) {
          return response.text();
        }
        throw new Error('Save failed');
      })
      .then(html => {
        window.Turbo.renderStreamMessage(html);
      })
      .catch(error => {
        console.error('Profile save error:', error);
        this.status?.error('Failed to save');
      });
  }
}
