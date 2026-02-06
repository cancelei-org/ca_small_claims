import { Controller } from '@hotwired/stimulus';

// Manages the Form Finder wizard interactions
export default class extends Controller {
  static targets = ['nextButton'];

  connect() {
    this.updateButtonState();
  }

  selectOption(_event) {
    this.updateButtonState();
  }

  updateButtonState() {
    if (!this.hasNextButtonTarget) {
      return;
    }

    // Check if any radio button in the form is selected
    const form = this.element.querySelector('form');

    if (!form) {
      return;
    }

    const selectedRadio = form.querySelector('input[type="radio"]:checked');

    this.nextButtonTarget.disabled = !selectedRadio;
  }
}
