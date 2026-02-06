import { Controller } from '@hotwired/stimulus';

// Provides interactive tooltips for legal terms
// Shows definition on hover/focus with option to learn more
export default class extends Controller {
  static values = {
    definition: String,
    simple: String,
    url: String
  };

  connect() {
    this.tooltip = null;
    this.isVisible = false;
    this.hideTimeout = null;
  }

  disconnect() {
    this.hideTooltip();
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
    }
  }

  // Show tooltip on mouse enter
  mouseenter() {
    this.showTooltip();
  }

  // Hide tooltip on mouse leave (with delay)
  mouseleave() {
    this.scheduleHide();
  }

  // Show tooltip on focus (keyboard navigation)
  focus() {
    this.showTooltip();
  }

  // Hide tooltip on blur
  blur() {
    this.scheduleHide();
  }

  // Toggle on click/tap for mobile
  click(event) {
    event.preventDefault();
    if (this.isVisible) {
      this.hideTooltip();
    } else {
      this.showTooltip();
    }
  }

  // Handle keyboard interactions
  keydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      this.click(event);
    } else if (event.key === 'Escape') {
      this.hideTooltip();
    }
  }

  showTooltip() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }

    if (this.isVisible) {
      return;
    }

    this.createTooltip();
    this.positionTooltip();
    this.isVisible = true;

    // Add event listeners to tooltip for hover persistence
    this.tooltip.addEventListener('mouseenter', () => {
      if (this.hideTimeout) {
        clearTimeout(this.hideTimeout);
        this.hideTimeout = null;
      }
    });
    this.tooltip.addEventListener('mouseleave', () => {
      this.scheduleHide();
    });
  }

  scheduleHide() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
    }
    this.hideTimeout = setTimeout(() => {
      this.hideTooltip();
    }, 200);
  }

  hideTooltip() {
    if (this.tooltip) {
      this.tooltip.remove();
      this.tooltip = null;
    }
    this.isVisible = false;
  }

  createTooltip() {
    this.tooltip = document.createElement('div');
    this.tooltip.className = 'legal-tooltip';
    this.tooltip.setAttribute('role', 'tooltip');
    const randomId = Array.from(
      window.crypto.getRandomValues(new Uint8Array(5))
    )
      .map(b => b.toString(36))
      .join('');

    this.tooltip.id = `tooltip-${randomId}`;

    // Build tooltip content
    let content = '';

    // Simple definition (headline)
    if (this.simpleValue) {
      content += `<div class="legal-tooltip-simple">${this.escapeHtml(this.simpleValue)}</div>`;
    }

    // Full definition
    if (this.definitionValue) {
      content += `<div class="legal-tooltip-definition">${this.escapeHtml(this.definitionValue)}</div>`;
    }

    // Learn more link
    if (this.urlValue) {
      content += `<a href="${this.escapeHtml(this.urlValue)}" target="_blank" rel="noopener" class="legal-tooltip-link">
        Learn more
        <svg class="w-3 h-3 inline-block ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
        </svg>
      </a>`;
    }

    this.tooltip.innerHTML = content;

    // Link ARIA
    this.element.setAttribute('aria-describedby', this.tooltip.id);

    document.body.appendChild(this.tooltip);
  }

  positionTooltip() {
    if (!this.tooltip) {
      return;
    }

    const rect = this.element.getBoundingClientRect();
    const tooltipRect = this.tooltip.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const scrollY = window.scrollY;
    const scrollX = window.scrollX;

    // Default: position above the element
    let top = rect.top + scrollY - tooltipRect.height - 8;
    let left = rect.left + scrollX + rect.width / 2 - tooltipRect.width / 2;

    // Arrow direction
    let arrowPosition = 'bottom';

    // If not enough space above, position below
    if (top < scrollY + 10) {
      top = rect.bottom + scrollY + 8;
      arrowPosition = 'top';
    }

    // Keep within horizontal bounds
    if (left < 10) {
      left = 10;
    } else if (left + tooltipRect.width > viewportWidth - 10) {
      left = viewportWidth - tooltipRect.width - 10;
    }

    this.tooltip.style.top = `${top}px`;
    this.tooltip.style.left = `${left}px`;
    this.tooltip.dataset.arrow = arrowPosition;
  }

  escapeHtml(text) {
    const div = document.createElement('div');

    div.textContent = text;

    return div.innerHTML;
  }
}
