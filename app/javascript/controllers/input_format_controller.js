import { Controller } from '@hotwired/stimulus';

/**
 * Input Format Controller
 * Provides auto-formatting for phone numbers and currency fields
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
        input.value = this.formatPhone(input.value);
        break;
      case 'currency':
        input.value = this.formatCurrency(input.value);
        break;
      case 'zip':
        input.value = this.formatZip(input.value);
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
   * Format phone number as (XXX) XXX-XXXX
   */
  formatPhone(value) {
    // Remove all non-digits
    const digits = value.replace(/\D/gu, '');

    // Limit to 10 digits
    const limited = digits.slice(0, 10);

    // Format based on length
    if (limited.length === 0) {
      return '';
    }

    if (limited.length <= 3) {
      return `(${limited}`;
    }

    if (limited.length <= 6) {
      return `(${limited.slice(0, 3)}) ${limited.slice(3)}`;
    }

    return `(${limited.slice(0, 3)}) ${limited.slice(3, 6)}-${limited.slice(6)}`;
  }

  /**
   * Format currency with thousands separator
   * Preserves decimal point for partial input
   */
  formatCurrency(value) {
    // Remove all non-numeric except decimal point
    let cleaned = value.replace(/[^\d.]/gu, '');

    // Handle multiple decimal points - keep only the first
    const parts = cleaned.split('.');

    if (parts.length > 2) {
      cleaned = `${parts[0]}.${parts.slice(1).join('')}`;
    }

    // Split into integer and decimal parts
    const [intPart, decPart] = cleaned.split('.');

    // Format integer part with commas
    const formattedInt = intPart.replace(/\B(?=(\d{3})+(?!\d))/gu, ',');

    // Combine with decimal part if present
    if (decPart !== undefined) {
      // Limit decimal to 2 places
      return `${formattedInt}.${decPart.slice(0, 2)}`;
    }

    return formattedInt;
  }

  /**
   * Format ZIP code as XXXXX or XXXXX-XXXX
   */
  formatZip(value) {
    // Remove all non-digits
    const digits = value.replace(/\D/gu, '');

    // Limit to 9 digits
    const limited = digits.slice(0, 9);

    // Format with dash for ZIP+4
    if (limited.length <= 5) {
      return limited;
    }

    return `${limited.slice(0, 5)}-${limited.slice(5)}`;
  }

  /**
   * Get raw numeric value (for form submission)
   */
  getRawValue() {
    if (!this.hasInputTarget) {
      return '';
    }

    const value = this.inputTarget.value;

    switch (this.typeValue) {
      case 'phone':
        return value.replace(/\D/gu, '');
      case 'currency':
        return value.replace(/[^\d.]/gu, '');
      case 'zip':
        return value.replace(/\D/gu, '');
      default:
        return value;
    }
  }
}
