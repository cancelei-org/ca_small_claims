import { Controller } from '@hotwired/stimulus';

/**
 * Keyboard Shortcuts Controller
 * Provides keyboard navigation for forms and the application
 *
 * Shortcuts:
 *   Ctrl/Cmd + S     - Save form
 *   Ctrl/Cmd + P     - Preview PDF
 *   Ctrl/Cmd + D     - Download PDF
 *   Ctrl/Cmd + /     - Show shortcuts help
 *   Arrow Left/Right - Navigate wizard cards (when in wizard mode)
 *   Tab/Shift+Tab    - Navigate between fields
 *   Escape           - Close modals/drawers
 *
 * Usage:
 *   <div data-controller="keyboard-shortcuts"
 *        data-keyboard-shortcuts-save-url-value="/forms/sc-100"
 *        data-keyboard-shortcuts-preview-url-value="/forms/sc-100/preview"
 *        data-keyboard-shortcuts-download-url-value="/forms/sc-100/download">
 */
export default class extends Controller {
  static values = {
    saveUrl: String,
    previewUrl: String,
    downloadUrl: String
  };

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this);
    document.addEventListener('keydown', this.handleKeydown);
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown);
  }

  handleKeydown(event) {
    // Check for modifier key (Ctrl on Windows/Linux, Cmd on Mac)
    const isMod = event.ctrlKey || event.metaKey;

    // Don't intercept if user is typing in an input
    const isTyping = ['INPUT', 'TEXTAREA', 'SELECT'].includes(
      document.activeElement?.tagName
    );

    if (isMod) {
      switch (event.key.toLowerCase()) {
        case 's':
          // Save form
          event.preventDefault();
          this.triggerSave();
          break;

        case 'p':
          // Preview PDF
          if (this.hasPreviewUrlValue) {
            event.preventDefault();
            window.open(this.previewUrlValue, '_blank');
          }
          break;

        case 'd':
          // Download PDF
          if (this.hasDownloadUrlValue) {
            event.preventDefault();
            window.location.href = this.downloadUrlValue;
          }
          break;

        case '/':
          // Show shortcuts help
          event.preventDefault();
          this.showHelp();
          break;

        default:
          // No action for other keys
          break;
      }
    }

    // Arrow key navigation for wizard mode (when not typing)
    if (!isTyping && !isMod) {
      const wizardController =
        this.application.getControllerForElementAndIdentifier(
          document.querySelector('[data-controller~="wizard"]'),
          'wizard'
        );

      if (wizardController) {
        switch (event.key) {
          case 'ArrowRight':
          case 'ArrowDown':
            event.preventDefault();
            wizardController.next?.();
            break;

          case 'ArrowLeft':
          case 'ArrowUp':
            event.preventDefault();
            wizardController.prev?.();
            break;

          default:
            // No action for other keys
            break;
        }
      }
    }
  }

  triggerSave() {
    // Find and submit the form
    const form = document.querySelector('#main-form');

    if (form) {
      // Trigger the form controller's save method
      const formController =
        this.application.getControllerForElementAndIdentifier(form, 'form');

      if (formController?.save) {
        formController.save();
        this.showToast('Form saved');
      } else {
        form.requestSubmit();
      }
    }
  }

  showHelp() {
    const modal = document.getElementById('keyboard-shortcuts-modal');

    if (modal?.showModal) {
      modal.showModal();
    } else {
      // Fallback: show alert with shortcuts
      // eslint-disable-next-line no-alert
      alert(
        'Keyboard Shortcuts:\n\n' +
          'Ctrl/Cmd + S  - Save form\n' +
          'Ctrl/Cmd + P  - Preview PDF\n' +
          'Ctrl/Cmd + D  - Download PDF\n' +
          'Arrow keys    - Navigate wizard\n' +
          'Escape        - Close dialogs'
      );
    }
  }

  showToast(message) {
    // Dispatch event to ToastController
    document.dispatchEvent(
      new CustomEvent('toast:show', {
        detail: { message, type: 'success' }
      })
    );
  }
}
