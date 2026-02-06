import { Controller } from '@hotwired/stimulus';

// Displays live completion percentage and rough time remaining for a form.
export default class extends Controller {
  static targets = ['percent', 'progress', 'eta'];
  static values = {
    requiredFields: Array,
    formSelector: { type: String, default: '#main-form' },
    formCode: String
  };

  connect() {
    this.form = document.querySelector(this.formSelectorValue);
    this.handleInput = this.update.bind(this);
    this.form?.addEventListener('input', this.handleInput);
    this.update();
  }

  disconnect() {
    this.form?.removeEventListener('input', this.handleInput);
  }

  update() {
    if (!this.form) {
      return;
    }

    const required = this.requiredFieldsValue || [];
    const formData = new FormData(this.form);
    const filled = required.filter(field => {
      const name = `submission[${field}]`;
      const value = formData.get(name);

      return value && value.toString().trim() !== '';
    }).length;

    const percent =
      required.length > 0 ? Math.round((filled / required.length) * 100) : 0;

    this.percentTarget.textContent = `${percent}%`;
    this.progressTarget.style.setProperty('--value', percent);
    this.etaTarget.textContent = this.estimatedTime(required.length, filled);

    this.persist(percent, filled, required.length);
  }

  estimatedTime(totalFields, filled) {
    if (!totalFields) {
      return 'Up to 2 min';
    }

    const remaining = Math.max(totalFields - filled, 0);
    const secondsPerField = 25;
    const minutes = Math.max(1, Math.ceil((remaining * secondsPerField) / 60));
    const upperBound = Math.max(minutes + 1, Math.ceil(minutes * 1.4));

    return `${minutes}-${upperBound} min left`;
  }

  persist(percent, filled, total) {
    const key = `completion-indicator:${this.formCodeValue || ''}`;
    const payload = {
      percent,
      filled,
      total,
      updatedAt: Date.now()
    };

    try {
      localStorage.setItem(key, JSON.stringify(payload));
    } catch (e) {
      console.warn('Failed to save completion state to localStorage', e);
    }
  }
}
