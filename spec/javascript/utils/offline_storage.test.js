/**
 * @jest-environment jsdom
 */

import { OfflineStorage, SYNC_STATUS, getOfflineStorage } from '../../../app/javascript/utils/offline_storage';

// Mock IndexedDB
const mockIndexedDB = {
  open: jest.fn()
};

describe('OfflineStorage', () => {
  let storage;

  beforeEach(() => {
    // Clear localStorage before each test
    localStorage.clear();

    // Reset singleton
    storage = new OfflineStorage();
    // Force localStorage fallback for easier testing
    storage.useIndexedDB = false;
  });

  describe('save', () => {
    it('saves form data to localStorage', async () => {
      const pathname = '/forms/SC-100';
      const formData = { 'submission[name]': 'John Doe' };

      const result = await storage.save(pathname, formData);

      expect(result).toBe(true);
      const saved = JSON.parse(localStorage.getItem(`offline_data_${pathname}`));
      expect(saved.formData).toEqual(formData);
      expect(saved.status).toBe(SYNC_STATUS.PENDING);
    });

    it('saves with custom status', async () => {
      const pathname = '/forms/SC-100';
      const formData = { 'submission[name]': 'John Doe' };

      await storage.save(pathname, formData, SYNC_STATUS.SYNCED);

      const saved = JSON.parse(localStorage.getItem(`offline_data_${pathname}`));
      expect(saved.status).toBe(SYNC_STATUS.SYNCED);
    });

    it('updates existing record preserving createdAt', async () => {
      const pathname = '/forms/SC-100';

      await storage.save(pathname, { field1: 'value1' });
      const first = JSON.parse(localStorage.getItem(`offline_data_${pathname}`));

      await storage.save(pathname, { field1: 'value2' });
      const second = JSON.parse(localStorage.getItem(`offline_data_${pathname}`));

      expect(second.formData.field1).toBe('value2');
      expect(second.createdAt).toBe(first.createdAt);
      expect(second.updatedAt).toBeGreaterThanOrEqual(first.updatedAt);
    });
  });

  describe('load', () => {
    it('loads saved form data', async () => {
      const pathname = '/forms/SC-100';
      const formData = { 'submission[name]': 'John Doe' };

      await storage.save(pathname, formData);
      const loaded = await storage.load(pathname);

      expect(loaded.formData).toEqual(formData);
      expect(loaded.pathname).toBe(pathname);
    });

    it('returns null for non-existent pathname', async () => {
      const loaded = await storage.load('/forms/NONEXISTENT');
      expect(loaded).toBeNull();
    });

    it('handles legacy format (backward compatibility)', async () => {
      const pathname = '/forms/SC-100';
      const legacyData = {
        data: { 'submission[name]': 'Legacy User' },
        timestamp: Date.now()
      };
      localStorage.setItem(`offline_data_${pathname}`, JSON.stringify(legacyData));

      const loaded = await storage.load(pathname);

      expect(loaded.formData).toEqual(legacyData.data);
      expect(loaded.status).toBe(SYNC_STATUS.PENDING);
    });
  });

  describe('delete', () => {
    it('removes saved form data', async () => {
      const pathname = '/forms/SC-100';
      await storage.save(pathname, { field: 'value' });

      const deleted = await storage.delete(pathname);
      const loaded = await storage.load(pathname);

      expect(deleted).toBe(true);
      expect(loaded).toBeNull();
    });
  });

  describe('getPendingSubmissions', () => {
    it('returns all pending submissions', async () => {
      await storage.save('/forms/SC-100', { f1: 'v1' }, SYNC_STATUS.PENDING);
      await storage.save('/forms/SC-101', { f2: 'v2' }, SYNC_STATUS.PENDING);
      await storage.save('/forms/SC-102', { f3: 'v3' }, SYNC_STATUS.SYNCED);

      const pending = await storage.getPendingSubmissions();

      expect(pending.length).toBe(2);
      expect(pending.some(p => p.pathname === '/forms/SC-100')).toBe(true);
      expect(pending.some(p => p.pathname === '/forms/SC-101')).toBe(true);
    });

    it('returns empty array when no pending submissions', async () => {
      await storage.save('/forms/SC-100', { f1: 'v1' }, SYNC_STATUS.SYNCED);

      const pending = await storage.getPendingSubmissions();

      expect(pending.length).toBe(0);
    });
  });

  describe('getPendingCount', () => {
    it('returns count of pending submissions', async () => {
      await storage.save('/forms/SC-100', {}, SYNC_STATUS.PENDING);
      await storage.save('/forms/SC-101', {}, SYNC_STATUS.PENDING);

      const count = await storage.getPendingCount();

      expect(count).toBe(2);
    });
  });

  describe('hasPendingSubmissions', () => {
    it('returns true when pending submissions exist', async () => {
      await storage.save('/forms/SC-100', {}, SYNC_STATUS.PENDING);

      const hasPending = await storage.hasPendingSubmissions();

      expect(hasPending).toBe(true);
    });

    it('returns false when no pending submissions', async () => {
      const hasPending = await storage.hasPendingSubmissions();

      expect(hasPending).toBe(false);
    });
  });

  describe('updateStatus', () => {
    it('updates sync status of a record', async () => {
      const pathname = '/forms/SC-100';
      await storage.save(pathname, { field: 'value' }, SYNC_STATUS.PENDING);

      await storage.updateStatus(pathname, SYNC_STATUS.SYNCING);

      const loaded = await storage.load(pathname);
      expect(loaded.status).toBe(SYNC_STATUS.SYNCING);
    });

    it('increments sync attempts when requested', async () => {
      const pathname = '/forms/SC-100';
      await storage.save(pathname, { field: 'value' });

      await storage.updateStatus(pathname, SYNC_STATUS.ERROR, true);
      await storage.updateStatus(pathname, SYNC_STATUS.ERROR, true);

      const loaded = await storage.load(pathname);
      expect(loaded.syncAttempts).toBe(2);
    });

    it('returns false for non-existent pathname', async () => {
      const result = await storage.updateStatus('/forms/NONEXISTENT', SYNC_STATUS.SYNCED);

      expect(result).toBe(false);
    });
  });

  describe('clearSynced', () => {
    it('removes only synced submissions', async () => {
      await storage.save('/forms/SC-100', {}, SYNC_STATUS.PENDING);
      await storage.save('/forms/SC-101', {}, SYNC_STATUS.SYNCED);
      await storage.save('/forms/SC-102', {}, SYNC_STATUS.SYNCED);

      await storage.clearSynced();

      const pending = await storage.load('/forms/SC-100');
      const synced1 = await storage.load('/forms/SC-101');
      const synced2 = await storage.load('/forms/SC-102');

      expect(pending).not.toBeNull();
      expect(synced1).toBeNull();
      expect(synced2).toBeNull();
    });
  });

  describe('getOfflineStorage singleton', () => {
    it('returns the same instance', () => {
      const instance1 = getOfflineStorage();
      const instance2 = getOfflineStorage();

      expect(instance1).toBe(instance2);
    });
  });
});

describe('SYNC_STATUS', () => {
  it('defines all expected statuses', () => {
    expect(SYNC_STATUS.PENDING).toBe('pending');
    expect(SYNC_STATUS.SYNCING).toBe('syncing');
    expect(SYNC_STATUS.SYNCED).toBe('synced');
    expect(SYNC_STATUS.CONFLICT).toBe('conflict');
    expect(SYNC_STATUS.ERROR).toBe('error');
  });
});
