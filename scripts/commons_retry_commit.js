/**
 * _retry_meta.json'dan doğrulanan tarifleri Storage'a yükler + Firestore günceller.
 *   node commons_retry_commit.js "Ad1" "Ad2" ...   → verilen isimlerin SEÇİLİ adayını yükle
 * Seçili aday = chosen indeksi (alt_retry ile değiştirilebilir).
 */
const admin = require('firebase-admin');
const crypto = require('crypto');
const fs = require('fs');
const sa = require('./serviceAccountKey.json');
const META = '_retry_meta.json';
const UA = 'kolay-tarifler-image-audit/1.0 (contact ogulcandnsvr@gmail.com)';
const BUCKET = `${sa.project_id}.firebasestorage.app`;
admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();

async function upload(docId, imageUrl) {
  const res = await fetch(imageUrl, { headers: { 'User-Agent': UA } });
  if (!res.ok) throw new Error(`indirme ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  const token = crypto.randomUUID();
  const path = `recipes/${docId}.jpg`;
  await bucket.file(path).save(buf, { metadata: { contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: token } }, resumable: false });
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

(async () => {
  const meta = JSON.parse(fs.readFileSync(META, 'utf8'));
  const want = new Set(process.argv.slice(2));
  const targets = meta.filter(m => want.has(m.name) && m.chosen >= 0 && m.candidates[m.chosen]);
  if (!targets.length) { console.error('yüklenecek yok'); process.exit(1); }
  let ok = 0, fail = 0;
  for (const m of targets) {
    const c = m.candidates[m.chosen];
    try {
      const url = await upload(m.id, c.thumbUrl);
      await db.collection('recipes').doc(m.id).update({
        imageUrls: [url],
        imageSources: [{ source: 'wikimedia', title: c.title, page: c.descUrl, license: c.license, artist: c.artist, query: m.query }],
        imageUpdatedAt: admin.firestore.Timestamp.now(),
        modifiedAt: admin.firestore.Timestamp.now(),
      });
      ok++; console.log('✅', m.name, '|', c.license, '|', c.title.replace('File:', ''));
    } catch (e) { fail++; console.log('❌', m.name, '|', e.message); }
  }
  console.log(`\neklenen: ${ok} | hata: ${fail}`);
  process.exit(0);
})().catch(e => { console.error('❌', e.message); process.exit(1); });
