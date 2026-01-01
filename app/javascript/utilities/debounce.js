/**
 * Debounce utility for rate-limiting function calls.
 * Ensures a function is only called after a specified delay since
 * the last invocation attempt.
 *
 * Usage:
 *   import { debounce, createDebouncedHandler, DEBOUNCE_DELAYS } from "utilities/debounce"
 *
 *   // Simple usage
 *   const debouncedSave = debounce(() => save(), 1000)
 *
 *   // In a Stimulus controller
 *   connect() {
 *     this.debouncedSearch = createDebouncedHandler(() => this.performSearch())
 *   }
 *
 *   disconnect() {
 *     this.debouncedSearch.cancel()
 *   }
 *
 *   search() {
 *     this.debouncedSearch.call(this.debounceDelayValue)
 *   }
 */

// Standard debounce delays used across the application
export const DEBOUNCE_DELAYS = {
  FAST: 300, // For quick interactions like search filtering
  NORMAL: 1000, // For form auto-save
  SLOW: 1500 // For heavy operations like PDF refresh
};

/**
 * Creates a debounced version of a function.
 *
 * @param {Function} fn - The function to debounce
 * @param {number} delay - Delay in milliseconds
 * @returns {Function} - Debounced function with a cancel() method
 */
export function debounce(fn, delay = DEBOUNCE_DELAYS.NORMAL) {
  let timeoutId = null;

  const debouncedFn = function (...args) {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }

    timeoutId = setTimeout(() => {
      fn.apply(this, args);
      timeoutId = null;
    }, delay);
  };

  // Allow canceling the pending debounced call
  debouncedFn.cancel = function () {
    if (timeoutId) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
  };

  // Check if there's a pending call
  debouncedFn.isPending = function () {
    return timeoutId !== null;
  };

  return debouncedFn;
}

/**
 * Creates a debounced handler with dynamic delay support.
 * Useful in Stimulus controllers where delay may come from a value.
 *
 * @param {Function} fn - The function to debounce
 * @returns {Object} - Object with call(delay), cancel(), and isPending() methods
 */
export function createDebouncedHandler(fn) {
  let timeoutId = null;

  return {
    /**
     * Call the debounced function with a specific delay.
     *
     * @param {number} delay - Delay in milliseconds
     * @param {...*} args - Arguments to pass to the function
     */
    call(delay = DEBOUNCE_DELAYS.NORMAL, ...args) {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }

      timeoutId = setTimeout(() => {
        fn.apply(null, args);
        timeoutId = null;
      }, delay);
    },

    /**
     * Cancel any pending debounced call.
     */
    cancel() {
      if (timeoutId) {
        clearTimeout(timeoutId);
        timeoutId = null;
      }
    },

    /**
     * Check if there's a pending call.
     *
     * @returns {boolean}
     */
    isPending() {
      return timeoutId !== null;
    }
  };
}

export default debounce;
