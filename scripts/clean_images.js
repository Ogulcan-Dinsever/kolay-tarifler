/**
 * Görsel temizliği:
 *  - Telifli hotlink (nefisyemektarifleri.com, yemek.com) URL'lerini imageUrls'ten SİLER.
 *  - Telifsiz ama Storage'da olmayan (unsplash.com) görselleri indirip Storage'a TAŞIR,
 *    URL'yi firebasestorage download-token linkiyle değiştirir.
 *  - firebasestorage/storage.googleapis linkleri olduğu gibi KORUNUR.
 *
 * node clean_images.js            (dry-run rapor)
 * node clean_images.js --commit   (uygula)
 */
const admin = require('firebase-admin');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const sa = require('./serviceAccountKey.json');

const COMMIT = process.argv.includes('--commit');
const BUCKET = `${sa.project_id}.firebasestorage.app`;
admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();
const LOCAL_RECIPES_PATH = path.join(
  __dirname,
  '..',
  'assets',
  'data',
  'turk_yemekleri_100.json',
);

const COPYRIGHTED = ['nefisyemektarifleri.com', 'yemek.com'];
const MOVE = ['unsplash.com'];           // telifsiz ama hotlink → Storage'a taşı
const KEEP = ['firebasestorage', 'storage.googleapis'];
const LEGACY_UNSPLASH_SOURCES = {
  'Lasagna': 'https://images.unsplash.com/photo-1709429790175-b02bb1b19207',
  'Margherita Pizza': 'https://images.unsplash.com/photo-1664309641932-0e03e0771b97',
  'Tiramisu': 'https://images.unsplash.com/photo-1766232333746-b0a2697d6d0d',
  'Caprese Salatası': 'https://images.unsplash.com/photo-1769458313860-3c8db667d990',
};

const hostOf = u => { try { return new URL(u).host; } catch { return ''; } };
const isCopyrighted = u => COPYRIGHTED.some(c => hostOf(u).includes(c));
const isMove = u => MOVE.some(c => hostOf(u).includes(c));
const isKeep = u => KEEP.some(c => hostOf(u).includes(c));
const isLicensedRemote = u => isKeep(u) || isMove(u) || hostOf(u).includes('pexels.com');
const isAiGeneratedSource = source =>
  (source?.source || source?.provider || '').toLowerCase().startsWith('ai-generated');

function normalizeImageSource(source) {
  const normalized = { ...source };
  const provider = (normalized.provider || normalized.source || '').toLowerCase();
  if (provider === 'pexels') {
    normalized.provider = 'Pexels';
    normalized.license = 'Pexels License';
    normalized.licenseUrl = 'https://www.pexels.com/license/';
  } else if (provider === 'wikimedia') {
    normalized.provider = 'Wikimedia Commons';
  }
  return normalized;
}

function cleanLocalRecipes(liveRecipesByName) {
  const recipes = JSON.parse(fs.readFileSync(LOCAL_RECIPES_PATH, 'utf8'));
  const localNames = new Set();
  let changedRecipes = 0;
  let droppedUrls = 0;
  let syncedFromLive = 0;
  let syncedSourcesFromLive = 0;
  let becameEmpty = 0;

  for (const recipe of recipes) {
    if (localNames.has(recipe.name)) {
      throw new Error(`Yerel veride yinelenen tarif adı: ${recipe.name}`);
    }
    localNames.add(recipe.name);
    const original = Array.isArray(recipe.imageUrls)
      ? recipe.imageUrls.filter(url => typeof url === 'string' && url.trim())
      : [];
    const liveRecipe = liveRecipesByName.get(recipe.name);
    const live = (liveRecipe?.imageUrls || []).filter(isLicensedRemote);
    const localLicensed = original.filter(isLicensedRemote);
    const next = liveRecipe ? live : localLicensed;

    droppedUrls += original.filter(url => !isLicensedRemote(url)).length;
    if (liveRecipe && JSON.stringify(live) !== JSON.stringify(original)) {
      syncedFromLive++;
    }
    if (original.length && next.length === 0) becameEmpty++;

    if (JSON.stringify(original) !== JSON.stringify(next)) {
      recipe.imageUrls = next;
      changedRecipes++;
    }

    const originalSources = Array.isArray(recipe.imageSources)
      ? recipe.imageSources
      : [];
    const liveSources = Array.isArray(liveRecipe?.imageSources)
      ? liveRecipe.imageSources
      : [];
    if (JSON.stringify(originalSources) !== JSON.stringify(liveSources)) {
      recipe.imageSources = liveSources;
      syncedSourcesFromLive++;
      if (JSON.stringify(original) === JSON.stringify(next)) changedRecipes++;
    }
  }

  if (COMMIT && changedRecipes) {
    fs.writeFileSync(LOCAL_RECIPES_PATH, `${JSON.stringify(recipes, null, 1)}\n`, 'utf8');
  }

  return {
    changedRecipes,
    droppedUrls,
    syncedFromLive,
    syncedSourcesFromLive,
    becameEmpty,
  };
}

async function moveToStorage(docId, idx, url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`indirme ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  const token = crypto.randomUUID();
  const path = idx === 0 ? `recipes/${docId}.jpg` : `recipes/${docId}_${idx}.jpg`;
  await bucket.file(path).save(buf, {
    metadata: { contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: token } },
    resumable: false,
  });
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

(async () => {
  console.log(`🧹 clean_images — ${COMMIT ? 'COMMIT' : 'DRY-RUN'} | bucket: ${BUCKET}\n`);
  const snap = await db.collection('recipes').get();
  const liveRecipesByName = new Map();
  let repairedSources = 0;
  let removedAiImages = 0;
  let normalizedSourceDocs = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (!data.name) continue;
    if (liveRecipesByName.has(data.name)) {
      throw new Error(`Firestore'da yinelenen tarif adı: ${data.name}`);
    }
    let imageSources = Array.isArray(data.imageSources) ? data.imageSources : [];
    const legacySourceUrl = LEGACY_UNSPLASH_SOURCES[data.name];
    if (!imageSources.length && legacySourceUrl && data.imageUrls?.length) {
      imageSources = [{
        provider: 'Unsplash',
        sourceUrl: legacySourceUrl,
        storageUrl: data.imageUrls[0],
        license: 'Unsplash License',
        licenseUrl: 'https://unsplash.com/license',
      }];
      repairedSources++;
    }
    const originalImageUrls = Array.isArray(data.imageUrls) ? data.imageUrls : [];
    const normalizedSources = [];
    const licensedImageUrls = [];
    for (let i = 0; i < originalImageUrls.length; i++) {
      const source = imageSources[i];
      if (source && isAiGeneratedSource(source)) {
        removedAiImages++;
        continue;
      }
      licensedImageUrls.push(originalImageUrls[i]);
      if (source) normalizedSources.push(normalizeImageSource(source));
    }
    imageSources = normalizedSources;
    const sourceChanged = JSON.stringify(imageSources) !== JSON.stringify(data.imageSources || []);
    const imageChanged = JSON.stringify(licensedImageUrls) !== JSON.stringify(originalImageUrls);
    if (sourceChanged) normalizedSourceDocs++;
    if (COMMIT && (sourceChanged || imageChanged)) {
      await doc.ref.update({
        imageUrls: licensedImageUrls,
        imageSources,
        ...(imageChanged ? { modifiedAt: admin.firestore.Timestamp.now() } : {}),
      });
    }
    liveRecipesByName.set(data.name, {
      imageUrls: licensedImageUrls,
      imageSources,
    });
  }

  let dropped = 0, moved = 0, becameEmpty = 0, changedDocs = 0, fail = 0, unknown = 0;
  const emptyNames = [];

  for (const d of snap.docs) {
    const r = d.data();
    const urls = (r.imageUrls || []).filter(u => u && u.trim());
    if (!urls.length) continue;

    const newUrls = [];
    let changed = false;
    let keptIdx = 0;

    for (const u of urls) {
      if (isCopyrighted(u)) { dropped++; changed = true; continue; }
      if (isKeep(u)) { newUrls.push(u); keptIdx++; continue; }
      if (isMove(u)) {
        changed = true;
        try {
          if (COMMIT) {
            const nu = await moveToStorage(d.id, keptIdx, u);
            newUrls.push(nu);
          } else {
            newUrls.push('[MOVE→storage] ' + u);
          }
          keptIdx++; moved++;
        } catch (e) { fail++; console.log(`❌ taşıma hata ${r.name}: ${e.message}`); }
        continue;
      }
      // bilinmeyen host → dokunma
      unknown++; newUrls.push(u); keptIdx++;
    }

    if (!changed) continue;
    changedDocs++;
    const finalUrls = newUrls.filter(u => !u.startsWith('[MOVE'));
    if ((COMMIT ? finalUrls.length : newUrls.length) === 0) { becameEmpty++; emptyNames.push(r.name); }

    if (COMMIT) {
      await d.ref.update({
        imageUrls: finalUrls,
        imageSources: finalUrls.length ? (r.imageSources || []) : [],
        modifiedAt: admin.firestore.Timestamp.now(),
      });
    }
  }

  console.log(`Telifli silinen URL: ${dropped}`);
  console.log(`Storage'a taşınan (unsplash): ${moved}`);
  console.log(`Değişen tarif: ${changedDocs}`);
  console.log(`Resimsiz kalan tarif: ${becameEmpty}`);
  console.log(`Kaynağı onarılan eski Unsplash tarifi: ${repairedSources}`);
  console.log(`Kaldırılan belirsiz AI görseli: ${removedAiImages}`);
  console.log(`Normalize edilen kaynak belgeleri: ${normalizedSourceDocs}`);
  if (unknown) console.log(`Bilinmeyen host (dokunulmadı): ${unknown}`);
  if (fail) console.log(`Hata: ${fail}`);
  if (emptyNames.length) console.log(`\nResimsiz kalanlar: ${emptyNames.join(', ')}`);
  const local = cleanLocalRecipes(liveRecipesByName);
  console.log('\nYerel tarif yedeği:');
  console.log(`  Değişen tarif: ${local.changedRecipes}`);
  console.log(`  Lisanssız silinen URL: ${local.droppedUrls}`);
  console.log(`  Firestore görseliyle eşitlenen tarif: ${local.syncedFromLive}`);
  console.log(`  Kaynak bilgisi eşitlenen tarif: ${local.syncedSourcesFromLive}`);
  console.log(`  Resimsiz kalan tarif: ${local.becameEmpty}`);
  console.log(COMMIT ? '\n🎉 Tamam.' : '\n(DRY-RUN — --commit ile uygula)');
  process.exit(0);
})().catch(e => { console.error('❌', e.message); process.exit(1); });
