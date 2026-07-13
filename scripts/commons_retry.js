/**
 * Resimsiz kalan tarifler için GELİŞTİRİLMİŞ sorgularla ikinci tur Commons araması.
 *   node commons_retry.js            → tüm retry sorgularını dener, cRETRY_<slug>.jpg indirir + _retry_meta.json
 * Doğrulama bende: Read ile bak, doğru olanları commons_retry_commit.js ile yükle.
 */
const fs = require('fs');
const OUT = 'C:/Users/ogulc/AppData/Local/Temp/claude/C--Windows-system32/d7db2b79-12ea-4261-bc79-4db96c569ea1/scratchpad';
const UA = 'kolay-tarifler-image-audit/1.0 (recipe image sourcing; contact ogulcandnsvr@gmail.com)';
const IDS = JSON.parse(fs.readFileSync('_retry_ids.json', 'utf8'));

// geliştirilmiş sorgular (yerel + açıklayıcı)
const Q = {
  'Balık Buğulama': 'balık buğulama',
  'Çerkez Tavuğu': 'circassian chicken',
  'Domatesli Bulgur Pilavı': 'bulgur pilavı',
  'Etli Kereviz': 'kereviz yemeği',
  'Fava': 'fava santorini meze',
  'Girit Ezmesi': 'girit ezmesi',
  'Hamsi Pilavı': 'hamsi pilav',
  'Havuç Tarator': 'havuç tarator',
  'Kabak Musakka': 'musakka',
  'Katmer': 'katmer gaziantep',
  'Kıymalı Erişte': 'erişte',
  'Muska Böreği': 'muska böreği',
  'Nohutlu Pilav': 'nohutlu pilav',
  'Patlıcanlı Pilav': 'patlıcanlı pilav',
  'Semizotu Salatası': 'purslane yogurt salad',
  'Şehriye Çorbası': 'şehriye çorbası',
  'Tavuk Sote': 'tavuk sote',
  'Uskumru Dolması': 'stuffed mackerel dolma',
  'Zeytinyağlı Kabak': 'zucchini olive oil dish',
  'Zeytinyağlı Kereviz': 'celeriac olive oil',
  'Bal Kaymak': 'kaymak bal',
  'Su Muhallebisi': 'su muhallebisi',
  'Hamsi Buğulama': 'hamsi tava',
  'Atom': 'haydari meze',
};

const stripTags = s => (s || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
const slug = s => s.toLowerCase().replace(/[^a-z0-9]+/g, '').slice(0, 12);

async function searchCommons(query) {
  const url = 'https://commons.wikimedia.org/w/api.php?format=json&action=query'
    + '&generator=search&gsrnamespace=6&gsrlimit=10'
    + '&gsrsearch=' + encodeURIComponent(query + ' filetype:bitmap')
    + '&prop=imageinfo&iiprop=url|extmetadata|mime|size&iiurlwidth=1000';
  const res = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!res.ok) throw new Error(`Commons ${res.status}`);
  const j = await res.json();
  const pages = j.query?.pages ? Object.values(j.query.pages) : [];
  pages.sort((a, b) => (a.index || 0) - (b.index || 0));
  const cands = [];
  for (const p of pages) {
    const ii = p.imageinfo?.[0]; if (!ii) continue;
    if (!/image\/(jpeg|png)/.test(ii.mime || '')) continue;
    if ((ii.width || 0) < 400) continue;
    const em = ii.extmetadata || {};
    cands.push({
      title: p.title, thumbUrl: ii.thumburl || ii.url, fullUrl: ii.url, descUrl: ii.descriptionurl,
      width: ii.width, height: ii.height,
      license: (em.LicenseShortName?.value) || '', artist: stripTags(em.Artist?.value) || '',
    });
  }
  return cands;
}
async function download(u, dest) {
  const res = await fetch(u, { headers: { 'User-Agent': UA } });
  if (!res.ok) throw new Error(`indirme ${res.status}`);
  fs.writeFileSync(dest, Buffer.from(await res.arrayBuffer()));
}

(async () => {
  const meta = [];
  for (const name of Object.keys(Q)) {
    const id = IDS[name];
    if (!id) { console.log('ID YOK |', name); continue; }
    const q = Q[name];
    const sl = slug(name);
    try {
      const cands = await searchCommons(q);
      const row = { name, id, query: q, slug: sl, chosen: cands.length ? 0 : -1, candidates: cands };
      meta.push(row);
      if (!cands.length) { console.log('SONUÇ YOK |', name, '|', q); continue; }
      await download(cands[0].thumbUrl, `${OUT}/r_${sl}.jpg`);
      console.log('r_' + sl, '|', name, '|', cands.length, 'aday | top:', cands[0].title.replace('File:', ''), '|', cands[0].license);
    } catch (e) { console.log('HATA |', name, '|', e.message); meta.push({ name, id, query: q, slug: sl, chosen: -1, candidates: [] }); }
    await new Promise(r => setTimeout(r, 250));
  }
  fs.writeFileSync('_retry_meta.json', JSON.stringify(meta));
  console.log('\n_retry_meta.json yazıldı (' + meta.length + ')');
  process.exit(0);
})();
