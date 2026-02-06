import { Controller } from '@hotwired/stimulus';

// Lightweight undo/redo stack for form inputs
export default class extends Controller {
  static targets = ['undoButton', 'redoButton'];
  static values = { limit: { type: Number, default: 30 } };

  connect() {
    this.undoStack = [];
    this.redoStack = [];
    this.currentValues = this.snapshot();

    this.handleInput = this.onInput.bind(this);
    this.element.addEventListener('input', this.handleInput);
    this.refreshButtons();
  }

  disconnect() {
    this.element.removeEventListener('input', this.handleInput);
  }

  onInput(event) {
    const name = event.target.name;

    if (!name) {
      return;
    }

    const previous = this.currentValues[name];
    const current = this.valueForElement(event.target);

    if (previous === current) {
      return;
    }

    this.undoStack.push({ name, previous, current });

    if (this.undoStack.length > this.limitValue) {
      this.undoStack.shift();
    }

    this.currentValues[name] = current;
    this.redoStack = [];
    this.refreshButtons();
  }

  undo(event) {
    event.preventDefault();
    const change = this.undoStack.pop();

    if (!change) {
      return;
    }

    this.applyChange(change.name, change.previous);
    this.redoStack.push(change);
    this.refreshButtons();
  }

  redo(event) {
    event.preventDefault();
    const change = this.redoStack.pop();

    if (!change) {
      return;
    }

    this.applyChange(change.name, change.current);
    this.undoStack.push(change);
    this.refreshButtons();
  }

  applyChange(name, value) {
    const selector = `[name="${this.escape(name)}"]`;
    const field = this.element.querySelector(selector);

    if (!field) {
      return;
    }

    if (field.type === 'checkbox' || field.type === 'radio') {
      field.checked =
        value === true ||
        value === 'true' ||
        value === 'on' ||
        value === field.value;
    } else {
      field.value = value ?? '';
    }

    // Trigger downstream listeners (autosave, validation)
    field.dispatchEvent(new Event('input', { bubbles: true }));
    field.dispatchEvent(new Event('change', { bubbles: true }));

    this.currentValues[name] = this.valueForElement(field);
  }

  snapshot() {
    const data = {};
    const formData = new FormData(this.element);

    formData.forEach((value, key) => {
      data[key] = value;
    });

    return data;
  }

  valueForElement(element) {
    if (element.type === 'checkbox' || element.type === 'radio') {
      return element.checked ? element.value || true : '';
    }

    return element.value;
  }

  refreshButtons() {
    if (this.hasUndoButtonTarget) {
      this.undoButtonTarget.disabled = this.undoStack.length === 0;
    }
    if (this.hasRedoButtonTarget) {
      this.redoButtonTarget.disabled = this.redoStack.length === 0;
    }
  }

  escape(value) {
    if (window.CSS?.escape) {
      return window.CSS.escape(value);
    }

    return value.replace(/"/gu, '\\"');
  }
}
