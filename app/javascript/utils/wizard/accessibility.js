/**
 * Accessibility Utilities for Wizard
 * Handles screen reader announcements and ARIA updates
 */

/**
 * Live region element ID
 */
const LIVE_REGION_ID = 'wizard-live-region';

/**
 * Get or create the live region element for screen reader announcements
 * @returns {HTMLElement} The live region element
 */
function getOrCreateLiveRegion() {
  let liveRegion = document.getElementById(LIVE_REGION_ID);

  if (!liveRegion) {
    liveRegion = document.createElement('div');
    liveRegion.id = LIVE_REGION_ID;
    liveRegion.className = 'sr-only';
    liveRegion.setAttribute('aria-live', 'polite');
    liveRegion.setAttribute('aria-atomic', 'true');
    document.body.appendChild(liveRegion);
  }

  return liveRegion;
}

/**
 * Announce a message to screen readers
 * @param {string} message - The message to announce
 * @param {'polite' | 'assertive'} priority - Announcement priority
 */
export function announceToScreenReader(message, priority = 'polite') {
  const liveRegion = getOrCreateLiveRegion();

  // Set the priority
  liveRegion.setAttribute('aria-live', priority);

  // Clear and set the message to ensure it's announced
  liveRegion.textContent = '';

  // Use requestAnimationFrame to ensure the clear is processed first
  requestAnimationFrame(() => {
    liveRegion.textContent = message;
  });
}

/**
 * Announce navigation change
 * @param {string} direction - 'next' or 'previous'
 * @param {number} currentStep - Current step number (1-based)
 * @param {number} totalSteps - Total number of steps
 * @param {string} fieldLabel - Label of the current field (optional)
 */
export function announceNavigation(direction, currentStep, totalSteps, fieldLabel = '') {
  const directionText = direction === 'next' ? 'Next' : 'Previous';
  let message = `${directionText}: Step ${currentStep} of ${totalSteps}`;

  if (fieldLabel) {
    message += `. ${fieldLabel}`;
  }

  announceToScreenReader(message);
}

/**
 * Announce validation error
 * @param {string} fieldLabel - Label of the field with error
 * @param {string} errorMessage - The validation error message
 */
export function announceValidationError(fieldLabel, errorMessage) {
  const message = `Error: ${fieldLabel}. ${errorMessage}`;
  announceToScreenReader(message, 'assertive');
}

/**
 * Announce completion status
 * @param {number} completedSteps - Number of completed steps
 * @param {number} totalSteps - Total number of steps
 */
export function announceProgress(completedSteps, totalSteps) {
  const percentage = Math.round((completedSteps / totalSteps) * 100);
  const message = `Progress: ${percentage}% complete. ${completedSteps} of ${totalSteps} fields filled.`;
  announceToScreenReader(message);
}

/**
 * Create focus trap within an element
 * @param {HTMLElement} element - The element to trap focus within
 * @returns {Object} Object with activate/deactivate methods
 */
export function createFocusTrap(element) {
  const focusableSelectors = [
    'button:not([disabled])',
    'input:not([disabled])',
    'select:not([disabled])',
    'textarea:not([disabled])',
    '[tabindex]:not([tabindex="-1"])',
    'a[href]'
  ].join(', ');

  let previousFocus = null;

  const getFocusableElements = () => {
    return element.querySelectorAll(focusableSelectors);
  };

  const handleKeydown = (event) => {
    if (event.key !== 'Tab') {
      return;
    }

    const focusableElements = getFocusableElements();

    if (focusableElements.length === 0) {
      event.preventDefault();
      return;
    }

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    if (event.shiftKey && document.activeElement === firstElement) {
      event.preventDefault();
      lastElement.focus();
    } else if (!event.shiftKey && document.activeElement === lastElement) {
      event.preventDefault();
      firstElement.focus();
    }
  };

  return {
    activate: () => {
      previousFocus = document.activeElement;
      element.addEventListener('keydown', handleKeydown);

      // Focus first focusable element
      const focusableElements = getFocusableElements();

      if (focusableElements.length > 0) {
        focusableElements[0].focus();
      }
    },
    deactivate: () => {
      element.removeEventListener('keydown', handleKeydown);

      // Restore previous focus
      if (previousFocus && previousFocus.focus) {
        previousFocus.focus();
      }
    }
  };
}
