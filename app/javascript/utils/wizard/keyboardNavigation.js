/**
 * Keyboard Navigation Utilities for Wizard
 * Handles keyboard shortcuts and navigation
 */

/**
 * Default keyboard navigation configuration
 */
export const KEYBOARD_CONFIG = {
  enableArrowKeys: true,
  enableEnterKey: true,
  enableTabKey: true,
  enableEscapeKey: true
};

/**
 * Create keyboard navigation handler
 * @param {Object} options - Configuration options
 * @param {Function} options.onNext - Callback for next navigation
 * @param {Function} options.onPrevious - Callback for previous navigation
 * @param {Function} options.onSubmit - Callback for enter/submit
 * @param {Function} options.onEscape - Callback for escape key
 * @param {Function} options.canAdvance - Function to check if can advance
 * @param {Function} options.isInputFocused - Function to check if input is focused
 * @param {Object} options.config - Override default config
 * @returns {Object} Object with bind/unbind methods and handler
 */
export function createKeyboardHandler(options = {}) {
  const {
    onNext,
    onPrevious,
    onSubmit,
    onEscape,
    canAdvance = () => true,
    isInputFocused = () => false,
    config = {}
  } = options;

  const mergedConfig = { ...KEYBOARD_CONFIG, ...config };

  const handleKeydown = (event) => {
    const { key, shiftKey, metaKey, ctrlKey } = event;

    // Don't interfere with browser shortcuts
    if (metaKey || ctrlKey) {
      return;
    }

    // Check if we're focused on an input
    const inputFocused = isInputFocused();

    switch (key) {
      case 'ArrowRight':
      case 'ArrowDown':
        if (mergedConfig.enableArrowKeys && !inputFocused) {
          event.preventDefault();
          if (canAdvance()) {
            onNext?.();
          }
        }
        break;

      case 'ArrowLeft':
      case 'ArrowUp':
        if (mergedConfig.enableArrowKeys && !inputFocused) {
          event.preventDefault();
          onPrevious?.();
        }
        break;

      case 'Enter':
        if (mergedConfig.enableEnterKey) {
          // Don't prevent default for textareas or submit buttons
          const activeElement = document.activeElement;
          const isTextarea = activeElement?.tagName === 'TEXTAREA';
          const isSubmitButton =
            activeElement?.type === 'submit' ||
            activeElement?.tagName === 'BUTTON';

          if (!isTextarea && !isSubmitButton) {
            event.preventDefault();
            if (canAdvance()) {
              onSubmit?.() ?? onNext?.();
            }
          }
        }
        break;

      case 'Tab':
        if (mergedConfig.enableTabKey) {
          // Allow normal tab behavior but track it
          if (shiftKey) {
            // Shift+Tab - might want to go to previous card
          }
        }
        break;

      case 'Escape':
        if (mergedConfig.enableEscapeKey && onEscape) {
          event.preventDefault();
          onEscape();
        }
        break;

      default:
        // No action for other keys
        break;
    }
  };

  return {
    handleKeydown,
    bind: (element = document) => {
      element.addEventListener('keydown', handleKeydown);
    },
    unbind: (element = document) => {
      element.removeEventListener('keydown', handleKeydown);
    }
  };
}

/**
 * Check if the active element is a text input
 * @returns {boolean}
 */
export function isTextInputFocused() {
  const activeElement = document.activeElement;

  if (!activeElement) {
    return false;
  }

  const tagName = activeElement.tagName.toLowerCase();
  const inputType = activeElement.type?.toLowerCase();

  // Check for text-based inputs
  if (tagName === 'textarea') {
    return true;
  }

  if (tagName === 'input') {
    const textTypes = ['text', 'email', 'tel', 'url', 'search', 'password', 'number'];
    return textTypes.includes(inputType);
  }

  // Check for contenteditable
  return activeElement.isContentEditable;
}
