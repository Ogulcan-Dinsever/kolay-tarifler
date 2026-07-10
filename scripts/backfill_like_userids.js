// Beğeni belgelerine `userId` alanını geriye dönük ekler.
// Neden: userLikedIdsStream artık collectionGroup('likes').where('userId', ==, uid)
// kullanıyor. Eski beğeni belgeleri sadece {createdAt} içeriyor; userId yok →
// kullanıcı yeniden beğenene kadar kalp dolu görünmez. Bu script bir kez çalışıp
// tüm eski beğenilere userId = <belge id'si> (== kullanıcı uid) yazar.
//
// Kullanım:
//   node backfill_like_userids.js            # DRY-RUN (sadece sayar, yazmaz)
//   node backfill_like_userids.js --commit   # gerçek yazma
//
// serviceAccountKey.json gerektirir (gitignored).

const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json')),
});
const db = admin.firestore();

const COMMIT = process.argv.includes('--commit');
const CHUNK = 400; // Firestore batch limiti 500; güvenli pay bırak.

(async () => {
  console.log(
    `🔧 backfill_like_userids — ${COMMIT ? 'COMMIT (gerçek yazma)' : 'DRY-RUN (yazma yok)'}\n`
  );

  const snap = await db.collectionGroup('likes').get();
  console.log(`Toplam beğeni belgesi: ${snap.size}`);

  // userId alanı eksik ya da belge id'siyle uyuşmayan belgeleri bul.
  const toFix = [];
  let alreadyOk = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.userId === doc.id) {
      alreadyOk++;
    } else {
      toFix.push(doc);
    }
  }

  console.log(`Zaten userId'li: ${alreadyOk}`);
  console.log(`Düzeltilecek:    ${toFix.length}`);

  if (toFix.length === 0) {
    console.log('\n✅ Yapılacak bir şey yok.');
    process.exit(0);
  }

  // Örnek birkaç yol göster.
  console.log('\nÖrnekler:');
  toFix.slice(0, 5).forEach((d) => console.log('  ' + d.ref.path + ' → userId=' + d.id));

  if (!COMMIT) {
    console.log('\n(DRY-RUN — gerçek yazma için --commit)');
    process.exit(0);
  }

  let written = 0;
  for (let i = 0; i < toFix.length; i += CHUNK) {
    const batch = db.batch();
    for (const doc of toFix.slice(i, i + CHUNK)) {
      // merge: createdAt vb. mevcut alanlar korunur.
      batch.set(doc.ref, { userId: doc.id }, { merge: true });
    }
    await batch.commit();
    written += Math.min(CHUNK, toFix.length - i);
    console.log(`  yazıldı: ${written}/${toFix.length}`);
  }

  console.log('\n🎉 Backfill tamam.');
  process.exit(0);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
