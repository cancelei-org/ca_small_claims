import { Controller } from '@hotwired/stimulus';

/**
 * Theme Controller
 *
 * Handles DaisyUI theme switching with:
 * - Immediate visual feedback (no page reload)
 * - localStorage persistence for fast initial load
 * - Server persistence for logged-in users
 */
export default class extends Controller {
  static values = {
    current: { type: String, default: 'light' },
    endpoint: { type: String, default: '/users/preferences/theme' }
  };

  connect() {
    // Initialize current theme from HTML attribute
    this.currentValue =
      document.documentElement.getAttribute('data-theme') || 'light';
    this.updateUI();

    // Track the trigger element for focus restoration (accessibility)
    this.triggerElement = null;

    // Listen for modal close to restore focus
    const modal = this.modal;

    if (modal) {
      modal.addEventListener('close', () => this.handleModalClose());
    }
  }

  /**
   * Get the theme modal element (rendered globally in layout)
   */
  get modal() {
    return document.getElementById('theme-modal');
  }

  /**
   * Open the theme modal
   */
  openModal(event) {
    const modal = this.modal;

    if (modal) {
      // Store the trigger element for focus restoration (accessibility)
      this.triggerElement = event?.currentTarget || document.activeElement;
      modal.showModal();
      // Update UI when modal opens (in case theme changed elsewhere)
      this.updateUI();
    }
  }

  /**
   * Close the theme modal
   */
  closeModal() {
    const modal = this.modal;

    if (modal) {
      modal.close();
    }
  }

  /**
   * Handle modal close - restore focus to trigger element (accessibility)
   */
  handleModalClose() {
    if (
      this.triggerElement &&
      typeof this.triggerElement.focus === 'function'
    ) {
      // Small delay to ensure modal is fully closed
      requestAnimationFrame(() => {
        this.triggerElement.focus();
        this.triggerElement = null;
      });
    }
  }

  /**
   * Switch theme - called from theme card click
   */
  switch(event) {
    event.preventDefault();
    const theme = event.currentTarget.dataset.themeValue;

    if (!theme || theme === this.currentValue) {
      return;
    }

    this.applyTheme(theme);
    this.persistTheme(theme);
  }

  /**
   * Apply theme immediately to DOM
   */
  applyTheme(theme) {
    // Update HTML attribute - DaisyUI picks this up immediately
    document.documentElement.setAttribute('data-theme', theme);

    // Update localStorage for fast initial load on next visit
    localStorage.setItem('theme', theme);

    // Update internal state
    this.currentValue = theme;
    this.updateUI();
  }

  /**
   * Persist theme to server
   */
  async persistTheme(theme) {
    try {
      const response = await fetch(this.endpointValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ theme })
      });

      if (!response.ok) {
        console.warn('Failed to persist theme preference');
      }
    } catch (error) {
      console.warn('Error persisting theme:', error);
      // Theme is already applied via localStorage, so graceful degradation
    }
  }

  /**
   * Update UI to reflect current theme
   */
  updateUI() {
    // Find all theme cards in the modal (which is outside controller scope)
    const themeCards = document.querySelectorAll('[data-theme-card]');

    themeCards.forEach(card => {
      const cardTheme = card.dataset.themeValue;
      const isSelected = cardTheme === this.currentValue;

      // Update ring highlight and border
      if (isSelected) {
        card.classList.add(
          'ring-2',
          'ring-primary',
          'ring-offset-2',
          'ring-offset-base-100',
          'border-primary'
        );
        card.classList.remove('border-base-300');
      } else {
        card.classList.remove(
          'ring-2',
          'ring-primary',
          'ring-offset-2',
          'ring-offset-base-100',
          'border-primary'
        );
        card.classList.add('border-base-300');
      }

      // Update checkmark visibility
      const checkmark = card.querySelector('[data-checkmark]');

      if (checkmark) {
        checkmark.classList.toggle('hidden', !isSelected);
      }
    });
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
  }
}
