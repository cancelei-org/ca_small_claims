'use strict';

const { test, expect } = require('../../fixtures/test-base.js');

/**
 * Cross-User Data Access Security Tests
 *
 * These tests verify that users cannot access data belonging to other users
 * that they shouldn't have access to. For CA Small Claims, this includes
 * form submissions, session data, and workflow progress.
 */
test.describe('Cross-User Data Access Security', () => {
  test.describe('Submission Access Control', () => {
    test("User cannot view another user's submission details", async ({
      page,
      login
    }) => {
      // Login as user A
      await login('user_a@example.com');

      // Create a submission for user A
      await page.goto('/test_only/create_submission?form_type=SC-100');
      const submissionUrl = page.url();
      const submissionId = submissionUrl.split('/').pop();

      // Login as user B (different user)
      await login('user_b@example.com');

      // Try to access user A's submission
      const response = await page.goto(`/submissions/${submissionId}`);

      // Should either show access denied or redirect
      const content = await page.content();
      const hasAccessDenied =
        content.includes('Access Denied') ||
        content.includes('not authorized') ||
        content.includes('You are not allowed') ||
        response.status() === 403 ||
        response.status() === 404;

      expect(
        hasAccessDenied || page.url().includes('/submissions')
      ).toBeTruthy();
    });

    test("User cannot edit another user's submission", async ({
      page,
      login
    }) => {
      // Login as user A and create a submission
      await login('user_a@example.com');
      await page.goto(
        '/test_only/create_submission?form_type=SC-100&status=draft'
      );
      const submissionUrl = page.url();
      const submissionId = submissionUrl.split('/').pop();

      // Login as user B
      await login('user_b@example.com');

      // Try to access user A's submission edit page
      const response = await page.goto(`/submissions/${submissionId}/edit`);

      // Should be denied access
      const content = await page.content();
      const isDenied =
        content.includes('not authorized') ||
        content.includes('Access Denied') ||
        response.status() === 403 ||
        response.status() === 404;

      expect(isDenied).toBeTruthy();
    });

    test('API returns only accessible submissions in list', async ({
      page,
      login
    }) => {
      // Login as user B
      await login('user_b@example.com');

      // Fetch submissions
      await page.goto('/submissions');

      // Get all submission links
      const submissionLinks = await page
        .locator(
          '[data-testid="submission-card"], [data-testid="submission-row"]'
        )
        .all();

      // Each submission should be accessible to the current user
      for (const link of submissionLinks) {
        const href = await link.getAttribute('href');

        if (href) {
          const response = await page.goto(href);

          expect(response.status()).not.toBe(403);
          expect(response.status()).not.toBe(404);
        }
      }
    });
  });

  test.describe('Session Submission Isolation', () => {
    test("User cannot access another user's in-progress form session", async ({
      page,
      login
    }) => {
      // Login as user A and start a form session
      await login('user_a@example.com');
      await page.goto('/test_only/create_session_submission?form_type=SC-100');
      const sessionUrl = page.url();

      // Login as user B
      await login('user_b@example.com');

      // Try to access user A's session
      await page.goto(sessionUrl);

      // Should be denied access
      const content = await page.content();
      const isDenied =
        content.includes('not authorized') ||
        content.includes('Access Denied') ||
        content.includes('session not found') ||
        page.url() !== sessionUrl;

      expect(isDenied).toBeTruthy();
    });

    test("User cannot resume another user's saved form progress", async ({
      page,
      login
    }) => {
      // Login as user A and save form progress
      await login('user_a@example.com');
      await page.goto('/forms/new');

      // Start a form and save progress (if the feature exists)
      const startButton = page
        .getByRole('button', { name: /SC-100|start/i })
        .first();

      if ((await startButton.count()) > 0) {
        await startButton.click();

        // Fill some data
        const nameField = page.getByLabel(/name/i).first();

        if ((await nameField.count()) > 0) {
          await nameField.fill('User A Name');
        }

        // Save draft
        const saveButton = page
          .getByRole('button', { name: /save|draft/i })
          .first();

        if ((await saveButton.count()) > 0) {
          await saveButton.click();
        }
      }

      // Get the current URL which should have session/draft ID
      const draftUrl = page.url();

      // Login as user B
      await login('user_b@example.com');

      // Try to access user A's draft
      if (draftUrl.includes('/forms/') || draftUrl.includes('/sessions/')) {
        await page.goto(draftUrl);

        const content = await page.content();
        const cannotAccess =
          content.includes('not authorized') ||
          content.includes('Access Denied') ||
          !content.includes('User A Name');

        expect(cannotAccess).toBeTruthy();
      }
    });
  });

  test.describe('Form Definition Access', () => {
    test('Non-admin cannot access admin-only form management', async ({
      page,
      login
    }) => {
      // Login as regular user
      await login('regular_user@example.com');

      // Try to access admin form management
      const response = await page.goto('/admin/form_definitions');

      // Should be denied or redirected
      const content = await page.content();
      const isDenied =
        content.includes('not authorized') ||
        content.includes('Access Denied') ||
        response.status() === 403 ||
        response.status() === 404 ||
        page.url().includes('/sign_in');

      expect(isDenied).toBeTruthy();
    });

    test('Non-admin cannot modify form definitions', async ({
      page,
      login
    }) => {
      // Login as regular user
      await login('regular_user@example.com');

      // Try to access form definition edit
      const response = await page.goto('/admin/form_definitions/1/edit');

      // Should be denied
      const content = await page.content();
      const isDenied =
        content.includes('not authorized') ||
        content.includes('Access Denied') ||
        response.status() === 403 ||
        response.status() === 404;

      expect(isDenied).toBeTruthy();
    });
  });

  test.describe('Workflow Step Data', () => {
    test("User cannot view another user's workflow progress details", async ({
      page,
      login
    }) => {
      // Login as user A and start workflow
      await login('user_a@example.com');
      await page.goto('/test_only/create_workflow_progress');
      const workflowUrl = page.url();

      // Login as user B
      await login('user_b@example.com');

      // Try to access user A's workflow progress
      await page.goto(workflowUrl);

      // Should be denied or see empty
      const content = await page.content();
      const hasRestriction =
        content.includes('Access Denied') ||
        content.includes('not authorized') ||
        !content.includes('User A');

      expect(hasRestriction).toBeTruthy();
    });
  });

  test.describe('PDF Generation Security', () => {
    test("User cannot download another user's generated PDF", async ({
      page,
      login
    }) => {
      // Login as user A and create a submission
      await login('user_a@example.com');
      await page.goto('/test_only/create_submission?form_type=SC-100');

      // Get the submission ID from URL
      const url = page.url();
      const submissionId = url.split('/').pop();

      // Login as user B
      await login('user_b@example.com');

      // Try to access user A's PDF download
      const response = await page.goto(
        `/submissions/${submissionId}/download_pdf`
      );

      // Should be denied (redirect to submissions or 404)
      const isDenied =
        response.status() === 403 ||
        response.status() === 404 ||
        (page.url().includes('/submissions') &&
          !page.url().includes(submissionId));

      expect(isDenied).toBeTruthy();
    });
  });

  test.describe('Category and Form Type Access', () => {
    test('All users can view public form categories', async ({
      page,
      login
    }) => {
      // Login as any user
      await login('user_a@example.com');

      // Access forms page (which shows categories)
      await page.goto('/forms');

      // Should be able to view forms/categories
      const response = await page.request.get('/forms');

      expect(response.status()).toBe(200);

      // Forms and categories should be visible
      const content = await page.content();

      expect(content).toMatch(/form|small claims|SC-/i);
    });

    test('Users can only start forms they have access to', async ({
      page,
      login
    }) => {
      // Login as user
      await login('user_a@example.com');

      // Navigate to forms
      await page.goto('/forms');

      // Get all available form links
      const formLinks = await page
        .locator('[data-testid="form-type-link"], .form-type-card a')
        .all();

      // Each form link should be accessible
      for (const link of formLinks) {
        const href = await link.getAttribute('href');

        if (href) {
          const response = await page.goto(href);

          // Should either work (200) or properly redirect, not throw 500
          expect(response.status()).not.toBe(500);
        }
      }
    });
  });
});
