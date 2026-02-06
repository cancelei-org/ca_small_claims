import { Controller } from '@hotwired/stimulus';

/**
 * Form Requirements Controller
 * Handles the "Before you start" checklist
 */
export default class extends Controller {
  static targets = ['checkbox', 'startButton', 'modal'];

  connect() {
    this.updateStartButton();
  }

  toggle(_event) {
    this.updateStartButton();
  }

  updateStartButton() {
    if (!this.hasStartButtonTarget) {
      return;
    }

    const requiredCheckboxes = this.checkboxTargets.filter(
      cb => cb.dataset.required === 'true'
    );
    const allRequiredChecked = requiredCheckboxes.every(cb => cb.checked);

    if (allRequiredChecked) {
      this.startButtonTarget.classList.remove('btn-disabled');
      this.startButtonTarget.removeAttribute('disabled');
    } else {
      this.startButtonTarget.classList.add('btn-disabled');
      this.startButtonTarget.setAttribute('disabled', 'true');
    }
  }

  start() {
    // Save that user has seen requirements for this form
    const formCode = this.element.dataset.formCode;

    if (formCode) {
      localStorage.setItem(`form_requirements_seen_${formCode}`, 'true');
    }

    if (this.hasModalTarget) {
      this.modalTarget.close();
    }
  }

  skip() {
    this.start();
  }
}
