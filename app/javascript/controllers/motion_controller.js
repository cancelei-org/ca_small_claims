import { Controller } from '@hotwired/stimulus';

/**
 * Motion Preference Controller
 *
 * Handles reduced motion preferences for users with vestibular disorders.
 * - Detects system preference (prefers-reduced-motion)
 * - Allows user override via toggle
 * - Persists preference in localStorage
 * - Adds CSS classes to document for styling
 *
 * Motion preference states:
 * - 'system': Follow OS/browser preference (default)
 * - 'reduce': Force reduced motion (user prefers less motion)
 * - 'normal': Force normal motion (user wants animations even if OS says reduce)
 */
export default class extends Controller {
  static targets = ['toggle', 'status'];
  static values = {
    preference: { type: String, default: 'system' }
  };

  connect() {
    // Load saved preference
    this.preferenceValue =
      localStorage.getItem('motion-preference') || 'system';

    // Set up system preference listener
    this.mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    this.handleSystemChange = this.handleSystemChange.bind(this);
    this.mediaQuery.addEventListener('change', this.handleSystemChange);

    // Apply initial state
    this.applyMotionPreference();
    this.updateUI();
  }

  disconnect() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener('change', this.handleSystemChange);
    }
  }

  /**
   * Handle system preference change
   */
  handleSystemChange() {
    if (this.preferenceValue === 'system') {
      this.applyMotionPreference();
      this.updateUI();
    }
  }

  /**
   * Check if reduced motion is active (either system or user preference)
   */
  get isReducedMotion() {
    if (this.preferenceValue === 'reduce') {
      return true;
    }

    if (this.preferenceValue === 'normal') {
      return false;
    }

    // 'system' - follow OS preference
    return this.mediaQuery?.matches ?? false;
  }

  /**
   * Get current effective motion state
   */
  get effectiveState() {
    if (this.preferenceValue !== 'system') {
      return this.preferenceValue;
    }

    return this.mediaQuery?.matches ? 'reduce' : 'normal';
  }

  /**
   * Cycle through motion preferences: system -> reduce -> normal -> system
   */
  toggle() {
    const states = ['system', 'reduce', 'normal'];
    const currentIndex = states.indexOf(this.preferenceValue);
    const nextIndex = (currentIndex + 1) % states.length;

    this.setPreference(states[nextIndex]);
  }

  /**
   * Set specific motion preference
   */
  setPreference(preference) {
    if (!['system', 'reduce', 'normal'].includes(preference)) {
      return;
    }

    this.preferenceValue = preference;
    localStorage.setItem('motion-preference', preference);
    this.applyMotionPreference();
    this.updateUI();

    // Announce change to screen readers
    this.announceChange();
  }

  /**
   * Apply motion preference CSS classes
   */
  applyMotionPreference() {
    const html = document.documentElement;

    // Remove existing motion classes
    html.classList.remove('reduce-motion', 'force-motion');

    if (this.preferenceValue === 'reduce') {
      // User explicitly wants reduced motion
      html.classList.add('reduce-motion');
    } else if (this.preferenceValue === 'normal') {
      // User explicitly wants motion (override OS reduce preference)
      html.classList.add('force-motion');
    }
    // 'system' - no class, CSS media query handles it
  }

  /**
   * Update toggle UI
   */
  updateUI() {
    if (this.hasToggleTarget) {
      // Update toggle state
      this.toggleTarget.checked = this.isReducedMotion;
      this.toggleTarget.setAttribute(
        'aria-checked',
        this.isReducedMotion.toString()
      );
    }

    if (this.hasStatusTarget) {
      // Update status text
      const statusText = this.getStatusText();

      this.statusTarget.textContent = statusText;
    }
  }

  /**
   * Get human-readable status text
   */
  getStatusText() {
    switch (this.preferenceValue) {
      case 'reduce':
        return 'Reduced (forced)';
      case 'normal':
        return 'Normal (forced)';
      case 'system':
      default:
        return this.mediaQuery?.matches
          ? 'Reduced (system)'
          : 'Normal (system)';
    }
  }

  /**
   * Announce preference change to screen readers
   */
  announceChange() {
    const message = this.isReducedMotion
      ? 'Motion reduced. Animations are now minimal.'
      : 'Motion enabled. Animations are now active.';

    // Find or create live region
    let liveRegion = document.getElementById('motion-live-region');

    if (!liveRegion) {
      liveRegion = document.createElement('div');
      liveRegion.id = 'motion-live-region';
      liveRegion.setAttribute('aria-live', 'polite');
      liveRegion.setAttribute('aria-atomic', 'true');
      liveRegion.className = 'sr-only';
      document.body.appendChild(liveRegion);
    }

    liveRegion.textContent = '';
    requestAnimationFrame(() => {
      liveRegion.textContent = message;
    });
  }
}

/**
 * Utility function to check reduced motion from anywhere
 * Can be imported and used by other modules
 */
export function prefersReducedMotion() {
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
