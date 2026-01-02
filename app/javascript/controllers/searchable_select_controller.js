import { Controller } from '@hotwired/stimulus';

/**
 * Searchable Select Controller
 * Adds type-ahead filtering to select dropdowns
 * Works by creating a custom dropdown overlay on top of the native select
 */
export default class extends Controller {
  static targets = ['select', 'input', 'dropdown', 'option'];

  static values = {
    placeholder: { type: String, default: 'Search...' },
    noResults: { type: String, default: 'No results found' },
    minOptions: { type: Number, default: 5 } // Only show search for 5+ options
  };

  connect() {
    if (!this.hasSelectTarget) {
      return;
    }

    // Only enhance if enough options
    const optionCount = this.selectTarget.options.length;

    if (optionCount < this.minOptionsValue) {
      return;
    }

    this.buildCustomDropdown();
    this.bindEvents();
  }

  disconnect() {
    this.unbindEvents();
  }

  buildCustomDropdown() {
    const select = this.selectTarget;

    // Hide native select (but keep it for form submission)
    select.classList.add('sr-only');
    select.setAttribute('tabindex', '-1');

    // Create wrapper
    const wrapper = document.createElement('div');

    wrapper.className = 'searchable-select-wrapper relative';
    select.parentNode.insertBefore(wrapper, select);
    wrapper.appendChild(select);

    // Create display button
    const button = document.createElement('button');

    button.type = 'button';
    button.className =
      'searchable-select-trigger select select-bordered w-full min-h-[48px] text-base text-left flex items-center justify-between';
    button.setAttribute('aria-haspopup', 'listbox');
    button.setAttribute('aria-expanded', 'false');

    const selectedOption = select.options[select.selectedIndex];
    const buttonText = document.createElement('span');

    buttonText.className = 'searchable-select-value truncate';
    buttonText.textContent = selectedOption?.text || 'Select...';
    button.appendChild(buttonText);

    // Chevron icon
    const chevron = document.createElement('span');

    chevron.innerHTML = `<svg class="w-4 h-4 text-base-content/50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
    </svg>`;
    button.appendChild(chevron);

    wrapper.appendChild(button);
    this.triggerButton = button;
    this.buttonText = buttonText;

    // Create dropdown
    const dropdown = document.createElement('div');

    dropdown.className =
      'searchable-select-dropdown hidden absolute z-50 w-full mt-1 bg-base-100 border border-base-300 rounded-lg shadow-lg max-h-60 overflow-hidden';
    dropdown.setAttribute('role', 'listbox');

    // Search input
    const searchWrapper = document.createElement('div');

    searchWrapper.className = 'p-2 border-b border-base-200';

    const searchInput = document.createElement('input');

    searchInput.type = 'text';
    searchInput.className = 'input input-bordered input-sm w-full text-base';
    searchInput.placeholder = this.placeholderValue;
    searchInput.setAttribute('aria-label', 'Search options');
    searchWrapper.appendChild(searchInput);
    dropdown.appendChild(searchWrapper);

    this.searchInput = searchInput;

    // Options list
    const optionsList = document.createElement('div');

    optionsList.className =
      'searchable-select-options overflow-y-auto max-h-48';

    Array.from(select.options).forEach((option, index) => {
      if (index === 0 && option.value === '') {
        return; // Skip placeholder option
      }

      const optionEl = document.createElement('div');

      optionEl.className =
        'searchable-select-option px-3 py-2 cursor-pointer hover:bg-base-200 transition-colors';
      optionEl.setAttribute('role', 'option');
      optionEl.setAttribute('data-value', option.value);
      optionEl.setAttribute('data-searchable-select-target', 'option');
      optionEl.textContent = option.text;

      if (option.selected) {
        optionEl.classList.add('bg-primary/10', 'text-primary');
        optionEl.setAttribute('aria-selected', 'true');
      }

      optionsList.appendChild(optionEl);
    });

    dropdown.appendChild(optionsList);

    // No results message
    const noResults = document.createElement('div');

    noResults.className =
      'searchable-select-no-results hidden px-3 py-4 text-center text-base-content/50 text-sm';
    noResults.textContent = this.noResultsValue;
    dropdown.appendChild(noResults);

    this.noResultsEl = noResults;
    this.optionsList = optionsList;

    wrapper.appendChild(dropdown);
    this.dropdown = dropdown;
  }

  bindEvents() {
    this.handleTriggerClick = this.handleTriggerClick.bind(this);
    this.handleSearch = this.handleSearch.bind(this);
    this.handleOptionClick = this.handleOptionClick.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);
    this.handleClickOutside = this.handleClickOutside.bind(this);

    this.triggerButton?.addEventListener('click', this.handleTriggerClick);
    this.searchInput?.addEventListener('input', this.handleSearch);
    this.optionsList?.addEventListener('click', this.handleOptionClick);
    this.dropdown?.addEventListener('keydown', this.handleKeydown);
    document.addEventListener('click', this.handleClickOutside);
  }

  unbindEvents() {
    this.triggerButton?.removeEventListener('click', this.handleTriggerClick);
    this.searchInput?.removeEventListener('input', this.handleSearch);
    this.optionsList?.removeEventListener('click', this.handleOptionClick);
    this.dropdown?.removeEventListener('keydown', this.handleKeydown);
    document.removeEventListener('click', this.handleClickOutside);
  }

  handleTriggerClick(event) {
    event.preventDefault();
    event.stopPropagation();
    this.toggleDropdown();
  }

  toggleDropdown() {
    const isOpen = !this.dropdown.classList.contains('hidden');

    if (isOpen) {
      this.closeDropdown();
    } else {
      this.openDropdown();
    }
  }

  openDropdown() {
    this.dropdown.classList.remove('hidden');
    this.triggerButton.setAttribute('aria-expanded', 'true');
    this.searchInput.value = '';
    this.filterOptions('');
    this.searchInput.focus();
  }

  closeDropdown() {
    this.dropdown.classList.add('hidden');
    this.triggerButton.setAttribute('aria-expanded', 'false');
  }

  handleSearch(event) {
    const query = event.target.value.toLowerCase().trim();

    this.filterOptions(query);
  }

  filterOptions(query) {
    let visibleCount = 0;

    this.optionTargets.forEach(option => {
      const text = option.textContent.toLowerCase();
      const matches = !query || text.includes(query);

      option.classList.toggle('hidden', !matches);

      if (matches) {
        visibleCount += 1;
      }
    });

    // Show/hide no results message
    this.noResultsEl.classList.toggle('hidden', visibleCount > 0);
  }

  handleOptionClick(event) {
    const option = event.target.closest('.searchable-select-option');

    if (!option) {
      return;
    }

    this.selectOption(option);
  }

  selectOption(optionEl) {
    const value = optionEl.dataset.value;

    // Update native select
    this.selectTarget.value = value;

    // Trigger change event
    this.selectTarget.dispatchEvent(new Event('change', { bubbles: true }));

    // Update display
    this.buttonText.textContent = optionEl.textContent;

    // Update visual selection
    this.optionTargets.forEach(opt => {
      opt.classList.remove('bg-primary/10', 'text-primary');
      opt.setAttribute('aria-selected', 'false');
    });
    optionEl.classList.add('bg-primary/10', 'text-primary');
    optionEl.setAttribute('aria-selected', 'true');

    this.closeDropdown();
    this.triggerButton.focus();
  }

  handleKeydown(event) {
    const options = this.optionTargets.filter(
      opt => !opt.classList.contains('hidden')
    );

    if (options.length === 0) {
      return;
    }

    const currentIndex = options.findIndex(opt =>
      opt.classList.contains('bg-base-200')
    );

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        this.highlightOption(options, currentIndex + 1);
        break;
      case 'ArrowUp':
        event.preventDefault();
        this.highlightOption(options, currentIndex - 1);
        break;
      case 'Enter':
        event.preventDefault();
        if (currentIndex >= 0) {
          this.selectOption(options[currentIndex]);
        }
        break;
      case 'Escape':
        event.preventDefault();
        this.closeDropdown();
        this.triggerButton.focus();
        break;
      default:
        break;
    }
  }

  highlightOption(options, index) {
    // Remove current highlight
    options.forEach(opt => opt.classList.remove('bg-base-200'));

    // Wrap around
    let newIndex = index;

    if (newIndex < 0) {
      newIndex = options.length - 1;
    }

    if (newIndex >= options.length) {
      newIndex = 0;
    }

    // Add highlight
    const option = options[newIndex];

    option.classList.add('bg-base-200');
    option.scrollIntoView({ block: 'nearest' });
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeDropdown();
    }
  }
}
