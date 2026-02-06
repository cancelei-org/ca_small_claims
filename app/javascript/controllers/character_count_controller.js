import { Controller } from '@hotwired/stimulus';

/**
 * Character Count Controller
 * Displays remaining character count for inputs with maxlength
 * Provides visual feedback as user approaches the limit
 */
export default class extends Controller {
  static targets = ['input', 'count', 'remaining'];

  static values = {
    max: { type: Number, default: 0 },
    warnAt: { type: Number, default: 20 } // Warn when this many chars remaining
  };

  connect() {
    this.updateCount();
  }

  updateCount() {
    if (!this.hasInputTarget) {
      return;
    }

    const currentLength = this.inputTarget.value.length;
    const maxLength = this.maxValue || this.inputTarget.maxLength || 0;

    if (maxLength <= 0) {
      return;
    }

    const remaining = maxLength - currentLength;

    // Update count display
    if (this.hasCountTarget) {
      this.countTarget.textContent = currentLength;
    }

    // Update remaining display
    if (this.hasRemainingTarget) {
      this.remainingTarget.textContent = remaining;

      // Visual feedback based on remaining characters
      this.remainingTarget.classList.remove(
        'text-base-content/60',
        'text-warning',
        'text-error'
      );

      if (remaining <= 0) {
        this.remainingTarget.classList.add('text-error');
      } else if (remaining <= this.warnAtValue) {
        this.remainingTarget.classList.add('text-warning');
      } else {
        this.remainingTarget.classList.add('text-base-content/60');
      }
    }

    // Update ARIA for screen readers
    if (remaining <= this.warnAtValue && remaining > 0) {
      this.inputTarget.setAttribute(
        'aria-describedby',
        `${this.inputTarget.id}-char-count`
      );
    }
  }
}
