import { Controller } from '@hotwired/stimulus';

/**
 * FAQ Controller
 * Handles opening the FAQ modal and scrolling to specific sections
 */
export default class extends Controller {
  static targets = ['modal', 'content'];

  connect() {
    this.modalElement = document.getElementById('faq-modal');
  }

  open(event) {
    const anchor = event.currentTarget.dataset.faqAnchor;

    if (!this.modalElement) {
      return;
    }

    this.modalElement.showModal();

    if (anchor) {
      // Small delay to ensure modal is rendered
      setTimeout(() => {
        const target = this.modalElement.querySelector(`#faq-${anchor}`);

        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          target.classList.add('bg-primary/10', 'rounded-lg', 'p-2');
          setTimeout(() => target.classList.remove('bg-primary/10'), 2000);
        }
      }, 100);
    }
  }

  close() {
    if (this.modalElement) {
      this.modalElement.close();
    }
  }
}
