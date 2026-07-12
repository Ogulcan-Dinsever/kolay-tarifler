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
const sa = require('./serviceAccountKey.json');

const COMMIT = process.argv.includes('--commit');
const BUCKET = `${sa.project_id}.firebasestorage.app`;
admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const COPYRIGHTED = ['nefisyemektarifleri.com', 'yemek.com'];
const MOVE = ['unsplash.com'];           // telifsiz ama hotlink → Storage'a taşı
const KEEP = ['firebasestorage', 'storage.googleapis'];

const hostOf = u => { try { return new URL(u).host; } catch { return ''; } };
const isCopyrighted = u => COPYRIGHTED.some(c => hostOf(u).includes(c));
const isMove = u => MOVE.some(c => hostOf(u).includes(c));
const isKeep = u => KEEP.some(c => hostOf(u).includes(c));

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
  if (unknown) console.log(`Bilinmeyen host (dokunulmadı): ${unknown}`);
  if (fail) console.log(`Hata: ${fail}`);
  if (emptyNames.length) console.log(`\nResimsiz kalanlar: ${emptyNames.join(', ')}`);
  console.log(COMMIT ? '\n🎉 Tamam.' : '\n(DRY-RUN — --commit ile uygula)');
  process.exit(0);
})().catch(e => { console.error('❌', e.message); process.exit(1); });
