/**
 * Yeni tarif oluşturma scripti — NePisirsem
 *
 * new_recipes.json içindeki her tarif için:
 *   1. İsim Firestore'da zaten varsa ATLA (duplicate yazma yok).
 *   2. Malzemeleri isimle Firestore ingredients'tan çöz; yoksa ing_<maxN+1> oluştur
 *      (Firestore + master asset JSON'a ekle). Kategori enum adıyla yazılır.
 *   3. Yeni recipe dokümanı (auto docId) oluştur: tüm alanlar + createdAt/modifiedAt.
 *   4. assets/data/turk_yemekleri_100.json'a da ekle (repo source-of-truth).
 *
 * DRY-RUN default. Gerçek yazma: node scripts/create_recipes.js --commit
 */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const COMMIT = process.argv.includes('--commit');
const ASSET_YEMEK = path.join(__dirname, '../assets/data/turk_yemekleri_100.json');
const ASSET_MALZ = path.join(__dirname, '../assets/data/turk_malzemeleri.json');
const NEW = path.join(__dirname, 'new_recipes.json');
const KEYFILE = path.join(__dirname, 'serviceAccountKey.json');

for (const [f, n] of [[KEYFILE, 'serviceAccountKey.json'], [NEW, 'new_recipes.json']]) {
  if (!fs.existsSync(f)) { console.error(`❌ scripts/${n} yok.`); process.exit(1); }
}

admin.initializeApp({ credential: admin.credential.cert(require(KEYFILE)) });
const db = admin.firestore();

const yemekler = JSON.parse(fs.readFileSync(ASSET_YEMEK, 'utf8'));
const malzemeler = JSON.parse(fs.readFileSync(ASSET_MALZ, 'utf8'));
const newRecipes = JSON.parse(fs.readFileSync(NEW, 'utf8'));
const norm = s => (s || '').toLowerCase().trim();

const ENUM_TO_TR = { vegetable:'sebze', fruit:'meyve', meat:'et', seafood:'balik',
  dairy:'sut', grain:'tahil', spice:'baharat', oil:'yag', nut:'kuruyemis', egg:'yumurta', other:'diger' };
const ENUM = Object.keys(ENUM_TO_TR);

(async () => {
  console.log(`🍳 create_recipes — ${COMMIT ? 'COMMIT (gerçek yazma)' : 'DRY-RUN'}\n`);

  const recSnap = await db.collection('recipes').get();
  const existingNames = new Set();
  recSnap.forEach(d => existingNames.add(norm(d.data().name)));

  const ingSnap = await db.collection('ingredients').get();
  const nameToIngId = {};
  let maxIngN = 0;
  ingSnap.forEach(d => {
    nameToIngId[norm(d.data().name)] = d.id;
    const m = /^ing_(\d+)$/.exec(d.id);
    if (m) maxIngN = Math.max(maxIngN, parseInt(m[1], 10));
  });
  console.log(`Firestore: ${recSnap.size} tarif, ${ingSnap.size} malzeme (max ing_${maxIngN})\n`);

  const newIngredients = [];
  function ensureIngredient(name, emoji, category) {
    const key = norm(name);
    if (nameToIngId[key]) return nameToIngId[key];
    const enumCat = ENUM.includes(category) ? category : 'other';
    const docId = `ing_${++maxIngN}`;
    nameToIngId[key] = docId;
    newIngredients.push({ docId, data: { name: name.trim(), emoji: emoji || '🍽️', imageUrl: '', category: enumCat } });
    if (!malzemeler.some(x => norm(x.name) === key)) {
      malzemeler.push({ category: ENUM_TO_TR[enumCat], emoji: emoji || '🍽️', imageUrl: '', name: name.trim() });
    }
    return docId;
  }

  const created = [], skipped = [];
  const toCreate = []; // {docId, data, assetEntry}

  for (const r of newRecipes) {
    if (existingNames.has(norm(r.name))) { skipped.push(`${r.name}: zaten var`); continue; }
    if (!r.steps || r.steps.length < 5) { skipped.push(`${r.name}: adım < 5 (${r.steps?.length||0}) — ATLANDI`); continue; }
    existingNames.add(norm(r.name)); // aynı dosyada tekrar varsa engelle

    const ingredients = r.ingredients.map(ing => ({
      ingredientId: ensureIngredient(ing.name, ing.emoji, ing.category),
      name: ing.name,
      amount: ing.amount,
      ...(ing.emoji ? { emoji: ing.emoji } : {}),
    }));
    const steps = r.steps.map((t, i) => ({ order: i + 1, text: t }));
    const ref = db.collection('recipes').doc();
    const now = admin.firestore.Timestamp.now();

    const data = {
      name: r.name,
      description: r.description || '',
      cuisine: 'Türk',
      type: r.type,
      emoji: r.emoji || '🍽️',
      duration: r.duration || '',
      servings: r.servings || '',
      imageUrls: [],
      imageSources: [],
      ingredients,
      steps,
      tags: r.tags || [],
      isOfficial: true,
      authorId: 'system',
      authorName: '',
      officialLikeCount: typeof r.likes === 'number' ? r.likes : (300 + Math.floor(Math.random() * 3700)),
      communityLikeCount: 0,
      likeCount: 0,
      commentCount: 0,
      createdAt: now,
      modifiedAt: now,
    };

    toCreate.push({ ref, data, name: r.name });
    created.push(`${r.name} → ${ref.id} (${steps.length} adım, ${ingredients.length} malzeme)`);

    // asset JSON
    yemekler.push({
      id: ref.id, name: r.name, description: data.description, cuisine: 'Türk',
      type: r.type, duration: data.duration, servings: data.servings, emoji: data.emoji,
      imageUrls: [], ingredients, steps, tags: data.tags,
      officialLikeCount: data.officialLikeCount, communityLikeCount: 0, likeCount: 0,
      authorId: 'system', authorName: '', isOfficial: true, commentCount: 0,
      createdAt: now.toDate().toISOString(),
    });
  }

  if (COMMIT) {
    for (const ni of newIngredients) await db.collection('ingredients').doc(ni.docId).set(ni.data);
    let batch = db.batch(), n = 0;
    for (const c of toCreate) {
      batch.set(c.ref, c.data);
      if (++n === 400) { await batch.commit(); batch = db.batch(); n = 0; }
    }
    if (n) await batch.commit();
    fs.writeFileSync(ASSET_YEMEK, JSON.stringify(yemekler, null, 1), 'utf8');
    fs.writeFileSync(ASSET_MALZ, JSON.stringify(malzemeler, null, 1), 'utf8');
  }

  console.log(`✅ Oluşturulacak: ${created.length}`);
  created.forEach(x => console.log('   ', x));
  if (newIngredients.length) {
    console.log(`\n🆕 Yeni malzeme: ${newIngredients.length}`);
    newIngredients.forEach(ni => console.log('   ', ni.docId, ':', ni.data.name, '(' + ni.data.category + ')'));
  }
  if (skipped.length) { console.log(`\n⚠️  ATLANAN: ${skipped.length}`); skipped.forEach(x => console.log('   ', x)); }
  console.log(COMMIT ? '\n🎉 Yazma tamam.' : '\n(DRY-RUN — gerçek yazma için --commit)');
  process.exit(0);
})().catch(e => { console.error('❌', e.message); console.error(e.stack); process.exit(1); });
