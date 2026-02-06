import { Controller } from '@hotwired/stimulus';
import { csrfToken } from 'utilities/csrf';

/**
 * Send Email Controller
 * Handles sending completed PDF forms to user's email
 * Prompts unauthenticated users to sign up first
 */
export default class extends Controller {
  static targets = ['sendButton', 'status', 'modal', 'signupLink', 'loginLink'];

  static values = {
    url: String,
    signedIn: Boolean,
    signupUrl: String,
    loginUrl: String,
    formCode: String
  };

  connect() {
    // Update signup/login links with return path
    this.updateAuthLinks();
  }

  /**
   * Update auth links to include return URL
   */
  updateAuthLinks() {
    const returnPath = window.location.pathname;

    if (this.hasSignupLinkTarget) {
      const signupUrl = new URL(this.signupUrlValue, window.location.origin);

      signupUrl.searchParams.set('return_to', returnPath);
      this.signupLinkTarget.href = signupUrl.toString();
    }

    if (this.hasLoginLinkTarget) {
      const loginUrl = new URL(this.loginUrlValue, window.location.origin);

      loginUrl.searchParams.set('return_to', returnPath);
      this.loginLinkTarget.href = loginUrl.toString();
    }
  }

  /**
   * Main action: Send PDF to email or show signup prompt
   */
  async send(event) {
    event.preventDefault();

    if (!this.signedInValue) {
      this.showSignupPrompt();

      return;
    }

    await this.sendEmail();
  }

  /**
   * Show the signup prompt modal
   */
  showSignupPrompt() {
    // Find the modal in the DOM (it's rendered in the layout)
    const modal = document.getElementById('signup-prompt-modal');

    if (modal) {
      modal.showModal();
    } else {
      // Fallback: redirect to signup
      window.location.href = this.signupUrlValue;
    }
  }

  /**
   * Close the signup prompt modal
   */
  closeModal() {
    const modal = document.getElementById('signup-prompt-modal');

    if (modal) {
      modal.close();
    }
  }

  /**
   * Redirect to download as fallback
   */
  download(event) {
    event.preventDefault();
    this.closeModal();

    // Trigger download
    const downloadUrl = this.urlValue.replace('/send_email', '/download');

    window.location.href = downloadUrl;
  }

  /**
   * Send the email via AJAX
   */
  async sendEmail() {
    this.setLoading(true);
    this.showStatus('Sending...', 'info');

    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken()
        }
      });

      const data = await response.json();

      if (response.ok && data.success) {
        this.showStatus(data.message, 'success');
        this.showToast(data.message, 'success');
      } else if (data.requires_signup) {
        this.showSignupPrompt();
      } else {
        this.showStatus(data.message || 'Failed to send email', 'error');
        this.showToast(data.message || 'Failed to send email', 'error');
      }
    } catch (error) {
      console.error('Send email error:', error);
      this.showStatus('Network error. Please try again.', 'error');
      this.showToast('Network error. Please try again.', 'error');
    } finally {
      this.setLoading(false);
    }
  }

  /**
   * Set loading state on button
   */
  setLoading(isLoading) {
    if (!this.hasSendButtonTarget) {
      return;
    }

    this.sendButtonTarget.disabled = isLoading;

    if (isLoading) {
      this.sendButtonTarget.classList.add('loading');
    } else {
      this.sendButtonTarget.classList.remove('loading');
    }
  }

  /**
   * Show status message below button
   */
  showStatus(message, type) {
    if (!this.hasStatusTarget) {
      return;
    }

    const statusEl = this.statusTarget;
    const span = statusEl.querySelector('span');

    if (span) {
      span.textContent = message;
    }

    // Remove existing color classes
    statusEl.classList.remove(
      'text-success',
      'text-error',
      'text-info',
      'text-warning'
    );

    // Add appropriate color class
    switch (type) {
      case 'success':
        statusEl.classList.add('text-success');
        break;
      case 'error':
        statusEl.classList.add('text-error');
        break;
      case 'info':
        statusEl.classList.add('text-info');
        break;
      default:
        statusEl.classList.add('text-base-content');
    }

    statusEl.classList.remove('hidden');

    // Hide after delay for success messages
    if (type === 'success') {
      setTimeout(() => {
        statusEl.classList.add('hidden');
      }, 5000);
    }
  }

  /**
   * Show toast notification
   */
  showToast(message, type) {
    // Check if toast container exists, create if not
    let toastContainer = document.getElementById('toast-container');

    if (!toastContainer) {
      toastContainer = document.createElement('div');
      toastContainer.id = 'toast-container';
      toastContainer.className = 'toast toast-end toast-bottom z-50';
      document.body.appendChild(toastContainer);
    }

    // Create toast element
    const toast = document.createElement('div');

    toast.className = `alert ${type === 'success' ? 'alert-success' : 'alert-error'} shadow-lg`;
    toast.innerHTML = `
      <div class="flex items-center gap-2">
        ${
          type === 'success'
            ? '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>'
            : '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>'
        }
        <span>${message}</span>
      </div>
    `;

    toastContainer.appendChild(toast);

    // Remove after delay
    setTimeout(() => {
      toast.classList.add('opacity-0', 'transition-opacity', 'duration-300');
      setTimeout(() => toast.remove(), 300);
    }, 5000);
  }
}
