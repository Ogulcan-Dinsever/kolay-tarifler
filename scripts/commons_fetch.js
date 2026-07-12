/**
 * Wikimedia Commons'tan TELİFSİZ (CC/PD) yemek görseli adayı indirir — GÖRSEL DOĞRULAMA için.
 * Commons tüm içeriği serbest lisanslıdır; lisans + atıf kaydedilir.
 *
 *   node commons_fetch.js <offset> <count>      → batch indir (c00..cNN.jpg) + _cand_meta.json
 *   node commons_fetch.js alt <idx> <candIdx>   → o tarif için alternatif adayı indir (cIDX.jpg)
 *
 * Doğrulama bende: cNN.jpg'leri Read ile bak, yemeğe ait olanları seç, sonra commons_commit.js.
 */
const fs = require('fs');
const OUT = 'C:/Users/ogulc/AppData/Local/Temp/claude/C--Users-ogulc-Downloads-Yeni-klas-r/28f292cc-44e5-45e9-a85a-02aada20f8bf/scratchpad';
const META = '_cand_meta.json';
const UA = 'nepisirsem-image-audit/1.0 (recipe image sourcing; contact ogulcandnsvr@gmail.com)';

const stripTags = s => (s || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();

async function searchCommons(query) {
  const url = 'https://commons.wikimedia.org/w/api.php?format=json&action=query'
    + '&generator=search&gsrnamespace=6&gsrlimit=10'
    + '&gsrsearch=' + encodeURIComponent(query + ' filetype:bitmap')
    + '&prop=imageinfo&iiprop=url|extmetadata|mime|size&iiurlwidth=1000';
  const res = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!res.ok) throw new Error(`Commons ${res.status}`);
  const j = await res.json();
  const pages = j.query?.pages ? Object.values(j.query.pages) : [];
  // arama sırasını koru
  pages.sort((a, b) => (a.index || 0) - (b.index || 0));
  const cands = [];
  for (const p of pages) {
    const ii = p.imageinfo?.[0]; if (!ii) continue;
    if (!/image\/(jpeg|png)/.test(ii.mime || '')) continue;
    if ((ii.width || 0) < 400) continue;
    const em = ii.extmetadata || {};
    cands.push({
      title: p.title,
      thumbUrl: ii.thumburl || ii.url,
      fullUrl: ii.url,
      descUrl: ii.descriptionurl,
      width: ii.width, height: ii.height,
      license: (em.LicenseShortName?.value) || '',
      artist: stripTags(em.Artist?.value) || '',
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
  const mode = process.argv[2];

  if (mode === 'alt') {
    const idx = parseInt(process.argv[3], 10);
    const candIdx = parseInt(process.argv[4], 10);
    const meta = JSON.parse(fs.readFileSync(META, 'utf8'));
    const row = meta.find(m => m.idx === idx);
    if (!row) { console.error('idx yok:', idx); process.exit(1); }
    const c = row.candidates[candIdx];
    if (!c) { console.error('cand yok:', candIdx, '(toplam', row.candidates.length, ')'); process.exit(1); }
    await download(c.thumbUrl, `${OUT}/c${String(idx % 100).padStart(2, '0')}.jpg`);
    row.chosen = candIdx;
    fs.writeFileSync(META, JSON.stringify(meta));
    console.log(`alt indirildi: idx ${idx} cand ${candIdx} | ${c.title} | ${c.license}`);
    process.exit(0);
  }

  const offset = parseInt(process.argv[2] || '0', 10);
  const count = parseInt(process.argv[3] || '16', 10);
  const list = JSON.parse(fs.readFileSync('_imageless.json', 'utf8'));
  const Q = JSON.parse(fs.readFileSync('_commons_queries.json', 'utf8'));
  const slice = list.slice(offset, offset + count);
  const meta = [];

  for (let i = 0; i < slice.length; i++) {
    const item = slice[i];
    const gidx = offset + i;
    const q = Q[item.name];
    if (!q) { console.log(String(gidx).padStart(3), '| SORGU YOK |', item.name); meta.push({ idx: gidx, name: item.name, id: item.id, query: null, chosen: -1, candidates: [] }); continue; }
    try {
      const cands = await searchCommons(q);
      const row = { idx: gidx, name: item.name, id: item.id, query: q, chosen: cands.length ? 0 : -1, candidates: cands };
      meta.push(row);
      if (!cands.length) { console.log(String(gidx).padStart(3), '| SONUÇ YOK |', item.name, '|', q); continue; }
      await download(cands[0].thumbUrl, `${OUT}/c${String(i).padStart(2, '0')}.jpg`);
      console.log(String(gidx).padStart(3), '| c' + String(i).padStart(2, '0'), '|', item.name, '|', cands.length, 'aday | top:', cands[0].title.replace('File:', ''), '|', cands[0].license);
    } catch (e) {
      console.log(String(gidx).padStart(3), '| HATA |', item.name, '|', e.message);
      meta.push({ idx: gidx, name: item.name, id: item.id, query: q, chosen: -1, candidates: [] });
    }
    await new Promise(r => setTimeout(r, 250));
  }
  fs.writeFileSync(META, JSON.stringify(meta));
  console.log(`\nmeta yazıldı: ${META} (${meta.length} tarif)`);
  process.exit(0);
})();
