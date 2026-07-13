// Read-only export used by the ingredient image/deduplication repair.
const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

const db = admin.firestore();

async function main() {
  const [ingredientSnapshot, recipeSnapshot, pendingSnapshot] = await Promise.all([
    db.collection('ingredients').get(),
    db.collection('recipes').get(),
    db.collection('pending_recipes').get(),
  ]);

  const usage = new Map();
  const recipes = [];
  for (const document of recipeSnapshot.docs) {
    const data = document.data();
    const ingredients = Array.isArray(data.ingredients) ? data.ingredients : [];
    recipes.push({
      id: document.id,
      name: data.name || '',
      ingredients: ingredients.map((item) => ({
        ingredientId: item?.ingredientId || '',
        name: item?.name || '',
        amount: item?.amount || '',
      })),
    });
    for (const item of ingredients) {
      if (!item?.ingredientId) continue;
      usage.set(item.ingredientId, (usage.get(item.ingredientId) || 0) + 1);
    }
  }

  const pendingRecipes = pendingSnapshot.docs.map((document) => {
    const data = document.data();
    const ingredients = Array.isArray(data.ingredients) ? data.ingredients : [];
    return {
      id: document.id,
      name: data.name || '',
      ingredients: ingredients.map((item) => ({
        ingredientId: item?.ingredientId || '',
        name: item?.name || '',
        amount: item?.amount || '',
      })),
    };
  });

  const ingredients = ingredientSnapshot.docs
    .map((document) => {
      const data = document.data();
      return {
        id: document.id,
        name: data.name || '',
        category: data.category || '',
        emoji: data.emoji || '',
        imageUrl: data.imageUrl || '',
        usage: usage.get(document.id) || 0,
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name, 'tr'));

  process.stdout.write(JSON.stringify({
    exportedAt: new Date().toISOString(),
    counts: {
      ingredients: ingredients.length,
      recipes: recipes.length,
      pendingRecipes: pendingRecipes.length,
      missingImages: ingredients.filter((item) => !item.imageUrl.trim()).length,
    },
    ingredients,
    recipes,
    pendingRecipes,
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
