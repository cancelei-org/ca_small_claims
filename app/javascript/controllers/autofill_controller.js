import { Controller } from '@hotwired/stimulus';

/**
 * Autofill Controller
 * Shows a dropdown with suggestions from user profile data
 * Always displays dropdown even for single suggestions for consistent UX
 */
export default class extends Controller {
  static values = {
    suggestions: { type: Array, default: [] }
  };

  connect() {
    this.isOpen = false;
    this.selectedIndex = -1;
    this.boundHandleClickOutside = this.handleClickOutside.bind(this);
    this.boundHandleKeydown = this.handleKeydown.bind(this);
  }

  disconnect() {
    this.closeDropdown();
  }

  toggle(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this.isOpen) {
      this.closeDropdown();
    } else {
      this.openDropdown();
    }
  }

  openDropdown() {
    if (this.suggestionsValue.length === 0) {
      return;
    }

    this.buildDropdown();
    this.isOpen = true;
    this.selectedIndex = 0;
    this.updateSelection();

    // Add event listeners
    document.addEventListener('click', this.boundHandleClickOutside);
    document.addEventListener('keydown', this.boundHandleKeydown);

    // Update ARIA
    this.element.setAttribute('aria-expanded', 'true');
  }

  closeDropdown() {
    if (this.dropdown) {
      this.dropdown.remove();
      this.dropdown = null;
    }

    this.isOpen = false;
    this.selectedIndex = -1;

    // Remove event listeners
    document.removeEventListener('click', this.boundHandleClickOutside);
    document.removeEventListener('keydown', this.boundHandleKeydown);

    // Update ARIA
    this.element.setAttribute('aria-expanded', 'false');
  }

  buildDropdown() {
    // Remove existing dropdown if any
    if (this.dropdown) {
      this.dropdown.remove();
    }

    const dropdown = document.createElement('div');

    dropdown.className =
      'autofill-dropdown absolute z-50 mt-1 w-64 bg-base-100 border border-base-300 rounded-lg shadow-lg overflow-hidden';
    dropdown.setAttribute('role', 'listbox');
    dropdown.setAttribute('aria-label', 'Autofill suggestions');

    // Header
    const header = document.createElement('div');

    header.className =
      'px-3 py-2 bg-base-200 border-b border-base-300 text-xs font-medium text-base-content/70';
    header.textContent = 'From your profile';
    dropdown.appendChild(header);

    // Options
    const optionsList = document.createElement('div');

    optionsList.className = 'py-1';

    this.suggestionsValue.forEach((suggestion, index) => {
      const option = document.createElement('button');

      option.type = 'button';
      option.className =
        'autofill-option w-full px-3 py-2 text-left hover:bg-primary/10 focus:bg-primary/10 focus:outline-none transition-colors';
      option.setAttribute('role', 'option');
      option.setAttribute('data-index', index);
      option.setAttribute('data-value', suggestion.value);

      // Option content with label and value
      const labelSpan = document.createElement('span');

      labelSpan.className = 'block text-xs text-base-content/60';
      labelSpan.textContent = suggestion.label;

      const valueSpan = document.createElement('span');

      valueSpan.className =
        'block text-sm font-medium text-base-content truncate';
      valueSpan.textContent = suggestion.value;

      option.appendChild(labelSpan);
      option.appendChild(valueSpan);

      option.addEventListener('click', e => {
        e.preventDefault();
        e.stopPropagation();
        this.selectSuggestion(index);
      });

      optionsList.appendChild(option);
    });

    dropdown.appendChild(optionsList);

    // Position dropdown relative to trigger button
    this.element.style.position = 'relative';
    this.element.appendChild(dropdown);
    this.dropdown = dropdown;
    this.options = optionsList.querySelectorAll('.autofill-option');
  }

  updateSelection() {
    if (!this.options) {
      return;
    }

    this.options.forEach((option, index) => {
      if (index === this.selectedIndex) {
        option.classList.add('bg-primary/10');
        option.setAttribute('aria-selected', 'true');
      } else {
        option.classList.remove('bg-primary/10');
        option.setAttribute('aria-selected', 'false');
      }
    });
  }

  selectSuggestion(index) {
    const suggestion = this.suggestionsValue[index];

    if (!suggestion) {
      return;
    }

    this.applyValue(suggestion.value);
    this.closeDropdown();
  }

  applyValue(value) {
    // Find the input within the same form-control group
    const wrapper = this.element.closest('.form-control');
    const input = wrapper?.querySelector('input, textarea, select');

    if (input) {
      input.value = value;

      // Trigger events for other controllers (auto-save, validation, etc.)
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));

      // Visual feedback - highlight briefly
      input.classList.add('bg-primary/10');
      setTimeout(() => input.classList.remove('bg-primary/10'), 1000);

      // Focus the input
      input.focus();

      // Toast notification
      document.dispatchEvent(
        new CustomEvent('toast:show', {
          detail: { message: 'Magic fill applied!', type: 'success' }
        })
      );
    }
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeDropdown();
    }
  }

  handleKeydown(event) {
    if (!this.isOpen) {
      return;
    }

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        this.selectedIndex = Math.min(
          this.selectedIndex + 1,
          this.suggestionsValue.length - 1
        );
        this.updateSelection();
        break;

      case 'ArrowUp':
        event.preventDefault();
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0);
        this.updateSelection();
        break;

      case 'Enter':
        event.preventDefault();
        if (this.selectedIndex >= 0) {
          this.selectSuggestion(this.selectedIndex);
        }
        break;

      case 'Escape':
        event.preventDefault();
        this.closeDropdown();
        this.element.focus();
        break;

      case 'Tab':
        this.closeDropdown();
        break;
    }
  }
}
