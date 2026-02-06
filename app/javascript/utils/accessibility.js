/**
 * Accessibility Utilities
 * Shared functions for handling accessibility preferences
 */

/**
 * Check if reduced motion is preferred
 * Respects both user override (stored in localStorage) and system preference
 *
 * @returns {boolean} True if reduced motion is preferred
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

/**
 * Get the effective motion preference state
 * @returns {'reduce' | 'normal'} The current effective motion state
 */
export function getMotionPreference() {
  const userPref = localStorage.getItem('motion-preference');

  if (userPref === 'reduce' || userPref === 'normal') {
    return userPref;
  }

  // System preference
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
    ? 'reduce'
    : 'normal';
}

/**
 * Set the motion preference and persist to localStorage
 * @param {'system' | 'reduce' | 'normal'} preference - The motion preference
 */
export function setMotionPreference(preference) {
  if (['system', 'reduce', 'normal'].includes(preference)) {
    localStorage.setItem('motion-preference', preference);
  }
}
