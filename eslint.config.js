'use strict';

const configAckamaBase = require('eslint-config-ackama');
const configAckamaJest = require('eslint-config-ackama/jest');
const pluginJestDOM = require('eslint-plugin-jest-dom');
const pluginTestingLibrary = require('eslint-plugin-testing-library');
const pluginSonarjs = require('eslint-plugin-sonarjs');
const globals = require('globals');

/** @type {import('eslint').Linter.FlatConfig[]} */
const config = [
  { files: ['**/*.{js,jsx,cjs,mjs}'] },
  { ignores: ['tmp/*', 'app/assets/builds/*'] },
  ...configAckamaBase,
  // SonarJS recommended rules for code quality and DRY
  pluginSonarjs.configs.recommended,
  {
    ignores: [
      'config/webpack/*',
      'babel.config.js',
      'eslint.config.js',
      'jest.config.js',
      '.stylelintrc.js',
      'playwright.config.js',
      'tailwind.config.js',
      'esbuild.config.mjs',
      'tests/**'
    ],
    languageOptions: {
      globals: {
        ...globals.browser,
        process: 'readonly'
      }
    },
    rules: {
      // Allow anonymous default exports for Stimulus controllers (common pattern)
      'import/no-anonymous-default-export': 'off',
      // Allow nested ternary in some cases
      'no-nested-ternary': 'warn',

      // ===========================================
      // DRY (Don't Repeat Yourself) Rules
      // ===========================================

      // Detect identical functions - key DRY rule
      'sonarjs/no-identical-functions': 'warn',

      // Detect duplicate string literals (3+ occurrences)
      'sonarjs/no-duplicate-string': ['warn', { threshold: 3 }],

      // Detect copy-pasted code blocks
      'sonarjs/no-duplicated-branches': 'warn',

      // Cognitive complexity - encourages breaking down complex functions
      'sonarjs/cognitive-complexity': ['warn', 15],

      // Detect collapsible if statements
      'sonarjs/no-collapsible-if': 'warn',

      // Detect redundant boolean expressions
      'sonarjs/no-redundant-boolean': 'warn',

      // Detect identical conditions in if-else chains
      'sonarjs/no-identical-conditions': 'error',

      // Detect unused collection elements
      'sonarjs/no-collection-size-mischeck': 'error',

      // Prefer object literal over switch for simple mappings
      'sonarjs/prefer-object-literal': 'warn',

      // Disable overly strict SonarJS rules not related to DRY
      'sonarjs/public-static-readonly': 'off',  // Too strict for Stimulus
      'sonarjs/void-use': 'off'                 // void is used for intentional side effects
    }
  },
  {
    files: ['esbuild.config.mjs'],
    languageOptions: {
      sourceType: 'module',
      globals: { ...globals.node }
    }
  },
  {
    files: [
      'config/webpack/*',
      'babel.config.js',
      'eslint.config.js',
      'jest.config.js',
      '.stylelintrc.js',
      'playwright.config.js',
      'tailwind.config.js',
      'tests/**/*.js'
    ],
    languageOptions: {
      sourceType: 'commonjs',
      globals: { ...globals.node }
    },
    rules: {
      'strict': ['error', 'global'],
      'n/global-require': 'off'
    }
  },
  {
    files: ['app/javascript/packs/*.js'],
    languageOptions: { globals: { require: 'readonly' } }
  },
  ...[
    pluginJestDOM.configs['flat/recommended'],
    pluginTestingLibrary.configs['flat/dom'],
    ...configAckamaJest,
    /** @type {import('eslint').Linter.FlatConfig} */ ({
      rules: {
        'jest/prefer-expect-assertions': 'off',
        'jest/require-hook': 'off',
        'no-undef': 'off',
        'init-declarations': 'off',
        'require-unicode-regexp': 'off',
        'testing-library/no-node-access': 'warn'
      }
    })
  ].map(c => ({ ...c, files: ['spec/javascript/**'] })),
  // Playwright test files
  {
    files: ['tests/**/*.js'],
    languageOptions: {
      globals: {
        ...globals.node,
        document: 'readonly',
        window: 'readonly'
      }
    },
    rules: {
      'no-undef': 'off',
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-await-in-loop': 'warn'
    }
  }
];

module.exports = config;
