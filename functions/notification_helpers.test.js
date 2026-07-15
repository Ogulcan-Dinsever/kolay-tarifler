'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeTokens,
  stringifyData,
  isInvalidTokenError,
  invalidTokensFromResponses,
} = require('./notification_helpers');

test('normalizeTokens merges legacy and multi-device tokens without duplicates', () => {
  assert.deepEqual(
    normalizeTokens({fcmToken: 'phone-a', fcmTokens: ['phone-a', 'phone-b']}),
    ['phone-a', 'phone-b']
  );
});

test('normalizeTokens ignores malformed values', () => {
  assert.deepEqual(normalizeTokens({fcmToken: 12, fcmTokens: ['', null, 'ok']}), ['ok']);
});

test('stringifyData creates an FCM-compatible string map', () => {
  assert.deepEqual(stringifyData({type: 'pending_recipe', id: 42}), {
    type: 'pending_recipe',
    id: '42',
  });
});

test('invalidTokensFromResponses selects only permanently invalid tokens', () => {
  const responses = [
    {success: true},
    {success: false, error: {code: 'messaging/registration-token-not-registered'}},
    {success: false, error: {code: 'messaging/internal-error'}},
  ];
  assert.deepEqual(
    invalidTokensFromResponses(['good', 'invalid', 'temporary'], responses),
    ['invalid']
  );
  assert.equal(isInvalidTokenError('messaging/invalid-registration-token'), true);
  assert.equal(isInvalidTokenError('messaging/internal-error'), false);
});
