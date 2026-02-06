/**
 * Swipe Gesture Utilities for Wizard Navigation
 * Provides touch/swipe handling for mobile navigation
 */

/**
 * Default swipe configuration
 */
export const SWIPE_CONFIG = {
  threshold: 50, // Minimum swipe distance in pixels
  maxVerticalOffset: 100, // Maximum vertical movement allowed
  hapticEnabled: true
};

/**
 * Create swipe gesture handlers for an element
 * @param {Object} options - Configuration options
 * @param {Function} options.onSwipeLeft - Callback for left swipe (next)
 * @param {Function} options.onSwipeRight - Callback for right swipe (previous)
 * @param {Object} options.config - Override default config
 * @returns {Object} Object with bind/unbind methods and handlers
 */
export function createSwipeHandler(options = {}) {
  const { onSwipeLeft, onSwipeRight, config = {} } = options;
  const mergedConfig = { ...SWIPE_CONFIG, ...config };

  let touchStartX = 0;
  let touchStartY = 0;
  let touchEndX = 0;
  let touchEndY = 0;

  const handleTouchStart = (event) => {
    touchStartX = event.changedTouches[0].screenX;
    touchStartY = event.changedTouches[0].screenY;
  };

  const handleTouchEnd = (event) => {
    touchEndX = event.changedTouches[0].screenX;
    touchEndY = event.changedTouches[0].screenY;
    handleSwipeGesture();
  };

  const handleSwipeGesture = () => {
    const deltaX = touchEndX - touchStartX;
    const deltaY = touchEndY - touchStartY;

    // Only process horizontal swipes (ignore vertical scrolling)
    if (Math.abs(deltaY) > mergedConfig.maxVerticalOffset) {
      return;
    }

    // Check if swipe meets threshold
    if (Math.abs(deltaX) < mergedConfig.threshold) {
      return;
    }

    // Determine direction and trigger callback
    if (deltaX < 0 && onSwipeLeft) {
      // Swipe left (next)
      if (mergedConfig.hapticEnabled) {
        triggerHapticFeedback('light');
      }
      onSwipeLeft();
    } else if (deltaX > 0 && onSwipeRight) {
      // Swipe right (previous)
      if (mergedConfig.hapticEnabled) {
        triggerHapticFeedback('light');
      }
      onSwipeRight();
    }
  };

  return {
    handleTouchStart,
    handleTouchEnd,
    bind: (element) => {
      element.addEventListener('touchstart', handleTouchStart, { passive: true });
      element.addEventListener('touchend', handleTouchEnd, { passive: true });
    },
    unbind: (element) => {
      element.removeEventListener('touchstart', handleTouchStart);
      element.removeEventListener('touchend', handleTouchEnd);
    }
  };
}

/**
 * Trigger haptic feedback if available
 * @param {'light' | 'medium' | 'heavy'} intensity - Vibration intensity
 */
export function triggerHapticFeedback(intensity = 'light') {
  if (!navigator.vibrate) {
    return;
  }

  const durations = {
    light: 10,
    medium: 25,
    heavy: 50
  };

  const duration = durations[intensity] || durations.light;

  try {
    navigator.vibrate(duration);
  } catch {
    // Vibration not supported or blocked
  }
}
