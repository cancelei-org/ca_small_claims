import { Controller } from '@hotwired/stimulus';

// Manages toast notifications
export default class extends Controller {
  static targets = ['container', 'template'];

  connect() {
    this.boundHandleEvent = this.handleEvent.bind(this);
    document.addEventListener('toast:show', this.boundHandleEvent);
  }

  disconnect() {
    document.removeEventListener('toast:show', this.boundHandleEvent);
  }

  handleEvent(event) {
    const { message, type = 'info', duration = 3000 } = event.detail;

    this.show(message, type, duration);
  }

  show(message, type = 'info', duration = 3000) {
    if (!this.hasContainerTarget) {
      return;
    }

    const toast = document.createElement('div');
    const alertClass = this.getAlertClass(type);

    // DaisyUI Alert structure
    toast.className = `alert ${alertClass} shadow-lg mb-2 animate-fade-in`;
    toast.innerHTML = `
      <div>
        ${this.getIcon(type)}
        <span>${message}</span>
      </div>
      <div class="flex-none">
        <button class="btn btn-sm btn-ghost" aria-label="Close">✕</button>
      </div>
    `;

    // Close button action
    toast.querySelector('button').addEventListener('click', () => {
      this.close(toast);
    });

    this.containerTarget.appendChild(toast);

    // Auto-dismiss
    if (duration > 0) {
      setTimeout(() => {
        this.close(toast);
      }, duration);
    }
  }

  close(toast) {
    toast.classList.add('animate-fade-out');
    toast.addEventListener('animationend', () => {
      toast.remove();
    });
  }

  getAlertClass(type) {
    switch (type) {
      case 'success':
        return 'alert-success';
      case 'error':
        return 'alert-error';
      case 'warning':
        return 'alert-warning';
      default:
        return 'alert-info';
    }
  }

  getIcon(type) {
    // Icons based on type
    const icons = {
      success:
        '<svg xmlns="http://www.w3.org/2000/svg" class="stroke-current flex-shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>',
      error:
        '<svg xmlns="http://www.w3.org/2000/svg" class="stroke-current flex-shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>',
      warning:
        '<svg xmlns="http://www.w3.org/2000/svg" class="stroke-current flex-shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>',
      info: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current flex-shrink-0 w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'
    };

    return icons[type] || icons.info;
  }
}
