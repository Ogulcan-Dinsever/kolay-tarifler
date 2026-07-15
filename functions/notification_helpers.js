'use strict';

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function normalizeTokens(userData = {}) {
  const tokens = Array.isArray(userData.fcmTokens)
    ? userData.fcmTokens.filter((token) => typeof token === 'string' && token)
    : [];
  if (typeof userData.fcmToken === 'string' && userData.fcmToken) {
    tokens.push(userData.fcmToken);
  }
  return [...new Set(tokens)].slice(0, 500);
}

function stringifyData(data = {}) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, String(value)])
  );
}

function isInvalidTokenError(code) {
  return INVALID_TOKEN_CODES.has(code);
}

function invalidTokensFromResponses(tokens, responses) {
  return responses.flatMap((response, index) =>
    !response.success && isInvalidTokenError(response.error?.code)
      ? [tokens[index]]
      : []
  );
}

module.exports = {
  normalizeTokens,
  stringifyData,
  isInvalidTokenError,
  invalidTokensFromResponses,
};
