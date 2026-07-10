/**
 * Pexels'ten yemek görseli çekip Firebase Storage'a yükler, imageUrls'i günceller.
 *
 * - Sadece bu oturumda eklenen 81 yeni Türk tarifi hedeflenir (QUERY haritasındaki isimler).
 * - Telifsiz: Pexels lisansı ticari kullanıma ücretsiz izin verir, atıf zorunlu değildir.
 * - Görsel bulunamazsa (query null veya sonuç yok) tarif RESİMSİZ bırakılır (zorlanmaz).
 * - Storage public erişimi download-token URL'i ile sağlanır (uniform bucket access uyumlu).
 *
 * API anahtarı ortam değişkeninden okunur, ASLA commit edilmez:
 *   PEXELS_KEY=xxx node fetch_images.js            (dry-run: sadece eşleşme raporu)
 *   PEXELS_KEY=xxx node fetch_images.js --commit   (indir + yükle + Firestore güncelle)
 */
const admin = require('firebase-admin');
const crypto = require('crypto');
const sa = require('./serviceAccountKey.json');

const COMMIT = process.argv.includes('--commit');
const KEY = process.env.PEXELS_KEY;
if (!KEY) { console.error('❌ PEXELS_KEY ortam değişkeni gerekli.'); process.exit(1); }

const BUCKET = `${sa.project_id}.firebasestorage.app`;
admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();

// Tarif adı -> Pexels arama sorgusu (kategori-doğru gerçek yemek fotoğrafı). null = atla.
const QUERY = {
  "Şehriye Çorbası": "turkish tomato soup", "Mantar Çorbası": "mushroom cream soup",
  "Brokoli Çorbası": "broccoli soup", "Balık Çorbası": "fish soup",
  "Toyga Çorbası": "yogurt soup", "Arabaşı Çorbası": "chicken soup bowl",
  "Beyran": "spicy meat soup", "Un Çorbası": "creamy soup bowl",
  "Cağ Kebabı": "turkish kebab", "Orman Kebabı": "beef stew vegetables",
  "Kuzu İncik": "lamb shank", "Kadınbudu Köfte": "fried meatballs",
  "İzmir Köfte": "meatballs tomato sauce", "Akçaabat Köftesi": "grilled meatballs",
  "Sulu Köfte": "meatballs in sauce", "Ekşili Köfte": "meatballs sauce",
  "Kuru Köfte": "turkish meatballs kofte", "Arnavut Ciğeri": "fried liver dish",
  "Külbastı": "grilled steak", "Papaz Yahnisi": "beef onion stew",
  "Et Sote": "beef saute peppers", "Tavuk Sote": "chicken saute vegetables",
  "Piliç Izgara": "grilled chicken", "Dana Rosto": "roast beef sliced",
  "Zeytinyağlı Kereviz": "cooked celery root", "Zeytinyağlı Barbunya": "borlotti beans dish",
  "Zeytinyağlı Kabak": "zucchini olive oil dish", "Zeytinyağlı Bamya": "okra tomato dish",
  "Etli Kereviz": "celeriac stew", "Etli Pırasa": "leek stew",
  "Sebzeli Güveç": "vegetable casserole", "Kabak Musakka": "zucchini moussaka",
  "Nohutlu Pilav": "rice pilaf chickpeas", "Tavuklu Pilav": "chicken rice pilaf",
  "Etli Pilav": "meat rice pilaf", "Patlıcanlı Pilav": "eggplant rice",
  "Meyhane Pilavı": "turkish rice pilaf", "Kestaneli Pilav": "chestnut rice pilaf",
  "Domatesli Bulgur Pilavı": "bulgur pilaf",
  "Ispanaklı Börek": "spinach pastry borek", "Muska Böreği": "turkish borek pastry",
  "Puf Böreği": "fried pastry puff", "Kaşarlı Pide": "turkish pide",
  "Sucuklu Pide": "turkish pide", "Yumurtalı Pide": "turkish pide egg",
  "Ramazan Pidesi": "turkish flatbread pide", "Bazlama": "turkish flatbread",
  "Kete": "turkish pastry", "Tahinli Çörek": "tahini pastry roll",
  "Tel Kadayıf": "kadayif dessert", "Muhallebi": "milk pudding",
  "Keşkül": "almond pudding", "Tavuk Göğsü": "milk pudding dessert",
  "Supangle": "chocolate pudding", "Zerde": "saffron rice pudding",
  "Ayva Tatlısı": "quince dessert", "İncir Tatlısı": "fig dessert",
  "Trileçe": "tres leches cake", "Sütlü Nuriye": "baklava",
  "Şöbiyet": "baklava dessert", "Sarığı Burma": "baklava rolls",
  "Kalburabastı": "syrup soaked dessert", "Hanım Göbeği": "turkish syrup dessert",
  "Kemalpaşa Tatlısı": "syrup dessert balls", "Lokum": "turkish delight",
  "Sahanda Yumurta": "fried eggs pan", "Bal Kaymak": "honey cream breakfast",
  "Pastırmalı Yumurta": "fried eggs skillet", "Köpoğlu": "fried eggplant yogurt",
  "Girit Ezmesi": "feta cheese dip", "Atom": "yogurt dip chili",
  "Havuç Tarator": "carrot yogurt dip", "Rus Salatası": "russian potato salad",
  "Fellah Köftesi": "bulgur kofte", "Çipura Izgara": "grilled sea bream",
  "Kalamar Tava": "fried calamari", "Balık Buğulama": "steamed fish vegetables",
  "Uskumru Dolması": "grilled mackerel", "Sardalya Tava": "fried sardines",
  "Kıymalı Erişte": "noodles with minced meat", "Su Muhallebisi": "rose milk pudding",
};

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function pexels(query) {
  const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape`;
  const res = await fetch(url, { headers: { Authorization: KEY } });
  if (!res.ok) throw new Error(`Pexels ${res.status}`);
  const j = await res.json();
  const p = j.photos?.[0];
  if (!p) return null;
  return { imageUrl: p.src.large2x || p.src.large || p.src.original, photographer: p.photographer, page: p.url };
}

async function uploadToStorage(docId, imageUrl) {
  const res = await fetch(imageUrl);
  if (!res.ok) throw new Error(`indirme ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  const token = crypto.randomUUID();
  const path = `recipes/${docId}.jpg`;
  const file = bucket.file(path);
  await file.save(buf, {
    metadata: { contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: token } },
    resumable: false,
  });
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

(async () => {
  console.log(`🖼️  fetch_images — ${COMMIT ? 'COMMIT' : 'DRY-RUN'} | bucket: ${BUCKET}\n`);

  // İsim -> docId (sadece bu oturumdaki isimler, Türk mutfağı)
  const snap = await db.collection('recipes').where('cuisine', '==', 'Türk').get();
  const nameToId = {};
  snap.forEach(d => { nameToId[d.data().name] = d.id; });

  let ok = 0, blank = 0, missing = 0, fail = 0;
  const results = [];

  for (const [name, query] of Object.entries(QUERY)) {
    const docId = nameToId[name];
    if (!docId) { missing++; results.push(`❓ ${name}: Firestore'da yok`); continue; }
    if (!query) { blank++; results.push(`⬜ ${name}: sorgu yok, resimsiz`); continue; }
    try {
      const hit = await pexels(query);
      await sleep(350); // Pexels'e nazik ol
      if (!hit) { blank++; results.push(`⬜ ${name}: eşleşme yok ("${query}")`); continue; }
      if (COMMIT) {
        const url = await uploadToStorage(docId, hit.imageUrl);
        await db.collection('recipes').doc(docId).update({
          imageUrls: [url],
          imageSources: [{ source: 'pexels', photographer: hit.photographer, page: hit.page, query }],
          imageUpdatedAt: admin.firestore.Timestamp.now(),
          modifiedAt: admin.firestore.Timestamp.now(),
        });
      }
      ok++;
      results.push(`✅ ${name}: ${hit.photographer} ("${query}")`);
    } catch (e) {
      fail++;
      results.push(`❌ ${name}: ${e.message}`);
    }
  }

  results.forEach(r => console.log(r));
  console.log(`\n📊 resim: ${ok} | resimsiz: ${blank} | bulunamadı(isim): ${missing} | hata: ${fail}`);
  console.log(COMMIT ? '\n🎉 Yükleme tamam.' : '\n(DRY-RUN — yükleme için --commit)');
  process.exit(0);
})().catch(e => { console.error('❌', e.message); process.exit(1); });
