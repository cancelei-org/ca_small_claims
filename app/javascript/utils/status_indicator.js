/**
 * Status Indicator Utility
 * Provides consistent UX feedback across the application
 *
 * Usage:
 *   import { StatusIndicator } from 'utils/status_indicator'
 *
 *   // In a Stimulus controller:
 *   this.status = new StatusIndicator(this.statusTarget)
 *   this.status.saving()
 *   this.status.saved()
 *   this.status.error('Custom message')
 */

// Standard status types
export const STATUS_TYPES = {
  IDLE: 'idle',
  SAVING: 'saving',
  SAVED: 'saved',
  LOADING: 'loading',
  UPDATING: 'updating',
  QUEUED: 'queued',
  ERROR: 'error',
  SUCCESS: 'success',
  INFO: 'info',
  WARNING: 'warning',
  // Cloud sync states
  SYNCING: 'syncing',
  SYNCED: 'synced',
  OFFLINE: 'offline',
  PENDING_SYNC: 'pending_sync'
};

// SVG icons for status indicators
const ICONS = {
  spinner: `<svg class="inline w-4 h-4 mr-1 animate-spin" fill="none" viewBox="0 0 24 24">
    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
  </svg>`,
  check: `<svg class="inline w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
  </svg>`,
  error: `<svg class="inline w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
  </svg>`,
  retry: `<svg class="inline w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
  </svg>`,
  x: `<svg class="inline w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
  </svg>`,
  cloud: `<svg class="inline w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z"></path>
  </svg>`,
  cloudUpload: `<svg class="inline w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
  </svg>`,
  offline: `<svg class="inline w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3"></path>
  </svg>`
};

/**
 * Format a timestamp for display
 * @param {Date|number} timestamp - Date object or timestamp
 * @returns {string} Formatted time string
 */
function formatTimestamp(timestamp) {
  const date = timestamp instanceof Date ? timestamp : new Date(timestamp);
  const now = new Date();
  const diffMs = now - date;
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);

  if (diffSec < 5) {
    return 'just now';
  }

  if (diffSec < 60) {
    return `${diffSec}s ago`;
  }

  if (diffMin < 60) {
    return `${diffMin}m ago`;
  }

  // Show actual time for older saves
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// Status configurations
const STATUS_CONFIG = {
  [STATUS_TYPES.IDLE]: {
    message: '',
    icon: null,
    textClass: 'text-base-content/50',
    badgeClass: 'badge-ghost'
  },
  [STATUS_TYPES.SAVING]: {
    message: 'Saving...',
    icon: ICONS.spinner,
    textClass: 'text-base-content/50',
    badgeClass: 'badge-info'
  },
  [STATUS_TYPES.SAVED]: {
    message: 'Saved',
    icon: ICONS.check,
    textClass: 'text-success',
    badgeClass: 'badge-success'
  },
  [STATUS_TYPES.LOADING]: {
    message: 'Loading...',
    icon: ICONS.spinner,
    textClass: 'text-base-content/50',
    badgeClass: 'badge-info'
  },
  [STATUS_TYPES.UPDATING]: {
    message: 'Updating...',
    icon: ICONS.spinner,
    textClass: 'text-base-content/50',
    badgeClass: 'badge-info'
  },
  [STATUS_TYPES.QUEUED]: {
    message: 'Update queued',
    icon: null,
    textClass: 'text-warning',
    badgeClass: 'badge-warning'
  },
  [STATUS_TYPES.ERROR]: {
    message: 'Error',
    icon: ICONS.error,
    textClass: 'text-error',
    badgeClass: 'badge-error'
  },
  [STATUS_TYPES.SUCCESS]: {
    message: 'Success',
    icon: ICONS.check,
    textClass: 'text-success',
    badgeClass: 'badge-success'
  },
  [STATUS_TYPES.INFO]: {
    message: '',
    icon: null,
    textClass: 'text-info',
    badgeClass: 'badge-info'
  },
  [STATUS_TYPES.WARNING]: {
    message: '',
    icon: null,
    textClass: 'text-warning',
    badgeClass: 'badge-warning'
  },
  // Cloud sync states
  [STATUS_TYPES.SYNCING]: {
    message: 'Syncing to cloud...',
    icon: ICONS.spinner,
    textClass: 'text-info',
    badgeClass: 'badge-info'
  },
  [STATUS_TYPES.SYNCED]: {
    message: 'Synced to cloud',
    icon: ICONS.cloud,
    textClass: 'text-success',
    badgeClass: 'badge-success'
  },
  [STATUS_TYPES.OFFLINE]: {
    message: 'Offline',
    icon: ICONS.offline,
    textClass: 'text-warning',
    badgeClass: 'badge-warning'
  },
  [STATUS_TYPES.PENDING_SYNC]: {
    message: 'Saved locally',
    icon: ICONS.cloudUpload,
    textClass: 'text-warning',
    badgeClass: 'badge-warning'
  }
};

export class StatusIndicator {
  /**
   * @param {HTMLElement|HTMLElement[]} elements - Target element(s) to update
   * @param {Object} options - Configuration options
   * @param {string} options.format - 'inline' (default), 'badge', or 'text-only'
   * @param {number} options.autoHideDelay - Auto-hide success status after ms (0 = never)
   * @param {Function} options.onRetry - Callback function for retry button
   */
  constructor(elements, options = {}) {
    this.elements = Array.isArray(elements) ? elements : [elements];
    this.format = options.format || 'inline';
    this.autoHideDelay = options.autoHideDelay || 0;
    this.onRetry = options.onRetry || null;
    this.hideTimeout = null;
    this.lastSavedAt = null;
  }

  /**
   * Update status
   * @param {string} status - Status type from STATUS_TYPES
   * @param {string} customMessage - Optional custom message
   */
  update(status, customMessage = null) {
    const config = STATUS_CONFIG[status] || STATUS_CONFIG[STATUS_TYPES.IDLE];
    const message = customMessage || config.message;
    const isError = status === STATUS_TYPES.ERROR;

    // Clear any pending auto-hide
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }

    // Track save timestamp
    if (status === STATUS_TYPES.SAVED) {
      this.lastSavedAt = new Date();
    }

    this.elements.forEach(el => {
      if (!el) {
        return;
      }

      // Add aria-live for screen reader announcements
      el.setAttribute('aria-live', 'polite');
      el.setAttribute('aria-atomic', 'true');

      el.innerHTML = this._render(config, message, isError);

      // Bind retry button if present
      if (isError && this.onRetry) {
        const retryBtn = el.querySelector('[data-retry-button]');

        if (retryBtn) {
          retryBtn.addEventListener('click', () => this.onRetry());
        }
      }
    });

    // Auto-hide for success states
    if (
      this.autoHideDelay > 0 &&
      (status === STATUS_TYPES.SAVED || status === STATUS_TYPES.SUCCESS)
    ) {
      this.hideTimeout = setTimeout(() => this.clear(), this.autoHideDelay);
    }
  }

  _render(config, message, showRetry = false) {
    if (!message) {
      return '';
    }

    const retryButton =
      showRetry && this.onRetry
        ? `<button type="button" data-retry-button class="ml-2 text-xs underline hover:no-underline focus:outline-none focus:ring-1 focus:ring-current rounded">${ICONS.retry}Retry</button>`
        : '';

    switch (this.format) {
      case 'badge':
        return `<div class="badge ${config.badgeClass} gap-1">${config.icon || ''} ${message}${retryButton}</div>`;

      case 'text-only':
        return `<span class="${config.textClass}">${message}${retryButton}</span>`;

      case 'inline':
      default:
        return `<span class="${config.textClass}">${config.icon || ''}${message}${retryButton}</span>`;
    }
  }

  // Convenience methods
  clear() {
    this.update(STATUS_TYPES.IDLE);
  }

  saving(msg) {
    this.update(STATUS_TYPES.SAVING, msg);
  }

  saved(msg) {
    const timestamp = new Date();

    this.lastSavedAt = timestamp;
    this.update(
      STATUS_TYPES.SAVED,
      msg || `Saved ${formatTimestamp(timestamp)}`
    );
  }

  /**
   * Get formatted timestamp of last save
   * @returns {string|null} Formatted timestamp or null if never saved
   */
  getLastSavedDisplay() {
    if (!this.lastSavedAt) {
      return null;
    }

    return formatTimestamp(this.lastSavedAt);
  }

  loading(msg) {
    this.update(STATUS_TYPES.LOADING, msg);
  }

  updating(msg) {
    this.update(STATUS_TYPES.UPDATING, msg);
  }

  queued(msg) {
    this.update(STATUS_TYPES.QUEUED, msg);
  }

  error(msg) {
    this.update(STATUS_TYPES.ERROR, msg || 'Error');
  }

  success(msg) {
    this.update(STATUS_TYPES.SUCCESS, msg);
  }

  info(msg) {
    this.update(STATUS_TYPES.INFO, msg);
  }

  warning(msg) {
    this.update(STATUS_TYPES.WARNING, msg);
  }

  // Cloud sync convenience methods
  syncing(msg) {
    this.update(STATUS_TYPES.SYNCING, msg);
  }

  synced(msg) {
    const timestamp = new Date();

    this.lastSavedAt = timestamp;
    this.update(
      STATUS_TYPES.SYNCED,
      msg || `Synced to cloud ${formatTimestamp(timestamp)}`
    );
  }

  offline(msg) {
    this.update(STATUS_TYPES.OFFLINE, msg);
  }

  pendingSync(msg) {
    this.update(STATUS_TYPES.PENDING_SYNC, msg);
  }
}

/**
 * Simple function for one-off status updates
 * @param {HTMLElement|HTMLElement[]} elements - Target element(s)
 * @param {string} status - Status type
 * @param {Object} options - Same as StatusIndicator options
 */
export function updateStatus(elements, status, options = {}) {
  const indicator = new StatusIndicator(elements, options);

  indicator.update(status, options.message);

  return indicator;
}
