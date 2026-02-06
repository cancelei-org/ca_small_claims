/**
 * @jest-environment jsdom
 */

import { Application } from '@hotwired/stimulus';
import FormController from 'controllers/form_controller';

// Mock dependencies
jest.mock('utilities/csrf', () => ({
  csrfToken: jest.fn(() => 'test-csrf-token')
}));

jest.mock('utilities/debounce', () => ({
  createDebouncedHandler: jest.fn(fn => ({
    call: jest.fn((delay) => fn()),
    cancel: jest.fn()
  }))
}));

jest.mock('utils/offline_storage', () => ({
  SYNC_STATUS: {
    PENDING: 'pending',
    SYNCING: 'syncing',
    ERROR: 'error',
    SYNCED: 'synced'
  },
  getOfflineStorage: jest.fn(() => ({
    save: jest.fn().mockResolvedValue(true),
    load: jest.fn().mockResolvedValue(null),
    delete: jest.fn().mockResolvedValue(true),
    updateStatus: jest.fn().mockResolvedValue(true),
    getPendingCount: jest.fn().mockResolvedValue(0)
  }))
}));

jest.mock('utils/status_indicator', () => ({
  StatusIndicator: jest.fn().mockImplementation(() => ({
    saving: jest.fn(),
    saved: jest.fn(),
    error: jest.fn(),
    warning: jest.fn(),
    info: jest.fn()
  }))
}));

describe('FormController', () => {
  let application;
  let element;
  let controller;

  beforeEach(() => {
    // Setup DOM
    document.body.innerHTML = `
      <form
        data-controller="form"
        data-form-save-url-value="/forms/SC-100"
        data-form-debounce-delay-value="300"
        id="test-form"
        action="/forms/SC-100"
      >
        <div data-form-target="status"></div>
        <input type="text" name="submission[field1]" value="" />
        <input type="text" name="submission[field2]" value="" />
        <button type="submit">Save</button>
      </form>
    `;

    // Mock navigator.onLine
    Object.defineProperty(navigator, 'onLine', {
      value: true,
      writable: true
    });

    // Mock window.location
    delete window.location;
    window.location = {
      pathname: '/forms/SC-100'
    };

    // Mock localStorage
    const localStorageMock = {
      getItem: jest.fn(),
      setItem: jest.fn(),
      clear: jest.fn()
    };
    Object.defineProperty(window, 'localStorage', {
      value: localStorageMock
    });

    // Mock fetch
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ success: true })
    });

    // Initialize Stimulus
    application = Application.start();
    application.register('form', FormController);

    element = document.querySelector('[data-controller="form"]');
    controller = application.getControllerForElementAndIdentifier(element, 'form');
  });

  afterEach(() => {
    application.stop();
    jest.clearAllMocks();
    document.body.innerHTML = '';
  });

  describe('connect', () => {
    it('initializes pendingChanges to false', () => {
      expect(controller.pendingChanges).toBe(false);
    });

    it('tracks activity on connect', () => {
      expect(window.localStorage.setItem).toHaveBeenCalledWith(
        'last_form_activity',
        expect.any(String)
      );
    });

    it('adds online/offline event listeners', () => {
      const addEventListenerSpy = jest.spyOn(window, 'addEventListener');

      // Reconnect to trigger connect()
      application.stop();
      application = Application.start();
      application.register('form', FormController);

      expect(addEventListenerSpy).toHaveBeenCalledWith('online', expect.any(Function));
      expect(addEventListenerSpy).toHaveBeenCalledWith('offline', expect.any(Function));
    });
  });

  describe('disconnect', () => {
    it('cancels debounced save', () => {
      const cancelSpy = controller.debouncedSave.cancel;

      controller.disconnect();

      expect(cancelSpy).toHaveBeenCalled();
    });
  });

  describe('fieldChanged', () => {
    it('sets pendingChanges to true', () => {
      controller.fieldChanged({ target: { name: 'field1' } });

      expect(controller.pendingChanges).toBe(true);
    });

    it('calls debounced save when online', () => {
      controller.isOffline = false;
      const debouncedCallSpy = controller.debouncedSave.call;

      controller.fieldChanged({ target: { name: 'field1' } });

      expect(debouncedCallSpy).toHaveBeenCalled();
    });

    it('saves locally when offline', async () => {
      controller.isOffline = true;
      const saveLocallySpy = jest.spyOn(controller, 'saveLocally');

      controller.fieldChanged({ target: { name: 'field1' } });

      expect(saveLocallySpy).toHaveBeenCalled();
    });
  });

  describe('handleConnectionChange', () => {
    it('updates isOffline state', () => {
      controller.handleConnectionChange(false);
      expect(controller.isOffline).toBe(true);

      controller.handleConnectionChange(true);
      expect(controller.isOffline).toBe(false);
    });

    it('syncs offline data when coming back online', () => {
      const syncSpy = jest.spyOn(controller, 'syncOfflineData');

      controller.handleConnectionChange(true);

      expect(syncSpy).toHaveBeenCalled();
    });
  });

  describe('trackActivity', () => {
    it('saves form activity to localStorage', () => {
      controller.trackActivity();

      expect(window.localStorage.setItem).toHaveBeenCalledWith(
        'last_form_activity',
        expect.stringContaining('SC-100')
      );
    });
  });

  describe('save', () => {
    it('does nothing when no pending changes', async () => {
      controller.pendingChanges = false;

      await controller.save();

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('performs save when there are pending changes', async () => {
      controller.pendingChanges = true;

      await controller.save();

      expect(global.fetch).toHaveBeenCalledWith(
        '/forms/SC-100',
        expect.objectContaining({
          method: 'PATCH',
          headers: expect.objectContaining({
            'X-CSRF-Token': 'test-csrf-token'
          })
        })
      );
    });

    it('resets pendingChanges on successful save', async () => {
      controller.pendingChanges = true;

      await controller.save();

      expect(controller.pendingChanges).toBe(false);
    });

    it('dispatches form:saved event on success', async () => {
      controller.pendingChanges = true;
      const dispatchSpy = jest.spyOn(document, 'dispatchEvent');

      await controller.save();

      expect(dispatchSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'form:saved'
        })
      );
    });
  });

  describe('performSave', () => {
    it('returns true on successful save', async () => {
      global.fetch.mockResolvedValueOnce({ ok: true });

      const result = await controller.performSave({ field1: 'value1' });

      expect(result).toBe(true);
    });

    it('returns false on failed save', async () => {
      global.fetch.mockResolvedValueOnce({ ok: false });

      const result = await controller.performSave({ field1: 'value1' });

      expect(result).toBe(false);
    });

    it('returns false on network error', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Network error'));

      const result = await controller.performSave({ field1: 'value1' });

      expect(result).toBe(false);
    });
  });

  describe('beforeUnload', () => {
    it('prevents unload when there are pending changes', () => {
      controller.pendingChanges = true;
      const event = { preventDefault: jest.fn(), returnValue: '' };

      controller.beforeUnload(event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(event.returnValue).toBe('');
    });

    it('allows unload when no pending changes', () => {
      controller.pendingChanges = false;
      const event = { preventDefault: jest.fn(), returnValue: '' };

      controller.beforeUnload(event);

      expect(event.preventDefault).not.toHaveBeenCalled();
    });
  });

  describe('retrySave', () => {
    it('sets pendingChanges and calls save', () => {
      const saveSpy = jest.spyOn(controller, 'save');

      controller.retrySave();

      expect(controller.pendingChanges).toBe(true);
      expect(saveSpy).toHaveBeenCalled();
    });
  });
});
