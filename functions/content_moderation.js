'use strict';

const BLOCKED_TERMS = new Set([
  'amk',
  'aq',
  'orospu',
  'siktir',
  'sikerim',
  'pic',
  'ibne',
  'geber',
  'oldururum',
  'tecavuz',
  'porn',
  'porno',
  'nude',
  'nudes',
  'onlyfans',
  'kill yourself',
  'kys',
  'fuck you',
]);

const SPAM_PATTERN = /(https?:\/\/|www\.|t\.me\/|wa\.me\/|bit\.ly\/|tinyurl\.com\/|telegram|whatsapp).{0,80}(para|kazanc|bahis|casino|kupon|yatirim|takipci|reklam)/i;
const REPEAT_PATTERN = /(.)\1{9,}/;

function normalize(value) {
  const replacements = {
    ç: 'c',
    ğ: 'g',
    ı: 'i',
    ö: 'o',
    ş: 's',
    ü: 'u',
    â: 'a',
    î: 'i',
    û: 'u',
  };
  let normalized = String(value || '').toLocaleLowerCase('tr-TR');
  for (const [source, target] of Object.entries(replacements)) {
    normalized = normalized.split(source).join(target);
  }
  return normalized
    .replace(/[^a-z0-9@:/._]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function containsPhrase(normalized, phrase) {
  const escaped = phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(^|\\s)${escaped}(\\s|$)`).test(normalized);
}

function findContentViolation(values) {
  for (const rawValue of values) {
    const normalized = normalize(rawValue);
    if (!normalized) continue;

    for (const term of BLOCKED_TERMS) {
      if (containsPhrase(normalized, term)) return 'Yasaklı veya saldırgan ifade';
    }
    if (SPAM_PATTERN.test(normalized)) return 'Spam veya yanıltıcı yönlendirme';
    if (REPEAT_PATTERN.test(normalized)) return 'Tekrarlanan spam içeriği';
  }
  return null;
}

function recipeTextValues(recipe = {}) {
  const ingredients = Array.isArray(recipe.ingredients) ? recipe.ingredients : [];
  const steps = Array.isArray(recipe.steps) ? recipe.steps : [];
  const tags = Array.isArray(recipe.tags) ? recipe.tags : [];
  return [
    recipe.name,
    recipe.description,
    recipe.duration,
    recipe.authorName,
    ...ingredients.flatMap((ingredient) => [ingredient?.name, ingredient?.amount]),
    ...steps.map((step) => step?.text),
    ...tags,
  ].filter((value) => typeof value === 'string');
}

module.exports = {
  findContentViolation,
  normalize,
  recipeTextValues,
};
