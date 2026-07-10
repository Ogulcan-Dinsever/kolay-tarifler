const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
const patch = require('./recipe_patch.json');
const norm = s => (s || '').toLowerCase().trim();
(async () => {
  const snap = await db.collection('recipes').get();
  const byName = {};
  snap.forEach(d => { byName[norm(d.data().name)] = { id: d.id, data: d.data() }; });
  const ingSnap = await db.collection('ingredients').get();
  const ingIds = new Set(); ingSnap.forEach(d => ingIds.add(d.id));

  let problems = 0;
  const now = Date.now();
  for (const p of patch) {
    const hit = byName[norm(p.name)];
    if (!hit) { console.log('❌ YOK:', p.name); problems++; continue; }
    const r = hit.data;
    const issues = [];
    if (!r.steps || r.steps.length !== p.steps.length) issues.push(`adım ${r.steps ? r.steps.length : 0}!=${p.steps.length}`);
    if ((r.steps || []).some(s => !s.text || !s.text.trim())) issues.push('boş adım');
    if ((r.steps || []).some((s, i) => s.order !== i + 1)) issues.push('order bozuk');
    if (!r.ingredients || r.ingredients.length !== p.ingredients.length) issues.push('malzeme sayısı');
    const badIng = (r.ingredients || []).filter(i => !i.ingredientId || i.ingredientId === 'ing_unknown' || !ingIds.has(i.ingredientId));
    if (badIng.length) issues.push('geçersiz ingredientId: ' + badIng.map(i => i.name).join(','));
    const mod = r.modifiedAt && r.modifiedAt.toMillis ? r.modifiedAt.toMillis() : 0;
    if (!mod || now - mod > 3600 * 1000) issues.push('modifiedAt eski/yok');
    if (issues.length) { console.log('⚠️ ', p.name, '->', issues.join(' | ')); problems++; }
  }
  console.log(problems === 0 ? `\n✅ ${patch.length}/${patch.length} temiz — boş adım yok, ingredientId geçerli, modifiedAt taze.` : `\n${problems} sorunlu tarif.`);
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });
