# Değişiklik Günlüğü

Kolay Tarifler'in kullanıcıya yansıyan önemli değişiklikleri bu dosyada listelenir.

## [1.1.2] - 2026-07-19

### Fixed

- Banner reklamlar geçici ağ veya reklam stoğu hatalarından sonra güvenli aralıklarla yeniden yüklenir.
- Android ve iOS reklam hata kodları platforma göre değerlendirilerek geçici iOS “no fill” yanıtlarında reklam alanının kalıcı olarak kapanması önlendi.
- Uygulama arka plana alındığında ya da reklam izni kaldırıldığında bekleyen reklam istekleri ve yeniden denemeler temizlenir.
- Yüklenemeyen banner alanı ekranı kaplamaz; başarılı reklam yalnızca gerçek 320 × 50 boyutu kadar yer kullanır.

## [1.1.0] - 2026-07-17

### Added

- Profilde, kullanıcının yaptığı yorumları ve beğendiği tarifleri tek ekranda görme imkânı eklendi.
- Kullanıcılar kendi yorumlarını; yöneticiler ise tüm kullanıcı yorumlarını silebilir.

### Changed

- Profildeki “Tarif Gönder” akışından onaylanan tarifler artık gönderen kişinin adıyla bağımsız ana tarif olarak yayımlanır ve keşif alanlarında gösterilir.
- Bir tarifin içinden eklenen topluluk tarifleri yalnızca ilgili ana tarifin altında gösterilen tek seviyeli varyasyonlardır.

### Fixed

- Topluluk varyasyonlarının ana sayfa, tüm tarifler, arama ve öneri listelerine karışması engellendi.
- Bir topluluk varyasyonunun altına yeniden varyasyon eklenebilmesine karşı uygulama ve veritabanı koruması eklendi.
