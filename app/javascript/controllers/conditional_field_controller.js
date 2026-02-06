import { Controller } from '@hotwired/stimulus';

// Shows or hides fields based on conditions
export default class extends Controller {
  static targets = ['field'];
  static values = {
    conditions: { type: Array, default: [] },
    logic: { type: String, default: 'and' }
  };

  connect() {
    this.boundHandleChange = this.handleChange.bind(this);
    document.addEventListener('change', this.boundHandleChange);
    document.addEventListener('input', this.boundHandleChange);

    // Initial check
    this.checkConditions();
  }

  disconnect() {
    document.removeEventListener('change', this.boundHandleChange);
    document.removeEventListener('input', this.boundHandleChange);
  }

  handleChange() {
    this.checkConditions();
  }

  checkConditions() {
    const data = this.getFormData();
    const results = this.conditionsValue.map(condition =>
      this.evaluateCondition(condition, data)
    );

    let isMatch = false;

    if (this.logicValue === 'or') {
      isMatch = results.some(r => r);
    } else {
      isMatch = results.every(r => r);
    }

    if (isMatch) {
      this.show();
    } else {
      this.hide();
    }
  }

  evaluateCondition(condition, data) {
    const { field, value: expected } = condition;
    const operator = condition.operator || 'equals';
    const actual = data[field];

    switch (operator) {
      case 'equals':
        return this.valuesEqual(actual, expected);
      case 'not_equals':
        return !this.valuesEqual(actual, expected);
      case 'present':
        return actual !== undefined && `${actual}`.trim() !== '';
      case 'blank':
        return actual === undefined || `${actual}`.trim() === '';
      case 'includes':
        return Array.isArray(actual)
          ? actual.includes(expected)
          : `${actual}`.includes(`${expected}`);
      case 'not_includes':
        return Array.isArray(actual)
          ? !actual.includes(expected)
          : !`${actual}`.includes(`${expected}`);
      case 'matches':
        return this.matchesPattern(actual, expected);
      default:
        return true;
    }
  }

  // Safe regex matching with pattern validation
  matchesPattern(actual, pattern) {
    try {
      // Use literal string matching instead of regex for safety
      return `${actual || ''}`
        .toLowerCase()
        .includes(`${pattern}`.toLowerCase());
    } catch {
      return false;
    }
  }

  // Compare values with type coercion for checkbox/boolean handling
  valuesEqual(actual, expected) {
    // Direct equality
    if (actual === expected) {
      return true;
    }

    // Handle boolean expected values (from YAML) vs string actual values (from form)
    if (expected === true) {
      return actual === '1' || actual === 'true' || actual === 'on';
    }

    if (expected === false) {
      return (
        actual === '0' ||
        actual === 'false' ||
        actual === '' ||
        actual === undefined
      );
    }

    // String comparison (handles numbers as strings)
    return `${actual}` === `${expected}`;
  }

  hide() {
    this.element.classList.add('hidden');
    this.disableInputs(true);
  }

  show() {
    this.element.classList.remove('hidden');
    this.disableInputs(false);
  }

  disableInputs(disabled) {
    this.element
      .querySelectorAll('input, select, textarea, button')
      .forEach(el => {
        el.disabled = disabled;
      });
  }

  getFormData() {
    const form = this.element.closest('form');

    if (!form) {
      return {};
    }

    const formData = new FormData(form);
    const data = {};

    for (const [key, value] of formData.entries()) {
      this.addToData(data, key, value);
      this.extractNestedFieldName(data, key, value);
    }

    return data;
  }

  // Add a value to the data object, handling multiple values
  addToData(data, key, value) {
    if (!data[key]) {
      data[key] = value;
    } else if (Array.isArray(data[key])) {
      data[key].push(value);
    } else {
      data[key] = [data[key], value];
    }
  }

  // Extract field name from Rails-style nested params (e.g., "submission[field_name]")
  extractNestedFieldName(data, key, value) {
    const bracketIndex = key.lastIndexOf('[');

    if (bracketIndex === -1) {
      return;
    }

    const fieldName = key.slice(bracketIndex + 1, -1);

    if (data[fieldName] === undefined) {
      data[fieldName] = value;
    } else if (!Array.isArray(data[fieldName]) && data[fieldName] !== value) {
      data[fieldName] = [data[fieldName], value];
    } else if (Array.isArray(data[fieldName])) {
      data[fieldName].push(value);
    }
  }
}
