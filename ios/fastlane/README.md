# App Store metadata

Bu klasör App Store Connect için Türkçe mağaza metinlerini ve 6.5 inç boyutunda
taslak mağaza görsellerini içerir.

- Bundle ID: `com.kolaytarifler.app`
- Dil: `tr-TR`
- Ekran görüntüleri: `screenshots/tr-TR`
- Metadata: `metadata/tr-TR`

Mevcut taslak görsellerin bazı kaynak ekranlarında Android sistem çubukları
bulunur. TestFlight build'i iPhone 11'e kurulduktan sonra aynı akışlar iOS'ta
yeniden çekilmeli ve App Review'a göndermeden önce bu dosyalar değiştirilmelidir.

Arkadaşının Mac bilgisayarında Fastlane kurulup App Store Connect yetkilendirmesi tamamlandıktan sonra `ios` klasörü içinde `fastlane deliver` ile yüklenebilir. Komut çalıştırılmadan önce App Store Connect'teki mevcut metadata ile çakışma olup olmadığı kontrol edilmelidir.

Hesap e-postası, takım kimliği veya App Store Connect API anahtarı güvenlik nedeniyle repoya eklenmemiştir.
