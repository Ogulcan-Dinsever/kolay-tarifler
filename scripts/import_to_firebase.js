/**
 * Firebase Import Script — Kolay Tarifler
 * Kullanım: node scripts/import_to_firebase.js
 *
 * Gereksinimler:
 *   npm install firebase-admin
 *
 * Önce Firebase Console > Project Settings > Service Accounts >
 * "Generate new private key" ile serviceAccountKey.json indirip
 * bu dosyanın yanına (scripts/) koyun.
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ─── Servis hesabı & başlatma ───────────────────────────────────────────────
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ─── JSON dosyalarını oku ───────────────────────────────────────────────────
const malzemelerRaw = fs.readFileSync(
  path.join(__dirname, 'turk_malzemeleri.json'),
  'utf8'
);
const yemeklerRaw = fs.readFileSync(
  path.join(__dirname, 'turk_yemekleri_100.json'),
  'utf8'
);

const malzemeler = JSON.parse(malzemelerRaw);
const yemekler = JSON.parse(yemeklerRaw);

// ─── Kategori eşlemesi (Türkçe → İngilizce enum adı) ───────────────────────
const CATEGORY_MAP = {
  // Sebze
  'sebze': 'vegetable',
  // Meyve
  'meyve': 'fruit',
  // Et & Tavuk
  'et': 'meat',
  'tavuk': 'meat',
  'et/tavuk': 'meat',
  'et & tavuk': 'meat',
  'kirmizi et': 'meat',
  'kırmızı et': 'meat',
  // Deniz Ürünleri
  'deniz': 'seafood',
  'deniz ürünleri': 'seafood',
  'deniz urunleri': 'seafood',
  'balik': 'seafood',
  'balık': 'seafood',
  // Süt Ürünleri
  'sut': 'dairy',
  'süt': 'dairy',
  'sut urunleri': 'dairy',
  'süt ürünleri': 'dairy',
  'peynir': 'dairy',
  'yumurta': 'dairy',
  // Tahıl & Bakliyat
  'tahil': 'grain',
  'tahıl': 'grain',
  'baklagil': 'grain',
  'bakliyat': 'grain',
  'un': 'grain',
  'ekmek': 'grain',
  'yufka': 'grain',
  'pirinc': 'grain',
  'pirinç': 'grain',
  'makarna': 'grain',
  'bulgur': 'grain',
  // Baharat
  'baharat': 'spice',
  'yesillik': 'spice',
  'yeşillik': 'spice',
  'ot': 'spice',
  'herb': 'spice',
  // Yağ & Sos
  'yag': 'oil',
  'yağ': 'oil',
  'sos': 'oil',
  'yag & sos': 'oil',
  'yağ & sos': 'oil',
  // Diğer
  'diger': 'other',
  'diğer': 'other',
};

function mapCategory(turkishCategory) {
  if (!turkishCategory) return 'other';
  const key = turkishCategory.trim().toLowerCase();
  return CATEGORY_MAP[key] || 'other';
}

// ─── Tarif tipi eşlemesi (eksik tipler için) ────────────────────────────────
const TYPE_MAP = {
  'Kahvaltılık': 'Kahvaltı',
  'Atıştırmalık': 'Ana Yemek', // en yakın alternatif
  'Yan Yemek': 'Ana Yemek',
  'Meze': 'Salata',
};

function mapType(type) {
  return TYPE_MAP[type] || type;
}

// ─── Emoji fix: bozuk encoding varsa temizle ────────────────────────────────
function fixEmoji(str) {
  if (!str) return '🍽️';
  // Bozuk Latin-1 → UTF-8 çevrim denemeleri için basit kontrol
  // Gerçek emoji Unicode bloğunda (U+1F300+) olmalı
  // Basit heuristic: string 2 karakterden kısaysa boş döndür
  try {
    // Emoji bazen birden fazla code unit içerir, geçerli test:
    const codePoint = str.codePointAt(0);
    if (codePoint && (codePoint >= 0x1F300 || codePoint >= 0x2600)) {
      return str;
    }
    return '🍽️';
  } catch {
    return '🍽️';
  }
}

// ─── Malzeme adına göre ID bul ──────────────────────────────────────────────
// ingredientId'leri isimle eşleştirmek için index
let ingredientNameToId = {};

// ─── 1. MALZEMELERI IMPORT ET ────────────────────────────────────────────────
async function importMalzemeler() {
  console.log(`\n📦 ${malzemeler.length} malzeme import ediliyor...`);

  // Mevcut dökümanları kontrol et
  const existing = await db.collection('ingredients').limit(1).get();
  if (!existing.empty) {
    console.log('⚠️  ingredients koleksiyonu zaten dolu. Atlanıyor...');
    console.log('   Zorla silmek için: node scripts/import_to_firebase.js --force');
    // Mevcut ID haritasını doldur
    const allSnap = await db.collection('ingredients').get();
    allSnap.forEach(doc => {
      ingredientNameToId[doc.data().name.toLowerCase()] = doc.id;
    });
    return;
  }

  const batchSize = 400; // Firestore batch limiti 500
  let batchCount = 0;
  let batch = db.batch();
  let processed = 0;

  for (let i = 0; i < malzemeler.length; i++) {
    const raw = malzemeler[i];
    const docId = `ing_${i + 1}`;

    const emoji = fixEmoji(raw.emoji);
    const name = (raw.name || '').trim();
    const category = mapCategory(raw.category);
    const imageUrl = raw.imageUrl || '';

    const data = {
      name,
      emoji,
      imageUrl,
      category,
    };

    batch.set(db.collection('ingredients').doc(docId), data);
    ingredientNameToId[name.toLowerCase()] = docId;
    batchCount++;
    processed++;

    if (batchCount === batchSize) {
      await batch.commit();
      console.log(`  ✓ ${processed}/${malzemeler.length} malzeme yazıldı`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    console.log(`  ✓ ${processed}/${malzemeler.length} malzeme yazıldı`);
  }

  console.log('✅ Malzemeler import tamamlandı.');
}

// ─── 2. TARİFLERİ IMPORT ET ─────────────────────────────────────────────────
async function importYemekler() {
  console.log(`\n🍽️  ${yemekler.length} tarif import ediliyor...`);

  const existing = await db.collection('recipes').limit(1).get();
  if (!existing.empty) {
    console.log('⚠️  recipes koleksiyonu zaten dolu. Atlanıyor...');
    return;
  }

  const batchSize = 400;
  let batchCount = 0;
  let batch = db.batch();
  let processed = 0;
  let warnings = [];

  for (let i = 0; i < yemekler.length; i++) {
    const raw = yemekler[i];

    // createdAt: ISO string → Firestore Timestamp  ← KRİTİK FİX
    let createdAt;
    try {
      const date = new Date(raw.createdAt);
      if (isNaN(date.getTime())) throw new Error('Geçersiz tarih');
      createdAt = admin.firestore.Timestamp.fromDate(date);
    } catch {
      createdAt = admin.firestore.Timestamp.now();
      warnings.push(`Tarif ${i + 1} (${raw.name}): createdAt dönüştürülemedi, şimdiki zaman kullanıldı`);
    }

    // Tip eşleme
    const type = mapType(raw.type || 'Ana Yemek');

    // Malzemeleri işle — ingredientId'yi isme göre eşleştir
    const ingredients = (raw.ingredients || []).map(ing => {
      const nameKey = (ing.name || '').toLowerCase().trim();
      const matchedId = ingredientNameToId[nameKey] || ing.ingredientId || 'ing_unknown';

      return {
        ingredientId: matchedId,
        name: ing.name || '',
        amount: ing.amount || '',
        ...(ing.emoji ? { emoji: ing.emoji } : {}),
      };
    });

    // Adımları işle — order'ın int olduğunu garantile
    const steps = (raw.steps || []).map(step => ({
      order: parseInt(step.order, 10) || 0,
      text: step.text || '',
      ...(step.imageUrl ? { imageUrl: step.imageUrl } : {}),
    }));

    const docId = raw.id || `recipe_${i + 1}`;

    const data = {
      name: raw.name || '',
      description: raw.description || '',
      cuisine: raw.cuisine || 'Türk',
      type,
      duration: raw.duration || '30 dk',
      emoji: fixEmoji(raw.emoji),
      imageUrls: Array.isArray(raw.imageUrls) ? raw.imageUrls : [],
      ingredients,
      steps,
      tags: Array.isArray(raw.tags) ? raw.tags : [],
      officialLikeCount: raw.officialLikeCount || 0,
      communityLikeCount: raw.communityLikeCount || 0,
      likeCount: raw.likeCount || 0,
      authorId: raw.authorId || 'system',
      authorName: raw.authorName || '',
      isOfficial: raw.isOfficial !== undefined ? raw.isOfficial : true,
      ...(raw.parentRecipeId ? { parentRecipeId: raw.parentRecipeId } : {}),
      commentCount: raw.commentCount || 0,
      createdAt,
    };

    batch.set(db.collection('recipes').doc(docId), data);
    batchCount++;
    processed++;

    if (batchCount === batchSize) {
      await batch.commit();
      console.log(`  ✓ ${processed}/${yemekler.length} tarif yazıldı`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    console.log(`  ✓ ${processed}/${yemekler.length} tarif yazıldı`);
  }

  if (warnings.length > 0) {
    console.log('\n⚠️  Uyarılar:');
    warnings.forEach(w => console.log('  - ' + w));
  }

  console.log('✅ Tarifler import tamamlandı.');
}

// ─── Ana akış ────────────────────────────────────────────────────────────────
(async () => {
  try {
    console.log('🚀 Firebase import başlıyor...');
    console.log(`   Proje: kolaytarifler-37c45`);

    await importMalzemeler();
    await importYemekler();

    console.log('\n🎉 Import tamamlandı!');
    process.exit(0);
  } catch (err) {
    console.error('\n❌ Hata:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
})();
