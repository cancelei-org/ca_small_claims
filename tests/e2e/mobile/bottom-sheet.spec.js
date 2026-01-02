'use strict';

/**
 * Mobile Bottom Sheet Tests
 *
 * Tests the form actions bottom sheet on mobile viewports.
 * Includes swipe gestures, touch targets, and accessibility.
 */

const { test, expect } = require('@playwright/test');

// Mobile viewport configurations
const mobileViewports = {
  iphone12: { width: 390, height: 844 },
  pixel5: { width: 393, height: 851 },
  iphoneSE: { width: 375, height: 667 }
};

test.describe('Mobile Bottom Sheet', () => {
  test.beforeEach(async ({ page }) => {
    // Use iPhone 12 viewport by default
    await page.setViewportSize(mobileViewports.iphone12);
  });

  test('should display form actions FAB on mobile', async ({ page }) => {
    await page.goto('/forms');

    // Click first form to open it
    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Look for the actions FAB button
      const actionsFab = page.locator('.form-actions-fab button');

      await expect(actionsFab).toBeVisible();

      // Verify touch-friendly size
      const fabSize = await actionsFab.boundingBox();

      if (fabSize) {
        expect(fabSize.height).toBeGreaterThanOrEqual(56);
      }
    }
  });

  test('should open bottom sheet when FAB is tapped', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Tap the FAB
      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();

        // Wait for animation
        await page.waitForTimeout(400);

        // Bottom sheet should be visible
        const bottomSheet = page.locator('.bottom-sheet.open');

        await expect(bottomSheet).toBeVisible();

        // Backdrop should be visible
        const backdrop = page.locator('.bottom-sheet-backdrop.open');

        await expect(backdrop).toBeVisible();
      }
    }
  });

  test('should display all form actions in bottom sheet', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Open bottom sheet
      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();
        await page.waitForTimeout(400);

        // Check for action buttons
        const actions = page.locator('.bottom-sheet-action');

        expect(await actions.count()).toBeGreaterThanOrEqual(3);

        // Check specific actions exist
        const saveAction = page.locator(
          '.bottom-sheet-action:has-text("Save Draft")'
        );
        const previewAction = page.locator(
          '.bottom-sheet-action:has-text("Preview PDF")'
        );
        const downloadAction = page.locator(
          '.bottom-sheet-action:has-text("Download PDF")'
        );

        await expect(saveAction).toBeVisible();
        await expect(previewAction).toBeVisible();
        await expect(downloadAction).toBeVisible();
      }
    }
  });

  test('should close bottom sheet when backdrop is tapped', async ({
    page
  }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Open bottom sheet
      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();
        await page.waitForTimeout(400);

        // Tap backdrop
        const backdrop = page.locator('.bottom-sheet-backdrop');

        await backdrop.click({ position: { x: 10, y: 10 } });

        // Wait for close animation
        await page.waitForTimeout(400);

        // Bottom sheet should be hidden
        const bottomSheet = page.locator('.bottom-sheet.open');

        await expect(bottomSheet).not.toBeVisible();
      }
    }
  });

  test('should close bottom sheet when close button is tapped', async ({
    page
  }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Open bottom sheet
      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();
        await page.waitForTimeout(400);

        // Tap close button
        const closeButton = page.locator(
          '.bottom-sheet-header button[aria-label="Close"]'
        );

        await closeButton.click();

        // Wait for close animation
        await page.waitForTimeout(400);

        // Bottom sheet should be hidden
        const bottomSheet = page.locator('.bottom-sheet.open');

        await expect(bottomSheet).not.toBeVisible();
      }
    }
  });

  test('action buttons should have 56px minimum touch targets', async ({
    page
  }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Open bottom sheet
      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();
        await page.waitForTimeout(400);

        // Check action button sizes
        const actions = page.locator('.bottom-sheet-action');
        const actionCount = await actions.count();

        for (let i = 0; i < Math.min(actionCount, 3); i++) {
          const action = actions.nth(i);
          const size = await action.boundingBox();

          if (size) {
            // Actions should be at least 56px tall for touch
            expect(size.height).toBeGreaterThanOrEqual(56);
          }
        }
      }
    }
  });

  test('should support swipe down to dismiss', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Open bottom sheet
      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();
        await page.waitForTimeout(400);

        // Get the drag handle
        const handle = page.locator('.bottom-sheet-handle');
        const handleBox = await handle.boundingBox();

        if (handleBox) {
          // Simulate swipe down gesture
          await page.mouse.move(
            handleBox.x + handleBox.width / 2,
            handleBox.y + handleBox.height / 2
          );
          await page.mouse.down();
          await page.mouse.move(
            handleBox.x + handleBox.width / 2,
            handleBox.y + handleBox.height / 2 + 150,
            { steps: 10 }
          );
          await page.mouse.up();

          // Wait for animation
          await page.waitForTimeout(500);

          // Bottom sheet should be closed
          const bottomSheet = page.locator('.bottom-sheet.open');

          await expect(bottomSheet).not.toBeVisible();
        }
      }
    }
  });

  test('should be hidden on desktop viewport', async ({ page }) => {
    // Set desktop viewport
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // FAB should not be visible on desktop
      const actionsFab = page.locator('.form-actions-fab');

      await expect(actionsFab).not.toBeVisible();
    }
  });

  test('should close on escape key press', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Open bottom sheet
      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();
        await page.waitForTimeout(400);

        // Press escape
        await page.keyboard.press('Escape');

        // Wait for close animation
        await page.waitForTimeout(400);

        // Bottom sheet should be closed
        const bottomSheet = page.locator('.bottom-sheet.open');

        await expect(bottomSheet).not.toBeVisible();
      }
    }
  });

  test('should have correct ARIA attributes', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Open bottom sheet
      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        // FAB should have proper ARIA
        await expect(actionsFab).toHaveAttribute('aria-haspopup', 'dialog');
        await expect(actionsFab).toHaveAttribute(
          'aria-label',
          'Open form actions menu'
        );

        await actionsFab.click();
        await page.waitForTimeout(400);

        // Bottom sheet should have dialog role
        const bottomSheet = page.locator('.bottom-sheet');

        await expect(bottomSheet).toHaveAttribute('role', 'dialog');
        await expect(bottomSheet).toHaveAttribute('aria-modal', 'true');
        await expect(bottomSheet).toHaveAttribute('aria-hidden', 'false');
      }
    }
  });
});

test.describe('Bottom Sheet on Different Devices', () => {
  test('iPhone SE - compact layout', async ({ page }) => {
    await page.setViewportSize(mobileViewports.iphoneSE);
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();
        await page.waitForTimeout(400);

        // Bottom sheet should not overflow viewport
        const bottomSheet = page.locator('.bottom-sheet.open');
        const sheetBox = await bottomSheet.boundingBox();

        if (sheetBox) {
          expect(sheetBox.height).toBeLessThanOrEqual(
            mobileViewports.iphoneSE.height * 0.9
          );
        }
      }
    }
  });

  test('Pixel 5 - actions accessible', async ({ page }) => {
    await page.setViewportSize(mobileViewports.pixel5);
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      const actionsFab = page.locator('.form-actions-fab button');

      if ((await actionsFab.count()) > 0) {
        await actionsFab.click();
        await page.waitForTimeout(400);

        // All actions should be visible
        const saveAction = page.locator(
          '.bottom-sheet-action:has-text("Save Draft")'
        );
        const previewAction = page.locator(
          '.bottom-sheet-action:has-text("Preview PDF")'
        );
        const downloadAction = page.locator(
          '.bottom-sheet-action:has-text("Download PDF")'
        );

        await expect(saveAction).toBeInViewport();
        await expect(previewAction).toBeInViewport();
        await expect(downloadAction).toBeInViewport();
      }
    }
  });
});
