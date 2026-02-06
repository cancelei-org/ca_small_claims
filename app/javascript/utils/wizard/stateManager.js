/**
 * State Manager Utilities for Wizard
 * Handles progress persistence and state restoration
 */

/**
 * Default storage key prefix
 */
const STORAGE_PREFIX = 'wizard_progress_';

/**
 * Create a state manager for wizard progress
 * @param {Object} options - Configuration options
 * @param {string} options.formCode - Unique identifier for the form
 * @param {string} options.storagePrefix - Override default storage prefix
 * @returns {Object} State manager with save/load/clear methods
 */
export function createStateManager(options = {}) {
  const { formCode, storagePrefix = STORAGE_PREFIX } = options;

  const storageKey = `${storagePrefix}${formCode || 'default'}`;

  /**
   * Save current progress state
   * @param {Object} state - State to save
   * @param {number} state.currentIndex - Current step index
   * @param {number} state.totalSteps - Total number of steps
   * @param {Array<boolean>} state.completedSteps - Array of completed step flags
   * @param {number} state.timestamp - Save timestamp
   */
  const saveProgress = (state) => {
    try {
      const data = {
        ...state,
        timestamp: Date.now()
      };
      localStorage.setItem(storageKey, JSON.stringify(data));
      return true;
    } catch {
      // localStorage might be full or disabled
      return false;
    }
  };

  /**
   * Load saved progress state
   * @param {number} maxAge - Maximum age in milliseconds (default: 24 hours)
   * @returns {Object|null} Saved state or null if not found/expired
   */
  const loadProgress = (maxAge = 24 * 60 * 60 * 1000) => {
    try {
      const saved = localStorage.getItem(storageKey);

      if (!saved) {
        return null;
      }

      const data = JSON.parse(saved);

      // Check if data is too old
      if (data.timestamp && Date.now() - data.timestamp > maxAge) {
        clearProgress();
        return null;
      }

      return data;
    } catch {
      return null;
    }
  };

  /**
   * Clear saved progress
   */
  const clearProgress = () => {
    try {
      localStorage.removeItem(storageKey);
      return true;
    } catch {
      return false;
    }
  };

  /**
   * Check if there is saved progress
   * @returns {boolean}
   */
  const hasProgress = () => {
    return loadProgress() !== null;
  };

  return {
    saveProgress,
    loadProgress,
    clearProgress,
    hasProgress,
    storageKey
  };
}

/**
 * Calculate completion percentage
 * @param {number} completed - Number of completed steps
 * @param {number} total - Total number of steps
 * @returns {number} Percentage (0-100)
 */
export function calculateProgress(completed, total) {
  if (total === 0) {
    return 0;
  }
  return Math.round((completed / total) * 100);
}

/**
 * Find first incomplete step index
 * @param {Array<boolean>} completedSteps - Array of completion flags
 * @returns {number} Index of first incomplete step, or -1 if all complete
 */
export function findFirstIncompleteStep(completedSteps) {
  return completedSteps.findIndex((completed) => !completed);
}
