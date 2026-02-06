'use strict';

const { test: base, expect } = require('@playwright/test');

/**
 * Custom test fixtures for CA Small Claims E2E tests
 *
 * Provides common utilities like login, form helpers, and wait utilities
 */
const test = base.extend({
  /**
   * Login fixture - provides a reusable login function
   * Usage: test('my test', async ({ page, login }) => { await login('user@example.com'); })
   */
  login: async ({ page, context }, use) => {
    const loginFn = async (email, password = 'password') => {
      // Clear cookies to ensure logged out state
      await context.clearCookies();

      await page.goto('/users/sign_in');
      await page.getByLabel(/email/iu).fill(email);
      await page.getByLabel(/password/iu).fill(password);
      await page.getByRole('button', { name: /log in/iu }).click();
      // Wait for successful login redirect
      await page.waitForURL(url => !url.pathname.includes('/sign_in'));
    };

    await use(loginFn);
  },

  /**
   * Logout fixture - provides a reusable logout function
   */
  logout: async ({ page }, use) => {
    const logoutFn = async () => {
      // Try to find and click logout button/link
      const logoutLink = page.getByRole('link', {
        name: /sign out|logout|log out/iu
      });

      if ((await logoutLink.count()) > 0) {
        await logoutLink.click();
      } else {
        // Fallback to direct navigation
        await page.goto('/users/sign_out');
      }
      await page.waitForURL(
        url => url.pathname.includes('/sign_in') || url.pathname === '/'
      );
    };

    await use(logoutFn);
  },

  /**
   * Enhanced wait for Turbo to finish processing
   * Waits for: preview completion, busy frames, and animations
   * @param {number} timeout - Max wait time in ms (default 5000)
   */
  waitForTurbo: async ({ page }, use) => {
    const waitFn = async (timeout = 5000) => {
      // Wait for Turbo preview to complete
      await page.waitForFunction(
        () =>
          document.documentElement.getAttribute('data-turbo-preview') === null,
        { timeout }
      );

      // Wait for any pending Turbo frames to finish loading
      await page.waitForFunction(
        () => {
          const busyFrames = document.querySelectorAll('turbo-frame[busy]');
          return busyFrames.length === 0;
        },
        { timeout }
      );

      // Wait for animations to complete
      await page.evaluate(() => {
        return new Promise(resolve => {
          if (document.readyState === 'complete') {
            requestAnimationFrame(() => requestAnimationFrame(resolve));
          } else {
            document.addEventListener('load', () => {
              requestAnimationFrame(() => requestAnimationFrame(resolve));
            });
          }
        });
      });

      // Buffer for Stimulus controller initialization
      await page.waitForTimeout(100);
    };

    await use(waitFn);
  },

  /**
   * Wait for a specific Turbo frame to finish loading
   * @param {string} frameId - The turbo-frame id to wait for
   * @param {number} timeout - Max wait time in ms
   */
  waitForFrameLoad: async ({ page }, use) => {
    const waitFn = async (frameId, timeout = 5000) => {
      const frame = page.locator(`turbo-frame[id="${frameId}"]`);

      // Wait for frame to exist
      await frame.waitFor({ timeout });

      // Wait for busy attribute to be removed
      await page.waitForFunction(
        id => {
          const f = document.querySelector(`turbo-frame[id="${id}"]`);
          return f && !f.hasAttribute('busy');
        },
        frameId,
        { timeout }
      );

      // Wait for frame to have content
      await page.waitForFunction(
        id => {
          const f = document.querySelector(`turbo-frame[id="${id}"]`);
          return f && f.innerHTML.trim().length > 0;
        },
        frameId,
        { timeout }
      );
    };

    await use(waitFn);
  },

  /**
   * Wait for Stimulus controllers to initialize
   * @param {string} controllerName - Optional specific controller to wait for
   * @param {number} timeout - Max wait time in ms
   */
  waitForStimulus: async ({ page }, use) => {
    const waitFn = async (controllerName = '', timeout = 5000) => {
      if (controllerName) {
        // Wait for specific controller
        await page.waitForFunction(
          name => {
            // Check if Stimulus application exists
            if (typeof window.Stimulus === 'undefined') return false;
            return window.Stimulus.application.controllers.some(
              c => c.identifier === name
            );
          },
          controllerName,
          { timeout }
        );
      } else {
        // Wait for DOM ready + Stimulus processing time
        await page.waitForLoadState('domcontentloaded');
        await page.waitForTimeout(300);
      }
    };

    await use(waitFn);
  },

  /**
   * Wait for autosave to complete after form input
   * Respects debounce timing (typically 800ms+)
   */
  waitForAutoSave: async ({ page }, use) => {
    const waitFn = async (timeout = 5000) => {
      // Look for save indicator or wait debounce period
      const hasIndicator = await page
        .locator('[data-auto-save-status], .autosave-indicator')
        .count();

      if (hasIndicator > 0) {
        // Wait for indicator to show 'saved' state
        await page.waitForFunction(
          () => {
            const indicator = document.querySelector(
              '[data-auto-save-status], .autosave-indicator'
            );
            if (!indicator) return true;
            const status = indicator.getAttribute('data-auto-save-status');
            return status === 'saved' || status === 'idle';
          },
          { timeout }
        );
      } else {
        // Fallback: wait for typical debounce + network time
        await page.waitForTimeout(1200);
      }
    };

    await use(waitFn);
  },

  /**
   * Reset test data via test-only endpoint with fallback cleanup
   */
  resetData: async ({ page, context }, use) => {
    const resetFn = async () => {
      try {
        const response = await page.request.post('/test_only/reset');

        if (!response.ok()) {
          console.warn('Reset endpoint failed, trying fallback cleanup');
          // Clear browser state as fallback
          await context.clearCookies();
          await page.evaluate(() => {
            sessionStorage.clear();
            localStorage.removeItem('form-draft');
            localStorage.removeItem('session-id');
            localStorage.removeItem('wizard-mode');
          });
        }
      } catch (error) {
        console.warn('Data reset error:', error.message);
        // Ensure browser state is clean
        await context.clearCookies();
      }
    };

    await use(resetFn);
  },

  /**
   * Wait for PDF download to complete
   * @param {Function} action - Async function that triggers the download
   * @param {number} timeout - Max wait time in ms
   */
  waitForDownload: async ({ page }, use) => {
    const waitFn = async (action, timeout = 30000) => {
      const downloadPromise = page.waitForEvent('download', { timeout });

      await action();

      const download = await downloadPromise;

      // Wait for download to complete and get path
      const path = await download.path();

      return {
        download,
        path,
        filename: download.suggestedFilename()
      };
    };

    await use(waitFn);
  }
});

module.exports = { test, expect };
