import { Controller } from '@hotwired/stimulus';

/**
 * Modal Accessibility Controller
 * Provides focus trap, focus restoration, and keyboard handling for modals
 */
export default class extends Controller {
  static targets = ['dialog'];

  connect() {
    this.previouslyFocusedElement = null;

    // Bind event handlers
    this.handleKeydown = this.handleKeydown.bind(this);
    this.handleDialogOpen = this.handleDialogOpen.bind(this);
    this.handleDialogClose = this.handleDialogClose.bind(this);

    // Listen for dialog open/close
    if (this.hasDialogTarget) {
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
      document.removeEventListener('keydown', this.handleKeydown);
    }

    if (this.observer) {
      this.observer.disconnect();
    }
  }

  handleDialogOpen() {
    // Store the previously focused element
    this.previouslyFocusedElement = document.activeElement;

    // Add keyboard listener for focus trap
    document.addEventListener('keydown', this.handleKeydown);

    // Focus the first focusable element in the dialog
    requestAnimationFrame(() => {
      this.focusFirstElement();
    });
  }

  handleDialogClose() {
    // Remove keyboard listener
    document.removeEventListener('keydown', this.handleKeydown);

    // Restore focus to the previously focused element
    if (this.previouslyFocusedElement && this.previouslyFocusedElement.focus) {
      this.previouslyFocusedElement.focus();
    }
  }

  handleKeydown(event) {
    if (event.key === 'Tab') {
      this.trapFocus(event);
    }
  }

  /**
   * Trap focus within the modal dialog
   */
  trapFocus(event) {
    if (!this.hasDialogTarget || !this.dialogTarget.open) {
      return;
    }

    const focusableElements = this.getFocusableElements();

    if (focusableElements.length === 0) {
      return;
    }

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    if (event.shiftKey) {
      // Shift + Tab: If on first element, go to last
      if (document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      }
    } else {
      // Tab: If on last element, go to first
      if (document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    }
  }

  /**
   * Focus the first focusable element in the dialog
   */
  focusFirstElement() {
    if (!this.hasDialogTarget) {
      return;
    }

    const focusableElements = this.getFocusableElements();

    if (focusableElements.length > 0) {
      focusableElements[0].focus();
    }
  }

  /**
   * Get all focusable elements within the dialog
   */
  getFocusableElements() {
    if (!this.hasDialogTarget) {
      return [];
    }

    const selector = [
      'button:not([disabled])',
      'a[href]',
      'input:not([disabled]):not([type="hidden"])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"])'
    ].join(', ');

    return Array.from(this.dialogTarget.querySelectorAll(selector)).filter(
      el => el.offsetParent !== null // Filter out hidden elements
    );
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
