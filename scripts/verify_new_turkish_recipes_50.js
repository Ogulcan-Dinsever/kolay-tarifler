const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('./serviceAccountKey.json');
const recipes = require('./new_turkish_recipes_50');
const bucketName = `${serviceAccount.project_id}.firebasestorage.app`;
const root = path.resolve(__dirname, '..');
const norm = value => (value || '').normalize('NFKC').trim().toLocaleLowerCase('tr-TR').replace(/\s+/g, ' ');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount), storageBucket: bucketName });
const db = admin.firestore();
const bucket = admin.storage().bucket();

(async () => {
  const errors = [];
  const [recipeSnap, ingredientSnap] = await Promise.all([
    db.collection('recipes').where('cuisine', '==', 'Türk').get(),
    db.collection('ingredients').get(),
  ]);
  const expected = new Set(recipes.map(recipe => norm(recipe.name)));
  const created = recipeSnap.docs.filter(doc => expected.has(norm(doc.data().name)));
  const ingredientIds = new Set(ingredientSnap.docs.map(doc => doc.id));
  if (created.length !== 50) errors.push(`Firestore tarif sayısı ${created.length}/50`);

  let urlCount = 0;
  let storageCount = 0;
  for (const doc of created) {
    const data = doc.data();
    if (!Array.isArray(data.imageUrls) || data.imageUrls.length !== 2) errors.push(`${data.name}: imageUrls`);
    if (!Array.isArray(data.imageSources) || data.imageSources.length !== 2) errors.push(`${data.name}: imageSources`);
    if (!Array.isArray(data.steps) || data.steps.length < 6) errors.push(`${data.name}: steps`);
    if (!Array.isArray(data.ingredients) || data.ingredients.length < 6) errors.push(`${data.name}: ingredients`);
    for (const ingredient of data.ingredients || []) {
      if (!ingredientIds.has(ingredient.ingredientId)) errors.push(`${data.name}: eksik malzeme ${ingredient.ingredientId}`);
    }
    for (const source of data.imageSources || []) {
      if (!source.page || !source.license || !source.storagePath) errors.push(`${data.name}: kaynak metadatası`);
      const [exists] = await bucket.file(source.storagePath).exists();
      if (!exists) errors.push(`${data.name}: storage eksik ${source.storagePath}`); else storageCount += 1;
    }
    for (const url of data.imageUrls || []) {
      const response = await fetch(url, { method: 'HEAD' });
      if (!response.ok || !(response.headers.get('content-type') || '').startsWith('image/')) {
        errors.push(`${data.name}: URL ${response.status}`);
      } else urlCount += 1;
    }
  }

  const localRecipes = JSON.parse(fs.readFileSync(path.join(root, 'assets', 'data', 'turk_yemekleri_100.json'), 'utf8'));
  const localNames = new Set(localRecipes.map(recipe => norm(recipe.name)));
  const localMissing = recipes.filter(recipe => !localNames.has(norm(recipe.name))).map(recipe => recipe.name);
  if (localMissing.length) errors.push(`Yerel eksik: ${localMissing.join(', ')}`);

  console.log(JSON.stringify({
    turkishRecipesInFirestore: recipeSnap.size,
    verifiedNewRecipes: created.length,
    verifiedStorageObjects: storageCount,
    reachableImageUrls: urlCount,
    ingredientDocuments: ingredientSnap.size,
    localRecipeEntries: localRecipes.length,
    errors,
  }, null, 2));
  process.exit(errors.length ? 1 : 0);
})().catch(error => { console.error(error.stack || error.message); process.exit(1); });
