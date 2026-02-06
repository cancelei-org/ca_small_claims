import { Controller } from '@hotwired/stimulus';
import { FocusTrap } from 'utils/modal_behavior';

/**
 * Modal Accessibility Controller
 * Provides focus trap, focus restoration, and keyboard handling for modals
 */
export default class extends Controller {
  static targets = ['dialog'];

  connect() {
    // Bind event handlers
    this.handleDialogOpen = this.handleDialogOpen.bind(this);
    this.handleDialogClose = this.handleDialogClose.bind(this);

    // Listen for dialog open/close
    if (this.hasDialogTarget) {
      this.focusManager = FocusTrap.createManager(this.dialogTarget);
      this.dialogTarget.addEventListener('close', this.handleDialogClose);

      // Use MutationObserver to detect when dialog opens
      this.observer = new MutationObserver(mutations => {
        mutations.forEach(mutation => {
          if (mutation.attributeName === 'open') {
            if (this.dialogTarget.open) {
              this.handleDialogOpen();
            }
          }
        });
      });

      this.observer.observe(this.dialogTarget, { attributes: true });
    }
  }

  disconnect() {
    if (this.hasDialogTarget) {
      this.dialogTarget.removeEventListener('close', this.handleDialogClose);
      this.focusManager?.deactivate();
    }

    if (this.observer) {
      this.observer.disconnect();
    }
  }

  handleDialogOpen() {
    this.focusManager?.activate();
  }

  handleDialogClose() {
    this.focusManager?.deactivate();
  }

  /**
   * Open the modal programmatically
   */
  open() {
    if (this.hasDialogTarget) {
      this.dialogTarget.showModal();
    }
  }

  /**
   * Close the modal programmatically
   */
  close() {
    if (this.hasDialogTarget) {
      this.dialogTarget.close();
    }
  }
}
