import { Controller } from '@hotwired/stimulus';
import { ModalUtils } from 'utils/modal_behavior';

export default class extends Controller {
  static targets = ['modal', 'form', 'button'];

  connect() {
    this._cleanupEscape = ModalUtils.setupEscapeKey(() => {
      if (this.isOpen()) {
        this.close();
      }
    });
  }

  disconnect() {
    this._cleanupEscape?.();
  }

  isOpen() {
    return this.hasModalTarget && this.modalTarget.open;
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
