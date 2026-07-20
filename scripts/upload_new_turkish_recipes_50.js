const admin = require('firebase-admin');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const COMMIT = process.argv.includes('--commit');
const root = path.resolve(__dirname, '..');
const recipes = require('./new_turkish_recipes_50');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'build', 'new-turkish-recipe-image-manifest.json'), 'utf8'));
const serviceAccount = require('./serviceAccountKey.json');
const bucketName = `${serviceAccount.project_id}.firebasestorage.app`;
const recipeAssetPath = path.join(root, 'assets', 'data', 'turk_yemekleri_100.json');
const ingredientAssetPath = path.join(root, 'assets', 'data', 'turk_malzemeleri.json');
const backupDir = path.join(__dirname, 'backups');
const reportDir = path.join(__dirname, 'reports');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount), storageBucket: bucketName });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const norm = value => (value || '').normalize('NFKC').trim().toLocaleLowerCase('tr-TR').replace(/\s+/g, ' ');
const slug = value => value.toLocaleLowerCase('tr-TR').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  .replace(/ı/g, 'i').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const serialize = value => {
  if (value == null) return value;
  if (value instanceof admin.firestore.Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(serialize);
  if (typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serialize(item)]));
  return value;
};
const mimeOf = buffer => buffer[0] === 0xff && buffer[1] === 0xd8 ? 'image/jpeg'
  : buffer.subarray(1, 4).toString() === 'PNG' ? 'image/png' : null;
const extOf = mime => mime === 'image/png' ? 'png' : 'jpg';
const categoryToAsset = { vegetable:'sebze', fruit:'meyve', meat:'et', seafood:'balik', dairy:'sut', grain:'tahil', spice:'baharat', oil:'yag', nut:'kuruyemis', egg:'yumurta', other:'diger' };

async function main() {
  if (recipes.length !== 50 || manifest.length !== 50) throw new Error('50 tariflik paket veya görsel manifesti eksik.');
  const manifestMap = new Map(manifest.map(item => [norm(item.name), item]));
  for (const recipe of recipes) {
    const images = manifestMap.get(norm(recipe.name))?.images || [];
    if (images.length !== 2) throw new Error(`${recipe.name}: iki görsel yok.`);
    for (const image of images) {
      const localPath = path.join(root, image.localPath || '');
      if (!image.page || !image.license || !fs.existsSync(localPath) || fs.statSync(localPath).size < 20000) {
        throw new Error(`${recipe.name}: kaynak veya yerel görsel doğrulaması başarısız.`);
      }
    }
    if (recipe.ingredients.length < 6 || recipe.steps.length < 6) throw new Error(`${recipe.name}: içerik ayrıntısı yetersiz.`);
  }

  const [recipeSnap, ingredientSnap] = await Promise.all([
    db.collection('recipes').get(), db.collection('ingredients').get(),
  ]);
  const liveNames = new Set(recipeSnap.docs.map(doc => norm(doc.data().name)));
  const clashes = recipes.filter(recipe => liveNames.has(norm(recipe.name))).map(recipe => recipe.name);
  if (clashes.length) throw new Error(`Canlı veride zaten bulunan tarifler: ${clashes.join(', ')}`);

  const ingredientByName = new Map();
  let maxIngredientNumber = 0;
  ingredientSnap.forEach(doc => {
    ingredientByName.set(norm(doc.data().name), { id: doc.id, data: doc.data() });
    const match = /^ing_(\d+)$/.exec(doc.id);
    if (match) maxIngredientNumber = Math.max(maxIngredientNumber, Number(match[1]));
  });
  const ingredientAssets = JSON.parse(fs.readFileSync(ingredientAssetPath, 'utf8'));
  const recipeAssets = JSON.parse(fs.readFileSync(recipeAssetPath, 'utf8'));
  const newIngredients = [];
  function ensureIngredient(ingredient) {
    const key = norm(ingredient.name);
    const existing = ingredientByName.get(key);
    if (existing) return existing.id;
    const id = `ing_${++maxIngredientNumber}`;
    const category = Object.hasOwn(categoryToAsset, ingredient.category) ? ingredient.category : 'other';
    const data = { name: ingredient.name.trim(), emoji: ingredient.emoji || '🍽️', imageUrl: '', category };
    ingredientByName.set(key, { id, data });
    newIngredients.push({ id, data });
    if (!ingredientAssets.some(item => norm(item.name) === key)) {
      ingredientAssets.push({ category: categoryToAsset[category], emoji: data.emoji, imageUrl: '', name: data.name });
    }
    return id;
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  fs.mkdirSync(backupDir, { recursive: true });
  fs.mkdirSync(reportDir, { recursive: true });
  const backupPath = path.join(backupDir, `new-turkish-recipes-50-before-${timestamp}.json`);
  fs.writeFileSync(backupPath, JSON.stringify({
    createdAt: new Date().toISOString(),
    projectId: serviceAccount.project_id,
    existingRecipeCount: recipeSnap.size,
    existingIngredientCount: ingredientSnap.size,
    ingredients: ingredientSnap.docs.map(doc => ({ id: doc.id, ...serialize(doc.data()) })),
  }, null, 2) + '\n');
  fs.copyFileSync(recipeAssetPath, path.join(backupDir, `turk_yemekleri_100-before-${timestamp}.json`));
  fs.copyFileSync(ingredientAssetPath, path.join(backupDir, `turk_malzemeleri-before-${timestamp}.json`));

  const prepared = recipes.map(recipe => {
    const ref = db.collection('recipes').doc();
    const ingredients = recipe.ingredients.map(ingredient => ({
      ingredientId: ensureIngredient(ingredient), name: ingredient.name, amount: ingredient.amount,
      ...(ingredient.emoji ? { emoji: ingredient.emoji } : {}),
    }));
    return { recipe, ref, ingredients, selectedImages: manifestMap.get(norm(recipe.name)).images };
  });

  console.log(`PREFLIGHT recipes=50 images=100 newIngredients=${newIngredients.length} mode=${COMMIT ? 'COMMIT' : 'DRY-RUN'}`);
  if (!COMMIT) return;

  const uploadedPaths = [];
  const uploaded = [];
  try {
    for (const item of prepared) {
      const imageResults = [];
      for (let index = 0; index < item.selectedImages.length; index += 1) {
        const image = item.selectedImages[index];
        const localPath = path.join(root, image.localPath);
        const buffer = fs.readFileSync(localPath);
        const contentType = mimeOf(buffer);
        if (!contentType) throw new Error(`${item.recipe.name}: tanınmayan görsel biçimi.`);
        const token = crypto.randomUUID();
        const storagePath = `recipe-images/official/${slug(item.recipe.name)}/${item.ref.id}-${index + 1}.${extOf(contentType)}`;
        await bucket.file(storagePath).save(buffer, {
          resumable: false,
          metadata: { contentType, cacheControl: 'public,max-age=31536000,immutable', metadata: { firebaseStorageDownloadTokens: token } },
        });
        uploadedPaths.push(storagePath);
        const storageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
        imageResults.push({
          storagePath, storageUrl,
          source: {
            provider: image.provider || '', source: image.source || '', title: image.title || '',
            artist: image.artist || '', author: image.artist || '', page: image.page, sourceUrl: image.page,
            license: image.license, licenseUrl: image.licenseUrl || '', modified: false,
            storageBucket: bucketName, storagePath, storageUrl,
          },
        });
      }
      uploaded.push({ ...item, imageResults });
      console.log(`UPLOAD ${uploaded.length}/50 ${item.recipe.name}`);
    }

    const batch = db.batch();
    newIngredients.forEach(item => batch.set(db.collection('ingredients').doc(item.id), item.data));
    const createdAt = admin.firestore.Timestamp.now();
    for (const item of uploaded) {
      const data = {
        name: item.recipe.name, description: item.recipe.description, cuisine: 'Türk', type: item.recipe.type,
        emoji: item.recipe.emoji || '🍽️', duration: item.recipe.duration, servings: item.recipe.servings,
        imageUrls: item.imageResults.map(image => image.storageUrl),
        imageSources: item.imageResults.map(image => image.source), ingredients: item.ingredients,
        steps: item.recipe.steps, tags: item.recipe.tags, isOfficial: true, authorId: 'system', authorName: '',
        officialLikeCount: 0, communityLikeCount: 0, likeCount: 0, commentCount: 0,
        createdAt, modifiedAt: createdAt, imageUpdatedAt: createdAt,
      };
      batch.set(item.ref, data);
      recipeAssets.push({ id: item.ref.id, ...serialize(data) });
    }
    await batch.commit();

    const recipeTemp = `${recipeAssetPath}.${timestamp}.tmp`;
    const ingredientTemp = `${ingredientAssetPath}.${timestamp}.tmp`;
    fs.writeFileSync(recipeTemp, JSON.stringify(recipeAssets, null, 1) + '\n', 'utf8');
    fs.writeFileSync(ingredientTemp, JSON.stringify(ingredientAssets, null, 1) + '\n', 'utf8');
    JSON.parse(fs.readFileSync(recipeTemp, 'utf8'));
    JSON.parse(fs.readFileSync(ingredientTemp, 'utf8'));
    fs.renameSync(recipeTemp, recipeAssetPath);
    fs.renameSync(ingredientTemp, ingredientAssetPath);

    const reportPath = path.join(reportDir, `new-turkish-recipes-50-upload-${timestamp}.json`);
    fs.writeFileSync(reportPath, JSON.stringify({
      timestamp, projectId: serviceAccount.project_id, backupPath,
      recipes: uploaded.map(item => ({ id: item.ref.id, name: item.recipe.name, imageUrls: item.imageResults.map(x => x.storageUrl), storagePaths: item.imageResults.map(x => x.storagePath) })),
      newIngredients,
    }, null, 2) + '\n');
    console.log(`COMMIT recipes=50 images=100 newIngredients=${newIngredients.length}`);
    console.log(`REPORT ${reportPath}`);
    console.log(`BACKUP ${backupPath}`);
  } catch (error) {
    console.error(`ROLLBACK storageObjects=${uploadedPaths.length}`);
    await Promise.allSettled(uploadedPaths.map(storagePath => bucket.file(storagePath).delete({ ignoreNotFound: true })));
    throw error;
  }
}

main().then(() => process.exit(0)).catch(error => { console.error(error.stack || error.message); process.exit(1); });
