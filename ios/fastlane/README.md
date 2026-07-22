# App Store metadata

Bu klasör App Store Connect için Türkçe mağaza metinlerini ve App Store uyumlu
mağaza görsellerini içerir.

- Bundle ID: `com.kolaytarifler.app`
- Dil: `tr-TR`
- Ekran görüntüleri: `screenshots/tr-TR`
- Metadata: `metadata/tr-TR`

Kaynak uygulama ekranlarının Android durum ve sistem gezinme çubukları üretim
betikleri tarafından kırpılır. App Store'a gönderilen çerçevelerde yalnızca
uygulama arayüzü bulunur; Android sistem kromu veya test reklamı bulunmaz.

Arkadaşının Mac bilgisayarında Fastlane kurulup App Store Connect yetkilendirmesi tamamlandıktan sonra `ios` klasörü içinde `fastlane deliver` ile yüklenebilir. Komut çalıştırılmadan önce App Store Connect'teki mevcut metadata ile çakışma olup olmadığı kontrol edilmelidir.

Hesap e-postası, takım kimliği veya App Store Connect API anahtarı güvenlik nedeniyle repoya eklenmemiştir.

App Review ret düzeltmeleri ve fiziksel cihaz kayıt akışı için
`docs/APPLE_REVIEW_RESUBMISSION.md` dosyasına bakın.
