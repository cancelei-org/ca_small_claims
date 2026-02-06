/* eslint-disable max-classes-per-file */
/**
 * Offline Storage Utility
 * Provides IndexedDB storage with localStorage fallback for form data
 * Refactored using Strategy pattern for cleaner storage backend abstraction
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

/**
 * Abstract Storage Strategy base class
 * Defines the interface for storage backends
 */
class StorageStrategy {
  async save(_record) {
    throw new Error('save() must be implemented');
  }

  async load(_pathname) {
    throw new Error('load() must be implemented');
  }

  async delete(_pathname) {
    throw new Error('delete() must be implemented');
  }

  async getByStatus(_status) {
    throw new Error('getByStatus() must be implemented');
  }

  async deleteByStatus(_status) {
    throw new Error('deleteByStatus() must be implemented');
  }
}

/**
 * IndexedDB Storage Strategy
 */
class IndexedDBStrategy extends StorageStrategy {
  constructor(db) {
    super();
    this.db = db;
  }

  async save(record) {
    return new Promise((resolve, reject) => {
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
    });
  }

  async load(pathname) {
    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([STORE_NAME], 'readonly');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.get(pathname);

      request.onsuccess = () => resolve(request.result || null);
      request.onerror = () => reject(request.error);
    });
  }

  async delete(pathname) {
    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.delete(pathname);

      request.onsuccess = () => resolve(true);
      request.onerror = () => reject(request.error);
    });
  }

  async getByStatus(status) {
    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([STORE_NAME], 'readonly');
      const store = transaction.objectStore(STORE_NAME);
      const index = store.index('status');
      const request = index.getAll(status);

      request.onsuccess = () => resolve(request.result || []);
      request.onerror = () => reject(request.error);
    });
  }

  async deleteByStatus(status) {
    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const index = store.index('status');
      const request = index.openCursor(status);

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
    });
  }
}

/**
 * LocalStorage Storage Strategy (fallback)
 */
class LocalStorageStrategy extends StorageStrategy {
  _getKey(pathname) {
    return `offline_data_${pathname}`;
  }

  async save(record) {
    try {
      const key = this._getKey(record.pathname);

      // Preserve createdAt from existing record
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

  async load(pathname) {
    try {
      const key = this._getKey(pathname);
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

  async delete(pathname) {
    try {
      localStorage.removeItem(this._getKey(pathname));

      return true;
    } catch (error) {
      console.error('localStorage delete failed:', error);

      return false;
    }
  }

  async getByStatus(status) {
    const results = [];

    try {
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);

        if (key && key.startsWith('offline_data_')) {
          const data = localStorage.getItem(key);

          if (data) {
            const record = JSON.parse(data);

            if (
              record.status === status ||
              (!record.status && status === SYNC_STATUS.PENDING)
            ) {
              results.push(record);
            }
          }
        }
      }
    } catch (error) {
      console.error('localStorage getByStatus failed:', error);
    }

    return results;
  }

  async deleteByStatus(status) {
    try {
      const keysToRemove = [];

      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);

        if (key && key.startsWith('offline_data_')) {
          const data = localStorage.getItem(key);

          if (data) {
            const record = JSON.parse(data);

            if (record.status === status) {
              keysToRemove.push(key);
            }
          }
        }
      }

      keysToRemove.forEach(key => localStorage.removeItem(key));

      return true;
    } catch (error) {
      console.error('localStorage deleteByStatus failed:', error);

      return false;
    }
  }
}

/**
 * Main OfflineStorage class
 * Uses Strategy pattern to delegate to appropriate storage backend
 */
export class OfflineStorage {
  constructor() {
    this.strategy = null;
    this.fallbackStrategy = new LocalStorageStrategy();
    this.dbReady = this._initDB();
  }

  /**
   * Initialize IndexedDB connection
   * Falls back to localStorage if IndexedDB is unavailable
   */
  async _initDB() {
    if (!window.indexedDB) {
      console.warn('IndexedDB not available, using localStorage fallback');
      this.strategy = this.fallbackStrategy;

      return undefined;
    }

    await new Promise(resolve => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => {
        console.warn('IndexedDB failed, using localStorage fallback');
        this.strategy = this.fallbackStrategy;
        resolve();
      };

      request.onsuccess = event => {
        const db = event.target.result;

        this.strategy = new IndexedDBStrategy(db);
        resolve();
      };

      request.onupgradeneeded = event => {
        const db = event.target.result;

        if (!db.objectStoreNames.contains(STORE_NAME)) {
          const store = db.createObjectStore(STORE_NAME, {
            keyPath: 'pathname'
          });

          store.createIndex('status', 'status', { unique: false });
          store.createIndex('updatedAt', 'updatedAt', { unique: false });
        }
      };
    });

    return undefined;
  }

  /**
   * Execute a storage operation with automatic fallback
   */
  async _execute(operation) {
    await this.dbReady;

    try {
      return await operation(this.strategy);
    } catch (error) {
      console.error('Storage operation failed, trying fallback:', error);
      // Fallback to localStorage if IndexedDB fails
      if (this.strategy !== this.fallbackStrategy) {
        return await operation(this.fallbackStrategy);
      }
      throw error;
    }
  }

  /**
   * Save form data to offline storage
   * @param {string} pathname - The form URL pathname (e.g., '/forms/SC-100')
   * @param {Object} formData - Form field data
   * @param {string} status - Sync status (default: PENDING)
   * @returns {Promise<boolean>} Success status
   */
  async save(pathname, formData, status = SYNC_STATUS.PENDING) {
    const record = {
      pathname,
      formData,
      status,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      syncAttempts: 0
    };

    return this._execute(strategy => strategy.save(record));
  }

  /**
   * Load form data from offline storage
   * @param {string} pathname - The form URL pathname
   * @returns {Promise<Object|null>} Stored record or null
   */
  async load(pathname) {
    return this._execute(strategy => strategy.load(pathname));
  }

  /**
   * Delete form data from offline storage
   * @param {string} pathname - The form URL pathname
   * @returns {Promise<boolean>} Success status
   */
  async delete(pathname) {
    return this._execute(strategy => strategy.delete(pathname));
  }

  /**
   * Get all pending submissions (not yet synced)
   * @returns {Promise<Array>} Array of pending records
   */
  async getPendingSubmissions() {
    return this._execute(strategy => strategy.getByStatus(SYNC_STATUS.PENDING));
  }

  /**
   * Update sync status for a record
   * @param {string} pathname - The form URL pathname
   * @param {string} status - New sync status
   * @param {boolean} incrementAttempts - Whether to increment sync attempts
   * @returns {Promise<boolean>} Success status
   */
  async updateStatus(pathname, status, incrementAttempts = false) {
    const record = await this.load(pathname);

    if (!record) {
      return false;
    }

    record.status = status;
    record.updatedAt = Date.now();
    if (incrementAttempts) {
      record.syncAttempts = (record.syncAttempts || 0) + 1;
    }

    return this._execute(strategy => strategy.save(record));
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
    return this._execute(strategy =>
      strategy.deleteByStatus(SYNC_STATUS.SYNCED)
    );
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
