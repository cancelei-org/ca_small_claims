import { Controller } from '@hotwired/stimulus';

// Handles repeating sections (e.g., multiple defendants, additional claims)
export default class extends Controller {
  static targets = ['template', 'container', 'item'];
  static values = {
    maxItems: { type: Number, default: 10 },
    minItems: { type: Number, default: 1 }
  };

  connect() {
    this.index = this.itemTargets.length;
  }

  add(event) {
    event.preventDefault();

    if (this.itemTargets.length >= this.maxItemsValue) {
      window.alert(`Maximum of ${this.maxItemsValue} items allowed`);

      return;
    }

    const template = this.templateTarget.innerHTML;
    const newItem = template.replace(/NEW_INDEX/gu, this.index);

    this.containerTarget.insertAdjacentHTML('beforeend', newItem);
    this.index += 1;

    // Dispatch event for other controllers to hook into
    this.dispatch('added', { detail: { index: this.index - 1 } });
  }

  remove(event) {
    event.preventDefault();

    if (this.itemTargets.length <= this.minItemsValue) {
      window.alert(`Minimum of ${this.minItemsValue} item(s) required`);

      return;
    }

    const item = event.target.closest("[data-repeating-target='item']");

    if (item) {
      item.remove();
      this.dispatch('removed');
    }
  }
}
