const admin = require('firebase-admin');
const fs = require('fs');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
const patch = require('./recipe_patch.json');
const norm = s => (s || '').toLowerCase().trim();
(async () => {
  const snap = await db.collection('recipes').get();
  const byName = {};
  snap.forEach(d => { byName[norm(d.data().name)] = { id: d.id, data: d.data() }; });
  const backup = [];
  patch.forEach(p => { const hit = byName[norm(p.name)]; if (hit) backup.push(hit); });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = `backup_recipes_${stamp}.json`;
  fs.writeFileSync(__dirname + '/' + file, JSON.stringify(backup, null, 1));
  console.log(`Yedeklendi: ${backup.length} tarif -> scripts/${file}`);
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });
