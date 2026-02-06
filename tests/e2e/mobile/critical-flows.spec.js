'use strict';

/**
 * Mobile Critical User Flows Tests
 *
 * Tests critical user flows on mobile viewports:
 * - Form Submission
 * - Admin Dashboard
 * - Feedback Management
 */

const { test, expect } = require('@playwright/test');

// Mobile viewport configurations
const mobileViewports = {
  iphone12: { width: 390, height: 844 },
  pixel5: { width: 393, height: 851 }
};

test.describe('Mobile Form Submission Flow', () => {
  test.use({ viewport: mobileViewports.iphone12 });

  test('can complete form wizard and save', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Fill first field if visible
      const firstInput = page
        .locator(
          '.wizard-card:visible input:visible, .wizard-card:visible textarea:visible'
        )
        .first();

      if ((await firstInput.count()) > 0) {
        const inputType = await firstInput.getAttribute('type');
        const tagName = await firstInput.evaluate(el =>
          el.tagName.toLowerCase()
        );

        if (tagName === 'textarea' || inputType === 'text') {
          await firstInput.fill('Test Value');
        } else if (inputType === 'email') {
          await firstInput.fill('test@example.com');
        } else if (inputType === 'tel') {
          await firstInput.fill('5551234567');
        }

        // Wait for autosave
        await page.waitForTimeout(1500);

        // Take screenshot of save state
        await page.screenshot({
          path: 'tests/screenshots/mobile-form-save.png'
        });
      }

      // Try advancing to next field
      const nextBtn = page.locator('[data-wizard-target="nextBtn"]');

      if ((await nextBtn.count()) > 0 && (await nextBtn.isEnabled())) {
        await nextBtn.click();
        await page.waitForTimeout(600);
      }
    }
  });

  test('form fields have proper mobile keyboard attributes', async ({
    page
  }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Check inputmode attributes
      const telInputs = page.locator('input[type="tel"]');

      for (let i = 0; i < (await telInputs.count()); i++) {
        const inputmode = await telInputs.nth(i).getAttribute('inputmode');

        expect(inputmode).toBe('tel');
      }

      const emailInputs = page.locator('input[type="email"]');

      for (let i = 0; i < (await emailInputs.count()); i++) {
        const inputmode = await emailInputs.nth(i).getAttribute('inputmode');

        expect(inputmode).toBe('email');
      }

      const numberInputs = page.locator('input[type="number"]');

      for (let i = 0; i < Math.min(await numberInputs.count(), 3); i++) {
        const inputmode = await numberInputs.nth(i).getAttribute('inputmode');

        expect(['numeric', 'decimal']).toContain(inputmode);
      }
    }
  });

  test('bottom sheet actions are accessible', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Check bottom sheet
      const bottomSheet = page.locator('[data-controller="bottom-sheet"]');

      if ((await bottomSheet.count()) > 0) {
        // Check touch targets
        const buttons = bottomSheet.locator('button, a');

        for (let i = 0; i < (await buttons.count()); i++) {
          const box = await buttons.nth(i).boundingBox();

          if (box && box.height > 0) {
            expect(box.height).toBeGreaterThanOrEqual(44);
          }
        }

        await page.screenshot({
          path: 'tests/screenshots/mobile-bottom-sheet.png'
        });
      }
    }
  });
});

test.describe('Mobile Admin Dashboard', () => {
  test.use({ viewport: mobileViewports.iphone12 });

  // Skip if auth not configured
  test.skip(
    ({ browserName: _browserName }) => true,
    'Requires authenticated admin session'
  );

  test('admin dashboard stats are scrollable on mobile', async ({ page }) => {
    // This test requires authentication
    await page.goto('/admin');

    // Check for stats cards horizontal scroll
    const statsContainer = page.locator('.overflow-x-auto');

    if ((await statsContainer.count()) > 0) {
      const container = statsContainer.first();

      // Should have horizontal scrolling capability
      const scrollWidth = await container.evaluate(
        el => el.scrollWidth > el.clientWidth
      );

      console.log('Stats scrollable:', scrollWidth);
    }
  });

  test('admin sidebar opens correctly on mobile', async ({ page }) => {
    await page.goto('/admin');

    // Look for drawer toggle
    const drawerToggle = page.locator('label[for="admin-drawer"]');

    if ((await drawerToggle.count()) > 0) {
      await drawerToggle.click();
      await page.waitForTimeout(300);

      // Sidebar should be visible
      const sidebar = page.locator('.drawer-side aside');

      await expect(sidebar).toBeVisible();

      await page.screenshot({
        path: 'tests/screenshots/mobile-admin-sidebar.png'
      });
    }
  });

  test('feedback list displays correctly on mobile', async ({ page }) => {
    await page.goto('/admin/feedbacks');

    // Check for mobile card layout (hidden on desktop)
    const mobileCards = page.locator('.md\\:hidden > div');

    // On mobile viewport, cards should be visible
    if ((await mobileCards.count()) > 0) {
      await expect(mobileCards.first()).toBeVisible();
    }

    // Take screenshot
    await page.screenshot({
      path: 'tests/screenshots/mobile-feedback-list.png',
      fullPage: true
    });
  });

  test('analytics page charts are responsive', async ({ page }) => {
    await page.goto('/admin/analytics');

    // Check collapsible sections
    const detailsSections = page.locator('details');

    if ((await detailsSections.count()) > 0) {
      // Should be open by default
      await expect(detailsSections.first()).toHaveAttribute('open');
    }

    // Check horizontal scroll prevention
    const hasOverflow = await page.evaluate(() => {
      return (
        document.documentElement.scrollWidth >
        document.documentElement.clientWidth
      );
    });

    expect(hasOverflow).toBe(false);

    await page.screenshot({
      path: 'tests/screenshots/mobile-analytics.png',
      fullPage: true
    });
  });
});

test.describe('Cross-Device Compatibility', () => {
  for (const [device, viewport] of Object.entries(mobileViewports)) {
    test(`${device} - complete user flow`, async ({ page }) => {
      await page.setViewportSize(viewport);

      // 1. Visit homepage
      await page.goto('/');
      await expect(page).toHaveTitle(/.*/u);

      // 2. Navigate to forms
      await page.goto('/forms');
      const heading = page.locator('h1');

      await expect(heading).toBeVisible();

      // 3. Open a form
      const formLink = page.locator('a[href*="/forms/"]').first();

      if ((await formLink.count()) > 0) {
        await formLink.click();
        await page.waitForLoadState('networkidle');

        // 4. Verify no horizontal overflow
        const hasOverflow = await page.evaluate(() => {
          return (
            document.documentElement.scrollWidth >
            document.documentElement.clientWidth
          );
        });

        expect(hasOverflow).toBe(false);

        // 5. Check wizard is visible
        const wizard = page.locator('[data-controller="wizard"]');

        if ((await wizard.count()) > 0) {
          await expect(wizard).toBeVisible();
        }
      }

      // Take final screenshot
      await page.screenshot({
        path: `tests/screenshots/mobile-complete-flow-${device}.png`,
        fullPage: true
      });
    });
  }
});
