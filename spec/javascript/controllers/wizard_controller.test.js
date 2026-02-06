/**
 * @jest-environment jsdom
 */

import { Application } from '@hotwired/stimulus';
import WizardController from 'controllers/wizard_controller';

// Mock toast utilities
jest.mock('utils/toast', () => ({
  clearFieldError: jest.fn(),
  showFieldError: jest.fn(),
  showToast: jest.fn()
}));

describe('WizardController', () => {
  let application;
  let element;
  let controller;

  const createWizardHTML = (options = {}) => {
    const { totalFields = 3, currentIndex = 0 } = options;

    let cardsHTML = '';
    for (let i = 0; i < totalFields; i++) {
      const isHidden = i !== currentIndex;
      cardsHTML += `
        <div data-wizard-target="card" class="${isHidden ? 'hidden' : 'wizard-card-active'}">
          <label class="label-text">Field ${i + 1}</label>
          <input type="text" name="field_${i}" ${i === 0 ? 'required' : ''} />
        </div>
      `;
    }

    return `
      <div
        data-controller="wizard"
        data-wizard-current-index-value="${currentIndex}"
        data-wizard-total-fields-value="${totalFields}"
        data-wizard-animation-duration-value="0"
        data-wizard-form-code-value="SC-100"
      >
        <div data-wizard-target="progressContainer"
             role="progressbar"
             aria-valuenow="0"
             aria-valuemin="0"
             aria-valuemax="100">
          <div data-wizard-target="progress" style="width: 0%"></div>
        </div>
        <div data-wizard-target="counter">1 / ${totalFields}</div>

        ${cardsHTML}

        <div data-wizard-target="dotStatus" class="sr-only"></div>

        <button data-wizard-target="prevBtn" data-action="wizard#previous">Previous</button>
        <button data-wizard-target="nextBtn" data-action="wizard#next">Next</button>
        <button data-wizard-target="finishBtn" class="hidden">Finish</button>
      </div>
    `;
  };

  beforeEach(async () => {
    // Reset DOM
    document.body.innerHTML = createWizardHTML();

    // Mock matchMedia - required by wizard_controller for reduced motion detection
    // Must be set before Stimulus starts as it's called during connect()
    window.matchMedia = jest.fn().mockImplementation((query) => ({
      matches: false,
      media: query,
      onchange: null,
      addEventListener: jest.fn(),
      removeEventListener: jest.fn()
    }));

    // Mock navigator.vibrate for haptic feedback
    navigator.vibrate = jest.fn();

    // Mock localStorage
    const localStorageMock = {
      store: {},
      getItem: jest.fn((key) => localStorageMock.store[key] || null),
      setItem: jest.fn((key, value) => {
        localStorageMock.store[key] = value;
      }),
      removeItem: jest.fn((key) => {
        delete localStorageMock.store[key];
      }),
      clear: jest.fn(() => {
        localStorageMock.store = {};
      })
    };
    Object.defineProperty(window, 'localStorage', { value: localStorageMock, configurable: true });

    // Setup Stimulus
    application = Application.start();
    application.register('wizard', WizardController);

    element = document.querySelector('[data-controller="wizard"]');

    // Wait for Stimulus to connect the controller (it happens asynchronously)
    await new Promise(resolve => setTimeout(resolve, 0));

    controller = application.getControllerForElementAndIdentifier(element, 'wizard');
  });

  afterEach(() => {
    if (application) {
      application.stop();
    }
    jest.clearAllMocks();
    document.body.innerHTML = '';
  });

  describe('initialization', () => {
    it('connects and sets initial state', () => {
      expect(controller).toBeDefined();
      expect(controller.currentIndexValue).toBe(0);
      expect(controller.totalFieldsValue).toBe(3);
    });

    it('shows first card as active', () => {
      const cards = element.querySelectorAll('[data-wizard-target="card"]');
      expect(cards[0].classList.contains('hidden')).toBe(false);
      expect(cards[0].classList.contains('wizard-card-active')).toBe(true);
      expect(cards[1].classList.contains('hidden')).toBe(true);
    });

    it('disables previous button on first card', () => {
      const prevBtn = element.querySelector('[data-wizard-target="prevBtn"]');
      expect(prevBtn.disabled).toBe(true);
    });
  });

  describe('navigation', () => {
    describe('next()', () => {
      it('does not advance when required field is empty', () => {
        controller.next();
        expect(controller.currentIndexValue).toBe(0);
        expect(navigator.vibrate).toHaveBeenCalled();
      });

      it('dispatches beforeNext event', () => {
        const input = element.querySelector('input[name="field_0"]');
        input.value = 'test value';

        let eventFired = false;
        element.addEventListener('wizard:beforeNext', (e) => {
          eventFired = true;
          expect(e.detail.currentIndex).toBe(0);
          expect(e.detail.targetIndex).toBe(1);
        });

        controller.next();
        expect(eventFired).toBe(true);
      });

      it('can be prevented via beforeNext event', () => {
        const input = element.querySelector('input[name="field_0"]');
        input.value = 'test value';

        element.addEventListener('wizard:beforeNext', (e) => {
          e.preventDefault();
        });

        controller.next();
        expect(controller.currentIndexValue).toBe(0);
      });
    });

    describe('previous()', () => {
      it('does not go back when at first card', () => {
        controller.previous();
        expect(controller.currentIndexValue).toBe(0);
      });
    });

    describe('goTo()', () => {
      it('does not navigate to invalid index', () => {
        const event = { currentTarget: { dataset: { index: '99' } } };
        controller.goTo(event);
        expect(controller.currentIndexValue).toBe(0);
      });

      it('does not navigate to same index', () => {
        const event = { currentTarget: { dataset: { index: '0' } } };
        controller.goTo(event);
        expect(controller.currentIndexValue).toBe(0);
      });
    });
  });

  describe('progress tracking', () => {
    it('updates counter text', () => {
      controller.currentIndexValue = 2;
      controller.updateProgress();

      const counter = element.querySelector('[data-wizard-target="counter"]');
      expect(counter.textContent).toBe('3 / 3');
    });

    it('persists progress to localStorage', () => {
      controller.currentIndexValue = 1;
      controller.updateProgress();

      expect(localStorage.setItem).toHaveBeenCalled();
    });
  });

  describe('field validation', () => {
    it('canAdvance returns true when required field is filled', () => {
      const input = element.querySelector('input[name="field_0"]');
      input.value = 'test value';

      expect(controller.canAdvance()).toBe(true);
    });

    it('canAdvance returns false when required field is empty', () => {
      expect(controller.canAdvance()).toBe(false);
    });

    it('isFieldEmpty returns true for empty text input', () => {
      const input = document.createElement('input');
      input.type = 'text';
      input.value = '';

      expect(controller.isFieldEmpty(input)).toBe(true);
    });

    it('isFieldEmpty returns false for filled text input', () => {
      const input = document.createElement('input');
      input.type = 'text';
      input.value = 'some value';

      expect(controller.isFieldEmpty(input)).toBe(false);
    });

    it('isFieldEmpty handles checkbox inputs', () => {
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';

      expect(controller.isFieldEmpty(checkbox)).toBe(true);

      checkbox.checked = true;
      expect(controller.isFieldEmpty(checkbox)).toBe(false);
    });
  });

  describe('reduced motion', () => {
    it('respects user motion preference override', () => {
      localStorage.store['motion-preference'] = 'reduce';

      expect(controller.prefersReducedMotion).toBe(true);
    });
  });

  describe('swipe gestures', () => {
    it('ignores small swipes', () => {
      controller.touchStartX = 100;
      controller.touchEndX = 120; // Only 20px, less than 50px threshold

      controller.handleSwipeGesture();
      expect(controller.currentIndexValue).toBe(0);
    });
  });

  describe('accessibility', () => {
    it('updates ARIA attributes on progress bar', () => {
      controller.currentIndexValue = 1;
      controller.updateProgress();

      const container = element.querySelector('[data-wizard-target="progressContainer"]');
      expect(container.getAttribute('aria-valuenow')).toBe('67');
    });

    it('announces navigation to screen readers', () => {
      controller.announceToScreenReader('Test message');

      const liveRegion = document.getElementById('wizard-live-region');
      expect(liveRegion).toBeDefined();
      expect(liveRegion.getAttribute('aria-live')).toBe('polite');
    });

    it('updates dot status for screen readers', () => {
      controller.updateDotStatus();

      const statusEl = element.querySelector('[data-wizard-target="dotStatus"]');
      expect(statusEl.textContent).toBe('Field 1 of 3');
    });
  });

  describe('haptic feedback', () => {
    it('triggers heavy vibration on validation error', () => {
      controller.next(); // Empty required field
      expect(navigator.vibrate).toHaveBeenCalledWith(40);
    });
  });

  describe('first empty field navigation', () => {
    it('finds first empty required field', () => {
      const inputs = element.querySelectorAll('input');
      inputs[0].value = 'filled';
      inputs[1].value = '';
      inputs[2].value = '';

      const index = controller.findFirstEmptyFieldIndex();
      expect(index).toBe(1);
    });

    it('returns 0 when all fields are filled', () => {
      const inputs = element.querySelectorAll('input');
      inputs.forEach(input => input.value = 'filled');

      const index = controller.findFirstEmptyFieldIndex();
      expect(index).toBe(0);
    });
  });
});
