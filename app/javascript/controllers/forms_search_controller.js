import { Controller } from '@hotwired/stimulus';

/**
 * Forms Search Controller
 * Provides instant search and category filtering for the forms index
 */
export default class extends Controller {
  static targets = ['input', 'category', 'loading', 'count'];
  static values = {
    debounceMs: { type: Number, default: 300 }
  };

  connect() {
    this.searchTimeout = null;
  }

  disconnect() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
    }
  }

  // Debounced search on input
  search() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
    }

    this.searchTimeout = setTimeout(() => {
      this.performSearch();
    }, this.debounceMsValue);
  }

  // Submit immediately on Enter key
  submit(event) {
    event.preventDefault();

    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
    }

    this.performSearch();
  }

  // Filter by category (from mobile dropdown)
  filterCategory() {
    const category = this.hasCategoryTarget ? this.categoryTarget.value : '';
    const search = this.hasInputTarget ? this.inputTarget.value : '';

    this.navigateToResults(search, category);
  }

  performSearch() {
    const search = this.hasInputTarget ? this.inputTarget.value : '';
    const category = this.getCurrentCategory();

    this.navigateToResults(search, category);
  }

  getCurrentCategory() {
    // Check mobile dropdown first
    if (this.hasCategoryTarget && this.categoryTarget.value) {
      return this.categoryTarget.value;
    }

    // Otherwise get from URL
    const url = new URL(window.location.href);

    return url.searchParams.get('category') || '';
  }

  navigateToResults(search, category) {
    // Show loading indicator
    this.showLoading();

    // Build URL with query params
    const url = new URL(`${window.location.origin}/forms`);

    if (search && search.trim()) {
      url.searchParams.set('search', search.trim());
    }

    if (category) {
      url.searchParams.set('category', category);
    }

    // Use Turbo for smooth navigation
    if (window.Turbo) {
      window.Turbo.visit(url.toString(), { action: 'replace' });
    } else {
      window.location.href = url.toString();
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden');
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden');
    }
  }
}
