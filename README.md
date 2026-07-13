# Kolay Tarifler

Türkçe ve dünya mutfaklarından tarifleri bir araya getiren, evdeki malzemeye göre tarif önerebilen, haftalık yemek planlaması yapıp otomatik alışveriş listesi çıkaran bir Flutter uygulaması. Firebase üzerinde çalışıyor ve Google Play yayın hazırlığı aşamasında.

Bu README'yi hem "bir kullanıcı gibi uygulamayı gezersem ne görürüm" hem de "kod tabanına ilk kez bakan bir geliştirici olsam neyi fark ederim" diye iki gözle yazdım. Aşağısı kısa bir tanıtım değil, dürüst bir döküm — neyin iyi oturduğu, neyin yarım kaldığı, neyin borç olarak biriktiği dahil.

## Kullanıcı gözünden

Uygulamayı açtığında önce kısa bir splash ekranı karşılıyor (arka planda sessizce anonim oturum açıyor, ilk çalıştırmaysa tarif/malzeme verisini Firestore'a tohumluyor), sonra alt tarafta 6-7 sekmeli bir gezinme çubuğuyla ana ekrana düşüyorsun. Giriş yapmadan da her şeye göz atabiliyorsun — hesap zorunluluğu sadece beğenme, yorum yapma ve tarif göndermede devreye giriyor.

**Ana akışlar şöyle:**

- **Ana Sayfa** — arama çubuğu, mutfak çipleri (Türk, İtalyan, Japon...), haftanın tarifi, ve her mutfaktan karışık 10 tarif. İlk açılışta 3 adımlık bir spotlight tanıtımı var (arama → mutfak çipleri → tarif kartları), bir daha göstermiyor.
- **Malzemeye göre** — elindeki malzemeleri seçip kaç tanesi eşleşiyor diye sıralanmış tarifleri görüyorsun. Fotoğraf yüklenmezse emoji'ye düşüyor, küçük ama düşünülmüş bir detay.
- **Türe göre** — çorba, tatlı, ana yemek gibi kategorilerde emoji'li bir grid.
- **Arama** — düz metin arama, sonuç yoksa "❌ bulunamadı" durumu var.
- **Takvim** — aylık görünümde hangi güne ne pişireceğini planlıyorsun, planlanan günler nokta ile işaretleniyor. Buradan tek dokunuşla alışveriş listesine geçiyorsun.
- **Alışveriş Listesi** — seçtiğin aydaki tüm planlanan tariflerin malzemelerini topluyor, aynı malzemeyi birleştirip miktarları topluyor ("400 gr" gibi serbest metin miktarları bile ayrıştırıyor), işaretleyip üstünü çizebiliyorsun.
- **Tarif Detayı** — kaydırmalı fotoğraf galerisi, beğeni, malzemeler/adımlar/yorumlar/notlarım sekmeleri, ve resmi tarifler için bir **Topluluk** sekmesi — kullanıcılar bir tarifin kendi versiyonlarını ekleyebiliyor. Bu kısım bence uygulamanın en özgün tarafı (aşağıda geliştirici gözünden de değineceğim).
- **Profil** — misafirsen giriş yapmaya nazikçe teşvik ediyor, girişliysen tema anahtarı, tarif gönderme ve "Başvurularım" linkleri var.
- **Tarif Gönder / Kendi Versiyonumu Paylaş** — ikisi de form ama farklı akış: yeni bir resmi tarif göndermek admin onayından geçiyor, bir tarifin "kendi versiyonunu" eklemek direkt yayınlanıyor. Bu ayrım bilinçli görünüyor — kalite kontrolü asıl tarif havuzunda, özgürlük varyasyonlarda.
- **Admin Paneli** — malzeme/tarif ekleme, admin yönetimi, ve bekleyen başvuruları onaylama/reddetme (red sebebi de yazılabiliyor, kullanıcı "Başvurularım"da görüyor).

**Fark ettiğim eksikler:** Ana ekrandaki zil ikonu ve Profil'deki "Bildirimler" satırı hiçbir şey yapmıyor — dokunma alanları boş. İlginç olan, arkada tam çalışan bir bildirim altyapısı var (FCM, yerel bildirim, bildirime tıklayınca doğru sayfaya yönlendirme) ama bunu kullanıcıya açan ayarlar ekranı hiç bağlanmamış. Ayrıca ağ hatası olduğunda genelde düz bir "Hata: ..." metni ya da snackbar görüyorsun, özenli bir hata ekranı yok. Bunun dışında kod seviyesinde hiçbir yerde "yakında" ya da yarım bırakılmış bir ekran yok — ne varsa çalışıyor.

## Geliştirici gözünden

**Yığın:** Flutter + Firebase (Auth, Firestore, Storage, Crashlytics, Cloud Messaging), state yönetimi Riverpod, yönlendirme go_router, yerel önbellek Hive, basit tercih/veri saklama SharedPreferences. `functions/` altında küçük bir Node.js Cloud Functions backend'i var — tamamen Firestore tetikleyicileri (tarif onaylandı/reddedildi, biri beğendi, biri yorum yaptı), HTTP endpoint yok, sadece push bildirim göndermek için var.

**Veri modeli konusunda bilinçli bir seçim var:** aynı `lib/models/` klasöründe üç farklı kalıcılık deseni bir arada — Hive'da ikili obje olarak saklanan tarif/malzeme verisi (offline-first, hızlı okuma), Firestore'a mapli sınıflar (kullanıcı profili, yorum, bekleyen tarif — gerçek zamanlı senkron gereken şeyler), ve düz JSON olarak SharedPreferences'ta duran sınıflar (takvim kaydı, kişisel notlar — cihaz-yerel kalması yeterli olan şeyler). Rastgele değil, her verinin gerçek ihtiyacına göre seçilmiş.

**En özgün mimari parça bence tarif model'indeki fork/topluluk sistemi:** her tarif `isOfficial`, `parentRecipeId`, `officialLikeCount` ve `communityLikeCount` alanlarını taşıyor, ve bir `communityLeads` getter'ı var — bir topluluk versiyonunun beğenisi resmi tarifin 1.5 katını geçtiğinde bunu işaretliyor. Yani sistem, kullanıcıların kendi versiyonlarının zamanla "resmi"yi geçebileceğini öngörecek şekilde tasarlanmış. Küçük bir detay ama uygulamanın felsefesini özetliyor.

**Riverpod tarafında genel desen sağlam:** servisler `Provider<XService>` olarak expose ediliyor, ekranlar bunlardan türetilen Stream/Future/AsyncNotifier provider'ları tüketiyor — business logic widget'larda değil, provider katmanında. `recipe_service.dart` içinde cache-first stream deseni tutarlı uygulanmış (önce Hive'dan anında göster, sonra Firestore'la senkronize et), ve her tarif kartı için ayrı bir "beğenildi mi" listener'ı açmak yerine tek bir `collectionGroup('likes')` sorgusuyla kullanıcının tüm beğenilerini tek noktadan çekmek gibi bilinçli bir maliyet optimizasyonu var.

**Ama tutarsızlıklar da var:** `notes_provider.dart` hâlâ eski `StateNotifierProvider` deseninde yazılmış, geri kalan her yer `AsyncNotifierProvider`'a geçmiş — bir gün normalize edilmeli. `AdminService` içinde ilk admin e-postası doğrudan kaynak koda gömülü (`initialAdminEmail`), tek kurucu için makul ama başka biri projeye girecekse config'e taşınmalı. `recipe_service.dart` 570 satır ve hem tohumlama/migrasyon mantığını hem normal sorgu metodlarını barındırıyor — ayrılabilir. Ve tüm tarif listeleme/arama/malzeme-eşleştirme fonksiyonları, koleksiyonun tamamını çekip Dart tarafında filtreliyor; şu anki (sıfır kullanıcı, birkaç yüz tarif) ölçekte sorun değil ama gerçek trafik gelirse Firestore sorgu/pagination'a geçmek gerekecek.

**Güvenlik kuralları** (`firestore.rules`) genel olarak makul: tarifler herkese açık okunur, yazma admin/yazar/sadece-beğeni-alanı ile sınırlı; kullanıcı profilleri sadece sahibi tarafından okunabilir; misafir (anonim) kullanıcılar tarif gönderemiyor ama beğenebiliyor/yorum yapabiliyor. `_meta/{id}` koleksiyonu herhangi bir girişli kullanıcının yazabildiği tek gevşek nokta — bugün sadece tohum-sürümü belgeleri tuttuğu için risksiz ama ileride dikkat gerektirir.

**Versiyon kontrolü konusunda dürüst olmak gerekirse:** proje henüz bir git deposu değil. `lib/` altında 70 Dart dosyası ve dosya değişiklik tarihlerine bakılırsa yaklaşık 2.5 aydır aktif geliştiriliyor — yani epey iş var ama hiçbir commit geçmişi/geri alma güvenliği yok. Kök dizindeki `TODOS.md`, üzerinde düşünülen ama henüz yapılmayan işleri tutuyor — örneğin "Mutfak Karnesi" (kişisel pişirme günlüğü) özelliği tasarım+mimari incelemesinden geçti ama profil/auth modeli netleşene kadar bilinçli olarak beklemede tutuluyor.

## Şu an nerede duruyoruz

- Kod seviyesinde uygulama olgun ve büyük ölçüde bitmiş — ana akışların hepsi çalışıyor.
- Henüz dağıtım (App Store / Play Store) planlanmadı, git deposu bile yok.
- Bilinen açık uçlar: bildirim ayarları ekranının bağlanması, `notes_provider`'ın modern Riverpod deseniyle güncellenmesi, ve `TODOS.md`'deki bekleyen kararlar.
- Kısacası: ürün tarafı zaten epey düşünülmüş, sırada dağıtım ve gerçek kullanıcıyla test var.
