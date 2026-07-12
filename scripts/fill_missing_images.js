/**
 * Resimsiz tariflere Pexels'ten TELİFSİZ, yemeğe AİT görsel bulup Storage'a yükler.
 * - Her tarife spesifik (yemeğin gerçek adı) sorgu. null = Pexels'te karşılığı yok, ATLA.
 * - Eşik: total_results < MIN ise güvenilmez kabul edip ATLAR (yanlış resim basmamak için).
 * - Bulunamazsa zorlamaz; tarif resimsiz kalır.
 *
 * PEXELS_KEY=xxx node fill_missing_images.js            (dry-run rapor)
 * PEXELS_KEY=xxx node fill_missing_images.js --commit   (indir+yükle+güncelle)
 */
const admin = require('firebase-admin');
const crypto = require('crypto');
const sa = require('./serviceAccountKey.json');

const COMMIT = process.argv.includes('--commit');
const KEY = process.env.PEXELS_KEY;
if (!KEY) { console.error('❌ PEXELS_KEY gerekli.'); process.exit(1); }
const MIN_RESULTS = 3;

const BUCKET = `${sa.project_id}.firebasestorage.app`;
admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const Q = {
  // ── Türk ──
  "Çerkez Tavuğu": "circassian chicken walnut", "Kabak Çiçeği Dolması": "stuffed zucchini flowers",
  "Tepsi Kebabı": "turkish tray kebab", "Tirit": null, "Keşkek": null, "Nokul": null,
  "Mercimek Çorbası": "red lentil soup", "Analı Kızlı Çorbası": null, "Tantuni": "tantuni turkish wrap",
  "İskender Kebap": "iskender kebab", "Adana Kebap": "adana kebab", "Urfa Kebap": "urfa kebab",
  "Şiş Kebap": "shish kebab skewer", "Tavuk Şiş": "chicken shish kebab", "İnegöl Köfte": "turkish grilled meatballs",
  "İçli Köfte": "kibbeh bulgur", "Çiğ Köfte": "cig kofte", "Hünkar Beğendi": "lamb stew eggplant puree",
  "Ezogelin Çorbası": "turkish red lentil soup", "Kuzu Tandır": "slow roasted lamb", "Tas Kebabı": "beef stew turkish",
  "Beyti Kebap": "beyti kebab", "Ali Nazik": "ali nazik kebab", "Kavurma": "sauteed lamb cubes",
  "Patlıcan Kebabı": "eggplant kebab", "Karnıyarık": "stuffed eggplant minced meat", "İmam Bayıldı": "imam bayildi stuffed eggplant",
  "Patlıcan Musakka": "turkish moussaka eggplant", "Etli Yaprak Sarması": "stuffed grape leaves", "Yayla Çorbası": "yogurt soup",
  "Zeytinyağlı Yaprak Sarması": "stuffed grape leaves dolma", "Etli Biber Dolması": "stuffed peppers", "Zeytinyağlı Biber Dolması": "stuffed peppers rice",
  "Etli Bezelye": "pea stew meat", "Etli Kabak": "zucchini stew meat", "Türlü": "turkish vegetable stew",
  "Mücver": "zucchini fritters", "Zeytinyağlı Pırasa": "braised leeks", "Zeytinyağlı Enginar": "braised artichokes",
  "Lahana Sarması": "stuffed cabbage rolls", "Tarhana Çorbası": "turkish tarhana soup", "Taze Fasulye": "green beans olive oil",
  "Kuru Fasulye": "white bean stew", "Etli Nohut": "chickpea stew meat", "Barbunya Pilaki": "borlotti beans dish",
  "Mercimek Köftesi": "lentil kofte balls", "Nohut Yemeği": "chickpea stew", "Pirinç Pilavı": "rice pilaf",
  "Bulgur Pilavı": "bulgur pilaf", "İç Pilav": "turkish rice pilaf", "Perde Pilavı": "perde pilavi rice dome",
  "İşkembe Çorbası": "tripe soup", "Şehriyeli Pilav": "rice pilaf vermicelli", "Mantı": "turkish manti dumplings",
  "Lahmacun": "lahmacun", "Kıymalı Pide": "turkish pide minced meat", "Su Böreği": "turkish su borek",
  "Sigara Böreği": "cheese borek rolls", "Kol Böreği": "turkish borek roll", "Talaş Böreği": "puff pastry meat",
  "Çiğ Börek": "fried turkish pastry", "Gül Böreği": "rose borek pastry", "Domates Çorbası": "tomato soup",
  "Açma": "turkish acma bun", "Poğaça": "turkish pogaca pastry", "Simit": "simit turkish bagel",
  "Pişi": "fried dough", "Gözleme": "gozleme turkish flatbread", "Katmer": "turkish katmer pastry",
  "Hamsi Tava": "fried anchovies", "Hamsi Buğulama": "anchovy fish dish", "Hamsi Pilavı": "anchovy rice",
  "Karides Güveç": "shrimp casserole clay pot", "Sebze Çorbası": "vegetable soup", "Levrek Buğulama": "steamed sea bass",
  "Baklava": "baklava", "Künefe": "kunefe kunafa", "Şekerpare": "sekerpare semolina cookies",
  "Revani": "revani semolina cake", "Sütlaç": "rice pudding", "Kazandibi": "turkish milk pudding",
  "Aşure": "asure noah pudding", "Lokma": "lokma fried dough syrup", "Tulumba": "tulumba dessert",
  "Tavuk Çorbası": "chicken soup", "Kabak Tatlısı": "pumpkin dessert", "Ekmek Kadayıfı": "bread kadayif dessert",
  "Güllaç": "gullac dessert", "İrmik Helvası": "semolina halva", "Un Helvası": "flour halva",
  "Cevizli Sucuk": "churchkhela walnut", "Çoban Salatası": "shepherd salad", "Gavurdağı Salatası": "tomato walnut salad",
  "Patlıcan Salatası": "eggplant salad", "Acılı Ezme": "turkish ezme salad", "Düğün Çorbası": "wedding soup",
  "Haydari": "yogurt dip haydari", "Cacık": "cacik cucumber yogurt", "Şakşuka": "fried eggplant vegetables",
  "Fava": "fava bean puree", "Humus": "hummus", "Mevsim Salatası": "mixed green salad",
  "Menemen": "menemen turkish eggs", "Sucuklu Yumurta": "eggs sausage skillet", "Çılbır": "turkish eggs yogurt cilbir",
  "Kuymak (Mıhlama)": "muhlama cheese fondue", "Semizotu Salatası": "purslane salad", "Höşmerim": null,
  "Balık Ekmek": "fish sandwich", "Havuç Dilimi": null,
  // ── Kore ──
  "Sigeumchi Namul": "korean spinach side dish", "Kongnamul Guk": "korean bean sprout soup", "Sujeonggwa": null,
  "Kongguksu": "korean soy milk noodles", "Musaengchae": "korean radish salad", "Godeungeo Jorim": "braised mackerel",
  "Kimchi Bokkeumbap": "kimchi fried rice", "Bibim Guksu": "korean spicy cold noodles", "Songpyeon": "songpyeon rice cake",
  "Yakgwa": null, "Danmuji": null, "Gyeranppang": "korean egg bread", "Gamja Jeon": "korean potato pancake",
  "Tteokguk": "tteokguk rice cake soup", "Dubu Jorim": "korean braised tofu", "Gyeranmari": "korean rolled omelette",
  "Sikhye": null, "Injeolmi": "injeolmi rice cake", "Jangjorim": null,
  // ── İtalyan ──
  "Pappa al Pomodoro": "pappa al pomodoro", "Pasta e Fagioli": "pasta e fagioli", "Peperonata": "peperonata peppers",
  "Pollo alla Cacciatora": "chicken cacciatore", "Ribollita": "ribollita soup",
  // ── Hint ──
  "Chana Masala": "chana masala", "Dal Makhani": "dal makhani", "Pakora": "pakora", "Tandoori Chicken": "tandoori chicken",
  "Bhindi Masala": "bhindi masala okra", "Aloo Gobi": "aloo gobi", "Rasam": "rasam soup", "Malai Kofta": "malai kofta",
  "Raita": "raita", "Butter Chicken (Murgh Makhani)": "butter chicken", "Rajma": "rajma curry", "Palak Paneer": "palak paneer",
  "Samosa": "samosa", "Chicken Biryani": "chicken biryani", "Chicken Tikka Masala": "chicken tikka masala",
  "Vegetable Biryani": "vegetable biryani", "Naan": "naan bread", "Chicken Tikka": "chicken tikka",
  // ── Çin ──
  "Twice Cooked Chicken": "twice cooked pork chicken", "Egg Drop Soup": "egg drop soup",
  "Chinese Broccoli with Oyster Sauce": "chinese broccoli oyster sauce", "Xiaolongbao (Tavuklu Çorba Mantısı)": "xiaolongbao soup dumplings",
  "Ma La Tang": "malatang hot soup", "Peking Duck (Pekin Ördeği)": "peking duck", "Ants Climbing a Tree": "sichuan glass noodles",
  // ── Amerikan ──
  "Meatball Sub (Köfteli Sandviç)": "meatball sub sandwich", "American Breakfast Platter (Amerikan Kahvaltı Tabağı)": "american breakfast platter",
  "Sloppy Joe (Kıymalı Sandviç)": "sloppy joe sandwich", "Gumbo (Cajun Yahnisi)": "gumbo stew",
  // ── Japon ──
  "Hiyayakko": "hiyayakko cold tofu", "Zenzai (Oshiruko)": "zenzai red bean soup", "Sukiyaki": "sukiyaki hot pot",
  "Chikuzenni": "japanese simmered vegetables",
  // ── İspanyol ──
  "Fabada Asturiana (Fasulye Güveci)": "fabada asturiana bean stew", "Arroz a la Cubana (İspanyol Usulü Pilav)": "arroz a la cubana",
  "Natillas (İspanyol Muhallebisi)": "natillas custard", "Boquerones en Vinagre (Sirkeli Hamsi)": "boquerones anchovies vinegar",
  "Cocido Madrileño": "cocido madrileno stew",
  // ── Yunan ──
  "Revani (Yunan Usulü İrmik Tatlısı)": "revani semolina cake", "Avgolemono (Yumurta-Limon Çorbası)": "avgolemono soup",
  "Fakes (Yunan Mercimek Çorbası)": "greek lentil soup", "Kolokithokeftedes (Kabak Mücveri)": "zucchini fritters",
  "Feta Saganaki (Fırında Feta)": "fried feta saganaki", "Fasolakia (Zeytinyağlı Taze Fasulye)": "greek green beans",
  // ── Tayland ──
  "Thai Basil Fried Rice (Fesleğenli Kavurma Pilav)": "thai basil fried rice", "Thai Basil Eggplant (Fesleğenli Patlıcan)": "thai basil eggplant",
  "Coconut Rice (Hindistan Cevizli Pirinç)": "coconut rice", "Roti Sai Mai (Şeker Pamuğu Rulosu)": null,
  "Mango Sticky Rice (Mangolu Yapışkan Pirinç)": "mango sticky rice", "Khao Pad (Tayland Usulü Kavurma Pilav)": "thai fried rice",
  // ── Lübnan ──
  "Loubia (Yeşil Fasulye Yahnisi)": "green bean stew loubia",
  // ── Vietnam ──
  "Cha Ca (Zerdeçallı Balık)": "cha ca turmeric fish", "Canh Rau (Sebze Çorbası)": "vietnamese vegetable soup",
  "Banh Da Lon (Katmanlı Hindistan Cevizli Kek)": null,
};

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function pexels(query) {
  const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=3&orientation=landscape`;
  const res = await fetch(url, { headers: { Authorization: KEY } });
  if (!res.ok) throw new Error(`Pexels ${res.status}`);
  const j = await res.json();
  const total = j.total_results || 0;
  const p = j.photos?.[0];
  if (!p || total < MIN_RESULTS) return { skip: true, total };
  return { imageUrl: p.src.large2x || p.src.large || p.src.original, photographer: p.photographer, page: p.url, total };
}

async function upload(docId, imageUrl) {
  const res = await fetch(imageUrl);
  if (!res.ok) throw new Error(`indirme ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  const token = crypto.randomUUID();
  const path = `recipes/${docId}.jpg`;
  await bucket.file(path).save(buf, { metadata: { contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: token } }, resumable: false });
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

(async () => {
  console.log(`🖼️  fill_missing_images — ${COMMIT ? 'COMMIT' : 'DRY-RUN'} | eşik: ${MIN_RESULTS}\n`);
  const snap = await db.collection('recipes').get();
  const nameToId = {}; const imageless = new Set();
  snap.forEach(d => {
    const r = d.data(); nameToId[r.name] = d.id;
    if (!(r.imageUrls || []).some(u => u && u.trim())) imageless.add(r.name);
  });

  let ok = 0, skipNull = 0, skipLow = 0, missing = 0, fail = 0;
  const done = [], skipped = [];

  for (const [name, query] of Object.entries(Q)) {
    if (!imageless.has(name)) continue; // zaten resimli
    const docId = nameToId[name];
    if (!docId) { missing++; continue; }
    if (query === null) { skipNull++; skipped.push(`⬜ ${name}: karşılığı yok (null)`); continue; }
    try {
      const hit = await pexels(query);
      await sleep(320);
      if (hit.skip) { skipLow++; skipped.push(`⬜ ${name}: az sonuç (${hit.total}) "${query}"`); continue; }
      if (COMMIT) {
        const url = await upload(docId, hit.imageUrl);
        await db.collection('recipes').doc(docId).update({
          imageUrls: [url],
          imageSources: [{ source: 'pexels', photographer: hit.photographer, page: hit.page, query }],
          imageUpdatedAt: admin.firestore.Timestamp.now(), modifiedAt: admin.firestore.Timestamp.now(),
        });
      }
      ok++; done.push(`✅ ${name} (${hit.total}) "${query}"`);
    } catch (e) { fail++; skipped.push(`❌ ${name}: ${e.message}`); }
  }

  done.forEach(x => console.log(x));
  console.log('\n' + skipped.join('\n'));
  console.log(`\n📊 eklenen: ${ok} | atlanan(null): ${skipNull} | atlanan(az sonuç): ${skipLow} | hata: ${fail}`);
  console.log(COMMIT ? '\n🎉 Tamam.' : '\n(DRY-RUN — --commit ile uygula)');
  process.exit(0);
})().catch(e => { console.error('❌', e.message); process.exit(1); });
