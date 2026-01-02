import { Controller } from '@hotwired/stimulus';
import { getOfflineStorage } from 'utils/offline_storage';

/**
 * Offline Indicator Controller
 * Displays connection status and pending sync count
 *
 * Usage:
 *   <div data-controller="offline-indicator">
 *     <span data-offline-indicator-target="status"></span>
 *     <span data-offline-indicator-target="badge" class="hidden"></span>
 *   </div>
 */
export default class extends Controller {
  static targets = ['status', 'badge', 'icon'];

  static values = {
    showWhenOnline: { type: Boolean, default: false }
  };

  connect() {
    this.isOffline = !navigator.onLine;
    this.isSyncing = false;
    this.pendingCount = 0;
    this.offlineStorage = getOfflineStorage();

    // Listen to online/offline events
    this.boundHandleOnline = this.handleOnline.bind(this);
    this.boundHandleOffline = this.handleOffline.bind(this);
    window.addEventListener('online', this.boundHandleOnline);
    window.addEventListener('offline', this.boundHandleOffline);

    // Listen to custom sync events
    this.boundHandleStatusChange = this.handleStatusChange.bind(this);
    this.boundHandleSyncStatus = this.handleSyncStatus.bind(this);
    document.addEventListener(
      'offline:status-change',
      this.boundHandleStatusChange
    );
    document.addEventListener(
      'offline:sync-status',
      this.boundHandleSyncStatus
    );

    // Initial render
    this.checkPendingCount();
    this.render();
  }

  disconnect() {
    window.removeEventListener('online', this.boundHandleOnline);
    window.removeEventListener('offline', this.boundHandleOffline);
    document.removeEventListener(
      'offline:status-change',
      this.boundHandleStatusChange
    );
    document.removeEventListener(
      'offline:sync-status',
      this.boundHandleSyncStatus
    );
  }

  handleOnline() {
    this.isOffline = false;
    this.render();
  }

  handleOffline() {
    this.isOffline = true;
    this.render();
  }

  handleStatusChange(event) {
    const { isOffline, isSyncing } = event.detail;

    this.isOffline = isOffline;
    this.isSyncing = isSyncing;
    this.render();
  }

  handleSyncStatus(event) {
    const { pendingCount, isSyncing } = event.detail;

    this.pendingCount = pendingCount;
    this.isSyncing = isSyncing;
    this.render();
  }

  async checkPendingCount() {
    this.pendingCount = await this.offlineStorage.getPendingCount();
    this.render();
  }

  render() {
    // Determine current state
    const state = this.getCurrentState();

    // Update status text
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = state.text;
      this.statusTarget.className = `text-sm ${state.textClass}`;
    }

    // Update badge (pending count)
    if (this.hasBadgeTarget) {
      if (this.pendingCount > 0 && !this.isSyncing) {
        this.badgeTarget.textContent = this.pendingCount;
        this.badgeTarget.classList.remove('hidden');
        this.badgeTarget.className = 'badge badge-warning badge-sm';
      } else {
        this.badgeTarget.classList.add('hidden');
      }
    }

    // Update icon
    if (this.hasIconTarget) {
      this.iconTarget.innerHTML = state.icon;
      this.iconTarget.className = state.iconClass;
    }

    // Show/hide entire element based on state
    if (
      !this.showWhenOnlineValue &&
      !this.isOffline &&
      !this.isSyncing &&
      this.pendingCount === 0
    ) {
      this.element.classList.add('hidden');
    } else {
      this.element.classList.remove('hidden');
    }
  }

  getCurrentState() {
    if (this.isSyncing) {
      return {
        text: 'Syncing...',
        textClass: 'text-info',
        icon: this.spinnerIcon(),
        iconClass: 'text-info animate-spin'
      };
    }

    if (this.isOffline) {
      return {
        text: 'Offline',
        textClass: 'text-warning',
        icon: this.offlineIcon(),
        iconClass: 'text-warning'
      };
    }

    if (this.pendingCount > 0) {
      return {
        text: `${this.pendingCount} pending`,
        textClass: 'text-warning',
        icon: this.pendingIcon(),
        iconClass: 'text-warning'
      };
    }

    return {
      text: 'Connected',
      textClass: 'text-success',
      icon: this.cloudIcon(),
      iconClass: 'text-success'
    };
  }

  // Icon SVGs
  cloudIcon() {
    return `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z"></path>
    </svg>`;
  }

  offlineIcon() {
    return `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3"></path>
    </svg>`;
  }

  pendingIcon() {
    return `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
    </svg>`;
  }

  spinnerIcon() {
    return `<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>`;
  }
}
