import { Controller } from '@hotwired/stimulus';
import { DEBOUNCE_DELAYS, createDebouncedHandler } from 'utilities/debounce';

export default class extends Controller {
  static targets = ['searchInput', 'categoryButton', 'results'];
  static values = {
    url: String,
    debounceDelay: { type: Number, default: DEBOUNCE_DELAYS.FAST }
  };

  connect() {
    this.debouncedSearch = createDebouncedHandler(() => this.performSearch());
  }

  disconnect() {
    this.debouncedSearch.cancel();
  }

  search() {
    this.debouncedSearch.call(this.debounceDelayValue);
  }

  selectCategory(event) {
    event.preventDefault();

    // Update active state on category buttons
    this.categoryButtonTargets.forEach(btn => {
      btn.classList.remove('btn-primary');
      btn.classList.add('btn-outline');
    });

    const clickedButton = event.currentTarget;

    if (clickedButton.dataset.category) {
      clickedButton.classList.remove('btn-outline');
      clickedButton.classList.add('btn-primary');
    }

    this.performSearch();
  }

  clearCategory(event) {
    event.preventDefault();

    // Reset all category buttons
    this.categoryButtonTargets.forEach(btn => {
      btn.classList.remove('btn-primary');
      btn.classList.add('btn-outline');
    });

    this.performSearch();
  }

  performSearch() {
    const searchValue = this.hasSearchInputTarget
      ? this.searchInputTarget.value
      : '';
    const activeCategory = this.categoryButtonTargets.find(btn =>
      btn.classList.contains('btn-primary')
    );
    const categoryValue = activeCategory ? activeCategory.dataset.category : '';

    const url = new URL(this.urlValue, window.location.origin);

    if (searchValue) {
      url.searchParams.set('search', searchValue);
    }
    if (categoryValue) {
      url.searchParams.set('category', categoryValue);
    }

    fetch(url, {
      headers: {
        Accept: 'text/vnd.turbo-stream.html'
      }
    })
      .then(response => response.text())
      .then(html => {
        window.Turbo.renderStreamMessage(html);
      });
  }
}
