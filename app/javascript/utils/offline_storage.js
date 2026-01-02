/**
 * Offline Storage Utility
 * Provides IndexedDB storage with localStorage fallback for form data
 *
 * Usage:
 *   import { OfflineStorage } from 'utils/offline_storage'
 *
 *   const storage = new OfflineStorage()
 *   await storage.save('/forms/SC-100', formData)
 *   const data = await storage.load('/forms/SC-100')
 *   const pending = await storage.getPendingSubmissions()
 */

const DB_NAME = 'ca_small_claims_offline';
const DB_VERSION = 1;
const STORE_NAME = 'form_submissions';

// Storage status for tracking sync state
export const SYNC_STATUS = {
  PENDING: 'pending', // Saved locally, not synced
  SYNCING: 'syncing', // Currently syncing to server
  SYNCED: 'synced', // Successfully synced
  CONFLICT: 'conflict', // Server has newer data
  ERROR: 'error' // Sync failed
};

export class OfflineStorage {
  constructor() {
    this.db = null;
    this.dbReady = this._initDB();
    this.useIndexedDB = true;
  }

  /**
   * Initialize IndexedDB connection
   * Falls back to localStorage if IndexedDB is unavailable
   */
  async _initDB() {
    if (!window.indexedDB) {
      console.warn('IndexedDB not available, using localStorage fallback');
      this.useIndexedDB = false;

      return;
    }

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => {
        console.warn('IndexedDB failed, using localStorage fallback');
        this.useIndexedDB = false;
        resolve();
      };

      request.onsuccess = event => {
        this.db = event.target.result;
        resolve();
      };

      request.onupgradeneeded = event => {
        const db = event.target.result;

        // Create object store for form submissions
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          const store = db.createObjectStore(STORE_NAME, {
            keyPath: 'pathname'
          });

          store.createIndex('status', 'status', { unique: false });
          store.createIndex('updatedAt', 'updatedAt', { unique: false });
        }
      };
    });
  }

  /**
   * Save form data to offline storage
   * @param {string} pathname - The form URL pathname (e.g., '/forms/SC-100')
   * @param {Object} formData - Form field data
   * @param {string} status - Sync status (default: PENDING)
   * @returns {Promise<boolean>} Success status
   */
  async save(pathname, formData, status = SYNC_STATUS.PENDING) {
    await this.dbReady;

    const record = {
      pathname,
      formData,
      status,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      syncAttempts: 0
    };

    if (this.useIndexedDB && this.db) {
      return this._saveToIndexedDB(record);
    }

    return this._saveToLocalStorage(record);
  }

  async _saveToIndexedDB(record) {
    return new Promise((resolve, reject) => {
      try {
        const transaction = this.db.transaction([STORE_NAME], 'readwrite');
        const store = transaction.objectStore(STORE_NAME);

        // Get existing record to preserve createdAt
        const getRequest = store.get(record.pathname);

        getRequest.onsuccess = () => {
          if (getRequest.result) {
            record.createdAt = getRequest.result.createdAt;
            record.syncAttempts = getRequest.result.syncAttempts || 0;
          }

          const putRequest = store.put(record);

          putRequest.onsuccess = () => resolve(true);
          putRequest.onerror = () => reject(putRequest.error);
        };
        getRequest.onerror = () => reject(getRequest.error);
      } catch (error) {
        console.error('IndexedDB save failed:', error);
        resolve(this._saveToLocalStorage(record));
      }
    });
  }

  _saveToLocalStorage(record) {
    try {
      const key = `offline_data_${record.pathname}`;

      // Preserve createdAt from existing record (like IndexedDB does)
      // Only preserve if not already set in the record being saved
      const existing = localStorage.getItem(key);
      if (existing) {
        const parsed = JSON.parse(existing);
        if (!record.createdAt) {
          record.createdAt = parsed.createdAt;
        }
        if (record.syncAttempts === undefined) {
          record.syncAttempts = parsed.syncAttempts || 0;
        }
      }

      localStorage.setItem(key, JSON.stringify(record));

      return true;
    } catch (error) {
      console.error('localStorage save failed:', error);

      return false;
    }
  }

  /**
   * Load form data from offline storage
   * @param {string} pathname - The form URL pathname
   * @returns {Promise<Object|null>} Stored record or null
   */
  async load(pathname) {
    await this.dbReady;

    if (this.useIndexedDB && this.db) {
      return this._loadFromIndexedDB(pathname);
    }

    return this._loadFromLocalStorage(pathname);
  }

  async _loadFromIndexedDB(pathname) {
    return new Promise((resolve, reject) => {
      try {
        const transaction = this.db.transaction([STORE_NAME], 'readonly');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.get(pathname);

        request.onsuccess = () => resolve(request.result || null);
        request.onerror = () => reject(request.error);
      } catch (error) {
        console.error('IndexedDB load failed:', error);
        resolve(this._loadFromLocalStorage(pathname));
      }
    });
  }

  _loadFromLocalStorage(pathname) {
    try {
      const key = `offline_data_${pathname}`;
      const data = localStorage.getItem(key);

      if (data) {
        const parsed = JSON.parse(data);

        // Handle legacy format (just { data, timestamp })
        if (parsed.data && !parsed.formData) {
          return {
            pathname,
            formData: parsed.data,
            status: SYNC_STATUS.PENDING,
            createdAt: parsed.timestamp,
            updatedAt: parsed.timestamp,
            syncAttempts: 0
          };
        }

        return parsed;
      }

      return null;
    } catch (error) {
      console.error('localStorage load failed:', error);

      return null;
    }
  }

  /**
   * Delete form data from offline storage
   * @param {string} pathname - The form URL pathname
   * @returns {Promise<boolean>} Success status
   */
  async delete(pathname) {
    await this.dbReady;

    if (this.useIndexedDB && this.db) {
      return this._deleteFromIndexedDB(pathname);
    }

    return this._deleteFromLocalStorage(pathname);
  }

  async _deleteFromIndexedDB(pathname) {
    return new Promise((resolve, reject) => {
      try {
        const transaction = this.db.transaction([STORE_NAME], 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.delete(pathname);

        request.onsuccess = () => resolve(true);
        request.onerror = () => reject(request.error);
      } catch (error) {
        console.error('IndexedDB delete failed:', error);
        resolve(this._deleteFromLocalStorage(pathname));
      }
    });
  }

  _deleteFromLocalStorage(pathname) {
    try {
      const key = `offline_data_${pathname}`;

      localStorage.removeItem(key);

      return true;
    } catch (error) {
      console.error('localStorage delete failed:', error);

      return false;
    }
  }

  /**
   * Get all pending submissions (not yet synced)
   * @returns {Promise<Array>} Array of pending records
   */
  async getPendingSubmissions() {
    await this.dbReady;

    if (this.useIndexedDB && this.db) {
      return this._getPendingFromIndexedDB();
    }

    return this._getPendingFromLocalStorage();
  }

  async _getPendingFromIndexedDB() {
    return new Promise((resolve, reject) => {
      try {
        const transaction = this.db.transaction([STORE_NAME], 'readonly');
        const store = transaction.objectStore(STORE_NAME);
        const index = store.index('status');
        const request = index.getAll(SYNC_STATUS.PENDING);

        request.onsuccess = () => resolve(request.result || []);
        request.onerror = () => reject(request.error);
      } catch (error) {
        console.error('IndexedDB getPending failed:', error);
        resolve(this._getPendingFromLocalStorage());
      }
    });
  }

  _getPendingFromLocalStorage() {
    const pending = [];

    try {
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);

        if (key && key.startsWith('offline_data_')) {
          const data = localStorage.getItem(key);

          if (data) {
            const record = JSON.parse(data);

            if (record.status === SYNC_STATUS.PENDING || !record.status) {
              pending.push(record);
            }
          }
        }
      }
    } catch (error) {
      console.error('localStorage getPending failed:', error);
    }

    return pending;
  }

  /**
   * Update sync status for a record
   * @param {string} pathname - The form URL pathname
   * @param {string} status - New sync status
   * @param {boolean} incrementAttempts - Whether to increment sync attempts
   * @returns {Promise<boolean>} Success status
   */
  async updateStatus(pathname, status, incrementAttempts = false) {
    await this.dbReady;

    const record = await this.load(pathname);

    if (!record) {
      return false;
    }

    record.status = status;
    record.updatedAt = Date.now();
    if (incrementAttempts) {
      record.syncAttempts = (record.syncAttempts || 0) + 1;
    }

    // Save the full record directly instead of calling save() which loses syncAttempts
    if (this.useIndexedDB && this.db) {
      return this._saveToIndexedDB(record);
    }

    return this._saveToLocalStorage(record);
  }

  /**
   * Get count of pending submissions
   * @returns {Promise<number>} Number of pending submissions
   */
  async getPendingCount() {
    const pending = await this.getPendingSubmissions();

    return pending.length;
  }

  /**
   * Check if there are any pending submissions
   * @returns {Promise<boolean>} True if pending submissions exist
   */
  async hasPendingSubmissions() {
    const count = await this.getPendingCount();

    return count > 0;
  }

  /**
   * Clear all synced submissions from storage
   * @returns {Promise<boolean>} Success status
   */
  async clearSynced() {
    await this.dbReady;

    if (this.useIndexedDB && this.db) {
      return this._clearSyncedFromIndexedDB();
    }

    return this._clearSyncedFromLocalStorage();
  }

  async _clearSyncedFromIndexedDB() {
    return new Promise((resolve, reject) => {
      try {
        const transaction = this.db.transaction([STORE_NAME], 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const index = store.index('status');
        const request = index.openCursor(SYNC_STATUS.SYNCED);

        request.onsuccess = event => {
          const cursor = event.target.result;

          if (cursor) {
            cursor.delete();
            cursor.continue();
          } else {
            resolve(true);
          }
        };
        request.onerror = () => reject(request.error);
      } catch (error) {
        console.error('IndexedDB clearSynced failed:', error);
        resolve(this._clearSyncedFromLocalStorage());
      }
    });
  }

  _clearSyncedFromLocalStorage() {
    try {
      const keysToRemove = [];

      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);

        if (key && key.startsWith('offline_data_')) {
          const data = localStorage.getItem(key);

          if (data) {
            const record = JSON.parse(data);

            if (record.status === SYNC_STATUS.SYNCED) {
              keysToRemove.push(key);
            }
          }
        }
      }
      keysToRemove.forEach(key => localStorage.removeItem(key));

      return true;
    } catch (error) {
      console.error('localStorage clearSynced failed:', error);

      return false;
    }
  }
}

// Singleton instance for app-wide usage
let storageInstance = null;

export function getOfflineStorage() {
  if (!storageInstance) {
    storageInstance = new OfflineStorage();
  }

  return storageInstance;
}
