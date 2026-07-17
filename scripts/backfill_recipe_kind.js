// Tarif hiyerarşisini sorgulanabilir `recipeKind` alanına taşır.
// Kullanım:
//   node backfill_recipe_kind.js            # DRY-RUN
//   node backfill_recipe_kind.js --commit   # gerçek yazma

const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json')),
});
const db = admin.firestore();

const COMMIT = process.argv.includes('--commit');
const CHUNK_SIZE = 400;

function kindFor(data) {
  return typeof data.parentRecipeId === 'string' && data.parentRecipeId.trim()
    ? 'variation'
    : 'main';
}

(async () => {
  console.log(
    `backfill_recipe_kind — ${COMMIT ? 'COMMIT' : 'DRY-RUN'}`,
  );
  const snapshot = await db.collection('recipes').get();
  const changes = snapshot.docs.filter(
    (document) => document.data().recipeKind !== kindFor(document.data()),
  );

  const mainCount = snapshot.docs.filter(
    (document) => kindFor(document.data()) === 'main',
  ).length;
  const variationCount = snapshot.size - mainCount;
  console.log(`Toplam: ${snapshot.size}`);
  console.log(`Ana tarif: ${mainCount}`);
  console.log(`Varyasyon: ${variationCount}`);
  console.log(`Güncellenecek: ${changes.length}`);

  const byId = new Map(snapshot.docs.map((document) => [document.id, document]));
  const nested = snapshot.docs.filter((document) => {
    const parentId = document.data().parentRecipeId;
    if (typeof parentId !== 'string' || !parentId.trim()) return false;
    const parent = byId.get(parentId);
    return parent && kindFor(parent.data()) === 'variation';
  });
  if (nested.length > 0) {
    throw new Error(
      `İç içe varyasyon bulundu; yazma durduruldu: ${nested
        .slice(0, 10)
        .map((document) => document.id)
        .join(', ')}`,
    );
  }

  if (!COMMIT || changes.length === 0) return;
  for (let start = 0; start < changes.length; start += CHUNK_SIZE) {
    const batch = db.batch();
    for (const document of changes.slice(start, start + CHUNK_SIZE)) {
      batch.update(document.ref, { recipeKind: kindFor(document.data()) });
    }
    await batch.commit();
    console.log(
      `Yazıldı: ${Math.min(start + CHUNK_SIZE, changes.length)}/${changes.length}`,
    );
  }
})()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
