import { Controller } from '@hotwired/stimulus';

/**
 * Download Controller
 * Adds loading indicators to download buttons (PDF, etc.)
 *
 * Usage:
 *   <a href="/download" data-controller="download" data-action="click->download#start">
 *     <span data-download-target="text">Download PDF</span>
 *     <span data-download-target="loading" class="hidden">Generating...</span>
 *   </a>
 */
export default class extends Controller {
  static targets = ['text', 'loading', 'icon'];

  start(_event) {
    // Show loading state
    if (this.hasTextTarget) {
      this.textTarget.classList.add('hidden');
    }
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden');
    }
    if (this.hasIconTarget) {
      this.iconTarget.classList.add('animate-spin');
    }

    // Add loading class to button
    this.element.classList.add('loading', 'pointer-events-none');

    // Reset after download starts (browser handles file download)
    // Use a timeout as we can't detect when download completes
    setTimeout(() => this.reset(), 5000);
  }

  reset() {
    if (this.hasTextTarget) {
      this.textTarget.classList.remove('hidden');
    }
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden');
    }
    if (this.hasIconTarget) {
      this.iconTarget.classList.remove('animate-spin');
    }

    this.element.classList.remove('loading', 'pointer-events-none');
  }
}
