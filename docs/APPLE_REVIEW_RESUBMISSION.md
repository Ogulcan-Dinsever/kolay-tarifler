# Apple App Review yeniden gönderim notları

## Düzeltilen ret maddeleri

### Guideline 2.3.10 — Accurate Metadata

- Tüm iPhone mağaza görsellerindeki Android durum ve sistem gezinme çubukları kaldırıldı.
- Görseller yalnızca gerçek Kolay Tarifler uygulama arayüzünü gösteriyor.
- Test reklamı görünen katkı ekranlarının alt bölümü mağaza görsellerinden çıkarıldı.

### Guideline 1.2 — User-Generated Content

- E-posta, Google, Apple ve misafir girişlerinden önce Kullanım ve Topluluk Koşulları onayı zorunlu.
- Koşullar uygunsuz içeriğe ve kötüye kullanıma sıfır toleransı açıkça belirtiyor.
- Yorum, ana tarif başvurusu ve topluluk varyasyonlarında istemci tarafı içerik filtresi var.
- Cloud Functions aynı filtreyi sunucu tarafında tekrar uyguluyor; uygunsuz yorum/varyasyon kaldırılıyor, ana tarif başvurusu reddediliyor ve admin raporu açılıyor.
- Her yorum ve topluluk tarifinde **Bildir** seçeneği bulunuyor.
- Her yorum ve topluluk tarifinde **Kullanıcıyı engelle** seçeneği bulunuyor.
- Engelleme, kullanıcının içeriklerini engelleyen kişinin akışından hemen kaldırıyor ve moderasyon kuyruğuna otomatik rapor gönderiyor.
- Admin rapor ekranında içerik silme ve ihlal eden kullanıcıyı topluluk özelliklerinden uzaklaştırma işlemleri bulunuyor.
- Askıya alınmış kullanıcı Firestore kurallarıyla yeni yorum, beğeni, tarif başvurusu veya varyasyon oluşturamıyor; yeniden giriş denemesinde uygulamadan çıkarılıyor.
- Kullanım Koşulları bildirimlerin 24 saat içinde inceleneceğini, ihlal içeriğinin kaldırılacağını ve hesabın askıya alınacağını açıkça belirtiyor.

## App Review Notes için hazır metin

The issues from the previous review have been addressed:

1. All App Store screenshots were replaced with device-neutral images that contain no Android status/navigation bars or test ads.
2. Before any email, Google, Apple, or guest authentication, the user must explicitly accept the Terms of Use and Community Guidelines. The terms state zero tolerance for objectionable content and abusive users.
3. User-generated text is filtered before submission and re-checked by server-side Cloud Functions.
4. Comments and community recipes include Report and Block User actions. Blocking immediately removes that user's content from the blocker's feed and automatically creates a developer moderation report.
5. The admin moderation queue supports content removal and user suspension. Suspended users are prevented by Firestore Security Rules from creating new community content.
6. Reports are reviewed within 24 hours, with offending content removed and abusive users suspended.

Review path:
- Launch app → authentication screen: Terms acceptance is visible before all sign-in options.
- Open any recipe → Comments → three-dot menu: Report / Block User.
- Open any recipe → Community Recipes → three-dot menu: Report / Block User.

Physical-device demonstration video: **VIDEO_URL_EKLENECEK**

## Fiziksel iPhone kayıt listesi

Apple'ın istediği tek kullanıcıya bağlı kanıt budur. Yeni üretim build'i iPhone 11'e kurulduktan sonra tek videoda:

1. Uygulamayı silip yeniden yükleyin veya çıkış yapın.
2. Giriş ekranındaki zorunlu koşul onayını ve koşullar bağlantısını gösterin.
3. Koşulu işaretlemeden giriş düğmelerinin pasif olduğunu gösterin.
4. Giriş yapın.
5. Bir tarifin yorumlarında üç nokta → **Bildir** ekranını gösterin.
6. Aynı menüden **Kullanıcıyı engelle** işlemini ve içeriğin anında kaybolmasını gösterin.
7. Topluluk Tarifleri sekmesinde aynı Bildir / Engelle menüsünü gösterin.
8. Videoyu erişilebilir bir bağlantıya yükleyip yukarıdaki `VIDEO_URL_EKLENECEK` alanı yerine App Review Notes'a ekleyin.
