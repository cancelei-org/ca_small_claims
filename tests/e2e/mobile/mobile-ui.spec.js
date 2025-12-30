'use strict';

const { test, expect } = require('@playwright/test');

test.describe('Mobile UI Rendering', () => {
  test.use({ viewport: { width: 375, height: 812 } }); // iPhone X dimensions

  test('homepage renders correctly on mobile', async ({ page }) => {
    await page.goto('/');

    // Take screenshot for visual inspection
    await page.screenshot({
      path: 'tests/screenshots/mobile-homepage.png',
      fullPage: true
    });

    // Check that the page loads
    await expect(page).toHaveTitle(/.*/);

    // Check for horizontal overflow (common mobile issue)
    const hasHorizontalOverflow = await page.evaluate(() => {
      return (
        document.documentElement.scrollWidth >
        document.documentElement.clientWidth
      );
    });

    if (hasHorizontalOverflow) {
      console.log('WARNING: Horizontal overflow detected on homepage');
    }

    // Check all visible elements are within viewport
    const elementsOutOfBounds = await page.evaluate(() => {
      const issues = [];
      const viewportWidth = window.innerWidth;
      const elements = document.querySelectorAll('*');

      elements.forEach(el => {
        const rect = el.getBoundingClientRect();

        if (rect.width > 0 && rect.right > viewportWidth + 10) {
          const tagName = el.tagName.toLowerCase();
          const className = el.className
            ? `.${el.className.split(' ')[0]}`
            : '';
          const id = el.id ? `#${el.id}` : '';

          issues.push({
            element: `${tagName}${id}${className}`,
            right: Math.round(rect.right),
            viewportWidth
          });
        }
      });

      return issues.slice(0, 10); // Limit to first 10 issues
    });

    if (elementsOutOfBounds.length > 0) {
      console.log('Elements extending beyond viewport:', elementsOutOfBounds);
    }

    expect(hasHorizontalOverflow).toBe(false);
  });

  test('navigation menu is accessible on mobile', async ({ page }) => {
    await page.goto('/');

    // Check for mobile menu button (hamburger)
    const mobileMenuButton = page.locator(
      '[data-testid="mobile-menu"], .hamburger, .menu-toggle, [aria-label*="menu"], button:has(.hamburger-icon), [class*="mobile-menu"]'
    );

    // If no mobile menu button, check if nav items are visible
    const navItems = page.locator('nav a, header a');
    const navItemsCount = await navItems.count();

    // Screenshot for debugging
    await page.screenshot({ path: 'tests/screenshots/mobile-nav.png' });

    console.log(`Found ${navItemsCount} nav items`);

    // Check if navigation is properly visible or hidden behind menu
    if ((await mobileMenuButton.count()) > 0) {
      console.log('Mobile menu button found');
      await mobileMenuButton.first().click();
      await page.waitForTimeout(300); // Wait for animation
      await page.screenshot({ path: 'tests/screenshots/mobile-nav-open.png' });
    }
  });

  test('forms are usable on mobile', async ({ page }) => {
    await page.goto('/forms');

    // Take screenshot
    await page.screenshot({
      path: 'tests/screenshots/mobile-forms.png',
      fullPage: true
    });

    // Check for form elements that might be too small
    const smallTouchTargets = await page.evaluate(() => {
      const issues = [];
      const minTouchSize = 44; // Apple's recommended minimum

      const interactiveElements = document.querySelectorAll(
        'button, a, input, select, textarea, [role="button"]'
      );

      interactiveElements.forEach(el => {
        const rect = el.getBoundingClientRect();

        if (rect.width > 0 && rect.height > 0) {
          if (rect.height < minTouchSize || rect.width < minTouchSize) {
            const tagName = el.tagName.toLowerCase();
            const text = el.textContent?.substring(0, 20) || '';

            issues.push({
              element: tagName,
              text: text.trim(),
              width: Math.round(rect.width),
              height: Math.round(rect.height)
            });
          }
        }
      });

      return issues.slice(0, 10);
    });

    if (smallTouchTargets.length > 0) {
      console.log('Touch targets too small (< 44px):', smallTouchTargets);
    }
  });

  test('text is readable on mobile', async ({ page }) => {
    await page.goto('/');

    // Check for text that's too small
    const smallText = await page.evaluate(() => {
      const issues = [];
      const minFontSize = 14; // Minimum readable size on mobile

      const textElements = document.querySelectorAll(
        'p, span, a, li, td, th, label, h1, h2, h3, h4, h5, h6'
      );

      textElements.forEach(el => {
        const style = window.getComputedStyle(el);
        const fontSize = parseFloat(style.fontSize);

        if (fontSize < minFontSize && el.textContent?.trim().length > 0) {
          const text = el.textContent.substring(0, 30);

          issues.push({
            element: el.tagName.toLowerCase(),
            text: text.trim(),
            fontSize: Math.round(fontSize)
          });
        }
      });

      return issues.slice(0, 10);
    });

    if (smallText.length > 0) {
      console.log('Text too small (< 14px):', smallText);
    }
  });

  test('check all pages for mobile issues', async ({ page }) => {
    const pagesToCheck = [
      '/',
      '/forms',
      '/users/sign_in',
      '/users/sign_up',
      '/forms/SC-104'
    ];

    for (const pageUrl of pagesToCheck) {
      try {
        await page.goto(pageUrl);
        await page.waitForLoadState('networkidle');

        const hasOverflow = await page.evaluate(() => {
          return (
            document.documentElement.scrollWidth >
            document.documentElement.clientWidth
          );
        });

        const filename =
          pageUrl.replace(/\//g, '-').replace(/^-/, '') || 'home';

        await page.screenshot({
          path: `tests/screenshots/mobile-${filename}.png`,
          fullPage: true
        });

        console.log(`${pageUrl}: ${hasOverflow ? 'HAS OVERFLOW' : 'OK'}`);
      } catch (e) {
        console.log(`${pageUrl}: Error - ${e.message}`);
      }
    }
  });

  test('form detail page mobile layout', async ({ page }) => {
    await page.goto('/forms/SC-104');
    await page.waitForLoadState('networkidle');

    // Take screenshot
    await page.screenshot({
      path: 'tests/screenshots/mobile-form-detail.png',
      fullPage: true
    });

    // Check for horizontal overflow
    const hasOverflow = await page.evaluate(() => {
      return (
        document.documentElement.scrollWidth >
        document.documentElement.clientWidth
      );
    });

    if (hasOverflow) {
      console.log('WARNING: Horizontal overflow on form detail page');
    }

    // Check action buttons touch targets
    const smallButtons = await page.evaluate(() => {
      const issues = [];
      const buttons = document.querySelectorAll(
        'button, a.inline-flex, input[type="submit"]'
      );

      buttons.forEach(btn => {
        const rect = btn.getBoundingClientRect();

        if (rect.width > 0 && rect.height < 44) {
          issues.push({
            text:
              btn.textContent?.trim().substring(0, 30) || btn.value || 'button',
            height: Math.round(rect.height),
            width: Math.round(rect.width)
          });
        }
      });

      return issues;
    });

    if (smallButtons.length > 0) {
      console.log('Buttons too small on form page:', smallButtons);
    }

    // Check if buttons wrap properly on mobile
    const buttonContainer = await page
      .locator('.bg-gray-50.border-t')
      .boundingBox();

    if (buttonContainer) {
      console.log('Button container height:', buttonContainer.height);
    }
  });
});
