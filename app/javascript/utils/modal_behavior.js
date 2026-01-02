/**
 * Modal Behavior Mixin
 * Provides common functionality for modal/drawer controllers:
 * - Escape key handling
 * - Body scroll locking
 * - Backdrop click handling
 *
 * Usage:
 *   import { withModalBehavior } from "utils/modal_behavior"
 *
 *   class MyModalController extends Controller {
 *     connect() { this.initModalBehavior() }
 *     disconnect() { this.cleanupModalBehavior() }
 *     isOpen() { return this.modalTarget.open }  // implement this
 *     performClose() { this.modalTarget.close() } // implement this
 *   }
 *   withModalBehavior(MyModalController)
 */

export function withModalBehavior(ControllerClass) {
  return class extends ControllerClass {
    initModalBehavior() {
      this._boundHandleKeydown = this._handleKeydown.bind(this);
      document.addEventListener('keydown', this._boundHandleKeydown);
    }

    cleanupModalBehavior() {
      if (this._boundHandleKeydown) {
        document.removeEventListener('keydown', this._boundHandleKeydown);
      }
      this._enableBodyScroll();
    }

    _handleKeydown(event) {
      if (event.key === 'Escape' && this.isOpen?.()) {
        this.close();
      }
    }

    _disableBodyScroll() {
      document.body.style.overflow = 'hidden';
    }

    _enableBodyScroll() {
      document.body.style.overflow = '';
    }

    // Handle backdrop clicks - attach to backdrop element
    handleBackdropClick(event) {
      if (event.target === event.currentTarget) {
        this.close();
      }
    }
  };
}

/**
 * Simpler approach: standalone utilities that controllers can call directly
 */
export const ModalUtils = {
  /**
   * Set up escape key listener
   * @returns {Function} cleanup function to remove listener
   */
  setupEscapeKey(closeCallback) {
    const handler = event => {
      if (event.key === 'Escape') {
        closeCallback();
      }
    };

    document.addEventListener('keydown', handler);

    return () => document.removeEventListener('keydown', handler);
  },

  disableBodyScroll() {
    document.body.style.overflow = 'hidden';
  },

  enableBodyScroll() {
    document.body.style.overflow = '';
  },

  /**
   * Wait for CSS transition to complete before executing callback
   * @param {HTMLElement} element - Element with transition
   * @param {Function} callback - Function to call after transition
   * @param {number} fallbackMs - Fallback timeout in ms (default: 300)
   */
  afterTransition(element, callback, fallbackMs = 300) {
    const handler = () => {
      element.removeEventListener('transitionend', handler);
      callback();
    };

    element.addEventListener('transitionend', handler);
    // Fallback in case transition doesn't fire
    setTimeout(() => {
      element.removeEventListener('transitionend', handler);
      callback();
    }, fallbackMs);
  }
};
