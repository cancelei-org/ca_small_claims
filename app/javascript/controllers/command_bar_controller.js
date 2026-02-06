import { Controller } from '@hotwired/stimulus';

// Simple command bar controller
export default class extends Controller {
  static targets = ['input', 'item', 'dialog', 'emptyState'];
  static values = {
    isOpen: { type: Boolean, default: false }
  };

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    window.addEventListener('keydown', this.boundHandleKeydown);
  }

  disconnect() {
    window.removeEventListener('keydown', this.boundHandleKeydown);
  }

  /**
   * Global keyboard shortcut to open command bar (Cmd/Ctrl + K)
   */
  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault();
      this.toggle();
    }

    if (this.isOpenValue && event.key === 'Escape') {
      this.close();
    }
  }

  /**
   * Handle input changes to filter items
   * Called as both 'filter' and 'search' (alias)
   */
  search() {
    this.filter();
  }

  filter() {
    const query = this.inputTarget.value.toLowerCase().trim();
    let hasVisibleItems = false;

    this.itemTargets.forEach(item => {
      const text = item.innerText.toLowerCase();
      const isVisible = text.includes(query);

      item.classList.toggle('hidden', !isVisible);
      if (isVisible) {
        hasVisibleItems = true;
      }
    });

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.toggle(
        'hidden',
        hasVisibleItems || query === ''
      );
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
    let nextIndex = 0;

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
    if (this.isOpenValue) {
      this.close();
    } else {
      this.open();
    }
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
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus();
    }
  }

  /**
   * Handle item selection
   */
  select(event) {
    const url = event.currentTarget.dataset.url;
    const action = event.currentTarget.dataset.commandBarAction;

    this.close();

    // Handle URL navigation
    if (url) {
      window.location.href = url;

      return;
    }

    // Handle command actions
    if (action) {
      // Execute the command action if it's a function or dispatch event
      if (typeof this[action] === 'function') {
        this[action]();
      } else {
        document.dispatchEvent(new CustomEvent(`command:${action}`));
      }
    }
  }

  // Example commands
  clearForm() {
    // eslint-disable-next-line no-alert -- User confirmation required for destructive action
    if (window.confirm('Are you sure you want to clear all form data?')) {
      document.dispatchEvent(new CustomEvent('form:clear'));
    }
  }

  goToDashboard() {
    window.location.href = '/dashboard';
  }

  showHelp() {
    document.dispatchEvent(new CustomEvent('help:show'));
  }
}
