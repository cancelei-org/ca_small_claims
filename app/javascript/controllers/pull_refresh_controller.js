import { Controller } from '@hotwired/stimulus';

/**
 * Pull-to-Refresh Controller
 * Mobile-optimized pull-to-refresh functionality for lists and data tables.
 *
 * Features:
 * - Touch-based pull-down gesture detection
 * - Visual indicator with progress feedback
 * - Haptic feedback at threshold
 * - Turbo-compatible page refresh
 * - Reduced motion support
 * - Only active when at scroll top
 *
 * Usage:
 *   <div data-controller="pull-refresh"
 *        data-pull-refresh-url-value="/admin/feedbacks">
 *     <div data-pull-refresh-target="indicator">...</div>
 *     <div data-pull-refresh-target="content">
 *       ... your list content ...
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ['indicator', 'content', 'spinner', 'arrow'];
  static values = {
    url: { type: String, default: '' },
    threshold: { type: Number, default: 80 }, // pixels to pull before refresh
    maxPull: { type: Number, default: 120 }, // max pull distance with resistance
    enabled: { type: Boolean, default: true }
  };

  connect() {
    // Only enable on touch devices
    this.isTouchDevice =
      'ontouchstart' in window || navigator.maxTouchPoints > 0;

    if (!this.isTouchDevice || !this.enabledValue) {
      this.element.classList.add('pull-refresh-disabled');

      return;
    }

    // State
    this.touchStartY = 0;
    this.touchCurrentY = 0;
    this.isPulling = false;
    this.isRefreshing = false;
    this.pullDistance = 0;

    // Check for reduced motion preference
    this.prefersReducedMotion =
      window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
      document.documentElement.classList.contains('reduce-motion');

    // Bind touch handlers
    this._onTouchStart = this.handleTouchStart.bind(this);
    this._onTouchMove = this.handleTouchMove.bind(this);
    this._onTouchEnd = this.handleTouchEnd.bind(this);

    // Add touch listeners
    this.element.addEventListener('touchstart', this._onTouchStart, {
      passive: true
    });
    this.element.addEventListener('touchmove', this._onTouchMove, {
      passive: false
    });
    this.element.addEventListener('touchend', this._onTouchEnd, {
      passive: true
    });

    // Create indicator if not present
    if (!this.hasIndicatorTarget) {
      this.createIndicator();
    }
  }

  disconnect() {
    if (!this.isTouchDevice) {
      return;
    }

    this.element.removeEventListener('touchstart', this._onTouchStart);
    this.element.removeEventListener('touchmove', this._onTouchMove);
    this.element.removeEventListener('touchend', this._onTouchEnd);
  }

  /**
   * Create the pull-to-refresh indicator element
   */
  createIndicator() {
    const indicator = document.createElement('div');

    indicator.className = 'pull-refresh-indicator';
    indicator.setAttribute('data-pull-refresh-target', 'indicator');
    indicator.innerHTML = `
      <div class="pull-refresh-indicator-content">
        <svg class="pull-refresh-arrow" data-pull-refresh-target="arrow" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3"></path>
        </svg>
        <span class="pull-refresh-spinner" data-pull-refresh-target="spinner">
          <span class="loading loading-spinner loading-sm"></span>
        </span>
        <span class="pull-refresh-text">Pull to refresh</span>
      </div>
    `;
    this.element.insertBefore(indicator, this.element.firstChild);
  }

  /**
   * Check if we're at the top of the scroll container
   */
  isAtTop() {
    // Check the main scrollable container
    const scrollElement = this.hasContentTarget
      ? this.contentTarget
      : this.element;

    // Also check if page is at top
    const pageAtTop = window.scrollY <= 0;
    const elementAtTop = scrollElement.scrollTop <= 0;

    return pageAtTop && elementAtTop;
  }

  handleTouchStart(event) {
    if (this.isRefreshing || !event.touches || event.touches.length !== 1) {
      return;
    }

    // Only start if at top of scroll
    if (!this.isAtTop()) {
      return;
    }

    this.touchStartY = event.touches[0].clientY;
    this.touchCurrentY = this.touchStartY;
    this.pullDistance = 0;
  }

  handleTouchMove(event) {
    if (this.isRefreshing || !event.touches || event.touches.length !== 1) {
      return;
    }
    if (this.touchStartY === 0) {
      return;
    }

    this.touchCurrentY = event.touches[0].clientY;
    const deltaY = this.touchCurrentY - this.touchStartY;

    // Only handle downward pull
    if (deltaY <= 0) {
      this.resetIndicator();

      return;
    }

    // Check if still at top (user might have started at top but scrolled down)
    if (!this.isAtTop() && !this.isPulling) {
      return;
    }

    // Prevent default scroll while pulling
    event.preventDefault();

    this.isPulling = true;

    // Apply resistance to pull distance
    const resistance = 0.5;

    this.pullDistance = Math.min(deltaY * resistance, this.maxPullValue);

    // Update indicator position
    this.updateIndicator();

    // Trigger haptic at threshold
    if (this.pullDistance >= this.thresholdValue && !this.reachedThreshold) {
      this.reachedThreshold = true;
      this.triggerHapticFeedback();
      this.updateIndicatorText('Release to refresh');
    } else if (
      this.pullDistance < this.thresholdValue &&
      this.reachedThreshold
    ) {
      this.reachedThreshold = false;
      this.updateIndicatorText('Pull to refresh');
    }
  }

  handleTouchEnd() {
    if (!this.isPulling) {
      this.touchStartY = 0;

      return;
    }

    if (this.pullDistance >= this.thresholdValue) {
      this.refresh();
    } else {
      this.resetIndicator();
    }

    this.isPulling = false;
    this.reachedThreshold = false;
    this.touchStartY = 0;
  }

  /**
   * Update the visual indicator based on pull distance
   */
  updateIndicator() {
    if (!this.hasIndicatorTarget) {
      return;
    }

    const progress = Math.min(this.pullDistance / this.thresholdValue, 1);

    // Show indicator
    this.indicatorTarget.classList.add('active');
    this.indicatorTarget.style.height = `${this.pullDistance}px`;
    this.indicatorTarget.style.opacity = Math.min(progress * 1.5, 1);

    // Rotate arrow based on progress
    if (this.hasArrowTarget) {
      const rotation = progress >= 1 ? 180 : progress * 180;

      if (!this.prefersReducedMotion) {
        this.arrowTarget.style.transform = `rotate(${rotation}deg)`;
      }
    }
  }

  updateIndicatorText(text) {
    const textElement =
      this.indicatorTarget?.querySelector('.pull-refresh-text');

    if (textElement) {
      textElement.textContent = text;
    }
  }

  /**
   * Reset the indicator to hidden state
   */
  resetIndicator() {
    if (!this.hasIndicatorTarget) {
      return;
    }

    this.indicatorTarget.classList.remove('active', 'refreshing');
    this.indicatorTarget.style.height = '0';
    this.indicatorTarget.style.opacity = '0';
    this.pullDistance = 0;

    if (this.hasArrowTarget) {
      this.arrowTarget.style.transform = '';
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('hidden');
    }
  }

  /**
   * Perform the refresh
   */
  async refresh() {
    this.isRefreshing = true;

    // Show refreshing state
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.classList.add('refreshing');
      this.updateIndicatorText('Refreshing...');
    }
    if (this.hasArrowTarget) {
      this.arrowTarget.classList.add('hidden');
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove('hidden');
    }

    // Dispatch event for custom handling
    this.dispatch('refresh');

    try {
      // Use Turbo to refresh the page
      const url = this.urlValue || window.location.href;

      if (window.Turbo) {
        await window.Turbo.visit(url, { action: 'replace' });
      } else {
        window.location.reload();
      }
    } catch {
      // Reset on error
      this.resetIndicator();
      this.isRefreshing = false;
    }

    // Note: If Turbo replaces the content, the controller will disconnect/reconnect
    // so we don't need to manually reset here in that case
  }

  /**
   * Trigger haptic feedback
   */
  triggerHapticFeedback() {
    if (this.prefersReducedMotion) {
      return;
    }

    if ('vibrate' in navigator) {
      navigator.vibrate(15);
    }
  }
}
