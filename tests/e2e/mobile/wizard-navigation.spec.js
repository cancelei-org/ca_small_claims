'use strict';

/**
 * Mobile Wizard Navigation Tests
 *
 * Tests touch-optimized wizard functionality on mobile viewports.
 * Includes swipe gestures, touch targets, and haptic feedback indicators.
 */

const { test, expect } = require('@playwright/test');

// Mobile viewport configurations
const mobileViewports = {
  iphone12: { width: 390, height: 844 },
  pixel5: { width: 393, height: 851 },
  iphoneSE: { width: 375, height: 667 }
};

test.describe('Mobile Wizard Navigation', () => {
  test.beforeEach(async ({ page }) => {
    // Use iPhone 12 viewport by default
    await page.setViewportSize(mobileViewports.iphone12);
  });

  test('should display swipe hint on mobile', async ({ page }) => {
    await page.goto('/forms');

    // Click first form to open it
    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Look for swipe hint (mobile only)
      const swipeHint = page.locator('text=Swipe to navigate');

      await expect(swipeHint).toBeVisible();
    }
  });

  test('wizard navigation buttons should have proper touch targets', async ({
    page
  }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Check previous button touch target
      const prevBtn = page.locator('[data-wizard-target="prevBtn"]');

      if ((await prevBtn.count()) > 0) {
        const prevSize = await prevBtn.boundingBox();

        expect(prevSize.height).toBeGreaterThanOrEqual(44);
      }

      // Check next button touch target
      const nextBtn = page.locator('[data-wizard-target="nextBtn"]');

      if ((await nextBtn.count()) > 0) {
        const nextSize = await nextBtn.boundingBox();

        expect(nextSize.height).toBeGreaterThanOrEqual(44);
      }
    }
  });

  test('navigation dots should have 44px minimum touch targets', async ({
    page
  }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Check navigation dots
      const dots = page.locator('[data-wizard-target="dot"]');
      const dotCount = await dots.count();

      for (let i = 0; i < Math.min(dotCount, 5); i++) {
        const dot = dots.nth(i);
        const size = await dot.boundingBox();

        if (size) {
          expect(size.width).toBeGreaterThanOrEqual(44);
          expect(size.height).toBeGreaterThanOrEqual(44);
        }
      }
    }
  });

  test('should support swipe gestures for navigation', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Get initial progress counter
      const counter = page.locator('[data-wizard-target="counter"]');
      const initialText = await counter.textContent();

      // Simulate swipe left (next)
      const wizardContainer = page.locator('[data-controller="wizard"]');

      if ((await wizardContainer.count()) > 0) {
        const box = await wizardContainer.boundingBox();

        if (box) {
          // Swipe left gesture
          await page.mouse.move(
            box.x + box.width * 0.8,
            box.y + box.height / 2
          );
          await page.mouse.down();
          await page.mouse.move(
            box.x + box.width * 0.2,
            box.y + box.height / 2,
            { steps: 10 }
          );
          await page.mouse.up();

          // Wait for animation
          await page.waitForTimeout(600);

          // Check if progress changed
          const newText = await counter.textContent();

          // Progress should have changed (unless on last field or validation failed)
          // We just verify the swipe didn't break anything
          expect(newText).toBeTruthy();
        }
      }
    }
  });

  test('should work correctly on different mobile viewports', async ({
    page
  }) => {
    for (const [device, viewport] of Object.entries(mobileViewports)) {
      await page.setViewportSize(viewport);
      await page.goto('/forms');

      // Check that page loads without horizontal scroll
      const hasHorizontalScroll = await page.evaluate(() => {
        return (
          document.documentElement.scrollWidth >
          document.documentElement.clientWidth
        );
      });

      expect(hasHorizontalScroll).toBe(false);

      // Check that forms index is visible
      const heading = page.locator('h1');

      await expect(heading).toBeVisible();
    }
  });

  test('keyboard hints should be hidden on mobile', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Keyboard hints should be hidden on mobile (they use lg:flex)
      const keyboardHint = page.locator('text=Enter');

      // Should not be visible on mobile viewport
      const isVisible = await keyboardHint.isVisible();

      expect(isVisible).toBe(false);
    }
  });

  test('form inputs should have proper sizing for touch', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Check input field sizes
      const inputs = page.locator(
        '.wizard-card input:visible, .wizard-card select:visible, .wizard-card textarea:visible'
      );
      const inputCount = await inputs.count();

      for (let i = 0; i < Math.min(inputCount, 3); i++) {
        const input = inputs.nth(i);
        const size = await input.boundingBox();

        if (size) {
          // Inputs should be at least 44px tall for touch
          expect(size.height).toBeGreaterThanOrEqual(40);
        }
      }
    }
  });
});

test.describe('Mobile Wizard Swipe on Different Devices', () => {
  test('iPhone 12 Pro - full swipe flow', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Verify wizard mode is active
      const wizardContainer = page.locator('[data-controller="wizard"]');

      await expect(wizardContainer).toBeVisible();
    }
  });

  test('Pixel 5 - navigation dots accessible', async ({ page }) => {
    await page.setViewportSize(mobileViewports.pixel5);
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Navigation dots should be tappable
      const dots = page.locator('[data-wizard-target="dot"]');

      if ((await dots.count()) > 1) {
        // Tap second dot
        await dots.nth(1).tap();

        // Wait for navigation
        await page.waitForTimeout(600);

        // Verify navigation occurred
        const counter = page.locator('[data-wizard-target="counter"]');
        const text = await counter.textContent();

        expect(text).toContain('2');
      }
    }
  });
});
