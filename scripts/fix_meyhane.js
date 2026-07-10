// Meyhane Pilavı düzeltmesi: yanlış "iç pilav" içeriği yerine gerçek meyhane usulü
// domatesli/biberli bulgur pilavı. İsimle Firestore'da bulunur, ingredientId'ler çözülür.
// node fix_meyhane.js --commit
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
const COMMIT = process.argv.includes('--commit');
const norm = s => (s || '').toLowerCase().trim();

const NAME = 'Meyhane Pilavı';
const DESC = 'Bulgurun biber salçası, rengarenk biber ve sarımsakla meyhane usulü piştiği, etsiz ve iştah açıcı pilav.';
const INGREDIENTS = [
  { name: 'Pilavlık bulgur', amount: '2 su bardağı', emoji: '🌾' },
  { name: 'Domates', amount: '2 adet', emoji: '🍅' },
  { name: 'Kırmızı Biber', amount: '1 adet', emoji: '🫑' },
  { name: 'Yeşil biber', amount: '2 adet', emoji: '🫑' },
  { name: 'Soğan', amount: '1 adet', emoji: '🧅' },
  { name: 'Sarımsak', amount: '2 diş', emoji: '🧄' },
  { name: 'Salça', amount: '1 yemek kaşığı', emoji: '🥫' },
  { name: 'Biber Salçası', amount: '1 tatlı kaşığı', emoji: '🥫' },
  { name: 'Tereyağı', amount: '2 yemek kaşığı', emoji: '🧈' },
  { name: 'Zeytinyağı', amount: '2 yemek kaşığı', emoji: '🫒' },
  { name: 'Tavuk Suyu', amount: '3 su bardağı', emoji: '🍲' },
  { name: 'Tuz', amount: '1 tatlı kaşığı', emoji: '🧂' },
  { name: 'Karabiber', amount: '1 çay kaşığı', emoji: '🌶️' },
  { name: 'Pul biber', amount: '1 çay kaşığı', emoji: '🌶️' },
];
const STEPS = [
  'Geniş tabanlı bir tencerede tereyağı ve zeytinyağını birlikte kızdırın; iki yağın karışımı meyhane pilavına karakteristik lezzetini verir.',
  'İnce doğranmış soğanı ekleyip hafif renk alana kadar orta ateşte kavurun.',
  'Küçük doğranmış kırmızı ve yeşil biberleri ekleyip 3-4 dakika soteleyin.',
  'İnce doğranmış sarımsağı ekleyip kokusu çıkana kadar 1 dakika kavurun.',
  'Domates salçası ve biber salçasını ekleyip ham kokusu geçene kadar 2 dakika kavurun.',
  'Küp doğranmış domatesleri ilave edip suyunu salıp çekene kadar pişirin.',
  'Pilavlık bulguru ekleyip 3-4 dakika kavurun; kavurmak bulgurun tane tane olmasını sağlar.',
  'Sıcak tavuk suyunu, tuz, karabiber ve pul biberi ekleyin.',
  'Kaynamaya başlayınca ateşi kısın, kapağı kapatıp bulgur suyunu çekene kadar 12-15 dakika pişirin.',
  'Ocaktan alıp kapağın altına temiz bir bez koyup 15 dakika demlendirin.',
  'Bulguru çatalla nazikçe kabartıp sıcak servis edin; yanında cacık çok yakışır.',
];

(async () => {
  const snap = await db.collection('recipes').where('name', '==', NAME).get();
  if (snap.size !== 1) { console.error(`❌ ${snap.size} eşleşme, beklenen 1`); process.exit(1); }
  const doc = snap.docs[0];

  const ingSnap = await db.collection('ingredients').get();
  const nameToId = {};
  ingSnap.forEach(d => nameToId[norm(d.data().name)] = d.id);

  const missing = INGREDIENTS.filter(i => !nameToId[norm(i.name)]).map(i => i.name);
  if (missing.length) { console.error('❌ eksik malzeme:', missing); process.exit(1); }

  const ingredients = INGREDIENTS.map(i => ({
    ingredientId: nameToId[norm(i.name)], name: i.name, amount: i.amount, emoji: i.emoji,
  }));
  const steps = STEPS.map((t, i) => ({ order: i + 1, text: t }));

  console.log(`Hedef: ${doc.id} | ${ingredients.length} malzeme | ${steps.length} adım`);
  if (!COMMIT) { console.log('(DRY-RUN — --commit ile yaz)'); process.exit(0); }

  await doc.ref.update({
    description: DESC, ingredients, steps,
    duration: '40 dk', servings: '4 kişilik',
    modifiedAt: admin.firestore.Timestamp.now(),
  });
  console.log('✅ Meyhane Pilavı düzeltildi.');
  process.exit(0);
})().catch(e => { console.error('❌', e.message); process.exit(1); });
