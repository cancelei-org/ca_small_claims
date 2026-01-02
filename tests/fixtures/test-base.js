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
      await page.getByLabel(/email/i).fill(email);
      await page.getByLabel(/password/i).fill(password);
      await page.getByRole('button', { name: /log in/i }).click();
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
        name: /sign out|logout|log out/i
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
   * Wait for Turbo to finish processing
   */
  waitForTurbo: async ({ page }, use) => {
    const waitFn = async () => {
      // Wait for Turbo Drive to finish
      await page.waitForFunction(() => {
        return (
          document.documentElement.getAttribute('data-turbo-preview') === null
        );
      });
      // Small additional wait for any animations
      await page.waitForTimeout(100);
    };

    await use(waitFn);
  },

  /**
   * Reset test data via test-only endpoint
   */
  resetData: async ({ page }, use) => {
    const resetFn = async () => {
      const response = await page.request.post('/test_only/reset');

      if (!response.ok()) {
        console.warn('Test data reset failed or endpoint not available');
      }
    };

    await use(resetFn);
  }
});

module.exports = { test, expect };
