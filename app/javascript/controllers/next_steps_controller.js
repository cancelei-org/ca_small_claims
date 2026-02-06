import { Controller } from '@hotwired/stimulus';

// Next Steps Guidance Controller
// Handles step tracking and local progress storage
export default class extends Controller {
  static targets = ['step'];
  static values = {
    formCode: String
  };

  connect() {
    this.loadProgress();
  }

  // Mark a step as completed (persisted to localStorage)
  toggleStep(event) {
    const stepElement = event.currentTarget.closest(
      "[data-next-steps-target='step']"
    );

    if (!stepElement) {
      return;
    }

    const stepId = stepElement.dataset.stepId;

    if (!stepId) {
      return;
    }

    const progress = this.getProgress();

    if (progress[stepId]) {
      delete progress[stepId];
      stepElement.classList.remove('step-completed');
    } else {
      progress[stepId] = {
        completed: true,
        completedAt: new Date().toISOString()
      };
      stepElement.classList.add('step-completed');
    }

    this.saveProgress(progress);
    this.updateProgressUI();
  }

  // Load progress from localStorage
  loadProgress() {
    const progress = this.getProgress();

    this.stepTargets.forEach(step => {
      const stepId = step.dataset.stepId;

      if (stepId && progress[stepId]) {
        step.classList.add('step-completed');
      }
    });

    this.updateProgressUI();
  }

  // Get progress from localStorage
  getProgress() {
    const key = this.storageKey();

    try {
      return JSON.parse(localStorage.getItem(key)) || {};
    } catch {
      return {};
    }
  }

  // Save progress to localStorage
  saveProgress(progress) {
    const key = this.storageKey();

    try {
      localStorage.setItem(key, JSON.stringify(progress));
    } catch {
      // localStorage not available
    }
  }

  // Generate storage key based on form code
  storageKey() {
    const formCode = this.formCodeValue || 'default';

    return `next_steps_progress_${formCode}`;
  }

  // Update any progress indicators
  updateProgressUI() {
    const progress = this.getProgress();
    const totalSteps = this.stepTargets.length;
    const completedSteps = Object.keys(progress).length;

    // Update progress counter if present
    const counter = this.element.querySelector('[data-next-steps-counter]');

    if (counter) {
      counter.textContent = `${completedSteps}/${totalSteps} completed`;
    }
  }

  // Reset all progress
  reset() {
    const key = this.storageKey();

    try {
      localStorage.removeItem(key);
    } catch {
      // localStorage not available
    }

    this.stepTargets.forEach(step => {
      step.classList.remove('step-completed');
    });

    this.updateProgressUI();
  }
}
