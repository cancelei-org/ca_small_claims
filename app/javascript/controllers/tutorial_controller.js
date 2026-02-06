import { Controller } from '@hotwired/stimulus';

// Provides step-by-step tutorial overlay for first-time users
export default class extends Controller {
  static targets = ['overlay', 'spotlight', 'tooltip', 'progress', 'stepCount'];

  static values = {
    tutorialId: String,
    steps: Array,
    currentStep: { type: Number, default: 0 },
    showDontShowAgain: { type: Boolean, default: true },
    spotlightPadding: { type: Number, default: 12 },
    spotlightRadius: { type: Number, default: 8 }
  };

  connect() {
    this.isActive = false;
    this.boundHandleResize = this.handleResize.bind(this);
    this.boundHandleKeydown = this.handleKeydown.bind(this);

    // Check if tutorial should be shown
    if (this.shouldShowTutorial()) {
      // Small delay to let page render
      setTimeout(() => this.start(), 500);
    }
  }

  disconnect() {
    this.cleanup();
  }

  shouldShowTutorial() {
    const storageKey = `tutorial_completed_${this.tutorialIdValue}`;

    // Check localStorage first
    if (localStorage.getItem(storageKey) === 'true') {
      return false;
    }

    // Check if user has completed (will be set via data attribute)
    if (this.element.dataset.tutorialCompleted === 'true') {
      return false;
    }

    return true;
  }

  start() {
    if (this.isActive) {
      return;
    }

    this.isActive = true;
    this.currentStepValue = 0;

    // Create overlay elements
    this.createOverlay();

    // Add event listeners
    window.addEventListener('resize', this.boundHandleResize);
    document.addEventListener('keydown', this.boundHandleKeydown);

    // Show first step
    this.showStep(0);

    // Announce to screen readers
    this.announceStep();
  }

  createOverlay() {
    // Create main overlay container
    const overlay = document.createElement('div');

    overlay.className = 'tutorial-overlay';
    overlay.dataset.tutorialTarget = 'overlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Tutorial');

    // Create spotlight cutout
    const spotlight = document.createElement('div');

    spotlight.className = 'tutorial-spotlight';
    spotlight.dataset.tutorialTarget = 'spotlight';

    // Create tooltip
    const tooltip = document.createElement('div');

    tooltip.className = 'tutorial-tooltip';
    tooltip.dataset.tutorialTarget = 'tooltip';
    tooltip.innerHTML = this.buildTooltipHTML();

    overlay.appendChild(spotlight);
    overlay.appendChild(tooltip);
    document.body.appendChild(overlay);

    // Store references
    this.overlayElement = overlay;
    this.spotlightElement = spotlight;
    this.tooltipElement = tooltip;

    // Prevent body scroll
    document.body.style.overflow = 'hidden';
  }

  buildTooltipHTML() {
    const step = this.stepsValue[this.currentStepValue];
    const isFirst = this.currentStepValue === 0;
    const isLast = this.currentStepValue === this.stepsValue.length - 1;
    const totalSteps = this.stepsValue.length;

    return `
      <div class="tutorial-tooltip-content">
        <div class="tutorial-tooltip-header">
          <h3 class="tutorial-tooltip-title">${this.escapeHtml(step.title)}</h3>
          <button type="button" class="tutorial-close-btn" data-action="click->tutorial#skip" aria-label="Close tutorial">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <p class="tutorial-tooltip-body">${this.escapeHtml(step.content)}</p>

        <div class="tutorial-tooltip-footer">
          <div class="tutorial-progress">
            <span class="tutorial-step-count">${this.currentStepValue + 1} / ${totalSteps}</span>
            <div class="tutorial-progress-bar">
              <div class="tutorial-progress-fill" style="width: ${((this.currentStepValue + 1) / totalSteps) * 100}%"></div>
            </div>
          </div>

          <div class="tutorial-actions">
            ${
              !isFirst
                ? `
              <button type="button" class="tutorial-btn tutorial-btn-secondary" data-action="click->tutorial#previous">
                Back
              </button>
            `
                : ''
            }

            ${
              isLast
                ? `
              <button type="button" class="tutorial-btn tutorial-btn-primary" data-action="click->tutorial#complete">
                Get Started
              </button>
            `
                : `
              <button type="button" class="tutorial-btn tutorial-btn-primary" data-action="click->tutorial#next">
                Next
              </button>
            `
            }
          </div>
        </div>

        ${
          isFirst && this.showDontShowAgainValue
            ? `
          <label class="tutorial-dont-show">
            <input type="checkbox" data-action="change->tutorial#toggleDontShow">
            <span>Don't show this again</span>
          </label>
        `
            : ''
        }
      </div>
    `;
  }

  showStep(index) {
    const step = this.stepsValue[index];

    if (!step) {
      return;
    }

    this.currentStepValue = index;

    // Update tooltip content
    if (this.tooltipElement) {
      this.tooltipElement.innerHTML = this.buildTooltipHTML();
    }

    // Position spotlight and tooltip
    if (step.target) {
      const targetElement = document.querySelector(step.target);

      if (targetElement) {
        this.positionSpotlight(targetElement);
        this.positionTooltip(targetElement, step.position || 'bottom');
        this.spotlightElement.classList.add('active');
      } else {
        this.centerTooltip();
        this.spotlightElement.classList.remove('active');
      }
    } else {
      this.centerTooltip();
      this.spotlightElement.classList.remove('active');
    }

    this.announceStep();
  }

  positionSpotlight(target) {
    const rect = target.getBoundingClientRect();
    const padding = this.spotlightPaddingValue;
    const radius = this.spotlightRadiusValue;

    this.spotlightElement.style.top = `${rect.top - padding + window.scrollY}px`;
    this.spotlightElement.style.left = `${rect.left - padding}px`;
    this.spotlightElement.style.width = `${rect.width + padding * 2}px`;
    this.spotlightElement.style.height = `${rect.height + padding * 2}px`;
    this.spotlightElement.style.borderRadius = `${radius}px`;

    // Scroll target into view if needed
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  positionTooltip(target, position) {
    const targetRect = target.getBoundingClientRect();
    const tooltipRect = this.tooltipElement.getBoundingClientRect();
    const padding = 16;
    const viewportWidth = window.innerWidth;

    let left = 0;
    let top = 0;

    switch (position) {
      case 'top':
        top = targetRect.top - tooltipRect.height - padding + window.scrollY;
        left = targetRect.left + (targetRect.width - tooltipRect.width) / 2;
        break;
      case 'bottom':
        top = targetRect.bottom + padding + window.scrollY;
        left = targetRect.left + (targetRect.width - tooltipRect.width) / 2;
        break;
      case 'left':
        top =
          targetRect.top +
          (targetRect.height - tooltipRect.height) / 2 +
          window.scrollY;
        left = targetRect.left - tooltipRect.width - padding;
        break;
      case 'right':
        top =
          targetRect.top +
          (targetRect.height - tooltipRect.height) / 2 +
          window.scrollY;
        left = targetRect.right + padding;
        break;
      default:
        this.centerTooltip();

        return;
    }

    // Keep within viewport
    if (left < padding) {
      left = padding;
    }
    if (left + tooltipRect.width > viewportWidth - padding) {
      left = viewportWidth - tooltipRect.width - padding;
    }
    if (top < padding + window.scrollY) {
      top = padding + window.scrollY;
    }

    this.tooltipElement.style.top = `${top}px`;
    this.tooltipElement.style.left = `${left}px`;
    this.tooltipElement.dataset.position = position;
  }

  centerTooltip() {
    this.tooltipElement.style.top = '50%';
    this.tooltipElement.style.left = '50%';
    this.tooltipElement.style.transform = 'translate(-50%, -50%)';
    this.tooltipElement.dataset.position = 'center';
  }

  next() {
    if (this.currentStepValue < this.stepsValue.length - 1) {
      this.showStep(this.currentStepValue + 1);
    }
  }

  previous() {
    if (this.currentStepValue > 0) {
      this.showStep(this.currentStepValue - 1);
    }
  }

  skip() {
    this.markCompleted();
    this.cleanup();
  }

  complete() {
    this.markCompleted();
    this.cleanup();
  }

  toggleDontShow(event) {
    this.dontShowAgain = event.target.checked;
  }

  markCompleted() {
    const storageKey = `tutorial_completed_${this.tutorialIdValue}`;

    localStorage.setItem(storageKey, 'true');

    // If user is logged in, also save to server
    if (
      this.dontShowAgain ||
      this.currentStepValue === this.stepsValue.length - 1
    ) {
      this.saveCompletionToServer();
    }
  }

  saveCompletionToServer() {
    // Only if user preferences endpoint exists
    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;

    if (!csrfToken) {
      return;
    }

    fetch('/profile/tutorial_completed', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({
        // eslint-disable-next-line camelcase -- Rails API expects snake_case
        tutorial_id: this.tutorialIdValue,
        completed: true
      })
    }).catch(() => {
      // Silently fail - localStorage is the primary storage
    });
  }

  cleanup() {
    this.isActive = false;

    // Remove event listeners
    window.removeEventListener('resize', this.boundHandleResize);
    document.removeEventListener('keydown', this.boundHandleKeydown);

    // Remove overlay
    if (this.overlayElement) {
      this.overlayElement.remove();
      this.overlayElement = null;
    }

    // Restore body scroll
    document.body.style.overflow = '';
  }

  handleResize() {
    if (this.isActive) {
      this.showStep(this.currentStepValue);
    }
  }

  handleKeydown(event) {
    if (!this.isActive) {
      return;
    }

    switch (event.key) {
      case 'Escape':
        this.skip();
        break;
      case 'ArrowRight':
      case 'Enter':
        if (this.currentStepValue === this.stepsValue.length - 1) {
          this.complete();
        } else {
          this.next();
        }
        break;
      case 'ArrowLeft':
        this.previous();
        break;
      default:
        break;
    }
  }

  announceStep() {
    const step = this.stepsValue[this.currentStepValue];
    const announcement = `Step ${this.currentStepValue + 1} of ${this.stepsValue.length}: ${step.title}. ${step.content}`;

    // Create or update live region
    let liveRegion = document.getElementById('tutorial-live-region');

    if (!liveRegion) {
      liveRegion = document.createElement('div');
      liveRegion.id = 'tutorial-live-region';
      liveRegion.className = 'sr-only';
      liveRegion.setAttribute('aria-live', 'polite');
      liveRegion.setAttribute('aria-atomic', 'true');
      document.body.appendChild(liveRegion);
    }

    liveRegion.textContent = announcement;
  }

  escapeHtml(text) {
    const div = document.createElement('div');

    div.textContent = text;

    return div.innerHTML;
  }
}
