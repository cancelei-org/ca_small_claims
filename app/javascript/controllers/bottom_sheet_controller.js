import { Controller } from '@hotwired/stimulus';
import { FocusTrap, ModalUtils } from 'utils/modal_behavior';

/**
 * Bottom Sheet Controller
 * Mobile-optimized bottom sheet with swipe-to-dismiss gesture support.
 * Used for form actions (save, preview, download) on mobile devices.
 *
 * Features:
 * - Slide up animation from bottom
 * - Swipe down to dismiss
 * - Drag handle for visual affordance
 * - Focus trapping for accessibility
 * - Haptic feedback on gestures
 * - Backdrop click to close
 */
export default class extends Controller {
  static targets = ['sheet', 'backdrop', 'content', 'handle'];
  static values = {
    dismissThreshold: { type: Number, default: 100 }, // pixels to drag before dismiss
    velocityThreshold: { type: Number, default: 0.5 } // velocity for quick dismiss
  };

  connect() {
    this._cleanupEscape = ModalUtils.setupEscapeKey(() => this.close());

    if (this.hasSheetTarget) {
      this.focusManager = FocusTrap.createManager(this.sheetTarget);
    }

    // Touch tracking state
    this.touchStartY = 0;
    this.touchCurrentY = 0;
    this.isDragging = false;
    this.dragStartTime = 0;

    // Bind touch handlers
    this._onTouchStart = this.handleTouchStart.bind(this);
    this._onTouchMove = this.handleTouchMove.bind(this);
    this._onTouchEnd = this.handleTouchEnd.bind(this);

    // Check for reduced motion preference
    this.prefersReducedMotion = window.matchMedia(
      '(prefers-reduced-motion: reduce)'
    ).matches;
  }

  disconnect() {
    this._cleanupEscape?.();
    this.removeTouchListeners();
    this.focusManager?.deactivate();
    ModalUtils.enableBodyScroll();
  }

  get isOpen() {
    return this.hasSheetTarget && this.sheetTarget.classList.contains('open');
  }

  /**
   * Open the bottom sheet
   */
  open() {
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('hidden');
      // Trigger reflow for transition (read property to force layout recalculation)
      // eslint-disable-next-line no-unused-expressions
      this.backdropTarget.offsetWidth;
      this.backdropTarget.classList.add('open');
    }

    if (this.hasSheetTarget) {
      this.sheetTarget.classList.add('open');
      this.sheetTarget.setAttribute('aria-hidden', 'false');

      // Add touch listeners for swipe gesture
      this.addTouchListeners();
    }

    // Activate focus trap
    this.focusManager?.activate();

    ModalUtils.disableBodyScroll();
    this.triggerHapticFeedback('light');
    this.dispatch('opened');
  }

  /**
   * Close the bottom sheet
   */
  close() {
    if (this.hasSheetTarget) {
      this.sheetTarget.classList.remove('open');
      this.sheetTarget.setAttribute('aria-hidden', 'true');
      this.sheetTarget.style.transform = '';

      this.removeTouchListeners();
    }

    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('open');
      ModalUtils.afterTransition(this.backdropTarget, () => {
        if (!this.backdropTarget.classList.contains('open')) {
          this.backdropTarget.classList.add('hidden');
        }
      });
    }

    // Deactivate focus trap and restore focus
    this.focusManager?.deactivate();

    ModalUtils.enableBodyScroll();
    this.dispatch('closed');
  }

  /**
   * Toggle the bottom sheet
   */
  toggle() {
    if (this.isOpen) {
      this.close();
    } else {
      this.open();
    }
  }

  // ==========================================
  // Touch/Swipe Gesture Handling
  // ==========================================

  addTouchListeners() {
    if (!this.hasSheetTarget) {
      return;
    }

    const target = this.hasHandleTarget ? this.handleTarget : this.sheetTarget;

    target.addEventListener('touchstart', this._onTouchStart, {
      passive: true
    });
    target.addEventListener('touchmove', this._onTouchMove, { passive: false });
    target.addEventListener('touchend', this._onTouchEnd, { passive: true });
  }

  removeTouchListeners() {
    if (!this.hasSheetTarget) {
      return;
    }

    const target = this.hasHandleTarget ? this.handleTarget : this.sheetTarget;

    target.removeEventListener('touchstart', this._onTouchStart);
    target.removeEventListener('touchmove', this._onTouchMove);
    target.removeEventListener('touchend', this._onTouchEnd);
  }

  handleTouchStart(event) {
    if (!event.touches || event.touches.length !== 1) {
      return;
    }

    this.touchStartY = event.touches[0].clientY;
    this.touchCurrentY = this.touchStartY;
    this.isDragging = true;
    this.dragStartTime = Date.now();

    // Disable transition during drag
    if (this.hasSheetTarget) {
      this.sheetTarget.style.transition = 'none';
    }
  }

  handleTouchMove(event) {
    if (!this.isDragging || !event.touches || event.touches.length !== 1) {
      return;
    }

    this.touchCurrentY = event.touches[0].clientY;
    const deltaY = this.touchCurrentY - this.touchStartY;

    // Only allow dragging downward
    if (deltaY > 0) {
      event.preventDefault();

      // Apply drag transform with rubber-band effect
      const resistance = 0.5;
      const transform = Math.min(deltaY * resistance, 300);

      this.sheetTarget.style.transform = `translateY(${transform}px)`;

      // Adjust backdrop opacity based on drag
      if (this.hasBackdropTarget) {
        const opacity = Math.max(0, 1 - transform / 200);

        this.backdropTarget.style.opacity = opacity;
      }
    }
  }

  handleTouchEnd() {
    if (!this.isDragging) {
      return;
    }

    this.isDragging = false;
    const deltaY = this.touchCurrentY - this.touchStartY;
    const dragDuration = Date.now() - this.dragStartTime;
    const velocity = deltaY / dragDuration;

    // Re-enable transition
    if (this.hasSheetTarget) {
      this.sheetTarget.style.transition = '';
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.style.opacity = '';
    }

    // Determine if we should dismiss
    const shouldDismiss =
      deltaY > this.dismissThresholdValue ||
      (velocity > this.velocityThresholdValue && deltaY > 30);

    if (shouldDismiss) {
      this.triggerHapticFeedback('medium');
      this.close();
    } else {
      // Snap back
      this.sheetTarget.style.transform = '';
    }
  }

  // ==========================================
  // Haptic Feedback
  // ==========================================

  /**
   * Open feedback modal if present on the page
   */
  openFeedback() {
    const modal = document.getElementById('feedback-modal');

    if (modal?.showModal) {
      modal.showModal();
      this.close();
    }
  }

  triggerHapticFeedback(intensity = 'light') {
    if (this.prefersReducedMotion) {
      return;
    }

    if ('vibrate' in navigator) {
      const patterns = { light: 10, medium: 20, heavy: 40 };

      navigator.vibrate(patterns[intensity] || patterns.light);
    }
  }
}
