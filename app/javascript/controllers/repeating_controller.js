import { Controller } from '@hotwired/stimulus';
import { showToast } from 'utils/toast';

// Handles repeating sections (e.g., multiple defendants, additional claims)
export default class extends Controller {
  static targets = ['template', 'container', 'item', 'addBtn', 'removeBtn'];
  static values = {
    maxItems: { type: Number, default: 10 },
    minItems: { type: Number, default: 1 }
  };

  connect() {
    this.index = this.itemTargets.length;
    this.updateButtonStates();
  }

  add(event) {
    event.preventDefault();

    if (this.itemTargets.length >= this.maxItemsValue) {
      showToast(`Maximum of ${this.maxItemsValue} items allowed`, 'warning');

      return;
    }

    const template = this.templateTarget.innerHTML;
    const newItem = template.replace(/NEW_INDEX/gu, this.index);

    this.containerTarget.insertAdjacentHTML('beforeend', newItem);
    this.index += 1;

    this.updateButtonStates();

    // Dispatch event for other controllers to hook into
    this.dispatch('added', { detail: { index: this.index - 1 } });
  }

  remove(event) {
    event.preventDefault();

    if (this.itemTargets.length <= this.minItemsValue) {
      showToast(`Minimum of ${this.minItemsValue} item(s) required`, 'warning');

      return;
    }

    const item = event.target.closest("[data-repeating-target='item']");

    if (item) {
      item.remove();
      this.updateButtonStates();
      this.dispatch('removed');
    }
  }

  // Update button states based on current item count
  updateButtonStates() {
    const count = this.itemTargets.length;
    const atMax = count >= this.maxItemsValue;
    const atMin = count <= this.minItemsValue;

    // Update add button
    if (this.hasAddBtnTarget) {
      this.addBtnTarget.disabled = atMax;

      if (atMax) {
        this.addBtnTarget.setAttribute('aria-disabled', 'true');
        this.addBtnTarget.title = `Maximum of ${this.maxItemsValue} items reached`;
      } else {
        this.addBtnTarget.removeAttribute('aria-disabled');
        this.addBtnTarget.title = '';
      }
    }

    // Update remove buttons
    this.removeBtnTargets?.forEach(btn => {
      btn.disabled = atMin;

      if (atMin) {
        btn.setAttribute('aria-disabled', 'true');
      } else {
        btn.removeAttribute('aria-disabled');
      }
    });
  }
}
