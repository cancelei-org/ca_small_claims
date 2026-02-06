import { Controller } from '@hotwired/stimulus';
import {
  formatZip,
  formatPhone,
  formatCurrency,
  getRawValue
} from '../utils/inputFormatting';

/**
 * Input Format Controller
 * Provides auto-formatting for phone numbers, currency, and ZIP fields
 */
export default class extends Controller {
  static targets = ['input'];

  static values = {
    type: { type: String, default: 'text' } // 'phone', 'currency', 'zip'
  };

  connect() {
    if (this.hasInputTarget) {
      this.format();
    }
  }

  /**
   * Format input value based on type
   */
  format() {
    if (!this.hasInputTarget) {
      return;
    }

    const input = this.inputTarget;
    const cursorPos = input.selectionStart;
    const oldLength = input.value.length;

    switch (this.typeValue) {
      case 'phone':
        input.value = formatPhone(input.value);
        break;
      case 'currency':
        input.value = formatCurrency(input.value);
        break;
      case 'zip':
        input.value = formatZip(input.value);
        break;
      default:
        break;
    }

    // Adjust cursor position after formatting
    const newLength = input.value.length;
    const diff = newLength - oldLength;
    const newPos = Math.max(0, cursorPos + diff);

    // Restore cursor position
    if (input === document.activeElement) {
      requestAnimationFrame(() => {
        input.setSelectionRange(newPos, newPos);
      });
    }
  }

  /**
   * Get raw numeric value (for form submission)
   */
  getRawValue() {
    if (!this.hasInputTarget) {
      return '';
    }

    return getRawValue(this.inputTarget.value, this.typeValue);
  }
}
