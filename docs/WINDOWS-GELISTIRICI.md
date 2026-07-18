# Windows'tan iOS geliştirme ve yayınlama — Kolay Tarifler

Bu belge, **Kolay Tarifler** Flutter projesini Windows bilgisayardan geliştirip
bulut tabanlı bir macOS derleyicisi kullanarak TestFlight ve App Store'a
gönderme sürecini anlatır.

## Kısa cevap

Windows bilgisayardan iOS yayını alınabilir; ancak iOS uygulaması Windows'un
kendisinde derlenmez. Windows yalnızca kodu, testleri ve yayın iş akışını
yönetir. Xcode derlemesi ve Apple imzalama işlemleri Codemagic'in buluttaki
macOS makinesinde yapılır.

Bu projede kullanılacak yöntem:

```text
Windows bilgisayar
  ├─ Flutter geliştirme ve test
  ├─ GitHub'a gönderme
  └─ Codemagic iş akışını başlatma
            │
            ▼
Codemagic macOS makinesi
  ├─ Flutter iOS bağımlılıklarını kurma
  ├─ Xcode ile derleme
  ├─ Apple sertifikasıyla imzalama
  ├─ IPA oluşturma
  └─ App Store Connect'e yükleme
            │
            ▼
TestFlight → iPhone 11 → App Review → App Store
```

> Bu proje Expo veya React Native değildir. `eas build`, `eas submit`, Metro ve
> Expo Dev Client komutları **kullanılmaz**. Proje Flutter'dır ve önerilen bulut
> derleme hizmeti Codemagic'tir.

## Projenin yayın kimliği

| Alan | Değer |
|---|---|
| Uygulama adı | Kolay Tarifler |
| GitHub deposu | `Ogulcan-Dinsever/kolay-tarifler` |
| Doğrulanan Flutter sürümü | `3.44.6` stable / Dart `3.12.2` |
| Uygulama sürümü | `1.1.1+6` |
| iOS Bundle ID | `com.kolaytarifler.app` |
| Apple uygulama ID'si | `6790800121` |
| Apple Team ID | `M9NTSXWYFS` |
| Minimum iOS | `16.0` |
| Firebase projesi | `kolaytarifler-37c45` |
| iOS Firebase App ID | `1:129219992136:ios:7655112eddbe532d2c967d` |
| Test cihazı | iPhone 11 |

Bu değerler başka projelerden kopyalanmamalıdır. Özellikle farklı bir Apple
uygulama ID'si, Bundle ID, Firebase projesi veya Expo proje kimliği kullanmak
mevcut Kolay Tarifler uygulamasını güncellemez.

## Windows'ta yapılabilenler ve yapılamayanlar

| İşlem | Windows | Açıklama |
|---|---:|---|
| Dart/Flutter kodu geliştirme | ✅ | VS Code veya Android Studio kullanılabilir. |
| `flutter analyze` ve `flutter test` | ✅ | iOS derlemesi gerektirmez. |
| Android emülatör ve gerçek Android testi | ✅ | Mevcut geliştirme akışı aynen devam eder. |
| Flutter web ile hızlı arayüz kontrolü | ✅ | iOS davranışının yerine geçmez. |
| Codemagic iOS build başlatma | ✅ | Derleme buluttaki macOS makinesinde yapılır. |
| App Store Connect ve TestFlight yönetimi | ✅ | Tarayıcıdan yapılır. |
| iPhone 11'e TestFlight kurulumu | ✅ | UDID kaydı gerekmez. |
| Windows'ta yerel IPA derleme | ❌ | Xcode ve iOS SDK macOS gerektirir. |
| Windows'ta iOS Simulator | ❌ | Simulator yalnızca macOS/Xcode ortamındadır. |
| Windows'tan iPhone'a Flutter hot reload | ❌ | Expo belgesindeki Metro yaklaşımı Flutter'a uygulanmaz. |
| Xcode debugger ve Instruments | ❌ | Gerekirse uzak/fiziksel bir Mac kullanılmalıdır. |

## Hazır olan iOS yapılandırmaları

Projede aşağıdaki iOS parçaları zaten bulunmaktadır:

- `ios/Runner/GoogleService-Info.plist`
- Firebase Auth, Firestore, Storage, Crashlytics ve Messaging yapılandırması
- Google ile giriş URL scheme'i
- Apple ile giriş entitlement'ı
- Push notification entitlement'ı
- Kamera ve fotoğraf galerisi izin açıklamaları
- ATT takip izni açıklaması
- Canlı iOS AdMob uygulama kimliği
- `ITSAppUsesNonExemptEncryption=false` ihracat uyumluluğu bildirimi
- `com.kolaytarifler.app` Bundle ID
- `M9NTSXWYFS` Apple geliştirme takımı
- 1024×1024 App Store simgesi
- App Store Connect'te 10 adet 6.5 inç boyutunda taslak mağaza görseli

> **App Review öncesi görsel kontrolü:** Mevcut taslakların kaynak ekranlarında
> Android durum/gezinti çubukları görünüyor. Boyutları App Store'a uygun olsa da
> iOS deneyimini doğru temsil etmeleri için TestFlight build'i iPhone 11'e
> kurulduktan sonra aynı senaryolar iPhone'da yeniden çekilmeli ve mağazadaki
> görseller bunlarla değiştirilmelidir. Bu durum TestFlight build yüklemesini
> engellemez; App Review'a gönderimden önce kapatılması gereken bir risktir.

Codemagic kurulumu bunların yerine geçmez; mevcut iOS projesini macOS üzerinde
derleyip imzalar.

# İlk kurulum

## 1. Windows geliştirme ortamını doğrula

PowerShell'de proje kökünde çalıştır:

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

Cloud Functions testleri için:

```powershell
npm --prefix functions ci
npm --prefix functions test
```

Firestore kuralları testi ayrıca Java ve Firebase Emulator gerektirir:

```powershell
npm --prefix functions run test:rules
```

## 2. GitHub durumunu temizle

Codemagic yalnızca GitHub'a gönderilmiş dosyaları görür. Derlemeden önce:

```powershell
git status
git pull --ff-only
```

Yalnızca gerekli ve test edilmiş değişiklikleri commit edip `main` dalına
gönder. `.p8`, `.p12`, provisioning profile, parola veya API anahtarı GitHub'a
eklenmemelidir.

## 3. Codemagic hesabını GitHub'a bağla

1. Codemagic hesabı oluştur.
2. GitHub bağlantısını yetkilendir.
3. `Ogulcan-Dinsever/kolay-tarifler` deposunu ekle.
4. Proje türü olarak Flutter seçildiğini doğrula.
5. Çalışma dizini olarak depo kökünü kullan.

Depo kökündeki `codemagic.yaml`, iOS analiz, test, imzalama, IPA üretme ve App
Store Connect'e yükleme adımlarını tanımlar. Codemagic uygulamayı eklediğinde
**Use codemagic.yaml** iş akışını seç. Entegrasyon adı aşağıdaki Apple bağlantısı
oluşturulurken tam olarak `Kolay Tarifler App Store` olmalıdır.

### Ücretsiz kota güvenliği

- Kişisel Codemagic hesabında yalnızca ücretsiz macOS M2 makinesini kullan.
- **Billing / Enable billing** seçeneğini açma ve Codemagic'e kredi kartı ekleme.
- Bu depoda otomatik GitHub tetikleyicisi yoktur; build yalnızca arayüzden elle
  başlatılır.
- `max_build_duration` 60 dakikadır. Takılan bir işlem varsa sonucu beklemeden
  build'i durdur.
- Her yeni denemeden önce **Billing / Usage** ekranındaki kalan ücretsiz dakikayı
  kontrol et. Kalan kota 60 dakikanın altındaysa yeni build başlatma.
- macOS M4, Linux, Windows, App Preview ve ek concurrency özelliklerini açma.
- Ücretsiz 500 dakika biterse bir sonraki ayın ilk günündeki yenilenmeyi bekle;
  ek dakika satın alma veya ücretli plana geçme.

## 4. App Store Connect API anahtarı oluştur

App Store Connect içinde:

1. **Users and Access** bölümünü aç.
2. **Integrations → App Store Connect API** sayfasına gir.
3. Yeni bir anahtar oluştur.
4. Ad olarak `Codemagic Kolay Tarifler` kullan.
5. Yetki olarak **App Manager** seç.
6. Şu üç değeri kaydet:
   - Issuer ID
   - Key ID
   - İndirilen `.p8` özel anahtar dosyası

`.p8` dosyası yalnızca bir kez indirilebilir. Dosyayı GitHub'a, sohbetlere veya
proje klasörüne koyma.

## 5. Codemagic'i Apple hesabına bağla

Codemagic'te **Team settings → Integrations → Developer Portal** bölümünde:

1. Issuer ID'yi gir.
2. Key ID'yi gir.
3. `.p8` dosyasını yükle.
4. Entegrasyona `Kolay Tarifler App Store` adını ver.
5. Bağlantıyı kaydet.

Ardından uygulamanın iOS code signing ayarlarında:

- Signing: **Automatic**
- Distribution type: **App Store**
- Bundle ID: `com.kolaytarifler.app`
- App Store Connect App: `Kolay Tarifler` / `6790800121`

Codemagic uygun Apple Distribution sertifikasını ve provisioning profile'ı
oluşturabilir. Fiziksel Mac veya Keychain gerekmez.

## 6. Apple capabilities ayarlarını doğrula

Apple Developer portalındaki `com.kolaytarifler.app` App ID'sinde şu yetenekler
açık olmalıdır:

- Sign in with Apple
- Push Notifications

Codemagic yeni provisioning profile oluştururken bu yetenekleri profile dahil
eder. App ID ile projedeki `Runner.entitlements` uyuşmazsa imzalama başarısız
olur.

### Firebase için APNs anahtarını doğrula

Push Notifications capability'sinin açık olması tek başına iPhone'a FCM
bildirimi ulaştırmaz. App Review öncesinde şu bağlantı zorunludur:

1. Apple Developer'da **Certificates, Identifiers & Profiles → Keys** bölümünde
   Apple Push Notifications service (APNs) yetkili bir anahtar bulunduğunu
   doğrula veya oluştur.
2. Anahtarın `.p8` dosyasını, Key ID'sini ve Team ID `M9NTSXWYFS` değerini kaydet.
3. Firebase Console'da `kolaytarifler-37c45` projesini aç.
4. **Project settings → Cloud Messaging → Apple app configuration** bölümünde
   `com.kolaytarifler.app` için APNs authentication key'i yükle.
5. TestFlight build'inde uygulama ön plandayken, arka plandayken ve tamamen
   kapalıyken yönetici onay/red bildirimi göndererek gerçek cihazda doğrula.

APNs `.p8` anahtarı ile App Store Connect API `.p8` anahtarı farklı amaçlara
hizmet eder; birbirinin yerine kullanılmamalı ve ikisi de GitHub'a eklenmemelidir.

## 7. Sürüm numarasını eşleştir

Projede şu an:

```yaml
version: 1.1.1+6
```

Bu değer iOS'ta şu alanlara dönüşür:

- `1.1.1` → `CFBundleShortVersionString`
- `6` → `CFBundleVersion`

App Store Connect'teki sürüm kaydı şu anda `1.0` ise build doğrudan o sürüme
bağlanmaz. Derlemeden önce iki yöntemden biri seçilmelidir:

### Önerilen: mağaza sürümünü proje ile eşleştir

App Store Connect'teki düzenlenebilir sürüm numarasını `1.1.1` yap ve normal
derleme al:

```bash
flutter build ipa --release
```

Bu yöntem Android ve iOS kullanıcı sürümlerini aynı tutar.

### Alternatif: ilk iOS sürümünü 1.0 olarak üret

App Store Connect `1.0` olarak kalacaksa Codemagic build komutunda sürümü geçici
olarak değiştir:

```bash
flutter build ipa --release --build-name=1.0 --build-number=$PROJECT_BUILD_NUMBER
```

Her yeni yüklemede build numarası benzersiz ve öncekinden yüksek olmalıdır.
Depodaki `codemagic.yaml` build başlatılırken `ios_marketing_version` alanını
gösterir ve ilk iOS yayını için `1.0` değerini varsayılan getirir. Sonraki App
Store sürümlerinde bu alan hedef sürümle (örneğin `1.1.1`) değiştirilmelidir.
TestFlight'taki son build numarası otomatik artırılır; Apple kimlik doğrulaması
veya build numarası sorgusu başarısız olursa iş akışı hatayı gizlemeden durur.
Android sürüm numarası ve `pubspec.yaml` bu işlemden etkilenmez.

# Codemagic yayın iş akışı

## Gerekli build adımları

Codemagic iş akışı aşağıdaki sırayı uygulamalıdır:

```bash
flutter pub get
flutter analyze
flutter test
flutter build ipa --release
```

Sürüm `1.0` olarak override edilecekse son komut önceki bölümdeki parametrelerle
çalıştırılır.

Yayın ayarlarında:

- App Store Connect authentication: `Kolay Tarifler App Store` entegrasyonu
- IPA'yı App Store Connect'e yükleme: açık
- TestFlight beta incelemesine otomatik gönderme: ilk build için kapalı
- App Review'a otomatik gönderme: kapalı

Yüklenen build Apple tarafından işlendikten sonra App Store Connect'te TestFlight
iç test grubuna elle eklenmelidir. Bu işlem beta incelemesi gerektirmez. İlk build
otomatik olarak App Review'a gönderilmemeli; önce iPhone 11 ile gerçek cihaz testi
tamamlanmalıdır.

## İlk build sonucunu doğrula

Codemagic başarılı olduğunda:

1. `.ipa` artifact'ı oluşur.
2. Build App Store Connect'e yüklenir.
3. Apple build'i işler.
4. Build TestFlight sekmesinde görünür.
5. Eksik export compliance sorusu çıkmamalıdır; projede
   `ITSAppUsesNonExemptEncryption=false` tanımlıdır.

Apple'ın işleme süresi birkaç dakikadan daha uzun sürebilir. Build 24 saatten
uzun süre Processing durumunda kalırsa teslimat logları incelenmelidir.

# iPhone 11 ile test

## TestFlight kurulumu

1. iPhone 11'i mümkün olan en güncel iOS sürümüne yükselt.
2. App Store'dan **TestFlight** uygulamasını yükle.
3. App Store Connect'teki Apple hesabını TestFlight iç test kullanıcısı yap.
4. İşlenmiş build'i iç test grubuna ekle.
5. iPhone'da TestFlight davetini kabul et.
6. Kolay Tarifler'i TestFlight üzerinden yükle.

İç TestFlight dağıtımında UDID kaydı gerekmez. Ad Hoc kurulum ancak TestFlight
kullanılmayacaksa tercih edilmeli ve iPhone UDID'si Apple Developer hesabına
kaydedilmelidir.

## iPhone 11 zorunlu test listesi

Her yayın adayında en az şu senaryolar denenmelidir:

- Temiz kurulum ve ilk açılış tanıtımı
- Uygulamayı kapatıp yeniden açınca tanıtımın tekrar gelmemesi
- Google ile giriş
- Apple ile giriş
- E-posta/şifre ile giriş ve çıkış
- Hesap silme
- ATT ve UMP reklam izinleri
- Banner reklamın içeriği veya alt gezinme çubuğunu kapatmaması
- Kendi reklamına tıklamadan test reklamı kontrolü
- Kamera ve galeriden tarif fotoğrafı seçme
- Ana tarif gönderme ve yönetici onay/red bildirimi
- Topluluk varyasyonu gönderme
- Beğeni, yorum, yorum silme ve yönetici yorum silme
- Bildirimin ön planda, arka planda ve uygulama kapalıyken davranışı
- Malzemeye göre tarif bulma
- Mutfak listesindeki “Tümünü gör” sayfası ve 20'li sayfalama
- Takvim ve alışveriş listesi
- İnternet yokken önbellek davranışı
- Koyu/açık tema ve erişilebilir metin boyutu

Test sırasında gerçek reklam birimine tıklama. AdMob hesabında iPhone'u test
cihazı olarak kaydet veya test reklam birimlerini kullan.

# Her sürümde tekrarlanacak akış

```text
1. Windows'ta geliştirme
2. flutter analyze
3. flutter test
4. Android/emülatör kontrolleri
5. Commit ve GitHub push
6. Codemagic iOS build
7. App Store Connect işlem kontrolü
8. TestFlight iç test
9. iPhone 11 gerçek cihaz senaryoları
10. App Store sürümüne build seçme
11. App Review'a gönderme
```

App Store'a gönderimden hemen önce ayrıca şunlar tamamlanmalıdır:

- Android sistem çubuğu görünen taslakları gerçek iPhone ekran görüntüleriyle değiştirmek
- Firebase APNs anahtarını doğrulayıp bildirimleri iPhone'da üç uygulama durumunda test etmek
- App Privacy cevaplarını **Publish** etmek
- Content Rights beyanını tamamlamak
- İnceleme için çalışan test hesabı kullanıcı adı/şifresi girmek
- Build'i sürüm kaydına seçmek
- App Review notlarını ve iletişim bilgilerini doğrulamak

# Sorun giderme

## `No matching profiles found`

- Bundle ID'nin `com.kolaytarifler.app` olduğunu doğrula.
- App Store profile türünün seçildiğini doğrula.
- Apple App ID'de Sign in with Apple ve Push Notifications yeteneklerini aç.
- Codemagic'in provisioning profile'ı yeniden üretmesini sağla.

## Build App Store Connect'te görünmüyor

- Codemagic publishing logunu kontrol et.
- Apple uygulama ID'sinin `6790800121` olduğunu doğrula.
- Build sürümünün App Store sürüm kaydıyla eşleştiğini doğrula.
- App Store Connect'te TestFlight → Build Uploads durumunu kontrol et.

## `CFBundleShortVersionString` uyuşmuyor

`pubspec.yaml` sürümü ile App Store Connect sürüm kaydını eşleştir veya build
komutunda `--build-name` kullan.

## Google ile giriş açılmıyor

- `ios/Runner/GoogleService-Info.plist` dosyasının build'e dahil olduğunu kontrol et.
- URL scheme'in Firebase'deki `REVERSED_CLIENT_ID` ile eşleştiğini doğrula.
- Firebase Authentication içinde Google sağlayıcısının açık olduğunu kontrol et.

## Apple ile giriş başarısız

- Firebase Authentication içinde Apple sağlayıcısını kontrol et.
- Apple App ID'de Sign in with Apple capability'sini kontrol et.
- Yeniden provisioning profile üret.
- Gerçek cihazda test et; yalnızca web veya Android sonucu yeterli değildir.

## Push bildirim gelmiyor

- Apple App ID'de Push Notifications capability'sini kontrol et.
- Codemagic'in güncel profile ile imzaladığını doğrula.
- Firebase Cloud Messaging APNs yapılandırmasını kontrol et.
- Bildirim izninin iPhone ayarlarında açık olduğunu doğrula.

## CocoaPods veya Xcode derleme hatası

Bu hata Windows'ta yerel olarak yeniden üretilemeyebilir. Codemagic build logunda
ilk gerçek hata satırını bul. Gerekirse cache temizlenmiş yeni build başlat.
Native seviyede ayrıntılı hata ayıklama gerekiyorsa arkadaşın Mac'i veya başka
bir uzak Mac ortamı kullanılmalıdır.

# Güvenlik kuralları

- App Store Connect `.p8` anahtarını GitHub'a ekleme.
- Sertifika, provisioning profile ve parolaları commit etme.
- Firebase servis hesabı anahtarlarını mobil uygulamaya gömme.
- Codemagic sırlarını yalnızca şifreli environment variable/integration olarak tut.
- Codemagic'e gereğinden geniş Apple rolü verme; App Manager yeterlidir.
- Gerçek AdMob reklamına geliştirici/test cihazından tıklama.

# Sonuç

Kolay Tarifler, fiziksel Mac sahibi olmadan Windows üzerinden App Store'a
gönderilebilir. Bunun anlamı “Windows iOS derler” değildir; Windows, GitHub ve
Codemagic üzerinden buluttaki Mac derlemesini yönetir.

Günlük Flutter geliştirme ve Android testleri Windows'ta yapılır. iOS yayın
adayları Codemagic ile üretilir ve iPhone 11'de TestFlight üzerinden doğrulanır.
Xcode debugger, Instruments veya doğrudan iOS hot reload gerektiğinde fiziksel
ya da uzak bir Mac hâlâ gereklidir.
