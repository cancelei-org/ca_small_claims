import { Controller } from '@hotwired/stimulus';

// Handles conditional show/hide of form sections based on field values
export default class extends Controller {
  static targets = ['trigger', 'section'];
  static values = {
    showWhen: String, // Format: "field_name:value" or "field_name:value1,value2"
    hideWhen: String
  };

  connect() {
    this.evaluate();
  }

  changed() {
    this.evaluate();
  }

  evaluate() {
    if (!this.hasSectionTarget) {
      return;
    }

    let shouldShow = true;

    if (this.hasShowWhenValue && this.showWhenValue) {
      shouldShow = this.checkCondition(this.showWhenValue);
    }

    if (this.hasHideWhenValue && this.hideWhenValue) {
      shouldShow = !this.checkCondition(this.hideWhenValue);
    }

    this.sectionTarget.classList.toggle('hidden', !shouldShow);

    // Also toggle the required attribute on hidden inputs
    const inputs = this.sectionTarget.querySelectorAll(
      'input, select, textarea'
    );

    inputs.forEach(input => {
      if (!shouldShow) {
        input.dataset.wasRequired = input.required;
        input.required = false;
      } else if (input.dataset.wasRequired === 'true') {
        input.required = true;
      }
    });
  }

  checkCondition(condition) {
    const [fieldName, values] = condition.split(':');
    const allowedValues = values.split(',').map(v => v.trim().toLowerCase());

    // Find the field by name
    const field = document.querySelector(`[name*="${fieldName}"]`);

    if (!field) {
      return false;
    }

    let fieldValue = '';

    if (field.type === 'checkbox') {
      fieldValue = field.checked ? 'true' : 'false';
    } else if (field.type === 'radio') {
      const checked = document.querySelector(`[name*="${fieldName}"]:checked`);

      fieldValue = checked ? checked.value.toLowerCase() : '';
    } else {
      fieldValue = field.value.toLowerCase();
    }

    return allowedValues.includes(fieldValue);
  }
}
