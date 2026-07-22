'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  findContentViolation,
  normalize,
  recipeTextValues,
} = require('./content_moderation');

test('normalizes Turkish characters', () => {
  assert.equal(normalize('ŞİDDETLİ ÇÖREK'), 'siddetli corek');
});

test('accepts ordinary recipe instructions', () => {
  assert.equal(
    findContentViolation(['Soğanı kavurup mercimeği ve sıcak suyu ekleyin.']),
    null,
  );
});

test('rejects abusive content', () => {
  assert.equal(findContentViolation(['SİKTİR git']), 'Yasaklı veya saldırgan ifade');
});

test('rejects spam redirects', () => {
  assert.equal(
    findContentViolation(['https://bit.ly/test üzerinden bahis kuponu al']),
    'Spam veya yanıltıcı yönlendirme',
  );
});

test('extracts nested recipe text without image URLs', () => {
  assert.deepEqual(
    recipeTextValues({
      name: 'Çorba',
      imageUrls: ['https://example.com/image.jpg'],
      ingredients: [{ name: 'Mercimek', amount: '1 bardak' }],
      steps: [{ text: 'Pişir' }],
    }),
    ['Çorba', 'Mercimek', '1 bardak', 'Pişir'],
  );
});
