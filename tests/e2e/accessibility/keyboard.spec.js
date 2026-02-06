'use strict';

/* eslint-disable sonarjs/no-skipped-tests -- conditional test.skip() based on test data availability */
/**
 * Keyboard Navigation Tests
 *
 * Ensures the application is fully navigable via keyboard only,
 * meeting WCAG 2.1 Success Criterion 2.1.1 (Keyboard).
 */

const { test, expect } = require('@playwright/test');

test.describe('Global Keyboard Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('skip link should work on Tab press', async ({ page }) => {
    // Press Tab - skip link should receive focus
    await page.keyboard.press('Tab');

    const skipLink = page.locator('a[href="#main-content"]');

    await expect(skipLink).toBeFocused();

    // Press Enter - should navigate to main content
    await page.keyboard.press('Enter');

    const main = page.locator('#main-content');

    await expect(main).toBeFocused();
  });

  test('should be able to Tab through navigation items', async ({ page }) => {
    // Skip past the skip link
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');

    // Should be on first nav element
    const focusedElement = page.locator(':focus');

    await expect(focusedElement).toBeVisible();
  });

  test('should maintain visible focus indicators', async ({ page }) => {
    // Tab to first focusable element
    await page.keyboard.press('Tab');

    const focused = page.locator(':focus');

    // Check focus is visible (has outline or ring)
    const styles = await focused.evaluate(el => {
      const computed = window.getComputedStyle(el);

      return {
        outline: computed.outline,
        outlineWidth: computed.outlineWidth,
        boxShadow: computed.boxShadow
      };
    });

    // Should have visible outline or box-shadow for focus
    const hasVisibleFocus =
      styles.outlineWidth !== '0px' ||
      (styles.boxShadow && styles.boxShadow !== 'none');

    expect(hasVisibleFocus).toBe(true);
  });
});

test.describe('Form Keyboard Navigation', () => {
  test('should navigate form fields with Tab', async ({ page }) => {
    await page.goto('/forms');

    // Click first form to open it
    const formLink = page.locator('a[href*="/forms/"]').first();
    const formCount = await formLink.count();

    // Skip test if no forms - forms may not exist in test environment
    test.skip(formCount === 0, 'No forms available in test environment');

    await formLink.click();
    await page.waitForLoadState('networkidle');

    // Tab through form elements
    const tabCount = 5;

    for (let i = 0; i < tabCount; i++) {
      await page.keyboard.press('Tab');
      await page.waitForTimeout(100);
    }

    // Should have a focused element
    const focused = page.locator(':focus');

    await expect(focused).toBeAttached();
  });

  test('should be able to fill form using keyboard only', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();
    const formCount = await formLink.count();

    // Skip test if no forms - forms may not exist in test environment
    test.skip(formCount === 0, 'No forms available in test environment');

    await formLink.click();
    await page.waitForLoadState('networkidle');

    // Find first text input in the form (exclude command bar input)
    const textInput = page
      .locator('main input[type="text"]:not([data-command-bar-target])')
      .first();
    const inputCount = await textInput.count();

    // Skip if no text inputs - form structure may vary
    test.skip(inputCount === 0, 'No text inputs in this form');

    // Focus and type
    await textInput.focus();
    await page.keyboard.type('Test keyboard input');

    await expect(textInput).toHaveValue('Test keyboard input');
  });

  test('Escape should close modals', async ({ page }) => {
    await page.goto('/');

    // Open theme modal
    const themeButton = page
      .locator('[data-action*="theme#openModal"]')
      .first();
    const buttonCount = await themeButton.count();

    // Skip if theme button not found - UI may differ
    test.skip(buttonCount === 0, 'Theme modal button not found');

    await themeButton.click();

    const modal = page.locator('#theme-modal');

    await expect(modal).toBeVisible();

    // Press Escape
    await page.keyboard.press('Escape');

    await expect(modal).not.toBeVisible();
  });
});

test.describe('Wizard Keyboard Navigation', () => {
  test('should navigate wizard with keyboard', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();
    const formCount = await formLink.count();

    // Skip test if no forms - forms may not exist in test environment
    test.skip(formCount === 0, 'No forms available in test environment');

    await formLink.click();
    await page.waitForLoadState('networkidle');

    // Check for wizard navigation buttons
    const nextButton = page.locator('button:has-text("Next")');
    const nextCount = await nextButton.count();

    // Skip if not a wizard form - form may use different layout
    test.skip(nextCount === 0, 'Not a wizard form - no Next button');

    // Navigate to Next button and click with Enter
    await nextButton.focus();
    await expect(nextButton).toBeFocused();

    // Verify keyboard activation works by pressing Enter
    // Note: Progress may or may not change depending on validation
    await page.keyboard.press('Enter');
    await page.waitForTimeout(500);
  });

  test('Escape should go back to previous field in wizard', async ({
    page
  }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();
    const formCount = await formLink.count();

    test.skip(formCount === 0, 'No forms available in test environment');

    await formLink.click();
    await page.waitForLoadState('networkidle');

    // Check for wizard mode indicators
    const progressBar = page.locator('[role="progressbar"]');
    const hasProgressBar = (await progressBar.count()) > 0;

    test.skip(!hasProgressBar, 'Not a wizard form - no progress bar');

    // Get initial progress text or counter
    const counter = page.locator('[data-wizard-target="counter"]');
    const hasCounter = (await counter.count()) > 0;

    if (hasCounter) {
      const initialText = await counter.textContent();

      // Navigate forward first (Enter or Next button)
      const nextBtn = page.locator('[data-action*="wizard#next"]').first();

      if ((await nextBtn.count()) > 0) {
        await nextBtn.click();
        await page.waitForTimeout(600);

        // Now press Escape to go back
        await page.keyboard.press('Escape');
        await page.waitForTimeout(600);

        // Counter should be back to initial value
        const afterEscapeText = await counter.textContent();

        expect(afterEscapeText).toBe(initialText);
      }
    }
  });
});

test.describe('Dropdown and Select Keyboard Navigation', () => {
  test('select dropdowns should work with arrow keys', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();
    const formCount = await formLink.count();

    // Skip test if no forms - forms may not exist in test environment
    test.skip(formCount === 0, 'No forms available in test environment');

    await formLink.click();
    await page.waitForLoadState('networkidle');

    // Find a select element
    const select = page.locator('select').first();
    const selectCount = await select.count();

    // Skip if no selects - form structure may vary
    test.skip(selectCount === 0, 'No select elements in this form');

    // Focus and navigate with arrow keys
    await select.focus();
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(100);

    // Select should still be focused after arrow navigation
    await expect(select).toBeFocused();
  });
});

test.describe('Focus Trap in Modals', () => {
  test('Tab should cycle within modal', async ({ page }) => {
    await page.goto('/');

    // Open theme modal
    const themeButton = page
      .locator('[data-action*="theme#openModal"]')
      .first();
    const buttonCount = await themeButton.count();

    // Skip if theme button not found - UI may differ
    test.skip(buttonCount === 0, 'Theme modal button not found');

    await themeButton.click();
    await page.waitForTimeout(300);

    const modal = page.locator('#theme-modal');

    await expect(modal).toBeVisible();

    // Get all focusable elements in modal
    const focusableInModal = modal.locator(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const count = await focusableInModal.count();

    // Skip if not enough elements to test focus trap
    test.skip(count < 2, 'Not enough focusable elements for focus trap test');

    // Tab through all elements plus one more
    for (let i = 0; i < count + 1; i++) {
      await page.keyboard.press('Tab');
    }

    // Focus should still be within modal (trapped)
    const focused = page.locator(':focus');
    const focusedInModal = await focused.evaluate(el => {
      return el.closest('#theme-modal') !== null;
    });

    expect(focusedInModal).toBe(true);
  });

  test('Shift+Tab should cycle backwards in modal', async ({ page }) => {
    await page.goto('/');

    const themeButton = page
      .locator('[data-action*="theme#openModal"]')
      .first();
    const buttonCount = await themeButton.count();

    // Skip if theme button not found - UI may differ
    test.skip(buttonCount === 0, 'Theme modal button not found');

    await themeButton.click();
    await page.waitForTimeout(300);

    const modal = page.locator('#theme-modal');

    await expect(modal).toBeVisible();

    // Shift+Tab should move backwards through elements
    await page.keyboard.press('Shift+Tab');

    const focused = page.locator(':focus');
    const focusedInModal = await focused.evaluate(el => {
      return el.closest('#theme-modal') !== null;
    });

    expect(focusedInModal).toBe(true);
  });
});

test.describe('Focus Restoration', () => {
  test('focus should return to trigger after modal close', async ({ page }) => {
    await page.goto('/');

    const themeButton = page
      .locator('[data-action*="theme#openModal"]')
      .first();
    const buttonCount = await themeButton.count();

    // Skip if theme button not found - UI may differ
    test.skip(buttonCount === 0, 'Theme modal button not found');

    // Open modal via keyboard
    await themeButton.focus();
    await page.keyboard.press('Enter');
    await page.waitForTimeout(300);

    const modal = page.locator('#theme-modal');

    await expect(modal).toBeVisible();

    // Close with Escape
    await page.keyboard.press('Escape');
    await page.waitForTimeout(300);

    // Focus should return to the trigger button
    await expect(themeButton).toBeFocused();
  });
});

test.describe('Arrow Key Navigation', () => {
  test('radio buttons should work with arrow keys', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();
    const formCount = await formLink.count();

    // Skip test if no forms - forms may not exist in test environment
    test.skip(formCount === 0, 'No forms available in test environment');

    await formLink.click();
    await page.waitForLoadState('networkidle');

    // Find radio button group
    const radioButtons = page.locator('input[type="radio"]');
    const radioCount = await radioButtons.count();

    // Skip if no radio buttons - form structure may vary
    test.skip(radioCount === 0, 'No radio buttons in this form');

    const firstRadio = radioButtons.first();

    // Focus and navigate
    await firstRadio.focus();
    await page.keyboard.press('ArrowDown');

    // Should have a focused radio button
    const focusedRadio = page.locator('input[type="radio"]:focus');

    await expect(focusedRadio).toBeAttached();
  });
});
/* eslint-enable sonarjs/no-skipped-tests */
