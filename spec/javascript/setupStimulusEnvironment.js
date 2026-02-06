/**
 * Setup file for Stimulus controller tests with jsdom
 *
 * This file handles the compatibility issues between:
 * - jsdom's window.location implementation
 * - Node's util.inspect (used by console.error)
 * - Stimulus's error handling
 *
 * The issue: When Stimulus encounters an error during controller connection,
 * it calls console.error. Node's util.inspect then traverses window properties
 * including location, which breaks with jsdom's HTMLBaseElement implementation.
 *
 * Solution: Override console.error during Stimulus operations to prevent
 * the util.inspect from traversing problematic objects.
 */

// Store original console.error
const originalConsoleError = console.error;

// Create a safe console.error that doesn't trigger util.inspect issues
console.error = (...args) => {
  // Convert objects to strings to avoid util.inspect traversal
  const safeArgs = args.map(arg => {
    if (typeof arg === 'object' && arg !== null) {
      try {
        // For Error objects, extract the message and stack
        if (arg instanceof Error) {
          return `${arg.name}: ${arg.message}\n${arg.stack || ''}`;
        }
        // For other objects, try JSON stringify
        return JSON.stringify(arg, null, 2);
      } catch {
        // If that fails, just use toString
        return String(arg);
      }
    }
    return arg;
  });

  originalConsoleError.apply(console, safeArgs);
};

// Ensure localStorage is available and properly mocked
if (typeof window !== 'undefined' && !window.localStorage) {
  const localStorageMock = {
    store: {},
    getItem: jest.fn((key) => localStorageMock.store[key] || null),
    setItem: jest.fn((key, value) => {
      localStorageMock.store[key] = String(value);
    }),
    removeItem: jest.fn((key) => {
      delete localStorageMock.store[key];
    }),
    clear: jest.fn(() => {
      localStorageMock.store = {};
    }),
    get length() {
      return Object.keys(localStorageMock.store).length;
    },
    key: jest.fn((index) => Object.keys(localStorageMock.store)[index] || null)
  };

  Object.defineProperty(window, 'localStorage', {
    value: localStorageMock,
    writable: true
  });
}

// Mock matchMedia - always override to ensure consistent behavior
if (typeof window !== 'undefined') {
  window.matchMedia = jest.fn().mockImplementation((query) => ({
    matches: false,
    media: query,
    onchange: null,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    addListener: jest.fn(), // Deprecated but some code uses it
    removeListener: jest.fn(), // Deprecated but some code uses it
    dispatchEvent: jest.fn()
  }));
}

// Mock navigator.vibrate for haptic feedback - always override
if (typeof navigator !== 'undefined') {
  navigator.vibrate = jest.fn().mockReturnValue(true);
}

// Mock requestAnimationFrame if not available
if (typeof window !== 'undefined' && !window.requestAnimationFrame) {
  window.requestAnimationFrame = (callback) => setTimeout(callback, 0);
  window.cancelAnimationFrame = (id) => clearTimeout(id);
}
