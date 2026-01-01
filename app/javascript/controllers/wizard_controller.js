import { Controller } from '@hotwired/stimulus';

// Handles wizard-style single-question form navigation with 3D card flip animations
export default class extends Controller {
  static targets = [
    'card',
    'progress',
    'counter',
    'prevBtn',
    'nextBtn',
    'finishBtn',
    'skipToggle',
    'dot'
  ];

  static values = {
    currentIndex: { type: Number, default: 0 },
    totalFields: Number,
    skipFilled: { type: Boolean, default: false },
    animationDuration: { type: Number, default: 500 }
  };

  connect() {
    this.updateVisibility();
    this.updateProgress();
    this.updateNavigationDots();
    this.bindKeyboardNavigation();
    this.bindModeChangeListener();
    this.bindFieldChangeListener();
    this.focusCurrentInput();
  }

  disconnect() {
    this.unbindKeyboardNavigation();
    this.unbindModeChangeListener();
    this.unbindFieldChangeListener();
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

  // Update navigation dots to reflect filled/empty state
  updateNavigationDots() {
    if (!this.hasDotTarget) {
      return;
    }

    this.dotTargets.forEach((dot, index) => {
      const card = this.cardTargets[index];
      const isActive = index === this.currentIndexValue;
      const isFilled = card ? this.isFieldFilled(card) : false;

      // Reset classes
      dot.classList.remove(
        'bg-primary',
        'bg-success',
        'bg-base-300',
        'ring-2',
        'ring-primary',
        'ring-offset-2'
      );

      if (isActive) {
        // Current field - primary with ring
        dot.classList.add(
          'bg-primary',
          'ring-2',
          'ring-primary',
          'ring-offset-2'
        );
      } else if (isFilled) {
        // Filled field - success color
        dot.classList.add('bg-success');
      } else {
        // Empty field - base color
        dot.classList.add('bg-base-300');
      }
    });
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
      }
    } else if (event.key === 'ArrowRight' && (event.metaKey || event.ctrlKey)) {
      if (this.canAdvance()) {
        event.preventDefault();
        this.next();
      }
    } else if (event.key === 'ArrowLeft' && (event.metaKey || event.ctrlKey)) {
      if (this.currentIndexValue > 0) {
        event.preventDefault();
        this.previous();
      }
    }
  }

  next() {
    if (this.currentIndexValue >= this.totalFieldsValue - 1) {
      return;
    }
    if (!this.canAdvance()) {
      this.showValidationMessage();

      return;
    }

    this.flipCard('next');
  }

  previous() {
    if (this.currentIndexValue <= 0) {
      return;
    }

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
      }, this.animationDurationValue);
    }, this.animationDurationValue);
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
      }, this.animationDurationValue);
    }, this.animationDurationValue);
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
    const percent =
      this.totalFieldsValue > 0
        ? ((this.currentIndexValue + 1) / this.totalFieldsValue) * 100
        : 0;

    if (this.hasProgressTarget) {
      this.progressTarget.style.width = `${percent}%`;
    }

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.currentIndexValue + 1} / ${this.totalFieldsValue}`;
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

    requiredInputs.forEach(input => {
      if (!input.value.trim()) {
        input.classList.add('input-error');
        input.reportValidity();

        // Remove error class after a delay
        setTimeout(() => {
          input.classList.remove('input-error');
        }, 2000);
      }
    });
  }
}
