/**
 * Recipe Update Script — Kolay Tarifler (v2, isim-eşleşmeli)
 *
 * Firestore GERÇEK durumu:
 *   - recipes: rastgele auto-docId. Eşleşme İSİM ile yapılır (24 hedef isim benzersiz doğrulandı).
 *   - ingredients: ing_N şeması. Malzeme İSİM ile Firestore'dan çözülür (JSON index'e güvenilmez).
 *
 * Akış (recipe_patch.json'daki her kayıt için):
 *   1. İsimle Firestore recipe dokümanını bul. 0 veya >1 eşleşme varsa ATLA (yanlış yazma yok).
 *   2. Patch malzemelerini Firestore ingredients'tan isimle çöz. Yoksa yeni ing_<maxN+1> oluştur
 *      (Firestore ingredients + master JSON'a ekle).
 *   3. Recipe dokümanını gerçek docId ile güncelle: ingredients/steps/duration/description/servings + modifiedAt.
 *   4. assets/data JSON'larını da güncelle (repo source-of-truth).
 *
 * DRY-RUN default. Gerçek yazma: node scripts/update_recipes.js --commit
 */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const COMMIT = process.argv.includes('--commit');
const ASSET_YEMEK = path.join(__dirname, '../assets/data/turk_yemekleri_100.json');
const ASSET_MALZ = path.join(__dirname, '../assets/data/turk_malzemeleri.json');
const PATCH = path.join(__dirname, 'recipe_patch.json');
const KEYFILE = path.join(__dirname, 'serviceAccountKey.json');

for (const [f, n] of [[KEYFILE, 'serviceAccountKey.json'], [PATCH, 'recipe_patch.json']]) {
  if (!fs.existsSync(f)) { console.error(`❌ scripts/${n} yok.`); process.exit(1); }
}

admin.initializeApp({ credential: admin.credential.cert(require(KEYFILE)) });
const db = admin.firestore();

const yemekler = JSON.parse(fs.readFileSync(ASSET_YEMEK, 'utf8'));
const malzemeler = JSON.parse(fs.readFileSync(ASSET_MALZ, 'utf8'));
const patch = JSON.parse(fs.readFileSync(PATCH, 'utf8'));
const norm = s => (s || '').toLowerCase().trim();

const ENUM_TO_TR = { vegetable:'sebze', fruit:'meyve', meat:'et', seafood:'balik',
  dairy:'sut', grain:'tahil', spice:'baharat', oil:'yag', nut:'kuruyemis', egg:'yumurta', other:'diger' };

(async () => {
  console.log(`🔧 update_recipes v2 — ${COMMIT ? 'COMMIT (gerçek yazma)' : 'DRY-RUN (yazma yok)'}\n`);

  // --- Firestore haritaları ---
  const recSnap = await db.collection('recipes').get();
  const nameToRecipeIds = {}; // name -> [docId,...]
  recSnap.forEach(d => {
    const n = norm(d.data().name);
    (nameToRecipeIds[n] = nameToRecipeIds[n] || []).push(d.id);
  });

  const ingSnap = await db.collection('ingredients').get();
  const nameToIngId = {};   // name -> ing_docId
  let maxIngN = 0;
  ingSnap.forEach(d => {
    nameToIngId[norm(d.data().name)] = d.id;
    const m = /^ing_(\d+)$/.exec(d.id);
    if (m) maxIngN = Math.max(maxIngN, parseInt(m[1], 10));
  });
  console.log(`Firestore: ${recSnap.size} tarif, ${ingSnap.size} malzeme (max ing_${maxIngN})\n`);

  const newIngredients = []; // {docId, data}
  function ensureIngredient(name, emoji, category) {
    const key = norm(name);
    if (nameToIngId[key]) return nameToIngId[key];
    const enumCat = ENUM_TO_TR[category] ? category : 'other';
    const docId = `ing_${++maxIngN}`;
    const data = { name: name.trim(), emoji: emoji || '🍽️', imageUrl: '', category: enumCat };
    nameToIngId[key] = docId;
    newIngredients.push({ docId, data });
    // master JSON'a Türkçe kategoriyle ekle (zaten varsa tekrar ekleme)
    if (!malzemeler.some(x => norm(x.name) === key)) {
      malzemeler.push({ category: ENUM_TO_TR[enumCat], emoji: emoji || '🍽️', imageUrl: '', name: name.trim() });
    }
    return docId;
  }

  const report = { updated: [], skipped: [] };

  for (const p of patch) {
    const ids = nameToRecipeIds[norm(p.name)] || [];
    if (ids.length === 0) { report.skipped.push(`${p.name}: Firestore'da isim YOK`); continue; }
    if (ids.length > 1) { report.skipped.push(`${p.name}: ${ids.length} eşleşme (belirsiz) — ATLANDI`); continue; }
    const docId = ids[0];

    const ingredients = p.ingredients.map(ing => ({
      ingredientId: ensureIngredient(ing.name, ing.emoji, ing.category),
      name: ing.name,
      amount: ing.amount,
      ...(ing.emoji ? { emoji: ing.emoji } : {}),
    }));
    const steps = p.steps.map((t, i) => ({ order: i + 1, text: t }));

    const update = { ingredients, steps, duration: p.duration, modifiedAt: admin.firestore.Timestamp.now() };
    if (p.description) update.description = p.description;
    if (p.servings) update.servings = p.servings;

    if (COMMIT) await db.collection('recipes').doc(docId).update(update);

    // asset JSON (isimle)
    const aIdx = yemekler.findIndex(x => x.name === p.name);
    if (aIdx >= 0) {
      Object.assign(yemekler[aIdx], {
        ingredients, steps, duration: p.duration,
        ...(p.description ? { description: p.description } : {}),
        ...(p.servings ? { servings: p.servings } : {}),
        modifiedAt: new Date().toISOString(),
      });
    }
    report.updated.push(`${p.name} → ${docId} (${steps.length} adım, ${ingredients.length} malzeme)`);
  }

  if (COMMIT) {
    for (const ni of newIngredients) await db.collection('ingredients').doc(ni.docId).set(ni.data);
    fs.writeFileSync(ASSET_YEMEK, JSON.stringify(yemekler, null, 1), 'utf8');
    fs.writeFileSync(ASSET_MALZ, JSON.stringify(malzemeler, null, 1), 'utf8');
  }

  console.log(`✅ Güncellenecek: ${report.updated.length}`);
  report.updated.forEach(x => console.log('   ', x));
  if (newIngredients.length) {
    console.log(`\n🆕 Yeni malzeme: ${newIngredients.length}`);
    newIngredients.forEach(ni => console.log('   ', ni.docId, ':', ni.data.name, '(' + ni.data.category + ')'));
  }
  if (report.skipped.length) {
    console.log(`\n⚠️  ATLANAN: ${report.skipped.length}`);
    report.skipped.forEach(x => console.log('   ', x));
  }
  console.log(COMMIT ? '\n🎉 Yazma tamam.' : '\n(DRY-RUN — gerçek yazma için --commit)');
  process.exit(0);
})().catch(e => { console.error('❌', e.message); console.error(e.stack); process.exit(1); });
