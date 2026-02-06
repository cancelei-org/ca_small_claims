/* eslint-disable max-classes-per-file */
/**
 * EventBinder Utility
 * Simplifies event listener management with automatic binding and cleanup.
 * Reduces boilerplate for the bind/unbind pattern in Stimulus controllers.
 *
 * Usage in Stimulus controller:
 *   import { EventBinder } from 'utils/event_binder';
 *
 *   connect() {
 *     this.events = new EventBinder(this);
 *     this.events.on(document, 'keydown', this.handleKeydown);
 *     this.events.on(this.element, 'click', this.handleClick, { passive: true });
 *   }
 *
 *   disconnect() {
 *     this.events.unbindAll();
 *   }
 */
export class EventBinder {
  /**
   * Create an EventBinder instance
   * @param {Object} context - The context to bind handlers to (usually `this` in a controller)
   */
  constructor(context) {
    this.context = context;
    this.listeners = [];
  }

  /**
   * Add an event listener with automatic binding
   * @param {EventTarget} target - The element or object to attach listener to
   * @param {string} eventType - The event type (e.g., 'click', 'keydown')
   * @param {Function} handler - The handler method (will be bound to context)
   * @param {Object} options - Optional addEventListener options
   * @returns {Function} The bound handler (for manual removal if needed)
   */
  on(target, eventType, handler, options = {}) {
    const boundHandler = handler.bind(this.context);

    target.addEventListener(eventType, boundHandler, options);

    this.listeners.push({
      target,
      eventType,
      handler: boundHandler,
      options
    });

    return boundHandler;
  }

  /**
   * Remove a specific event listener
   * @param {EventTarget} target - The element or object
   * @param {string} eventType - The event type
   * @param {Function} boundHandler - The bound handler returned from on()
   */
  off(target, eventType, boundHandler) {
    const index = this.listeners.findIndex(
      l =>
        l.target === target &&
        l.eventType === eventType &&
        l.handler === boundHandler
    );

    if (index !== -1) {
      const listener = this.listeners[index];

      listener.target.removeEventListener(
        listener.eventType,
        listener.handler,
        listener.options
      );
      this.listeners.splice(index, 1);
    }
  }

  /**
   * Remove all registered event listeners
   * Call this in the controller's disconnect() method
   */
  unbindAll() {
    this.listeners.forEach(({ target, eventType, handler, options }) => {
      target.removeEventListener(eventType, handler, options);
    });
    this.listeners = [];
  }

  /**
   * Check if any listeners are registered
   * @returns {boolean}
   */
  hasListeners() {
    return this.listeners.length > 0;
  }

  /**
   * Get count of registered listeners
   * @returns {number}
   */
  get listenerCount() {
    return this.listeners.length;
  }
}

/**
 * MediaQueryBinder - Specialized binder for media query listeners
 * Handles the matchMedia API with proper cleanup
 */
export class MediaQueryBinder {
  constructor(context) {
    this.context = context;
    this.queries = [];
  }

  /**
   * Add a media query listener
   * @param {string} query - The media query string
   * @param {Function} handler - The change handler
   * @returns {MediaQueryList} The MediaQueryList object
   */
  on(query, handler) {
    const mediaQuery = window.matchMedia(query);
    const boundHandler = handler.bind(this.context);

    mediaQuery.addEventListener('change', boundHandler);

    this.queries.push({
      mediaQuery,
      handler: boundHandler
    });

    return mediaQuery;
  }

  /**
   * Remove all media query listeners
   */
  unbindAll() {
    this.queries.forEach(({ mediaQuery, handler }) => {
      mediaQuery.removeEventListener('change', handler);
    });
    this.queries = [];
  }
}

export default EventBinder;
