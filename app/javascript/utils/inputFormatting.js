/**
 * Input Formatting Utilities
 * Shared functions for formatting user input (phone, ZIP, currency, etc.)
 */

/**
 * Format ZIP code as XXXXX or XXXXX-XXXX
 * @param {string} value - The raw input value
 * @returns {string} The formatted ZIP code
 */
export function formatZip(value) {
  // Remove all non-digits
  const digits = String(value || '').replace(/\D/gu, '');

  // Limit to 9 digits
  const limited = digits.slice(0, 9);

  // Format with dash for ZIP+4
  if (limited.length <= 5) {
    return limited;
  }

  return `${limited.slice(0, 5)}-${limited.slice(5)}`;
}

/**
 * Format phone number as (XXX) XXX-XXXX
 * @param {string} value - The raw input value
 * @returns {string} The formatted phone number
 */
export function formatPhone(value) {
  // Remove all non-digits
  const digits = String(value || '').replace(/\D/gu, '');

  // Limit to 10 digits
  const limited = digits.slice(0, 10);

  // Format progressively
  if (limited.length < 4) {
    return limited;
  }

  if (limited.length < 7) {
    return `(${limited.slice(0, 3)}) ${limited.slice(3)}`;
  }

  return `(${limited.slice(0, 3)}) ${limited.slice(3, 6)}-${limited.slice(6)}`;
}

/**
 * Format currency value with commas and 2 decimal places
 * @param {string} value - The raw input value
 * @returns {string} The formatted currency string (without $ symbol)
 */
export function formatCurrency(value) {
  // Remove all except digits and decimal
  const cleaned = String(value || '').replace(/[^\d.]/gu, '');

  // Handle empty input
  if (!cleaned) {
    return '';
  }

  // Split by decimal point and take only first decimal
  const parts = cleaned.split('.');
  const integerPart = parts[0] || '0';
  const decimalPart = parts[1] ? parts[1].slice(0, 2) : '';

  // Add commas to integer part
  const withCommas = integerPart.replace(/\B(?=(\d{3})+(?!\d))/gu, ',');

  // Return with or without decimal
  if (decimalPart || cleaned.includes('.')) {
    return `${withCommas}.${decimalPart}`;
  }

  return withCommas;
}

/**
 * Get raw numeric value from formatted input
 * @param {string} value - The formatted value
 * @param {'phone' | 'currency' | 'zip'} type - The format type
 * @returns {string} The raw numeric value
 */
export function getRawValue(value, type) {
  const str = String(value || '');

  switch (type) {
    case 'phone':
    case 'zip':
      return str.replace(/\D/gu, '');
    case 'currency':
      return str.replace(/[^\d.]/gu, '');
    default:
      return str;
  }
}
