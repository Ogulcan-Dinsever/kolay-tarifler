// Denetim kuyruğundan görsel indirir. node download_batch.js <offset> <count>
const admin = require('firebase-admin');
const fs = require('fs');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
const OUT = 'C:/Users/ogulc/AppData/Local/Temp/claude/C--Windows-system32/d7db2b79-12ea-4261-bc79-4db96c569ea1/scratchpad';
const queue = JSON.parse(fs.readFileSync('_audit_queue.json', 'utf8'));
const offset = parseInt(process.argv[2] || '0', 10);
const count = parseInt(process.argv[3] || '16', 10);
(async () => {
  const snap = await db.collection('recipes').get();
  const byName = {};
  snap.forEach(d => { byName[d.data().name] = (d.data().imageUrls || [])[0]; });
  const slice = queue.slice(offset, offset + count);
  let i = 0;
  for (const item of slice) {
    const url = byName[item.name];
    if (!url) { console.log(String(offset + i).padStart(3), '| RESİMSİZ |', item.name); i++; continue; }
    try {
      const buf = Buffer.from(await (await fetch(url)).arrayBuffer());
      fs.writeFileSync(`${OUT}/a${String(i).padStart(2, '0')}.jpg`, buf);
      console.log(String(offset + i).padStart(3), '| a' + String(i).padStart(2, '0'), '|', item.name, '|', item.q);
    } catch (e) { console.log('HATA', item.name, e.message); }
    i++;
  }
  process.exit(0);
})();
