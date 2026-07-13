# Google Play Data Safety cevap taslağı

Bu cevaplar mevcut kod ve kullanılan Firebase/Google Mobile Ads SDK'larına göre hazırlanmıştır. SDK veya veri akışı değişirse form yeniden gözden geçirilmelidir.

## Genel

- Uygulama gerekli kullanıcı verilerini topluyor veya paylaşıyor mu? **Evet**
- Tüm kullanıcı verileri aktarım sırasında şifreleniyor mu? **Evet**
- Kullanıcı hesap silme talebinde bulunabiliyor mu? **Evet**
- Hesap silme URL'si: `https://kolaytarifler-37c45.web.app/account-deletion`
- Bağımsız veri silme talebi: destek e-postası ve aynı web sayfası üzerinden mümkün

## Bildirilecek veri türleri

| Play veri türü | Toplanır | Paylaşılır | Amaç | İsteğe bağlı mı? |
|---|---:|---:|---|---:|
| Yaklaşık konum | Evet | Evet | Reklam, analiz, sahtekârlığı önleme | Hayır |
| Ad | Evet | Hayır | Hesap yönetimi, uygulama işlevi, topluluk görünümü | Hesap açmak isteğe bağlı |
| E-posta adresi | Evet | Hayır | Hesap yönetimi, güvenlik, destek | Hesap açmak isteğe bağlı |
| Kullanıcı kimlikleri | Evet | Hayır | Kimlik doğrulama, uygulama işlevi, güvenlik | Hesap açmak isteğe bağlı |
| Fotoğraflar | Evet | Hayır | Profil ve kullanıcı tarifi paylaşımı | Evet |
| Diğer kullanıcı içeriği | Evet | Hayır | Tarif, yorum, not ve topluluk özellikleri | Evet |
| Uygulama etkileşimleri | Evet | Evet | Reklam, analiz, sahtekârlığı önleme | Hayır |
| Kilitlenme günlükleri | Evet | Hayır | Uygulama kararlılığı ve hata giderme | Hayır |
| Teşhis verileri | Evet | Evet | Performans, reklam, analiz, sahtekârlığı önleme | Hayır |
| Diğer uygulama performans verileri | Evet | Hayır | Kararlılık ve performans | Hayır |
| Cihaz veya diğer kimlikler | Evet | Evet | Bildirim, reklam, analiz, sahtekârlığı önleme | Hayır |

## Açıklama notları

- Google Mobile Ads SDK; IP adresinden yaklaşık konum, ürün etkileşimleri, tanılama bilgileri ve cihaz/reklam kimliklerini reklam, analiz ve sahtekârlığı önleme amacıyla otomatik toplar ve paylaşır.
- Firebase Authentication hesap verilerini; Firestore ve Storage geliştirici tanımlı kullanıcı içeriklerini; Crashlytics çökme ve tanılama verilerini; Cloud Messaging uygulama sürümü, Firebase kurulum kimliği ve bildirim belirtecini işler.
- Uygulamada Google Analytics paketi bulunmuyor. İleride eklenirse Data Safety formu güncellenmelidir.
- Yemek takvimi, alışveriş listesi ve bazı tercihler cihaz üzerinde tutulabilir. Buluta gönderilmeyen cihaz içi veriler Data Safety'de “toplanan” sayılmaz.
- “Paylaşılır” işareti, Google Mobile Ads'in üçüncü taraf reklam işleme akışı nedeniyle verilmiştir. Google'ın hizmet sağlayıcı istisnasını Console'daki güncel tanımlara göre tekrar kontrol edin.
- Gizlilik politikasındaki açıklamalar bu tabloyla aynı kalmalıdır.
