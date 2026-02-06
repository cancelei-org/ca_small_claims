/**
 * Search Filter Utility
 * Provides reusable client-side filtering functionality for Stimulus controllers.
 * Reduces duplication across FAQ, glossary, and other search controllers.
 *
 * Usage in Stimulus controller:
 *   import { createFilter, applyFilter, debounce } from 'utils/search_filter';
 *
 *   filter() {
 *     const query = this.inputTarget.value;
 *     const matcher = createFilter(query);
 *     applyFilter(this.itemTargets, matcher, {
 *       textExtractor: (el) => el.dataset.searchText || el.textContent
 *     });
 *   }
 */

/**
 * Normalize a search query for matching
 * @param {string} query - The raw search query
 * @returns {string} Normalized query (lowercase, trimmed)
 */
export function normalizeQuery(query) {
  return (query || '').toLowerCase().trim();
}

/**
 * Create a filter matcher function for a query
 * @param {string} query - The search query
 * @param {Object} options - Matcher options
 * @param {boolean} options.matchAll - If true, all words must match (default: false)
 * @returns {Function} A function that takes text and returns true if it matches
 */
export function createFilter(query, options = {}) {
  const normalizedQuery = normalizeQuery(query);

  // Empty query matches everything
  if (!normalizedQuery) {
    return () => true;
  }

  const { matchAll = false } = options;
  const words = normalizedQuery.split(/\s+/u).filter(Boolean);

  return text => {
    const normalizedText = normalizeQuery(text);

    if (matchAll) {
      return words.every(word => normalizedText.includes(word));
    }

    return normalizedText.includes(normalizedQuery);
  };
}

/**
 * Apply a filter to a collection of elements
 * @param {Element[]|NodeList} elements - Elements to filter
 * @param {Function} matcher - Filter matcher function from createFilter()
 * @param {Object} options - Filter options
 * @param {Function} options.textExtractor - Function to extract searchable text from element
 * @param {string} options.hiddenClass - Class to apply when hidden (default: 'hidden')
 * @param {Function} options.onMatch - Callback when element matches
 * @param {Function} options.onNoMatch - Callback when element doesn't match
 * @returns {Object} Results with matched and hidden counts
 */
export function applyFilter(elements, matcher, options = {}) {
  const {
    textExtractor = el => el.textContent,
    hiddenClass = 'hidden',
    onMatch = null,
    onNoMatch = null
  } = options;

  let matchedCount = 0;
  let hiddenCount = 0;

  elements.forEach(element => {
    const text = textExtractor(element);
    const isMatch = matcher(text);

    if (isMatch) {
      element.classList.remove(hiddenClass);
      matchedCount += 1;
      if (onMatch) {
        onMatch(element);
      }
    } else {
      element.classList.add(hiddenClass);
      hiddenCount += 1;
      if (onNoMatch) {
        onNoMatch(element);
      }
    }
  });

  return { matchedCount, hiddenCount, total: elements.length };
}

/**
 * Create a debounced version of a function
 * @param {Function} fn - Function to debounce
 * @param {number} delay - Delay in milliseconds (default: 300)
 * @returns {Function} Debounced function with cancel() method
 */
export function debounce(fn, delay = 300) {
  let timeoutId = null;

  function debouncedFn(...args) {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }

    timeoutId = setTimeout(() => {
      fn(...args);
      timeoutId = null;
    }, delay);
  }

  debouncedFn.cancel = function cancel() {
    if (timeoutId) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
  };

  return debouncedFn;
}

/**
 * Highlight matching text in an element (optional enhancement)
 * @param {Element} element - Element containing text to highlight
 * @param {string} query - Query to highlight
 * @param {string} highlightClass - Class for highlight span (default: 'bg-yellow-200')
 */
export function highlightMatches(
  element,
  query,
  highlightClass = 'bg-yellow-200'
) {
  const normalizedQuery = normalizeQuery(query);

  if (!normalizedQuery) {
    return;
  }

  const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
  const textNodes = [];

  while (walker.nextNode()) {
    textNodes.push(walker.currentNode);
  }

  textNodes.forEach(node => {
    const text = node.textContent;
    const lowerText = text.toLowerCase();
    const index = lowerText.indexOf(normalizedQuery);

    if (index !== -1) {
      const before = text.slice(0, index);
      const match = text.slice(index, index + normalizedQuery.length);
      const after = text.slice(index + normalizedQuery.length);

      const span = document.createElement('span');

      span.className = highlightClass;
      span.textContent = match;

      const fragment = document.createDocumentFragment();

      if (before) {
        fragment.appendChild(document.createTextNode(before));
      }
      fragment.appendChild(span);
      if (after) {
        fragment.appendChild(document.createTextNode(after));
      }

      node.parentNode.replaceChild(fragment, node);
    }
  });
}

/**
 * Remove all highlights from an element
 * @param {Element} element - Element to clear highlights from
 * @param {string} highlightClass - Class used for highlights
 */
export function clearHighlights(element, highlightClass = 'bg-yellow-200') {
  const highlights = element.querySelectorAll(`.${highlightClass}`);

  highlights.forEach(span => {
    const text = document.createTextNode(span.textContent);

    span.parentNode.replaceChild(text, span);
  });

  // Normalize to merge adjacent text nodes
  element.normalize();
}

export default {
  normalizeQuery,
  createFilter,
  applyFilter,
  debounce,
  highlightMatches,
  clearHighlights
};
