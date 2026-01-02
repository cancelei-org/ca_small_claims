import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['dialog', 'input', 'results', 'item'];
  static values = {
    isOpen: Boolean
  };

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    this.previouslyFocusedElement = null;
    document.addEventListener('keydown', this.boundHandleKeydown);
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleKeydown);
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      this.toggle();
    }

    if (this.isOpenValue) {
      if (event.key === 'Escape') {
        event.preventDefault();
        this.close();
      }

      // Arrow key navigation for items
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        this.navigateItems(event.key === 'ArrowDown' ? 1 : -1);
      }

      // Enter to select focused item
      if (event.key === 'Enter') {
        const focusedItem = this.element.querySelector(
          '[data-command-bar-target="item"]:focus'
        );

        if (focusedItem) {
          event.preventDefault();
          focusedItem.click();
        }
      }
    }
  }

  /**
   * Navigate through items with arrow keys
   */
  navigateItems(direction) {
    const visibleItems = this.itemTargets.filter(
      item => !item.classList.contains('hidden')
    );

    if (visibleItems.length === 0) {
      return;
    }

    const currentIndex = visibleItems.findIndex(
      item => item === document.activeElement
    );
    let nextIndex;

    if (currentIndex === -1) {
      nextIndex = direction === 1 ? 0 : visibleItems.length - 1;
    } else {
      nextIndex = currentIndex + direction;
      if (nextIndex < 0) {
        nextIndex = visibleItems.length - 1;
      }
      if (nextIndex >= visibleItems.length) {
        nextIndex = 0;
      }
    }

    visibleItems[nextIndex].focus();
  }

  toggle() {
    this.isOpenValue ? this.close() : this.open();
  }

  open() {
    // Store previously focused element for restoration
    this.previouslyFocusedElement = document.activeElement;

    this.isOpenValue = true;
    this.dialogTarget.showModal();
    this.inputTarget.focus();
    document.body.classList.add('overflow-hidden');
  }

  close() {
    this.isOpenValue = false;
    this.dialogTarget.close();
    document.body.classList.remove('overflow-hidden');

    // Restore focus to previously focused element
    if (this.previouslyFocusedElement && this.previouslyFocusedElement.focus) {
      requestAnimationFrame(() => {
        this.previouslyFocusedElement.focus();
        this.previouslyFocusedElement = null;
      });
    }
  }

  search(event) {
    const query = event.target.value.toLowerCase();

    // Simple client-side filtering for now
    this.itemTargets.forEach(item => {
      const text = item.textContent.toLowerCase();
      const match = text.includes(query);

      item.classList.toggle('hidden', !match);
    });
  }

  select(event) {
    const item = event.currentTarget;
    const url = item.dataset.url;
    const action = item.dataset.commandBarAction;

    if (url) {
      window.location.href = url;
    } else if (action === 'theme') {
      // Trigger theme toggle event
      const themeController =
        this.application.getControllerForElementAndIdentifier(
          document.querySelector('[data-controller="theme"]'),
          'theme'
        );

      themeController?.openModal();
      this.close();
    } else if (action === 'clear-form') {
      this.clearForm();
    } else if (action === 'copy-link') {
      this.copyLink();
    }
  }

  clearForm() {
    const form = document.querySelector('#main-form');

    if (
      form &&
      confirm(
        'Are you sure you want to clear all fields? This cannot be undone.'
      )
    ) {
      form.reset();
      // Dispatch input event to trigger autosave/validation clear if needed
      form.querySelectorAll('input, textarea, select').forEach(input => {
        input.dispatchEvent(new Event('input', { bubbles: true }));
      });
      this.close();

      document.dispatchEvent(
        new CustomEvent('toast:show', {
          detail: { message: 'Form cleared', type: 'info' }
        })
      );
    }
  }

  copyLink() {
    navigator.clipboard.writeText(window.location.href).then(() => {
      this.close();
      document.dispatchEvent(
        new CustomEvent('toast:show', {
          detail: { message: 'Link copied to clipboard', type: 'success' }
        })
      );
    });
  }
}
