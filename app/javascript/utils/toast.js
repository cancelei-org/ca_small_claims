/**
 * Toast notification utility
 * Creates accessible toast notifications with auto-dismiss
 * Respects reduced motion preferences for users with vestibular disorders
 *
 * Usage:
 *   import { showToast } from '../utils/toast';
 *   showToast('Form saved successfully', 'success');
 *   showToast('Please fill required fields', 'error');
 */

/**
 * Check if reduced motion is preferred
 */
function prefersReducedMotion() {
  // Check user override first
  const userPref = localStorage.getItem('motion-preference');

  if (userPref === 'reduce') {
    return true;
  }

  if (userPref === 'normal') {
    return false;
  }

  // Fall back to system preference
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

const TOAST_TYPES = {
  success: {
    bgClass: 'bg-success',
    textClass: 'text-success-content',
    icon: `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
    </svg>`
  },
  error: {
    bgClass: 'bg-error',
    textClass: 'text-error-content',
    icon: `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
    </svg>`
  },
  warning: {
    bgClass: 'bg-warning',
    textClass: 'text-warning-content',
    icon: `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
    </svg>`
  },
  info: {
    bgClass: 'bg-info',
    textClass: 'text-info-content',
    icon: `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
    </svg>`
  }
};

/**
 * Get or create the toast container
 */
function getToastContainer() {
  let container = document.getElementById('toast-container');

  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    container.className = 'fixed bottom-4 right-4 z-50 flex flex-col gap-2';
    container.setAttribute('aria-live', 'polite');
    container.setAttribute('aria-atomic', 'false');
    document.body.appendChild(container);
  }

  return container;
}

/**
 * Show a toast notification
 * @param {string} message - The message to display
 * @param {string} type - Toast type: 'success', 'error', 'warning', 'info'
 * @param {number} duration - Time in ms before auto-dismiss (default: 4000)
 */
export function showToast(message, type = 'info', duration = 4000) {
  const container = getToastContainer();
  const config = TOAST_TYPES[type] || TOAST_TYPES.info;
  const reduceMotion = prefersReducedMotion();

  const toast = document.createElement('div');

  // Use shorter transition for reduced motion
  const transitionClass = reduceMotion
    ? 'transition-opacity duration-100'
    : 'transition-all duration-300';

  // Start state differs based on motion preference
  const startState = reduceMotion
    ? 'opacity-0'
    : 'transform translate-x-full opacity-0';

  toast.className = `
    flex items-center gap-3 px-4 py-3 rounded-lg shadow-lg
    ${config.bgClass} ${config.textClass}
    ${startState} ${transitionClass}
    max-w-sm
  `.trim();

  toast.setAttribute('role', 'alert');
  toast.innerHTML = `
    <span class="flex-shrink-0">${config.icon}</span>
    <span class="text-sm font-medium">${escapeHtml(message)}</span>
    <button type="button"
            class="ml-auto -mr-1 p-1 rounded hover:bg-black/10 focus:outline-none focus:ring-2 focus:ring-white/50"
            aria-label="Dismiss">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
      </svg>
    </button>
  `;

  // Dismiss on close button click
  const closeBtn = toast.querySelector('button');

  closeBtn.addEventListener('click', () => dismissToast(toast, reduceMotion));

  container.appendChild(toast);

  // Trigger enter animation
  requestAnimationFrame(() => {
    if (reduceMotion) {
      toast.classList.remove('opacity-0');
    } else {
      toast.classList.remove('translate-x-full', 'opacity-0');
    }
  });

  // Auto-dismiss after duration
  if (duration > 0) {
    setTimeout(() => dismissToast(toast, reduceMotion), duration);
  }

  return toast;
}

/**
 * Dismiss a toast with animation
 * @param {HTMLElement} toast - The toast element
 * @param {boolean} reduceMotion - Whether to use reduced motion
 */
function dismissToast(toast, reduceMotion = false) {
  if (reduceMotion) {
    toast.classList.add('opacity-0');
    setTimeout(() => toast.remove(), 100);
  } else {
    toast.classList.add('translate-x-full', 'opacity-0');
    setTimeout(() => toast.remove(), 300);
  }
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text) {
  const div = document.createElement('div');

  div.textContent = text;

  return div.innerHTML;
}

/**
 * Show field validation error
 * Updates the field's error container and shows a toast
 * Screen reader accessible with aria-describedby linking
 * @param {HTMLElement} field - The input element
 * @param {string} message - Error message
 */
export function showFieldError(field, message) {
  // Find and update error container
  const wrapper = field.closest('[data-field-name]');
  const errorContainer = wrapper?.querySelector('.field-error');

  if (errorContainer) {
    errorContainer.textContent = message;
    errorContainer.classList.remove('hidden');

    // Ensure error container has an ID for aria-describedby
    if (!errorContainer.id) {
      errorContainer.id = `error-${field.name || field.id || Math.random().toString(36).slice(2)}`;
    }

    // Set aria-live on error container for screen reader announcements
    errorContainer.setAttribute('aria-live', 'assertive');
    errorContainer.setAttribute('role', 'alert');

    // Link field to its error message for screen readers
    const existingDescribedBy = field.getAttribute('aria-describedby');

    if (!existingDescribedBy?.includes(errorContainer.id)) {
      field.setAttribute(
        'aria-describedby',
        existingDescribedBy
          ? `${existingDescribedBy} ${errorContainer.id}`
          : errorContainer.id
      );
    }
  }

  // Add error styling to input
  field.classList.add('input-error', 'border-error');
  field.setAttribute('aria-invalid', 'true');

  // Show toast for immediate feedback
  showToast(message, 'error', 5000);
}

/**
 * Clear field validation error
 * @param {HTMLElement} field - The input element
 */
export function clearFieldError(field) {
  const wrapper = field.closest('[data-field-name]');
  const errorContainer = wrapper?.querySelector('.field-error');

  if (errorContainer) {
    errorContainer.textContent = '';
    errorContainer.classList.add('hidden');
  }

  field.classList.remove('input-error', 'border-error');
  field.removeAttribute('aria-invalid');
}

export default { showToast, showFieldError, clearFieldError };
