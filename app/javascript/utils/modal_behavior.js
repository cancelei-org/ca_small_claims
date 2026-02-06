/**
 * Modal Behavior Mixin
 * Provides common functionality for modal/drawer controllers:
 * - Escape key handling
 * - Body scroll locking
 * - Backdrop click handling
 * - Focus trapping
 * - Focus restoration
 *
 * Usage:
 *   import { withModalBehavior, FocusTrap } from "utils/modal_behavior"
 *
 *   class MyModalController extends Controller {
 *     connect() { this.initModalBehavior() }
 *     disconnect() { this.cleanupModalBehavior() }
 *     isOpen() { return this.modalTarget.open }  // implement this
 *     performClose() { this.modalTarget.close() } // implement this
 *   }
 *   withModalBehavior(MyModalController)
 */

/**
 * Focus Trap Utility
 * Provides focus management for modal dialogs, drawers, and bottom sheets.
 * Consolidates duplicated focus trap logic across multiple controllers.
 */
export const FocusTrap = {
  /**
   * Selector for all focusable elements
   */
  FOCUSABLE_SELECTOR: [
    'button:not([disabled])',
    'a[href]',
    'input:not([disabled]):not([type="hidden"])',
    'select:not([disabled])',
    'textarea:not([disabled])',
    '[tabindex]:not([tabindex="-1"])'
  ].join(', '),

  /**
   * Get all focusable elements within a container
   * @param {HTMLElement} container - The container element
   * @returns {HTMLElement[]} Array of focusable elements
   */
  getFocusableElements(container) {
    if (!container) {
      return [];
    }

    return Array.from(
      container.querySelectorAll(this.FOCUSABLE_SELECTOR)
    ).filter(
      el => el.offsetParent !== null // Filter out hidden elements
    );
  },

  /**
   * Trap focus within a container on Tab key press
   * @param {KeyboardEvent} event - The keyboard event
   * @param {HTMLElement} container - The container to trap focus within
   */
  trapFocus(event, container) {
    if (!container) {
      return;
    }

    const focusableElements = this.getFocusableElements(container);

    if (focusableElements.length === 0) {
      return;
    }

    const [firstElement] = focusableElements;
    const lastElement = focusableElements[focusableElements.length - 1];

    if (event.shiftKey) {
      // Shift + Tab: If on first element, go to last
      if (document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      }
    } else if (document.activeElement === lastElement) {
      // Tab: If on last element, go to first
      event.preventDefault();
      firstElement.focus();
    }
  },

  /**
   * Focus the first focusable element in a container
   * @param {HTMLElement} container - The container element
   * @param {HTMLElement} [preferredElement] - Optional preferred element to focus first
   */
  focusFirst(container, preferredElement = null) {
    if (preferredElement?.focus) {
      preferredElement.focus();

      return;
    }

    const focusableElements = this.getFocusableElements(container);

    if (focusableElements.length > 0) {
      focusableElements[0].focus();
    }
  },

  /**
   * Create a focus manager instance for a modal/drawer
   * @param {HTMLElement} container - The container element
   * @returns {Object} Focus manager with open/close methods
   */
  createManager(container) {
    let previouslyFocusedElement = null;
    let keydownHandler = null;

    return {
      /**
       * Activate focus trap - call when opening modal
       * @param {HTMLElement} [preferredFocusElement] - Optional element to focus first
       */
      activate(preferredFocusElement = null) {
        previouslyFocusedElement = document.activeElement;

        keydownHandler = event => {
          if (event.key === 'Tab') {
            FocusTrap.trapFocus(event, container);
          }
        };

        document.addEventListener('keydown', keydownHandler);

        requestAnimationFrame(() => {
          FocusTrap.focusFirst(container, preferredFocusElement);
        });
      },

      /**
       * Deactivate focus trap - call when closing modal
       */
      deactivate() {
        if (keydownHandler) {
          document.removeEventListener('keydown', keydownHandler);
          keydownHandler = null;
        }

        if (previouslyFocusedElement?.focus) {
          previouslyFocusedElement.focus();
          previouslyFocusedElement = null;
        }
      },

      /**
       * Get the previously focused element (for custom handling)
       */
      getPreviouslyFocused() {
        return previouslyFocusedElement;
      }
    };
  }
};

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
