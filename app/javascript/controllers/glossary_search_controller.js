import { Controller } from '@hotwired/stimulus';
import { applyFilter, createFilter } from '../utils/search_filter';

// Filters glossary terms based on search input
export default class extends Controller {
  static targets = ['container'];

  filter(event) {
    const query = event.target.value;
    const terms = document.querySelectorAll('.glossary-term');
    const matcher = createFilter(query);

    applyFilter(terms, matcher, {
      textExtractor: el => `${el.dataset.term || ''} ${el.textContent}`
    });
  }
}
