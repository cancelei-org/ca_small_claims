'use strict';

const config = {
  clearMocks: true,
  restoreMocks: true,
  resetMocks: true,

  testEnvironment: 'jsdom',

  testPathIgnorePatterns: ['config/', 'tests/'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1',
    '^controllers/(.*)$': '<rootDir>/app/javascript/controllers/$1',
    '^utils/(.*)$': '<rootDir>/app/javascript/utils/$1',
    '^utilities/(.*)$': '<rootDir>/app/javascript/utilities/$1'
  },
  transform: {
    '^.+\\.js$': ['@swc/jest']
  },
  setupFilesAfterEnv: [
    './spec/javascript/setupJestDomMatchers.js',
    './spec/javascript/setupExpectEachTestHasAssertions.js',
    './spec/javascript/setupStimulusEnvironment.js'
  ]
};

module.exports = config;
