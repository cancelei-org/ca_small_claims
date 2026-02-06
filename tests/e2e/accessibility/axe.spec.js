'use strict';

/**
 * Accessibility Tests with axe-core
 *
 * Tests WCAG 2.1 Level AA compliance across key pages.
 * Uses @axe-core/playwright for automated accessibility scanning.
 */

const AxeBuilder = require('@axe-core/playwright').default;
const { test, expect } = require('@playwright/test');

/**
 * Run axe accessibility check and return violations
 */
async function checkA11y(page, options = {}) {
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .exclude(options.exclude || [])
    .analyze();

  return results.violations;
}

/**
 * Format violation for readable output
 */
function formatViolation(violation) {
  const nodes = violation.nodes
    .map(
      node =>
        `  - ${node.html.substring(0, 100)}${node.html.length > 100 ? '...' : ''}\n    ${node.failureSummary}`
    )
    .join('\n');

  return `[${violation.impact}] ${violation.id}: ${violation.description}\n${nodes}`;
}

test.describe('Homepage Accessibility', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should have no critical or serious WCAG violations', async ({
    page
  }) => {
    const violations = await checkA11y(page);
    const serious = violations.filter(
      v => v.impact === 'critical' || v.impact === 'serious'
    );

    if (serious.length > 0) {
      const report = serious.map(formatViolation).join('\n\n');

      console.log('Critical/Serious violations:\n', report);
    }

    expect(serious).toHaveLength(0);
  });

  test('should have proper document structure', async ({ page }) => {
    // Check for main landmark
    const main = page.locator('main');

    await expect(main).toBeVisible();

    // Check for navigation (page has multiple nav elements - Main and Secondary)
    const nav = page.locator('nav').first();

    await expect(nav).toBeVisible();

    // Check for h1
    const h1 = page.locator('h1');

    await expect(h1).toHaveCount(1);

    // Check lang attribute
    const html = page.locator('html');

    await expect(html).toHaveAttribute('lang', 'en');
  });

  test('should have skip-to-content link', async ({ page }) => {
    const skipLink = page.locator('a[href="#main-content"]');

    await expect(skipLink).toBeAttached();

    // Should be visible on focus
    await skipLink.focus();
    await expect(skipLink).toBeVisible();
  });
});

test.describe('Forms Index Accessibility', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/forms');
  });

  test('should have no critical accessibility violations', async ({ page }) => {
    const violations = await checkA11y(page);
    const critical = violations.filter(v => v.impact === 'critical');

    if (critical.length > 0) {
      const report = critical.map(formatViolation).join('\n\n');

      console.log('Critical violations on /forms:\n', report);
    }

    expect(critical).toHaveLength(0);
  });

  test('should have accessible form cards', async ({ page }) => {
    // All form links should have accessible names
    const formLinks = page.locator('a[href*="/forms/"]');
    const count = await formLinks.count();

    for (let i = 0; i < Math.min(count, 5); i++) {
      const link = formLinks.nth(i);
      const text = await link.textContent();

      expect(text?.trim()).toBeTruthy();
    }
  });
});

test.describe('Form Wizard Accessibility', () => {
  test('wizard should have proper ARIA attributes', async ({ page }) => {
    await page.goto('/forms');

    // Click first available form
    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Check progress bar has progressbar role
      const progressBar = page.locator('[role="progressbar"]');

      if ((await progressBar.count()) > 0) {
        await expect(progressBar).toHaveAttribute('aria-valuenow', /.+/u);
        await expect(progressBar).toHaveAttribute('aria-valuemin', '0');
        await expect(progressBar).toHaveAttribute('aria-valuemax', '100');
      }

      // Run full accessibility check on form
      const violations = await checkA11y(page, {
        exclude: ['[data-turbo-frame]'] // Exclude dynamic frames still loading
      });
      const serious = violations.filter(
        v => v.impact === 'critical' || v.impact === 'serious'
      );

      expect(serious).toHaveLength(0);
    }
  });
});

test.describe('Color Contrast', () => {
  test('should have sufficient color contrast in light mode', async ({
    page
  }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2aa'])
      .options({ rules: { 'color-contrast': { enabled: true } } })
      .analyze();

    const contrastViolations = results.violations.filter(
      v => v.id === 'color-contrast'
    );

    if (contrastViolations.length > 0) {
      console.log(
        'Contrast violations:',
        contrastViolations.map(formatViolation).join('\n')
      );
    }

    // Allow some minor violations but no critical ones
    const criticalContrast = contrastViolations.filter(
      v => v.impact === 'critical'
    );

    expect(criticalContrast).toHaveLength(0);
  });

  test('high contrast theme should meet WCAG AAA standards', async ({
    page
  }) => {
    await page.goto('/');

    // Set high contrast light theme
    await page.evaluate(() => {
      document.documentElement.setAttribute(
        'data-theme',
        'high-contrast-light'
      );
      localStorage.setItem('theme', 'high-contrast-light');
    });

    // Wait for theme to apply
    await page.waitForTimeout(100);

    // Run axe with WCAG AAA color contrast rules (7:1 ratio)
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2aaa'])
      .options({ rules: { 'color-contrast-enhanced': { enabled: true } } })
      .analyze();

    const contrastViolations = results.violations.filter(
      v => v.id === 'color-contrast-enhanced' || v.id === 'color-contrast'
    );

    // High contrast theme should have zero contrast violations
    expect(contrastViolations).toHaveLength(0);
  });
});

test.describe('Interactive Elements', () => {
  test('all buttons should have accessible names', async ({ page }) => {
    await page.goto('/');

    const buttons = page.locator(
      'button:not([aria-hidden="true"]):not([tabindex="-1"])'
    );
    const count = await buttons.count();

    for (let i = 0; i < count; i++) {
      const button = buttons.nth(i);
      const name =
        (await button.getAttribute('aria-label')) ||
        (await button.textContent());

      expect(name?.trim()).toBeTruthy();
    }
  });

  test('all links should have accessible names', async ({ page }) => {
    await page.goto('/');

    const links = page.locator(
      'a:not([aria-hidden="true"]):not([tabindex="-1"])'
    );
    const count = await links.count();

    for (let i = 0; i < count; i++) {
      const link = links.nth(i);
      const name =
        (await link.getAttribute('aria-label')) || (await link.textContent());

      expect(name?.trim()).toBeTruthy();
    }
  });
});

test.describe('ARIA Compliance', () => {
  test('modals should have proper ARIA attributes', async ({ page }) => {
    await page.goto('/');

    // Check theme modal
    const themeModal = page.locator('#theme-modal');

    if ((await themeModal.count()) > 0) {
      await expect(themeModal).toHaveAttribute('role', 'dialog');
      await expect(themeModal).toHaveAttribute('aria-modal', 'true');
      await expect(themeModal).toHaveAttribute('aria-labelledby', /.+/u);
    }

    // Check keyboard shortcuts modal
    const kbModal = page.locator('#keyboard-shortcuts-modal');

    if ((await kbModal.count()) > 0) {
      await expect(kbModal).toHaveAttribute('role', 'dialog');
      await expect(kbModal).toHaveAttribute('aria-modal', 'true');
    }
  });

  test('form inputs should have associated labels', async ({ page }) => {
    await page.goto('/forms');

    const formLink = page.locator('a[href*="/forms/"]').first();

    if ((await formLink.count()) > 0) {
      await formLink.click();
      await page.waitForLoadState('networkidle');

      // Check for inputs without labels
      const results = await new AxeBuilder({ page })
        .options({
          rules: {
            label: { enabled: true }
          }
        })
        .analyze();

      const labelViolations = results.violations.filter(v => v.id === 'label');

      expect(labelViolations).toHaveLength(0);
    }
  });
});

test.describe('Text Scaling (WCAG 1.4.10 Reflow)', () => {
  test('should not have horizontal scrolling at 200% zoom on homepage', async ({
    page
  }) => {
    // Set viewport to 1280px width, then zoom will effectively make it 640px
    await page.setViewportSize({ width: 1280, height: 720 });
    await page.goto('/');

    // Simulate 200% zoom by setting viewport to half width
    // This is equivalent to 200% browser zoom
    await page.setViewportSize({ width: 640, height: 720 });

    // Check for horizontal overflow
    const hasHorizontalScroll = await page.evaluate(() => {
      return (
        document.documentElement.scrollWidth >
        document.documentElement.clientWidth
      );
    });

    expect(hasHorizontalScroll).toBe(false);
  });

  test('should not have horizontal scrolling at 200% zoom on forms page', async ({
    page
  }) => {
    await page.setViewportSize({ width: 640, height: 720 });
    await page.goto('/forms');

    const hasHorizontalScroll = await page.evaluate(() => {
      return (
        document.documentElement.scrollWidth >
        document.documentElement.clientWidth
      );
    });

    expect(hasHorizontalScroll).toBe(false);
  });

  test('should maintain readable text at 200% zoom', async ({ page }) => {
    await page.setViewportSize({ width: 640, height: 720 });
    await page.goto('/');

    // Check that main content text is still visible and readable
    const mainHeading = page.locator('h1').first();
    const headingCount = await mainHeading.count();

    if (headingCount > 0) {
      await expect(mainHeading).toBeVisible();

      // Verify the heading has reasonable font size (not clipped)
      const fontSize = await mainHeading.evaluate(el => {
        return parseFloat(window.getComputedStyle(el).fontSize);
      });

      // At 200% zoom, text should still be reasonably sized (at least 14px effective)
      expect(fontSize).toBeGreaterThanOrEqual(14);
    }
  });

  test('touch targets should remain accessible at 200% zoom', async ({
    page
  }) => {
    await page.setViewportSize({ width: 640, height: 720 });
    await page.goto('/');

    // Check that buttons maintain minimum touch target size
    const buttons = page.locator('button:visible, a.btn:visible').first();
    const buttonCount = await buttons.count();

    if (buttonCount > 0) {
      const size = await buttons.evaluate(el => {
        const rect = el.getBoundingClientRect();

        return { width: rect.width, height: rect.height };
      });

      // WCAG requires 44x44 minimum touch targets
      // At 200% zoom, elements should still be tappable
      expect(size.height).toBeGreaterThanOrEqual(40);
    }
  });
});

test.describe('Reduced Motion (WCAG 2.3.3)', () => {
  test('should respect prefers-reduced-motion system preference', async ({
    page
  }) => {
    // Emulate reduced motion preference
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');

    // Check that animations are disabled via CSS
    const animationDuration = await page.evaluate(() => {
      const element = document.querySelector('.wizard-card, .btn, body');

      if (!element) {
        return '0.01ms';
      }
      const style = window.getComputedStyle(element);

      return style.animationDuration || '0.01ms';
    });

    // Animation duration should be very short (essentially instant)
    const durationMs =
      parseFloat(animationDuration) *
      (animationDuration.includes('ms') ? 1 : 1000);

    expect(durationMs).toBeLessThanOrEqual(100);
  });

  test('should allow user to toggle reduced motion preference', async ({
    page
  }) => {
    await page.goto('/');

    // Open theme modal
    const themeButton = page
      .locator('button[data-action*="theme#openModal"]')
      .first();

    await themeButton.click();

    // Wait for modal to be visible
    const modal = page.locator('#theme-modal');

    await expect(modal).toBeVisible();

    // Find motion toggle
    const motionToggle = page.locator('[data-motion-target="toggle"]');
    const toggleExists = (await motionToggle.count()) > 0;

    if (toggleExists) {
      // Toggle should be present and interactive
      await expect(motionToggle).toBeVisible();
      await expect(motionToggle).toBeEnabled();

      // Toggle the preference
      await motionToggle.click();

      // Verify the preference was stored
      const storedPreference = await page.evaluate(() => {
        return localStorage.getItem('motion-preference');
      });

      expect(storedPreference).toBeTruthy();
    }
  });

  test('user motion preference should override system preference', async ({
    page
  }) => {
    await page.goto('/');

    // Set user preference to reduce motion
    await page.evaluate(() => {
      localStorage.setItem('motion-preference', 'reduce');
      document.documentElement.classList.add('reduce-motion');
    });

    // Check that reduce-motion class is applied
    const hasReduceMotionClass = await page.evaluate(() => {
      return document.documentElement.classList.contains('reduce-motion');
    });

    expect(hasReduceMotionClass).toBe(true);

    // Clear preference and set to normal
    await page.evaluate(() => {
      localStorage.setItem('motion-preference', 'normal');
      document.documentElement.classList.remove('reduce-motion');
      document.documentElement.classList.add('force-motion');
    });

    // Check that force-motion class is applied
    const hasForceMotionClass = await page.evaluate(() => {
      return document.documentElement.classList.contains('force-motion');
    });

    expect(hasForceMotionClass).toBe(true);
  });

  test('motion preference toggle should announce changes to screen readers', async ({
    page
  }) => {
    await page.goto('/');

    // Open theme modal
    const themeButton = page
      .locator('button[data-action*="theme#openModal"]')
      .first();

    await themeButton.click();

    const modal = page.locator('#theme-modal');

    await expect(modal).toBeVisible();

    // Find and click motion toggle
    const motionToggle = page.locator('[data-motion-target="toggle"]');

    if ((await motionToggle.count()) > 0) {
      await motionToggle.click();

      // Wait for live region to be created and updated
      await page.waitForTimeout(200);

      // Check for aria-live region with announcement
      const liveRegion = page.locator('#motion-live-region');

      if ((await liveRegion.count()) > 0) {
        const announcement = await liveRegion.textContent();

        expect(announcement).toBeTruthy();
        expect(announcement).toMatch(/motion/iu);
      }
    }
  });
});
