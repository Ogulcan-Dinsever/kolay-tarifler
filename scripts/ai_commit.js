/**
 * Görsel doğrulaması geçen AI üretimi görselleri (gNN.jpg) Storage'a yükler
 * ve Firestore'daki tarifi günceller.
 *   node ai_commit.js <idx> <idx> ...   → _ai_prompts.json indeksleri
 */
const admin = require('firebase-admin');
const crypto = require('crypto');
const fs = require('fs');
const sa = require('./serviceAccountKey.json');
const OUT = 'C:/Users/ogulc/AppData/Local/Temp/claude/C--Users-ogulc-Downloads-Yeni-klas-r/28f292cc-44e5-45e9-a85a-02aada20f8bf/scratchpad';

const BUCKET = `${sa.project_id}.firebasestorage.app`;
admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const ITEMS = JSON.parse(fs.readFileSync('_ai_prompts.json', 'utf8'));

async function upload(docId, localPath) {
  const buf = fs.readFileSync(localPath);
  const token = crypto.randomUUID();
  const path = `recipes/${docId}.jpg`;
  await bucket.file(path).save(buf, { metadata: { contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: token } }, resumable: false });
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

(async () => {
  const want = process.argv.slice(2).map(Number);
  if (!want.length) { console.error('idx verilmedi'); process.exit(1); }

  let ok = 0, fail = 0;
  for (const i of want) {
    const it = ITEMS[i];
    if (!it) { console.log('❌ idx yok:', i); fail++; continue; }
    const local = `${OUT}/g${String(i).padStart(2, '0')}.jpg`;
    try {
      const url = await upload(it.id, local);
      await db.collection('recipes').doc(it.id).update({
        imageUrls: [url],
        imageSources: [{ source: 'ai-generated (pollinations flux)', prompt: it.prompt }],
        imageUpdatedAt: admin.firestore.Timestamp.now(),
        modifiedAt: admin.firestore.Timestamp.now(),
      });
      ok++; console.log('✅', it.name);
    } catch (e) { fail++; console.log('❌', it.name, '|', e.message); }
  }
  console.log(`\neklenen: ${ok} | hata: ${fail}`);
  process.exit(0);
})().catch(e => { console.error('❌', e.message); process.exit(1); });
