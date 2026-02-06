import { Controller } from '@hotwired/stimulus';

/**
 * Session Expiry Controller
 *
 * Displays countdown warnings for anonymous 72-hour sessions to prevent data loss.
 * Shows non-intrusive banners at 48h, 24h, 6h, and 1h marks.
 * Allows dismissal but re-shows at next threshold.
 */
export default class extends Controller {
  static targets = ['banner', 'countdown', 'message', 'urgencyIcon'];

  static values = {
    expiresAt: String, // ISO 8601 timestamp of session expiration
    thresholds: { type: Array, default: [48, 24, 6, 1] }, // Hours before expiry to show warning
    checkInterval: { type: Number, default: 60000 } // Check every minute
  };

  connect() {
    if (!this.hasExpiresAtValue || !this.expiresAtValue) {
      return;
    }

    this.expiresAtDate = new Date(this.expiresAtValue);

    // Validate expiration date
    if (isNaN(this.expiresAtDate.getTime())) {
      console.error('Invalid session expiration date:', this.expiresAtValue);

      return;
    }

    this.dismissedThreshold = this.loadDismissedThreshold();
    this.checkAndShowWarning();

    // Set up interval to check expiration periodically
    this.intervalId = setInterval(
      () => this.checkAndShowWarning(),
      this.checkIntervalValue
    );

    // Update countdown every second when visible
    this.countdownIntervalId = null;
  }

  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
    if (this.countdownIntervalId) {
      clearInterval(this.countdownIntervalId);
    }
  }

  /**
   * Calculate time remaining until session expires
   * @returns {number} Seconds remaining
   */
  getTimeRemaining() {
    return Math.max(0, (this.expiresAtDate.getTime() - Date.now()) / 1000);
  }

  /**
   * Get hours remaining until expiration
   * @returns {number} Hours remaining
   */
  getHoursRemaining() {
    return this.getTimeRemaining() / 3600;
  }

  /**
   * Determine which threshold we're at
   * @returns {number|null} Current threshold in hours, or null if none
   */
  getCurrentThreshold() {
    const hoursRemaining = this.getHoursRemaining();

    for (const threshold of this.thresholdsValue) {
      if (hoursRemaining <= threshold) {
        return threshold;
      }
    }

    return null;
  }

  /**
   * Get urgency level based on hours remaining
   * @param {number} hoursRemaining
   * @returns {string} 'info', 'warning', or 'danger'
   */
  getUrgencyLevel(hoursRemaining) {
    if (hoursRemaining <= 1) {
      return 'danger';
    } else if (hoursRemaining <= 6) {
      return 'warning';
    }

    return 'info';
  }

  /**
   * Check if we should show warning and display if needed
   */
  checkAndShowWarning() {
    const currentThreshold = this.getCurrentThreshold();

    // No threshold reached yet
    if (currentThreshold === null) {
      this.hideBanner();

      return;
    }

    // Already dismissed this threshold
    if (
      this.dismissedThreshold !== null &&
      currentThreshold >= this.dismissedThreshold
    ) {
      return;
    }

    // Show the warning
    this.showBanner(currentThreshold);
  }

  /**
   * Show the warning banner
   * @param {number} _threshold Current threshold in hours (used for tracking)
   */
  showBanner(_threshold) {
    if (!this.hasBannerTarget) {
      return;
    }

    const hoursRemaining = this.getHoursRemaining();
    const urgency = this.getUrgencyLevel(hoursRemaining);

    // Update urgency styling
    this.updateUrgencyStyles(urgency);

    // Update message
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = this.getWarningMessage(hoursRemaining);
    }

    // Start countdown timer
    this.updateCountdown();
    if (!this.countdownIntervalId) {
      this.countdownIntervalId = setInterval(
        () => this.updateCountdown(),
        1000
      );
    }

    // Show the banner with animation
    this.bannerTarget.classList.remove('hidden');
    this.bannerTarget.classList.add('session-expiry-banner-visible');

    // Announce to screen readers
    this.bannerTarget.setAttribute('role', 'alert');
    this.bannerTarget.setAttribute('aria-live', 'polite');
  }

  /**
   * Hide the warning banner
   */
  hideBanner() {
    if (!this.hasBannerTarget) {
      return;
    }

    this.bannerTarget.classList.add('hidden');
    this.bannerTarget.classList.remove('session-expiry-banner-visible');

    if (this.countdownIntervalId) {
      clearInterval(this.countdownIntervalId);
      this.countdownIntervalId = null;
    }
  }

  /**
   * Update the countdown display
   */
  updateCountdown() {
    if (!this.hasCountdownTarget) {
      return;
    }

    const secondsRemaining = this.getTimeRemaining();

    if (secondsRemaining <= 0) {
      this.countdownTarget.textContent = 'Session expired';
      if (this.countdownIntervalId) {
        clearInterval(this.countdownIntervalId);
        this.countdownIntervalId = null;
      }

      return;
    }

    this.countdownTarget.textContent =
      this.formatTimeRemaining(secondsRemaining);
  }

  /**
   * Format seconds into human-readable time
   * @param {number} seconds
   * @returns {string}
   */
  formatTimeRemaining(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);

    if (hours > 0) {
      return `${hours}h ${minutes}m remaining`;
    } else if (minutes > 0) {
      return `${minutes}m ${secs}s remaining`;
    }

    return `${secs}s remaining`;
  }

  /**
   * Get appropriate warning message based on time remaining
   * @param {number} hoursRemaining
   * @returns {string}
   */
  getWarningMessage(hoursRemaining) {
    if (hoursRemaining <= 1) {
      return 'Your session is about to expire! Save your work now to avoid losing data.';
    } else if (hoursRemaining <= 6) {
      return 'Your anonymous session will expire soon. Create an account to save your progress permanently.';
    } else if (hoursRemaining <= 24) {
      return 'Your session expires in less than 24 hours. Consider creating an account to keep your data.';
    }

    return 'Your anonymous session will expire in 2 days. Create an account for permanent access.';
  }

  /**
   * Update banner styling based on urgency
   * @param {string} urgency 'info', 'warning', or 'danger'
   */
  updateUrgencyStyles(urgency) {
    if (!this.hasBannerTarget) {
      return;
    }

    // Remove existing urgency classes
    this.bannerTarget.classList.remove(
      'session-expiry-info',
      'session-expiry-warning',
      'session-expiry-danger'
    );

    // Add new urgency class
    this.bannerTarget.classList.add(`session-expiry-${urgency}`);

    // Update icon if present
    if (this.hasUrgencyIconTarget) {
      this.updateUrgencyIcon(urgency);
    }
  }

  /**
   * Update the urgency icon
   * @param {string} urgency
   */
  updateUrgencyIcon(urgency) {
    const icons = {
      info: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />`,
      warning: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />`,
      danger: `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />`
    };

    this.urgencyIconTarget.innerHTML = icons[urgency] || icons.info;
  }

  /**
   * Dismiss the banner until the next threshold
   */
  dismiss() {
    const currentThreshold = this.getCurrentThreshold();

    if (currentThreshold !== null) {
      this.saveDismissedThreshold(currentThreshold);
      this.dismissedThreshold = currentThreshold;
    }

    this.hideBanner();
  }

  /**
   * Load dismissed threshold from localStorage
   * @returns {number|null}
   */
  loadDismissedThreshold() {
    try {
      const stored = localStorage.getItem('session_expiry_dismissed_threshold');
      const sessionId = localStorage.getItem('session_expiry_session_id');

      // Check if it's for the current session
      if (sessionId !== this.expiresAtValue) {
        // Different session, clear old data
        localStorage.removeItem('session_expiry_dismissed_threshold');
        localStorage.removeItem('session_expiry_session_id');

        return null;
      }

      return stored ? parseInt(stored) : null;
    } catch {
      return null;
    }
  }

  /**
   * Save dismissed threshold to localStorage
   * @param {number} threshold
   */
  saveDismissedThreshold(threshold) {
    try {
      localStorage.setItem(
        'session_expiry_dismissed_threshold',
        threshold.toString()
      );
      localStorage.setItem('session_expiry_session_id', this.expiresAtValue);
    } catch (error) {
      console.warn('Could not save dismissed threshold to localStorage', error);
    }
  }

  /**
   * Export form data as JSON backup
   */
  async exportData() {
    try {
      // Gather form data from localStorage/IndexedDB
      const offlineData = await this.gatherOfflineData();

      if (!offlineData || Object.keys(offlineData).length === 0) {
        this.showToast('No form data to export', 'warning');

        return;
      }

      // Create and download JSON file
      const blob = new Blob([JSON.stringify(offlineData, null, 2)], {
        type: 'application/json'
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');

      a.href = url;
      a.download = `ca-small-claims-backup-${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      this.showToast('Data exported successfully', 'success');
    } catch (error) {
      console.error('Export failed:', error);
      this.showToast('Failed to export data', 'error');
    }
  }

  /**
   * Gather all offline stored form data
   * @returns {Promise<Object>}
   */
  async gatherOfflineData() {
    const data = {
      exportedAt: new Date().toISOString(),
      sessionExpiresAt: this.expiresAtValue,
      forms: {}
    };

    // Try to get data from localStorage
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);

      if (key && key.startsWith('offline_data_')) {
        try {
          const formData = JSON.parse(localStorage.getItem(key));

          data.forms[key.replace('offline_data_', '')] = formData;
        } catch {
          // Skip invalid JSON entries
        }
      }

      // Also get last_form_activity for context
      if (key === 'last_form_activity') {
        try {
          data.lastActivity = JSON.parse(localStorage.getItem(key));
        } catch {
          // Skip if invalid JSON
        }
      }
    }

    return data;
  }

  /**
   * Show a toast notification
   * @param {string} message
   * @param {string} type 'success', 'warning', 'error'
   */
  showToast(message, type) {
    // Use the existing toast system if available
    const toastContainer = document.getElementById('toast-container');

    if (!toastContainer) {
      return;
    }

    const alertClass =
      {
        success: 'alert-success',
        warning: 'alert-warning',
        error: 'alert-error'
      }[type] || 'alert-info';

    const toast = document.createElement('div');

    toast.className = `alert ${alertClass} shadow-lg animate-fade-in`;
    toast.innerHTML = `<span>${message}</span>`;

    toastContainer.appendChild(toast);

    setTimeout(() => {
      toast.classList.add('animate-fade-out');
      setTimeout(() => toast.remove(), 300);
    }, 3000);
  }
}
