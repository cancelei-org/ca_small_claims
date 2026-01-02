import { Controller } from '@hotwired/stimulus';

/**
 * Address Controller
 * Manages structured address fields and combines them into a single value
 * Also provides ZIP code formatting
 */
export default class extends Controller {
  static targets = ['street1', 'street2', 'city', 'state', 'zip', 'combined'];

  static values = {
    separator: { type: String, default: '\n' }
  };

  connect() {
    this.updateCombined();
  }

  /**
   * Update the combined hidden field with all address parts
   */
  updateCombined() {
    if (!this.hasCombinedTarget) {
      return;
    }

    const parts = [];

    if (this.hasStreet1Target && this.street1Target.value.trim()) {
      parts.push(this.street1Target.value.trim());
    }

    if (this.hasStreet2Target && this.street2Target.value.trim()) {
      parts.push(this.street2Target.value.trim());
    }

    // City, State ZIP line
    const cityStateZip = this.formatCityStateZip();

    if (cityStateZip) {
      parts.push(cityStateZip);
    }

    this.combinedTarget.value = parts.join(this.separatorValue);

    // Trigger change event for form controller
    this.combinedTarget.dispatchEvent(new Event('change', { bubbles: true }));
  }

  /**
   * Format City, State ZIP line
   */
  formatCityStateZip() {
    const city = this.hasCityTarget ? this.cityTarget.value.trim() : '';
    const state = this.hasStateTarget ? this.stateTarget.value.trim() : '';
    const zip = this.hasZipTarget ? this.zipTarget.value.trim() : '';

    if (!city && !state && !zip) {
      return '';
    }

    let result = city;

    if (state) {
      result += result ? `, ${state}` : state;
    }

    if (zip) {
      result += result ? ` ${zip}` : zip;
    }

    return result;
  }

  /**
   * Format ZIP code as user types (XXXXX or XXXXX-XXXX)
   */
  formatZip() {
    if (!this.hasZipTarget) {
      return;
    }

    const input = this.zipTarget;
    let value = input.value.replace(/\D/gu, '');

    // Limit to 9 digits
    value = value.slice(0, 9);

    // Format with dash for ZIP+4
    if (value.length > 5) {
      value = `${value.slice(0, 5)}-${value.slice(5)}`;
    }

    input.value = value;
    this.updateCombined();
  }

  /**
   * Handle field change
   */
  fieldChanged() {
    this.updateCombined();
  }

  /**
   * Parse an existing combined address into parts (for editing)
   * Called on connect if combined field has a value
   */
  parseExisting() {
    if (!this.hasCombinedTarget || !this.combinedTarget.value) {
      return;
    }

    const lines = this.combinedTarget.value.split(/\n/u);

    if (lines.length >= 1 && this.hasStreet1Target) {
      this.street1Target.value = lines[0] || '';
    }

    if (lines.length >= 3 && this.hasStreet2Target) {
      // If 3+ lines, second line is street2
      this.street2Target.value = lines[1] || '';
    }

    // Parse last line for City, State ZIP
    const lastLine = lines[lines.length - 1] || '';
    const cityStateZipMatch = lastLine.match(
      /^(.+),\s*([A-Z]{2})\s*(\d{5}(?:-\d{4})?)$/iu
    );

    if (cityStateZipMatch) {
      if (this.hasCityTarget) {
        this.cityTarget.value = cityStateZipMatch[1].trim();
      }

      if (this.hasStateTarget) {
        this.stateTarget.value = cityStateZipMatch[2].toUpperCase();
      }

      if (this.hasZipTarget) {
        this.zipTarget.value = cityStateZipMatch[3];
      }
    }
  }
}
