# Kişisel hesap için kapalı test planı

## Zorunlu eşik

Yeni kişisel geliştirici hesabında üretim erişimine başvurmadan önce en az **12 test kullanıcısının 14 gün kesintisiz** kapalı teste katılmış olması gerekir. Test kullanıcılarının yalnız listeye eklenmesi yetmez; opt-in bağlantısından teste katılmaları gerekir. Güvenli marj için 13–15 hesap ve 15 gün planlayın.

## Uygulama adımları

1. Play Console > Test > Kapalı test bölümünde bir kanal oluşturun.
2. Test kullanıcılarını bir e-posta listesine ekleyin.
3. İmzalı AAB sürümünü kanala yükleyin ve incelemeye gönderin.
4. Opt-in bağlantısını test kullanıcılarına iletin.
5. Her kullanıcı bağlantıdan katılıp Play Store test sayfasından uygulamayı yüklesin.
6. Katılımcı sayısını ve başlangıç tarihini ekran görüntüsüyle kaydedin.
7. 14 gün boyunca kanalı kapatmayın ve kullanıcıları listeden çıkarmayın.
8. Geri bildirimleri, bulunan sorunları ve yayınlanan düzeltmeleri kaydedin.

## Test senaryoları

- İlk kurulum, splash ve ilk tanıtım; ikinci açılışta tanıtımın tekrar gelmemesi
- Misafir gezinme, arama, malzeme seçimi ve tarif detayı
- Google ile giriş, çıkış ve yeniden giriş
- Yorum gönderme öncesi koşul kabulü
- Yorum/tarif bildirme ve kullanıcı engelleme
- Tarif gönderme, fotoğraf yükleme ve başvuru durumu
- Beğeni, bildirim, takvim ve alışveriş listesi
- Açık/koyu tema, küçük/büyük ekran ve geri tuşu
- Alt banner'ın tüm kullanıcı sayfalarında gezinmeyi kapatmaması, 320×50 alanı
  aşmaması ve geçici ağ/reklam stoğu hatasından sonra yeniden yüklenmesi
- Profilde gizlilik, koşullar, destek ve hesap silme bağlantıları
- Uygulama içi hesap silme ve silinen hesapla yeniden giriş davranışı
- Çevrimdışı/zayıf ağ, izin reddi, yükleme hatası ve tekrar deneme

## Üretim erişimi başvuru notları

Başvuruda test kullanıcılarının uygulamayı nasıl kullandığını, hangi geri bildirimlerin geldiğini ve bunlara göre neleri değiştirdiğinizi somut yazın. “Sadece kurup baktılar” yerine örnek akış ve düzeltmeler belirtin. Yanıtlar gerçek test sonuçlarıyla doldurulmalı; şimdiden uydurulmamalıdır.
