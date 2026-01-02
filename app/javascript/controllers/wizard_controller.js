import { Controller } from '@hotwired/stimulus';
import { clearFieldError, showFieldError, showToast } from 'utils/toast';

// Handles multi-step wizard form logic

export default class extends Controller {
  static targets = [
    'card',
    'progress',
    'progressContainer',
    'counter',
    'prevBtn',
    'nextBtn',
    'finishBtn',
    'skipToggle',
    'dot',
    'dotStatus'
  ];

  static values = {
    currentIndex: { type: Number, default: 0 },
    totalFields: Number,
    skipFilled: { type: Boolean, default: false },
    animationDuration: { type: Number, default: 500 }
  };

  connect() {
    // Check for reduced motion preference
    this.updateReducedMotionState();

    // Listen for motion preference changes
    this.motionMediaQuery = window.matchMedia(
      '(prefers-reduced-motion: reduce)'
    );
    this.handleMotionChange = this.handleMotionChange.bind(this);
    this.motionMediaQuery.addEventListener('change', this.handleMotionChange);

    this.updateVisibility();
    this.updateProgress();
    this.updateNavigationDots();
    this.bindKeyboardNavigation();
    this.bindModeChangeListener();
    this.bindFieldChangeListener();
    this.bindSwipeGestures();
    this.focusCurrentInput();
  }

  disconnect() {
    this.unbindKeyboardNavigation();
    this.unbindModeChangeListener();
    this.unbindFieldChangeListener();
    this.unbindSwipeGestures();

    // Clean up motion preference listener
    if (this.motionMediaQuery) {
      this.motionMediaQuery.removeEventListener(
        'change',
        this.handleMotionChange
      );
    }
  }

  /**
   * Check if reduced motion is preferred (system or user override)
   */
  get prefersReducedMotion() {
    // Check user override first
    const userPref = localStorage.getItem('motion-preference');

    if (userPref === 'reduce') {
      return true;
    }

    if (userPref === 'normal') {
      return false;
    }

    // Fall back to system preference
    return this.motionMediaQuery?.matches ?? false;
  }

  /**
   * Update reduced motion state and adjust animation duration
   */
  updateReducedMotionState() {
    // Adjust animation duration based on motion preference
    // Reduced motion uses instant transitions (CSS handles this via media query)
    // but we also need to adjust JS timeouts
    this._effectiveAnimationDuration = this.prefersReducedMotion
      ? 50 // Very short for reduced motion
      : this.animationDurationValue;
  }

  /**
   * Handle system motion preference change
   */
  handleMotionChange() {
    this.updateReducedMotionState();
  }

  /**
   * Get effective animation duration (considers reduced motion)
   */
  get effectiveAnimationDuration() {
    return this._effectiveAnimationDuration ?? this.animationDurationValue;
  }

  // Touch swipe gesture support for mobile navigation
  bindSwipeGestures() {
    this.touchStartX = 0;
    this.touchStartY = 0;
    this.touchEndX = 0;
    this.touchEndY = 0;

    this.handleTouchStart = this.handleTouchStart.bind(this);
    this.handleTouchEnd = this.handleTouchEnd.bind(this);

    this.element.addEventListener('touchstart', this.handleTouchStart, {
      passive: true
    });
    this.element.addEventListener('touchend', this.handleTouchEnd, {
      passive: true
    });
  }

  unbindSwipeGestures() {
    this.element.removeEventListener('touchstart', this.handleTouchStart);
    this.element.removeEventListener('touchend', this.handleTouchEnd);
  }

  handleTouchStart(event) {
    this.touchStartX = event.changedTouches[0].screenX;
    this.touchStartY = event.changedTouches[0].screenY;
  }

  handleTouchEnd(event) {
    this.touchEndX = event.changedTouches[0].screenX;
    this.touchEndY = event.changedTouches[0].screenY;
    this.handleSwipeGesture();
  }

  handleSwipeGesture() {
    const deltaX = this.touchEndX - this.touchStartX;
    const deltaY = this.touchEndY - this.touchStartY;

    // Minimum swipe distance (px) to trigger navigation
    const minSwipeDistance = 50;

    // Ensure horizontal swipe is more significant than vertical
    if (Math.abs(deltaX) < minSwipeDistance) {
      return;
    }

    if (Math.abs(deltaX) < Math.abs(deltaY)) {
      return; // Vertical scroll, ignore
    }

    // Don't navigate if user is interacting with a text input
    const activeElement = document.activeElement;
    const isTyping =
      activeElement?.tagName === 'INPUT' ||
      activeElement?.tagName === 'TEXTAREA';

    if (isTyping) {
      return;
    }

    if (deltaX > 0) {
      // Swipe right - go to previous
      this.triggerHapticFeedback('light');
      this.previous();
    } else {
      // Swipe left - go to next
      this.triggerHapticFeedback('light');
      this.next();
    }
  }

  /**
   * Trigger haptic feedback on supported devices
   * @param {string} intensity - 'light', 'medium', or 'heavy'
   */
  triggerHapticFeedback(intensity = 'light') {
    // Use Vibration API if available
    if ('vibrate' in navigator) {
      const patterns = {
        light: 10, // Short, subtle vibration
        medium: 20, // Medium vibration
        heavy: 40 // Longer vibration for errors
      };

      navigator.vibrate(patterns[intensity] || patterns.light);
    }
  }

  bindModeChangeListener() {
    this.handleModeChange = this.handleModeChange.bind(this);
    // Listen for view-toggle mode changes on the parent element
    document.addEventListener('view-toggle:modeChanged', this.handleModeChange);
  }

  unbindModeChangeListener() {
    document.removeEventListener(
      'view-toggle:modeChanged',
      this.handleModeChange
    );
  }

  bindFieldChangeListener() {
    this.handleFieldChange = this.handleFieldChange.bind(this);
    // Listen for input events on all wizard cards to update dots
    this.element.addEventListener('input', this.handleFieldChange);
    this.element.addEventListener('change', this.handleFieldChange);
  }

  unbindFieldChangeListener() {
    this.element.removeEventListener('input', this.handleFieldChange);
    this.element.removeEventListener('change', this.handleFieldChange);
  }

  handleFieldChange(_event) {
    // Update navigation dots when field values change
    this.updateNavigationDots();
  }

  handleModeChange(event) {
    const { mode } = event.detail;

    if (mode === 'wizard') {
      // Switching to wizard mode - navigate to first empty field
      this.navigateToFirstEmptyField();
    }
  }

  // Find the index of the first empty required field, or first empty field if no required
  findFirstEmptyFieldIndex() {
    let firstEmptyRequired = -1;
    let firstEmpty = -1;

    this.cardTargets.forEach((card, index) => {
      const input = card.querySelector(
        "input:not([type='hidden']), select, textarea"
      );

      if (!input) {
        return;
      }

      const isEmpty = this.isFieldEmpty(input);

      if (isEmpty && firstEmpty === -1) {
        firstEmpty = index;
      }

      if (isEmpty && input.required && firstEmptyRequired === -1) {
        firstEmptyRequired = index;
      }
    });

    // Prefer first empty required field, fallback to first empty, or stay at 0
    if (firstEmptyRequired !== -1) {
      return firstEmptyRequired;
    }

    if (firstEmpty !== -1) {
      return firstEmpty;
    }

    return 0;
  }

  // Check if a field is empty
  isFieldEmpty(input) {
    if (input.type === 'checkbox') {
      return !input.checked;
    }

    if (input.type === 'radio') {
      const name = input.name;
      const form = input.closest('form');
      const radioGroup = form
        ? form.querySelectorAll(`[name="${name}"]`)
        : [input];

      return !Array.from(radioGroup).some(r => r.checked);
    }

    return !input.value || input.value.trim() === '';
  }

  // Check if a field has a value (filled)
  isFieldFilled(card) {
    const input = card.querySelector(
      "input:not([type='hidden']), select, textarea"
    );

    if (!input) {
      return false;
    }

    return !this.isFieldEmpty(input);
  }

  navigateToFirstEmptyField() {
    const targetIndex = this.findFirstEmptyFieldIndex();

    if (targetIndex !== this.currentIndexValue) {
      // Use instant navigation (no animation) when switching modes
      this.goToInstant(targetIndex);
    } else {
      // Already at the right position, just ensure UI is updated
      this.updateVisibility();
      this.updateProgress();
      this.updateNavigationDots();
      this.focusCurrentInput();
    }
  }

  // Navigate to a specific index instantly (no animation)
  goToInstant(index) {
    if (index < 0 || index >= this.totalFieldsValue) {
      return;
    }

    this.cardTargets.forEach((card, i) => {
      const isActive = i === index;

      card.classList.toggle('hidden', !isActive);
      card.classList.toggle('wizard-card-active', isActive);
      // Remove any animation classes
      card.classList.remove(
        'wizard-flip-exit',
        'wizard-flip-enter',
        'wizard-flip-next',
        'wizard-flip-prev'
      );
    });

    this.currentIndexValue = index;
    this.updateVisibility();
    this.updateProgress();
    this.updateNavigationDots();
    this.focusCurrentInput();
  }

  // Update navigation dots to reflect filled/empty state with proper ARIA
  updateNavigationDots() {
    if (!this.hasDotTarget) {
      return;
    }

    this.dotTargets.forEach((dot, index) => {
      const card = this.cardTargets[index];
      const isActive = index === this.currentIndexValue;
      const isFilled = card ? this.isFieldFilled(card) : false;

      // Update ARIA selected state
      dot.setAttribute('aria-selected', isActive ? 'true' : 'false');

      // Find the visual indicator and completed checkmark inside the button
      const indicator = dot.querySelector('.wizard-dot-indicator');
      const completeMark = dot.querySelector('.wizard-dot-complete');

      if (indicator) {
        // Reset indicator classes
        indicator.classList.remove(
          'bg-primary',
          'bg-success',
          'bg-base-300',
          'ring-2',
          'ring-primary',
          'ring-offset-2',
          'ring-offset-base-100'
        );

        if (isActive) {
          // Current field - primary with ring
          indicator.classList.add(
            'bg-primary',
            'ring-2',
            'ring-primary',
            'ring-offset-2',
            'ring-offset-base-100'
          );
        } else if (isFilled) {
          // Filled field - success color
          indicator.classList.add('bg-success');
        } else {
          // Empty field - base color
          indicator.classList.add('bg-base-300');
        }
      }

      // Show/hide completed checkmark
      if (completeMark) {
        if (isFilled && !isActive) {
          completeMark.classList.remove('hidden');
          if (indicator) {
            indicator.classList.add('hidden');
          }
        } else {
          completeMark.classList.add('hidden');
          if (indicator) {
            indicator.classList.remove('hidden');
          }
        }
      }
    });

    // Update screen reader status
    this.updateDotStatus();
  }

  // Update screen reader status for navigation dots
  updateDotStatus() {
    const statusEl = this.element.querySelector(
      '[data-wizard-target="dotStatus"]'
    );

    if (statusEl) {
      const currentField = this.currentIndexValue + 1;
      const totalFields = this.cardTargets.length;

      statusEl.textContent = `Field ${currentField} of ${totalFields}`;
    }
  }

  bindKeyboardNavigation() {
    this.handleKeydown = this.handleKeydown.bind(this);
    document.addEventListener('keydown', this.handleKeydown);
  }

  unbindKeyboardNavigation() {
    document.removeEventListener('keydown', this.handleKeydown);
  }

  handleKeydown(event) {
    // Don't navigate if user is typing in a textarea
    if (event.target.tagName === 'TEXTAREA') {
      // Allow Escape to still work in textarea
      if (event.key !== 'Escape') {
        return;
      }
    }

    // Escape key - go back to previous field (accessibility)
    // But don't interfere with modal dialogs
    if (event.key === 'Escape') {
      // Check if a modal dialog is open - don't capture Escape
      const openModal = document.querySelector(
        'dialog[open], .modal-open, [role="dialog"][aria-modal="true"]:not([aria-hidden="true"])'
      );

      if (openModal) {
        return; // Let the modal handle Escape
      }

      if (this.currentIndexValue > 0) {
        event.preventDefault();
        this.previous();
        this.announceNavigation('previous');
      }

      return;
    }

    if (event.key === 'Enter' && !event.shiftKey) {
      // Don't interfere with form submission on last field
      if (this.currentIndexValue >= this.totalFieldsValue - 1) {
        return;
      }

      if (this.canAdvance()) {
        event.preventDefault();
        this.next();
        this.announceNavigation('next');
      }
    } else if (event.key === 'ArrowRight' && (event.metaKey || event.ctrlKey)) {
      if (this.canAdvance()) {
        event.preventDefault();
        this.next();
        this.announceNavigation('next');
      }
    } else if (event.key === 'ArrowLeft' && (event.metaKey || event.ctrlKey)) {
      if (this.currentIndexValue > 0) {
        event.preventDefault();
        this.previous();
        this.announceNavigation('previous');
      }
    }
  }

  /**
   * Announce navigation changes to screen readers via aria-live region
   */
  announceNavigation(direction) {
    const currentStep = this.currentIndexValue + 1;
    const totalSteps = this.totalFieldsValue;
    const currentCard = this.cardTargets[this.currentIndexValue];
    let fieldName = '';

    if (currentCard) {
      const label = currentCard.querySelector('.label-text, label');

      if (label) {
        fieldName = label.textContent.replace('*', '').trim();
      }
    }

    const message = fieldName
      ? `Moved to ${fieldName}, question ${currentStep} of ${totalSteps}`
      : `Question ${currentStep} of ${totalSteps}`;

    this.announceToScreenReader(message);
  }

  /**
   * Announce a message to screen readers
   */
  announceToScreenReader(message, priority = 'polite') {
    // Find or create an aria-live region
    let liveRegion = document.getElementById('wizard-live-region');

    if (!liveRegion) {
      liveRegion = document.createElement('div');
      liveRegion.id = 'wizard-live-region';
      liveRegion.setAttribute('aria-live', priority);
      liveRegion.setAttribute('aria-atomic', 'true');
      liveRegion.className = 'sr-only';
      liveRegion.style.cssText =
        'position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;';
      document.body.appendChild(liveRegion);
    }

    // Clear and set new message (screen readers need the change to announce)
    liveRegion.textContent = '';
    requestAnimationFrame(() => {
      liveRegion.textContent = message;
    });
  }

  next() {
    if (this.currentIndexValue >= this.totalFieldsValue - 1) {
      return;
    }
    if (!this.canAdvance()) {
      this.triggerHapticFeedback('heavy'); // Error feedback
      this.showValidationMessage();

      return;
    }

    this.triggerHapticFeedback('light');
    this.flipCard('next');
  }

  previous() {
    if (this.currentIndexValue <= 0) {
      return;
    }

    this.triggerHapticFeedback('light');
    this.flipCard('prev');
  }

  goTo(event) {
    const index = parseInt(event.currentTarget.dataset.index);

    if (index === this.currentIndexValue) {
      return;
    }
    if (index < 0 || index >= this.totalFieldsValue) {
      return;
    }

    this.triggerHapticFeedback('medium');

    const direction = index > this.currentIndexValue ? 'next' : 'prev';

    // For jumping multiple steps, we just animate once
    const currentCard = this.cardTargets[this.currentIndexValue];
    const targetCard = this.cardTargets[index];

    if (!currentCard || !targetCard) {
      return;
    }

    // Apply exit animation to current card
    currentCard.classList.add('wizard-flip-exit', `wizard-flip-${direction}`);

    setTimeout(() => {
      currentCard.classList.add('hidden');
      currentCard.classList.remove(
        'wizard-flip-exit',
        `wizard-flip-${direction}`,
        'wizard-card-active'
      );

      this.currentIndexValue = index;
      this.updateVisibility();
      this.updateProgress();
      this.updateNavigationDots();

      // Apply enter animation to target card
      targetCard.classList.remove('hidden');
      targetCard.classList.add(
        'wizard-card-active',
        'wizard-flip-enter',
        `wizard-flip-${direction}`
      );

      setTimeout(() => {
        targetCard.classList.remove(
          'wizard-flip-enter',
          `wizard-flip-${direction}`
        );
        this.focusCurrentInput();
      }, this.effectiveAnimationDuration);
    }, this.effectiveAnimationDuration);
  }

  flipCard(direction) {
    const currentCard = this.cardTargets[this.currentIndexValue];
    const nextIndex =
      direction === 'next'
        ? this.currentIndexValue + 1
        : this.currentIndexValue - 1;
    const nextCard = this.cardTargets[nextIndex];

    if (!currentCard || !nextCard) {
      return;
    }

    // Apply exit animation to current card
    currentCard.classList.add('wizard-flip-exit', `wizard-flip-${direction}`);

    setTimeout(() => {
      // Hide current card after animation
      currentCard.classList.add('hidden');
      currentCard.classList.remove(
        'wizard-flip-exit',
        `wizard-flip-${direction}`,
        'wizard-card-active'
      );

      // Update index
      this.currentIndexValue = nextIndex;
      this.updateVisibility();
      this.updateProgress();
      this.updateNavigationDots();

      // Show and animate new card
      nextCard.classList.remove('hidden');
      nextCard.classList.add(
        'wizard-card-active',
        'wizard-flip-enter',
        `wizard-flip-${direction}`
      );

      setTimeout(() => {
        nextCard.classList.remove(
          'wizard-flip-enter',
          `wizard-flip-${direction}`
        );
        this.focusCurrentInput();
      }, this.effectiveAnimationDuration);
    }, this.effectiveAnimationDuration);
  }

  updateVisibility() {
    this.cardTargets.forEach((card, index) => {
      const isActive = index === this.currentIndexValue;

      card.classList.toggle('hidden', !isActive);
      card.classList.toggle('wizard-card-active', isActive);
    });

    // Update navigation buttons
    if (this.hasPrevBtnTarget) {
      this.prevBtnTarget.disabled = this.currentIndexValue === 0;
      this.prevBtnTarget.classList.toggle(
        'btn-disabled',
        this.currentIndexValue === 0
      );
    }

    if (this.hasNextBtnTarget) {
      const isLastField = this.currentIndexValue === this.totalFieldsValue - 1;

      this.nextBtnTarget.classList.toggle('hidden', isLastField);
    }

    if (this.hasFinishBtnTarget) {
      const isLastField = this.currentIndexValue === this.totalFieldsValue - 1;

      this.finishBtnTarget.classList.toggle('hidden', !isLastField);
    }
  }

  updateProgress() {
    const currentStep = this.currentIndexValue + 1;
    const totalSteps = this.totalFieldsValue;
    const percent = totalSteps > 0 ? (currentStep / totalSteps) * 100 : 0;
    const percentRounded = Math.round(percent);

    if (this.hasProgressTarget) {
      this.progressTarget.style.width = `${percent}%`;
    }

    // Update ARIA attributes on progress bar container
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.setAttribute(
        'aria-valuenow',
        percentRounded
      );
      this.progressContainerTarget.setAttribute(
        'aria-label',
        `Form completion progress: ${percentRounded}% complete, question ${currentStep} of ${totalSteps}`
      );
    }

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${currentStep} / ${totalSteps}`;
    }
  }

  focusCurrentInput() {
    const currentCard = this.cardTargets[this.currentIndexValue];

    if (!currentCard) {
      return;
    }

    // Small delay to ensure DOM is ready
    setTimeout(() => {
      const input = currentCard.querySelector(
        "input:not([type='hidden']), select, textarea"
      );

      if (input && !input.disabled) {
        input.focus();
      }
    }, 100);
  }

  canAdvance() {
    const currentCard = this.cardTargets[this.currentIndexValue];

    if (!currentCard) {
      return true;
    }

    const requiredInputs = currentCard.querySelectorAll('[required]');

    return Array.from(requiredInputs).every(input => {
      if (input.type === 'checkbox') {
        return input.checked;
      }
      if (input.type === 'radio') {
        const name = input.name;
        const radioGroup = currentCard.querySelectorAll(`[name="${name}"]`);

        return Array.from(radioGroup).some(r => r.checked);
      }

      return input.value.trim() !== '';
    });
  }

  showValidationMessage() {
    const currentCard = this.cardTargets[this.currentIndexValue];

    if (!currentCard) {
      return;
    }

    const requiredInputs = currentCard.querySelectorAll('[required]');
    const emptyFields = [];

    requiredInputs.forEach(input => {
      if (!input.value.trim()) {
        emptyFields.push(input);

        // Get field label for error message
        const label = this.getFieldLabel(input);
        const message = `${label} is required`;

        // Show field-level error
        showFieldError(input, message);

        // Clear error after delay
        setTimeout(() => {
          clearFieldError(input);
        }, 5000);
      }
    });

    // Show summary toast if multiple fields are empty
    if (emptyFields.length > 1) {
      showToast(
        `Please fill in ${emptyFields.length} required fields`,
        'error',
        5000
      );
    } else if (emptyFields.length === 1) {
      // Focus the empty field
      emptyFields[0].focus();
    }
  }

  // Get human-readable label for a field
  getFieldLabel(input) {
    // Try to find associated label
    const wrapper = input.closest('[data-field-name]');

    if (wrapper) {
      const label = wrapper.querySelector('.label-text');

      if (label) {
        return label.textContent.replace('*', '').trim();
      }
    }

    // Try aria-label
    if (input.getAttribute('aria-label')) {
      return input.getAttribute('aria-label');
    }

    // Fallback to name or placeholder
    return (
      input.placeholder ||
      input.name.replace(/_/gu, ' ').replace(/\[.*\]/gu, '')
    );
  }
}
