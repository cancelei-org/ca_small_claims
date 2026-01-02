import { Controller } from '@hotwired/stimulus';
import { ModalUtils } from 'utils/modal_behavior';

/**
 * PDF Drawer Controller
 * Handles the mobile/tablet PDF preview drawer slide-in panel
 * Includes focus management for accessibility
 */
export default class extends Controller {
  static targets = ['drawer', 'backdrop', 'panel', 'closeButton'];

  connect() {
    this._cleanupEscape = ModalUtils.setupEscapeKey(() => this.close());
    this._onInput = this.handleInput.bind(this);
    this._handleKeydown = this.handleKeydown.bind(this);
    this.previouslyFocusedElement = null;

    document.addEventListener('input', this._onInput);
  }

  disconnect() {
    this._cleanupEscape?.();
    document.removeEventListener('input', this._onInput);
    document.removeEventListener('keydown', this._handleKeydown);
    ModalUtils.enableBodyScroll();
  }

  handleInput(event) {
    if (
      this.isOpen &&
      this.hasDrawerTarget &&
      !this.drawerTarget.contains(event.target)
    ) {
      this.close();
    }
  }

  handleKeydown(event) {
    if (!this.isOpen) {
      return;
    }

    if (event.key === 'Tab') {
      this.trapFocus(event);
    }
  }

  /**
   * Trap focus within the drawer panel
   */
  trapFocus(event) {
    if (!this.hasPanelTarget) {
      return;
    }

    const focusableElements = this.getFocusableElements();

    if (focusableElements.length === 0) {
      return;
    }

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    if (event.shiftKey) {
      if (document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      }
    } else if (document.activeElement === lastElement) {
      event.preventDefault();
      firstElement.focus();
    }
  }

  /**
   * Get all focusable elements within the drawer panel
   */
  getFocusableElements() {
    if (!this.hasPanelTarget) {
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

    return Array.from(this.panelTarget.querySelectorAll(selector)).filter(
      el => el.offsetParent !== null
    );
  }

  get isOpen() {
    return this.hasDrawerTarget && this.drawerTarget.classList.contains('open');
  }

  open() {
    // Store previously focused element for restoration
    this.previouslyFocusedElement = document.activeElement;

    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.add('open');
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('hidden');
      // Trigger reflow for transition
      if (this.backdropTarget.offsetWidth) {
        this.backdropTarget.classList.add('open');
      }
    }

    // Add focus trap keyboard listener
    document.addEventListener('keydown', this._handleKeydown);

    // Focus the close button or first focusable element
    requestAnimationFrame(() => {
      if (this.hasCloseButtonTarget) {
        this.closeButtonTarget.focus();
      } else {
        const focusable = this.getFocusableElements();

        if (focusable.length > 0) {
          focusable[0].focus();
        }
      }
    });

    ModalUtils.disableBodyScroll();
    this.dispatch('opened');
  }

  close() {
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.remove('open');
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('open');
      ModalUtils.afterTransition(this.backdropTarget, () => {
        if (!this.backdropTarget.classList.contains('open')) {
          this.backdropTarget.classList.add('hidden');
        }
      });
    }

    // Remove focus trap keyboard listener
    document.removeEventListener('keydown', this._handleKeydown);

    // Restore focus to previously focused element
    if (this.previouslyFocusedElement && this.previouslyFocusedElement.focus) {
      this.previouslyFocusedElement.focus();
      this.previouslyFocusedElement = null;
    }

    ModalUtils.enableBodyScroll();
    this.dispatch('closed');
  }

  toggle() {
    if (this.hasDrawerTarget && this.drawerTarget.classList.contains('open')) {
      this.close();
    } else {
      this.open();
    }
  }
}
