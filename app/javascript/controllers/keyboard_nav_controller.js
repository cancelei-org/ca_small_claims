import { Controller } from '@hotwired/stimulus';
import { EventBinder } from 'utils/event_binder';

/**
 * Keyboard Navigation Controller
 *
 * Handles keyboard navigation between form fields on mobile devices.
 * Implements Next/Done button functionality and Enter key navigation.
 */
export default class extends Controller {
  static targets = ['input'];

  connect() {
    // Detect if on mobile device
    this.isMobile = /iPhone|iPad|iPod|Android/iu.test(navigator.userAgent);

    // Listen for focus changes to update enterkeyhint
    this.events = new EventBinder(this);
    this.events.on(this.element, 'focusin', this.handleFocusIn);
  }

  disconnect() {
    this.events?.unbindAll();
  }

  /**
   * Handle keydown events on form fields
   * Moves focus to next field on Enter, or submits if last field
   */
  handleKeydown(event) {
    if (event.key !== 'Enter') {
      return;
    }

    const currentInput = event.target;

    // Don't interfere with textareas (allow newlines)
    if (currentInput.tagName === 'TEXTAREA') {
      return;
    }

    // Don't interfere with submit buttons
    if (currentInput.type === 'submit') {
      return;
    }

    event.preventDefault();

    const nextInput = this.findNextInput(currentInput);

    if (nextInput) {
      // Move to next field
      nextInput.focus();

      // Scroll into view with keyboard offset on mobile
      if (this.isMobile) {
        this.scrollIntoViewWithKeyboard(nextInput);
      }
    } else {
      // Last field - blur to dismiss keyboard
      currentInput.blur();

      // Optionally trigger form save/advance
      this.dispatchDone(currentInput);
    }
  }

  /**
   * Update enterkeyhint based on field position
   */
  handleFocusIn(event) {
    const input = event.target;

    if (!this.isFormInput(input)) {
      return;
    }

    const nextInput = this.findNextInput(input);

    // Set appropriate hint for mobile keyboard
    if (nextInput) {
      input.setAttribute('enterkeyhint', 'next');
    } else {
      input.setAttribute('enterkeyhint', 'done');
    }
  }

  /**
   * Find the next focusable input after the current one
   */
  findNextInput(currentInput) {
    const inputs = this.getAllFormInputs();
    const currentIndex = inputs.indexOf(currentInput);

    if (currentIndex === -1 || currentIndex === inputs.length - 1) {
      return null;
    }

    // Find next visible, enabled input
    for (let i = currentIndex + 1; i < inputs.length; i++) {
      const input = inputs[i];

      if (this.isInteractable(input)) {
        return input;
      }
    }

    return null;
  }

  /**
   * Get all form inputs in DOM order
   */
  getAllFormInputs() {
    const form = this.element.closest('form') || this.element;
    const selector =
      "input:not([type='hidden']):not([type='submit']):not([type='button']), textarea, select";

    return Array.from(form.querySelectorAll(selector));
  }

  /**
   * Check if element is a form input
   */
  isFormInput(element) {
    return element.matches('input, textarea, select');
  }

  /**
   * Check if input is visible and enabled
   */
  isInteractable(input) {
    if (input.disabled || input.readOnly) {
      return false;
    }
    if (input.type === 'hidden') {
      return false;
    }

    // Check visibility
    const style = window.getComputedStyle(input);

    if (style.display === 'none' || style.visibility === 'hidden') {
      return false;
    }

    // Check if within visible container (not in collapsed details, etc.)
    const rect = input.getBoundingClientRect();

    if (rect.width === 0 || rect.height === 0) {
      return false;
    }

    return true;
  }

  /**
   * Scroll element into view accounting for mobile keyboard
   */
  scrollIntoViewWithKeyboard(element) {
    // Wait for keyboard animation
    setTimeout(() => {
      const rect = element.getBoundingClientRect();
      const viewportHeight = window.innerHeight;

      // Estimate keyboard height (roughly 40% of viewport on mobile)
      const estimatedKeyboardHeight = viewportHeight * 0.4;
      const visibleHeight = viewportHeight - estimatedKeyboardHeight;

      // If element is below visible area, scroll it into view
      if (rect.top > visibleHeight - 100) {
        element.scrollIntoView({
          behavior: 'smooth',
          block: 'center'
        });
      }
    }, 100);
  }

  /**
   * Dispatch done event when last field completed
   */
  dispatchDone(input) {
    const event = new CustomEvent('keyboard-nav:done', {
      bubbles: true,
      detail: { input }
    });

    this.element.dispatchEvent(event);
  }
}
