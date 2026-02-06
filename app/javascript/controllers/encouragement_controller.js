import { Controller } from '@hotwired/stimulus';
import { showToast } from 'utils/toast';

/**
 * Encouragement Controller
 *
 * Provides contextual encouragement messages during form completion
 * to reduce user anxiety and improve completion rates.
 *
 * Features:
 * - Milestone messages at 25%, 50%, 75%, 90%, 100%
 * - Checkmark animations when completing fields
 * - Progress bar color transitions
 * - Celebration effect at 100%
 * - Respects user preference to disable encouragement
 * - Respects reduced motion preferences
 */
export default class extends Controller {
  static targets = ['progress', 'progressBar', 'field'];

  static values = {
    formCode: String,
    enabled: { type: Boolean, default: true },
    currentPercent: { type: Number, default: 0 }
  };

  // Milestone messages configuration
  static milestones = {
    25: {
      message: "Great start! You're making progress.",
      type: 'encouragement',
      icon: 'rocket'
    },
    50: {
      message: 'Halfway there! Keep going.',
      type: 'encouragement',
      icon: 'star'
    },
    75: {
      message: 'Almost done! Just a few more fields.',
      type: 'encouragement',
      icon: 'fire'
    },
    90: {
      message: "Final stretch! You've got this.",
      type: 'encouragement',
      icon: 'lightning'
    },
    100: {
      message: 'All done! Ready to download.',
      type: 'success',
      icon: 'trophy',
      celebrate: true
    }
  };

  connect() {
    this.shownMilestones = new Set();
    this.loadPreferences();
    this.loadShownMilestones();
    this.bindProgressListener();
    this.bindFieldListeners();

    // Initial check for current progress
    this.checkInitialProgress();
  }

  disconnect() {
    this.unbindProgressListener();
    this.unbindFieldListeners();
  }

  /**
   * Load user preferences from localStorage
   */
  loadPreferences() {
    const pref = localStorage.getItem('encouragement-enabled');

    if (pref !== null) {
      this.enabledValue = pref !== 'false';
    }
  }

  /**
   * Load already shown milestones for this form session
   */
  loadShownMilestones() {
    try {
      const key = this.storageKey('shown-milestones');
      const stored = localStorage.getItem(key);

      if (stored) {
        const data = JSON.parse(stored);
        // Only restore if from the same session (within 30 minutes)
        const thirtyMinutes = 30 * 60 * 1000;

        if (Date.now() - data.timestamp < thirtyMinutes) {
          this.shownMilestones = new Set(data.milestones);
        }
      }
    } catch {
      // Ignore storage errors - localStorage may be unavailable in private browsing
    }
  }

  /**
   * Save shown milestones to localStorage
   */
  saveShownMilestones() {
    try {
      const key = this.storageKey('shown-milestones');
      const data = {
        milestones: Array.from(this.shownMilestones),
        timestamp: Date.now()
      };

      localStorage.setItem(key, JSON.stringify(data));
    } catch {
      // Ignore storage errors - localStorage may be unavailable in private browsing
    }
  }

  /**
   * Generate storage key for this form
   */
  storageKey(suffix) {
    return `encouragement:${this.formCodeValue || 'default'}:${suffix}`;
  }

  /**
   * Check if reduced motion is preferred
   */
  get prefersReducedMotion() {
    const userPref = localStorage.getItem('motion-preference');

    if (userPref === 'reduce') {
      return true;
    }

    if (userPref === 'normal') {
      return false;
    }

    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  /**
   * Bind listener for progress changes from completion-indicator controller
   */
  bindProgressListener() {
    this.handleProgress = this.handleProgressUpdate.bind(this);
    document.addEventListener(
      'completion-indicator:update',
      this.handleProgress
    );

    // Also listen for form input changes to calculate progress ourselves
    const form = document.querySelector('#main-form');

    if (form) {
      this.form = form;
      this.handleFormInput = this.calculateAndCheckProgress.bind(this);
      form.addEventListener('input', this.handleFormInput);
      form.addEventListener('change', this.handleFormInput);
    }
  }

  unbindProgressListener() {
    document.removeEventListener(
      'completion-indicator:update',
      this.handleProgress
    );

    if (this.form) {
      this.form.removeEventListener('input', this.handleFormInput);
      this.form.removeEventListener('change', this.handleFormInput);
    }
  }

  /**
   * Bind listeners to track individual field completions
   */
  bindFieldListeners() {
    this.fieldStates = new Map();

    // Track all form inputs
    const form = document.querySelector('#main-form');

    if (!form) {
      return;
    }

    const inputs = form.querySelectorAll(
      'input:not([type="hidden"]):not([type="submit"]), select, textarea'
    );

    inputs.forEach(input => {
      // Store initial state
      this.fieldStates.set(input, this.isFieldFilled(input));

      // Listen for changes
      input.addEventListener('blur', this.handleFieldBlur.bind(this));
      input.addEventListener('change', this.handleFieldChange.bind(this));
    });
  }

  unbindFieldListeners() {
    // Cleanup is handled by garbage collection when element disconnects
  }

  /**
   * Check if a field has a value
   */
  isFieldFilled(input) {
    if (input.type === 'checkbox') {
      return input.checked;
    }

    if (input.type === 'radio') {
      const form = input.closest('form');
      const radioGroup = form
        ? form.querySelectorAll(`[name="${input.name}"]`)
        : [input];

      return Array.from(radioGroup).some(r => r.checked);
    }

    return input.value && input.value.trim() !== '';
  }

  /**
   * Handle field blur - check if newly completed
   */
  handleFieldBlur(event) {
    this.checkFieldCompletion(event.target);
  }

  /**
   * Handle field change - for select, checkbox, radio
   */
  handleFieldChange(event) {
    this.checkFieldCompletion(event.target);
  }

  /**
   * Check if a field was just completed and show checkmark
   */
  checkFieldCompletion(input) {
    if (!this.enabledValue) {
      return;
    }

    const wasFilled = this.fieldStates.get(input) || false;
    const isFilled = this.isFieldFilled(input);

    // Update state
    this.fieldStates.set(input, isFilled);

    // Show checkmark animation if field was just completed
    if (!wasFilled && isFilled && input.required) {
      this.showFieldCheckmark(input);
    }
  }

  /**
   * Show checkmark animation on a completed field
   */
  showFieldCheckmark(input) {
    if (this.prefersReducedMotion) {
      return;
    }

    // Find the field wrapper
    const wrapper =
      input.closest('[data-field-name]') ||
      input.closest('.form-control') ||
      input.closest('[data-wizard-target="card"]');

    if (!wrapper || wrapper.querySelector('.field-checkmark')) {
      return;
    }

    // Create checkmark element
    const checkmark = document.createElement('div');

    checkmark.className = 'field-checkmark';
    checkmark.innerHTML = `
      <svg class="w-5 h-5 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
      </svg>
    `;

    // Position relative to input
    const inputRect = input.getBoundingClientRect();
    const wrapperRect = wrapper.getBoundingClientRect();

    checkmark.style.cssText = `
      position: absolute;
      right: ${wrapper.offsetWidth - (inputRect.right - wrapperRect.left) - 8}px;
      top: 50%;
      transform: translateY(-50%);
      z-index: 10;
      pointer-events: none;
    `;

    // Ensure wrapper has relative positioning
    const wrapperPosition = window.getComputedStyle(wrapper).position;

    if (wrapperPosition === 'static') {
      wrapper.style.position = 'relative';
    }

    wrapper.appendChild(checkmark);

    // Trigger animation
    requestAnimationFrame(() => {
      checkmark.classList.add('field-checkmark-animate');
    });

    // Remove after animation
    setTimeout(() => {
      checkmark.remove();
    }, 1500);
  }

  /**
   * Check initial progress when controller connects
   */
  checkInitialProgress() {
    // Wait a tick for completion-indicator to calculate
    requestAnimationFrame(() => {
      this.calculateAndCheckProgress();
    });
  }

  /**
   * Calculate progress and check for milestones
   */
  calculateAndCheckProgress() {
    if (!this.enabledValue) {
      return;
    }

    // Try to get progress from completion-indicator
    const percentEl = document.querySelector(
      '[data-completion-indicator-target="percent"]'
    );
    let percent = 0;

    if (percentEl) {
      percent = parseInt(percentEl.textContent) || 0;
    }

    this.updateProgress(percent);
  }

  /**
   * Handle progress update event from completion-indicator
   */
  handleProgressUpdate(event) {
    if (!this.enabledValue) {
      return;
    }

    const { percent } = event.detail || {};

    if (typeof percent === 'number') {
      this.updateProgress(percent);
    }
  }

  /**
   * Update progress and check for milestone triggers
   */
  updateProgress(newPercent) {
    const oldPercent = this.currentPercentValue;

    this.currentPercentValue = newPercent;

    // Update progress bar color
    this.updateProgressBarColor(newPercent);

    // Check for milestone triggers (only when increasing)
    if (newPercent > oldPercent) {
      this.checkMilestones(oldPercent, newPercent);
    }
  }

  /**
   * Update progress bar color based on completion percentage
   */
  updateProgressBarColor(percent) {
    // Find progress bar elements
    const progressBars = document.querySelectorAll(
      '[data-wizard-target="progress"], .wizard-progress-bar, [data-completion-indicator-target="progress"]'
    );

    progressBars.forEach(bar => {
      // Remove existing color classes
      bar.classList.remove(
        'bg-base-300',
        'bg-primary',
        'bg-info',
        'bg-success',
        'progress-primary',
        'progress-info',
        'progress-success'
      );

      // Add new color based on progress
      if (percent >= 100) {
        bar.classList.add('bg-success', 'progress-success');

        if (!this.prefersReducedMotion) {
          bar.classList.add('progress-pulse');
        }
      } else if (percent >= 75) {
        bar.classList.add('bg-info', 'progress-info');
      } else if (percent >= 25) {
        bar.classList.add('bg-primary', 'progress-primary');
      } else {
        bar.classList.add('bg-base-300');
      }
    });

    // Update radial progress color for completion indicator
    const radialProgress = document.querySelector(
      '[data-completion-indicator-target="progress"]'
    );

    if (radialProgress) {
      radialProgress.classList.remove(
        'text-primary',
        'text-info',
        'text-success'
      );

      if (percent >= 100) {
        radialProgress.classList.add('text-success');
      } else if (percent >= 75) {
        radialProgress.classList.add('text-info');
      } else {
        radialProgress.classList.add('text-primary');
      }
    }
  }

  /**
   * Check if any milestones were crossed
   */
  checkMilestones(oldPercent, newPercent) {
    const milestoneThresholds = Object.keys(this.constructor.milestones)
      .map(Number)
      .sort((a, b) => a - b);

    for (const threshold of milestoneThresholds) {
      // Check if we crossed this threshold
      if (oldPercent < threshold && newPercent >= threshold) {
        // Check if we haven't shown this milestone yet
        if (!this.shownMilestones.has(threshold)) {
          this.triggerMilestone(threshold);
        }
      }
    }
  }

  /**
   * Trigger milestone message and effects
   */
  triggerMilestone(threshold) {
    const milestone = this.constructor.milestones[threshold];

    if (!milestone) {
      return;
    }

    // Mark as shown
    this.shownMilestones.add(threshold);
    this.saveShownMilestones();

    // Show encouragement toast
    this.showEncouragementToast(milestone);

    // Pulse the progress bar
    if (!this.prefersReducedMotion) {
      this.pulseProgressBar();
    }

    // Celebration effect at 100%
    if (milestone.celebrate && !this.prefersReducedMotion) {
      this.showCelebration();
    }

    // Dispatch event for other controllers
    this.dispatch('milestone', {
      detail: { threshold, milestone }
    });
  }

  /**
   * Show encouragement toast notification
   */
  showEncouragementToast(milestone) {
    const icon = this.getIcon(milestone.icon);
    const type = milestone.type === 'success' ? 'success' : 'info';

    // Use custom toast with encouragement styling
    this.showCustomToast(milestone.message, type, icon);
  }

  /**
   * Show a custom styled encouragement toast
   */
  showCustomToast(message, type, iconHtml) {
    const container = this.getToastContainer();
    const reduceMotion = this.prefersReducedMotion;

    const toast = document.createElement('div');

    // Encouragement-specific styling
    const bgClass =
      type === 'success'
        ? 'bg-success'
        : 'bg-gradient-to-r from-primary to-secondary';
    const textClass =
      type === 'success' ? 'text-success-content' : 'text-primary-content';

    const transitionClass = reduceMotion
      ? 'transition-opacity duration-100'
      : 'transition-all duration-300';

    const startState = reduceMotion
      ? 'opacity-0'
      : 'transform translate-y-4 opacity-0 scale-95';

    toast.className = `
      flex items-center gap-3 px-5 py-4 rounded-xl shadow-lg
      ${bgClass} ${textClass}
      ${startState} ${transitionClass}
      max-w-sm encouragement-toast
    `.trim();

    toast.setAttribute('role', 'status');
    toast.setAttribute('aria-live', 'polite');

    toast.innerHTML = `
      <span class="flex-shrink-0 encouragement-icon">${iconHtml}</span>
      <span class="text-sm font-semibold">${this.escapeHtml(message)}</span>
    `;

    container.appendChild(toast);

    // Trigger enter animation
    requestAnimationFrame(() => {
      if (reduceMotion) {
        toast.classList.remove('opacity-0');
      } else {
        toast.classList.remove('translate-y-4', 'opacity-0', 'scale-95');
      }
    });

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      if (reduceMotion) {
        toast.classList.add('opacity-0');
        setTimeout(() => toast.remove(), 100);
      } else {
        toast.classList.add('translate-y-4', 'opacity-0', 'scale-95');
        setTimeout(() => toast.remove(), 300);
      }
    }, 5000);
  }

  /**
   * Get or create toast container (use existing if available)
   */
  getToastContainer() {
    let container = document.getElementById('encouragement-toast-container');

    if (!container) {
      container = document.createElement('div');
      container.id = 'encouragement-toast-container';
      container.className =
        'fixed bottom-20 left-1/2 -translate-x-1/2 z-50 flex flex-col items-center gap-2 pointer-events-none';
      container.setAttribute('aria-live', 'polite');
      container.setAttribute('aria-atomic', 'false');
      document.body.appendChild(container);
    }

    return container;
  }

  /**
   * Pulse the progress bar at milestones
   */
  pulseProgressBar() {
    const progressBars = document.querySelectorAll(
      '[data-wizard-target="progress"], .wizard-progress-bar'
    );

    progressBars.forEach(bar => {
      bar.classList.add('milestone-pulse');

      setTimeout(() => {
        bar.classList.remove('milestone-pulse');
      }, 1000);
    });
  }

  /**
   * Show celebration effect at 100% completion
   */
  showCelebration() {
    // Create confetti container
    const container = document.createElement('div');

    container.className = 'celebration-container';
    container.setAttribute('aria-hidden', 'true');
    document.body.appendChild(container);

    // Create confetti pieces
    const colors = [
      '#FFD700',
      '#FF6B6B',
      '#4ECDC4',
      '#45B7D1',
      '#96CEB4',
      '#FFEAA7',
      '#DDA0DD',
      '#98D8C8'
    ];
    const confettiCount = 50;

    for (let i = 0; i < confettiCount; i++) {
      const confetti = document.createElement('div');
      const random = () => {
        const array = new Uint32Array(1);

        window.crypto.getRandomValues(array);

        return array[0] / (0xffffffff + 1);
      };

      confetti.className = 'confetti';
      confetti.style.cssText = `
        left: ${random() * 100}%;
        background-color: ${colors[Math.floor(random() * colors.length)]};
        animation-delay: ${random() * 0.5}s;
        animation-duration: ${2 + random() * 2}s;
      `;
      container.appendChild(confetti);
    }

    // Remove after animation
    setTimeout(() => {
      container.remove();
    }, 4000);
  }

  /**
   * Get icon SVG for milestone type
   */
  getIcon(iconType) {
    const icons = {
      rocket: `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.59 14.37a6 6 0 01-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 006.16-12.12A14.98 14.98 0 009.631 8.41m5.96 5.96a14.926 14.926 0 01-5.841 2.58m-.119-8.54a6 6 0 00-7.381 5.84h4.8m2.581-5.84a14.927 14.927 0 00-2.58 5.84m2.699 2.7c-.103.021-.207.041-.311.06a15.09 15.09 0 01-2.448-2.448 14.9 14.9 0 01.06-.312m-2.24 2.39a4.493 4.493 0 00-1.757 4.306 4.493 4.493 0 004.306-1.758M16.5 9a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0z"></path>
      </svg>`,
      star: `<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
        <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"></path>
      </svg>`,
      fire: `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 18.657A8 8 0 016.343 7.343S7 9 9 10c0-2 .5-5 2.986-7C14 5 16.09 5.777 17.656 7.343A7.975 7.975 0 0120 13a7.975 7.975 0 01-2.343 5.657z"></path>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.879 16.121A3 3 0 1012.015 11L11 14H9c0 .768.293 1.536.879 2.121z"></path>
      </svg>`,
      lightning: `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
      </svg>`,
      trophy: `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 21h8m-4-4v4m-4-8a4 4 0 01-4-4V5a2 2 0 012-2h8a2 2 0 012 2v4a4 4 0 01-4 4m-4 0h-4a2 2 0 01-2-2V5m14 4a2 2 0 01-2 2h-4"></path>
      </svg>`
    };

    return icons[iconType] || icons.star;
  }

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    const div = document.createElement('div');

    div.textContent = text;

    return div.innerHTML;
  }

  /**
   * Toggle encouragement messages on/off
   */
  toggle(event) {
    this.enabledValue = event?.target?.checked ?? !this.enabledValue;
    localStorage.setItem('encouragement-enabled', this.enabledValue.toString());

    // Show confirmation
    const message = this.enabledValue
      ? 'Encouragement messages enabled'
      : 'Encouragement messages disabled';

    showToast(message, 'info', 2000);
  }

  /**
   * Reset shown milestones (for testing or new session)
   */
  reset() {
    this.shownMilestones.clear();

    const key = this.storageKey('shown-milestones');

    localStorage.removeItem(key);
  }
}
