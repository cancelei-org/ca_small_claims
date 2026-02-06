import { Controller } from '@hotwired/stimulus';
import { applyFilter, createFilter } from '../utils/search_filter';

// Simple client-side filter for FAQ cards
export default class extends Controller {
  static targets = ['input', 'item'];

  filter() {
    const query = this.inputTarget.value;
    const matcher = createFilter(query);

    applyFilter(this.itemTargets, matcher, {
      textExtractor: el => el.dataset.faqText || el.textContent
    });
  }
}
