import { Controller } from '@hotwired/stimulus';
import { DEBOUNCE_DELAYS, createDebouncedHandler } from 'utilities/debounce';

/**
 * PDF Preview Controller
 * Handles live PDF preview with optimized refresh and request coalescing
 *
 * Optimizations:
 * - Reduced debounce delay (form already debounces saves)
 * - Request coalescing (cancels pending loads when new request comes in)
 * - Immediate refresh option for manual triggers
 * - Status text updates for better UX feedback
 */
export default class extends Controller {
  static targets = ['frame', 'loading', 'error', 'autoRefreshToggle', 'statusText', 'refreshIcon'];
  static values = {
    url: String,
    debounceDelay: { type: Number, default: DEBOUNCE_DELAYS.FAST }, // Reduced from SLOW
    autoRefresh: { type: Boolean, default: true }
  };

  connect() {
    this.isLoading = false;
    this.pendingRefresh = false;
    this.lastLoadTime = 0;

    // Optimized debounce - shorter delay since form already debounces
    this.debouncedRefresh = createDebouncedHandler(() => this.performRefresh());

    // Listen for form save events
    this.handleFormSaved = this.handleFormSaved.bind(this);
    document.addEventListener('form:saved', this.handleFormSaved);

    // Initial load
    this.loadPreview();
  }

  disconnect() {
    this.debouncedRefresh.cancel();
    document.removeEventListener('form:saved', this.handleFormSaved);
    if (this.loadTimeout) {
      clearTimeout(this.loadTimeout);
      this.loadTimeout = null;
    }
  }

  handleFormSaved(event) {
    if (!this.autoRefreshValue) {
      return;
    }

    // Request coalescing: if already loading, mark as pending
    if (this.isLoading) {
      this.pendingRefresh = true;
      this.updateStatus('queued');
      return;
    }

    this.triggerDebouncedRefresh();
  }

  triggerDebouncedRefresh() {
    this.updateStatus('updating');
    this.showLoading();
    this.debouncedRefresh.call(this.debounceDelayValue);
  }

  // Manual refresh - immediate, no debounce
  refresh() {
    this.debouncedRefresh.cancel();
    this.performRefresh();
  }

  performRefresh() {
    this.loadPreview();
  }

  loadPreview() {
    if (!this.hasFrameTarget) {
      return;
    }

    // Request coalescing: cancel if already loading same content
    if (this.isLoading) {
      this.pendingRefresh = true;
      return;
    }

    this.isLoading = true;
    this.pendingRefresh = false;
    this.showLoading();
    this.hideError();
    this.updateStatus('loading');
    this.animateRefreshIcon(true);

    // Clear any existing load timeout
    if (this.loadTimeout) {
      clearTimeout(this.loadTimeout);
    }

    // Add cache-busting timestamp
    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set('t', Date.now());

    this.frameTarget.src = url.toString();

    // Fallback timeout for PDF load events that may not fire in some browsers
    this.loadTimeout = setTimeout(() => {
      if (this.isLoading) {
        this.handleLoad();
      }
    }, 5000);
  }

  handleLoad() {
    // Clear fallback timeout since load completed
    if (this.loadTimeout) {
      clearTimeout(this.loadTimeout);
      this.loadTimeout = null;
    }

    this.isLoading = false;
    this.lastLoadTime = Date.now();
    this.hideLoading();
    this.hideError();
    this.updateStatus('ready');
    this.animateRefreshIcon(false);

    // Process queued refresh if any
    if (this.pendingRefresh) {
      this.pendingRefresh = false;
      // Small delay to prevent rapid re-renders
      setTimeout(() => this.triggerDebouncedRefresh(), 100);
    }
  }

  handleError() {
    this.isLoading = false;
    this.pendingRefresh = false;
    this.hideLoading();
    this.showError();
    this.updateStatus('error');
    this.animateRefreshIcon(false);
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

  showError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.remove('hidden');
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add('hidden');
    }
  }

  updateStatus(status) {
    if (!this.hasStatusTextTarget) {
      return;
    }

    const messages = {
      ready: 'Up to date',
      loading: 'Loading...',
      updating: 'Updating...',
      queued: 'Update queued',
      error: 'Error'
    };

    this.statusTextTarget.textContent = messages[status] || status;

    // Update styling based on status
    this.statusTextTarget.classList.remove('text-success', 'text-error', 'text-warning');
    if (status === 'ready') {
      this.statusTextTarget.classList.add('text-success');
    } else if (status === 'error') {
      this.statusTextTarget.classList.add('text-error');
    } else if (status === 'queued') {
      this.statusTextTarget.classList.add('text-warning');
    }
  }

  animateRefreshIcon(spinning) {
    if (!this.hasRefreshIconTarget) {
      return;
    }

    if (spinning) {
      this.refreshIconTarget.classList.add('animate-spin');
    } else {
      this.refreshIconTarget.classList.remove('animate-spin');
    }
  }

  toggleAutoRefresh(event) {
    this.autoRefreshValue = event.target.checked;
    this.updateStatus(this.autoRefreshValue ? 'ready' : 'paused');
  }

  // Open preview in new tab
  openFullscreen() {
    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set('t', Date.now());
    window.open(url.toString(), '_blank');
  }
}
