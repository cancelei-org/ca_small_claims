import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['modal', 'form', 'button'];

  connect() {
    // Handle ESC key to close modal
    this.handleEscape = this.handleEscape.bind(this);
    document.addEventListener('keydown', this.handleEscape);
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleEscape);
  }

  open(event) {
    event.preventDefault();
    if (this.hasModalTarget) {
      this.modalTarget.showModal();
    }
  }

  close(event) {
    if (event) {
      event.preventDefault();
    }
    if (this.hasModalTarget) {
      this.modalTarget.close();
    }
  }

  handleEscape(event) {
    if (
      event.key === 'Escape' &&
      this.hasModalTarget &&
      this.modalTarget.open
    ) {
      this.close();
    }
  }

  // Close modal when clicking backdrop
  backdropClick(event) {
    if (event.target === this.modalTarget) {
      this.close();
    }
  }

  // Reset form when modal is closed
  reset() {
    if (this.hasFormTarget) {
      this.formTarget.reset();
    }
  }
}
