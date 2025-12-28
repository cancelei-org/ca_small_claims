/**
 * Puppeteer configuration
 * Uses system Chrome instead of downloading bundled version
 */
module.exports = {
  // Skip Chrome download since we use system Chrome
  skipDownload: true,
  // Use system Chrome
  executablePath: process.env.CHROMIUM_PATH || '/usr/bin/google-chrome',
};
