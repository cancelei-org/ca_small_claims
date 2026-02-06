import { Controller } from '@hotwired/stimulus';
import { csrfToken } from 'utilities/csrf';
import { createDebouncedHandler } from 'utilities/debounce';
import { SYNC_STATUS, getOfflineStorage } from 'utils/offline_storage';
import { StatusIndicator } from 'utils/status_indicator';

// Handles form auto-save functionality with optimized debounce and offline support
export default class extends Controller {
  static targets = ['status', 'form', 'syncIndicator'];
  static values = {
    saveUrl: String,
    debounceDelay: { type: Number, default: 300 }
  };

  connect() {
    this.trackActivity();

    this.pendingChanges = false;
    this.isOffline = !navigator.onLine;
    this.isSyncing = false;
    this.offlineStorage = getOfflineStorage();
    this.debouncedSave = createDebouncedHandler(() => this.save());

    // Initialize status indicator if target exists with retry callback
    if (this.hasStatusTarget) {
      this.status = new StatusIndicator(this.statusTargets, {
        onRetry: () => this.retrySave()
      });
    }

    // Handle online/offline events with consolidated handler
    this.boundHandleConnectionChange = event =>
      this.handleConnectionChange(event.type === 'online');
    window.addEventListener('online', this.boundHandleConnectionChange);
    window.addEventListener('offline', this.boundHandleConnectionChange);

    // Listen for sync status updates
    this.boundUpdateSyncIndicator = this.updateSyncIndicator.bind(this);
    document.addEventListener(
      'offline:sync-status',
      this.boundUpdateSyncIndicator
    );

    // Update initial offline indicator state
    this.updateOfflineIndicator();

    // Sync any pending offline data on connect
    if (navigator.onLine) {
      this.syncOfflineData();
    }
  }

  disconnect() {
    this.debouncedSave.cancel();
    window.removeEventListener('online', this.boundHandleConnectionChange);
    window.removeEventListener('offline', this.boundHandleConnectionChange);
    document.removeEventListener(
      'offline:sync-status',
      this.boundUpdateSyncIndicator
    );
  }

  /**
   * Consolidated handler for online/offline state changes
   * @param {boolean} isOnline - Whether the browser is now online
   */
  handleConnectionChange(isOnline) {
    this.isOffline = !isOnline;
    this.updateOfflineIndicator();

    if (isOnline) {
      this.status?.info('Back online. Syncing...');
      this.syncOfflineData();
    } else {
      this.status?.warning('Offline. Saving locally.');
    }
  }

  updateOfflineIndicator() {
    // Dispatch event for offline indicator controller
    document.dispatchEvent(
      new CustomEvent('offline:status-change', {
        detail: { isOffline: this.isOffline, isSyncing: this.isSyncing }
      })
    );
  }

  updateSyncIndicator(event) {
    const { pendingCount, isSyncing } = event.detail;

    this.isSyncing = isSyncing;

    if (this.hasSyncIndicatorTarget) {
      if (pendingCount > 0) {
        this.syncIndicatorTarget.textContent = `${pendingCount} pending`;
        this.syncIndicatorTarget.classList.remove('hidden');
      } else {
        this.syncIndicatorTarget.classList.add('hidden');
      }
    }
  }

  trackActivity() {
    const match = window.location.pathname.match(/\/forms\/([A-Z0-9-]+)/iu);

    if (match) {
      const [, code] = match;
      const activity = {
        code,
        path: window.location.pathname,
        timestamp: Date.now()
      };

      localStorage.setItem('last_form_activity', JSON.stringify(activity));
    }
  }

  retrySave() {
    this.pendingChanges = true;
    this.save();
  }

  fieldChanged(_event) {
    this.pendingChanges = true;

    if (this.isOffline) {
      this.saveLocally();
    } else {
      this.status?.saving();
      this.debouncedSave.call(this.debounceDelayValue);
    }
  }

  async saveLocally() {
    const form = this.hasFormTarget ? this.formTarget : this.element;
    const formData = new FormData(form);

    // Handle duplicate names (Wizard + Traditional views)
    // We want to prioritize non-empty values
    const data = {};

    for (const [key, value] of formData.entries()) {
      if (value || !data[key]) {
        data[key] = value;
      }
    }

    // Save to IndexedDB/localStorage
    const saved = await this.offlineStorage.save(
      window.location.pathname,
      data,
      SYNC_STATUS.PENDING
    );

    if (saved) {
      this.status?.warning('Saved locally (offline)');
      this.pendingChanges = false;

      // Update sync indicator
      this.notifySyncStatus();
    } else {
      this.status?.error('Failed to save locally');
    }
  }

  async notifySyncStatus() {
    const pendingCount = await this.offlineStorage.getPendingCount();

    document.dispatchEvent(
      new CustomEvent('offline:sync-status', {
        detail: { pendingCount, isSyncing: this.isSyncing }
      })
    );
  }

  async syncOfflineData() {
    const record = await this.offlineStorage.load(window.location.pathname);

    if (record && record.status === SYNC_STATUS.PENDING) {
      this.isSyncing = true;
      this.updateOfflineIndicator();
      this.status?.info('Syncing to cloud...');

      try {
        await this.offlineStorage.updateStatus(
          window.location.pathname,
          SYNC_STATUS.SYNCING
        );

        const success = await this.performSave(record.formData);

        if (success) {
          await this.offlineStorage.delete(window.location.pathname);
          this.status?.saved('Saved and synced to cloud');

          // Dispatch sync complete event
          document.dispatchEvent(
            new CustomEvent('offline:sync-complete', {
              detail: { pathname: window.location.pathname }
            })
          );
        } else {
          await this.offlineStorage.updateStatus(
            window.location.pathname,
            SYNC_STATUS.PENDING,
            true // increment attempts
          );
          this.status?.error('Sync failed. Will retry.');
        }
      } catch (e) {
        console.error('Offline sync failed', e);
        await this.offlineStorage.updateStatus(
          window.location.pathname,
          SYNC_STATUS.ERROR,
          true
        );
        this.status?.error('Sync failed');
      }

      this.isSyncing = false;
      this.updateOfflineIndicator();
      this.notifySyncStatus();
    }
  }

  async save() {
    if (!this.pendingChanges) {
      return;
    }

    const form = this.hasFormTarget ? this.formTarget : this.element;
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());

    const success = await this.performSave(data);

    if (success) {
      this.pendingChanges = false;
      this.status?.saved('Saved to cloud');

      document.dispatchEvent(
        new CustomEvent('form:saved', {
          detail: { formId: form.id, timestamp: Date.now() }
        })
      );
    } else if (this.isOffline) {
      this.saveLocally();
    }
  }

  async performSave(data) {
    const form = this.hasFormTarget ? this.formTarget : this.element;
    const formData = new FormData();

    Object.entries(data).forEach(([key, value]) => formData.append(key, value));

    try {
      const response = await fetch(this.saveUrlValue || form.action, {
        method: 'PATCH',
        body: formData,
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken()
        }
      });

      if (!response.ok) {
        this.status?.error('Save failed');

        return false;
      }

      return true;
    } catch {
      // Check if we went offline during the request
      if (!navigator.onLine) {
        this.isOffline = true;
        this.updateOfflineIndicator();
      }
      this.status?.error('Connection error');

      return false;
    }
  }

  beforeUnload(event) {
    if (this.pendingChanges) {
      event.preventDefault();
      event.returnValue = '';
    }
  }
}
