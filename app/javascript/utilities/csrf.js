/**
 * CSRF token utilities for making secure requests.
 * Provides centralized access to Rails CSRF token.
 *
 * Usage:
 *   import { csrfToken, csrfHeaders } from "utilities/csrf"
 *
 *   // Get just the token
 *   const token = csrfToken()
 *
 *   // Get headers for fetch requests
 *   fetch(url, {
 *     method: "PATCH",
 *     headers: {
 *       ...csrfHeaders(),
 *       "Accept": "application/json"
 *     },
 *     body: formData
 *   })
 */

/**
 * Get the CSRF token from the meta tag.
 *
 * @returns {string|null} - The CSRF token or null if not found
 */
export function csrfToken() {
  const metaTag = document.querySelector("meta[name='csrf-token']");

  return metaTag ? metaTag.content : null;
}

/**
 * Get the CSRF parameter name from the meta tag.
 *
 * @returns {string|null} - The CSRF parameter name or null if not found
 */
export function csrfParam() {
  const metaTag = document.querySelector("meta[name='csrf-param']");

  return metaTag ? metaTag.content : null;
}

/**
 * Get headers object with CSRF token for fetch requests.
 *
 * @returns {Object} - Headers object with X-CSRF-Token
 */
export function csrfHeaders() {
  const token = csrfToken();

  return token ? { 'X-CSRF-Token': token } : {};
}

/**
 * Add CSRF token to a FormData object.
 *
 * @param {FormData} formData - The FormData to modify
 * @returns {FormData} - The modified FormData
 */
export function addCsrfToFormData(formData) {
  const param = csrfParam();
  const token = csrfToken();

  if (param && token) {
    formData.set(param, token);
  }

  return formData;
}

export default csrfToken;
