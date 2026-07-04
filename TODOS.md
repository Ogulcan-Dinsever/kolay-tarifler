# TODOS

## Mutfak Karnesi (Profilim — Personal Cooking Journal) follow-ups

- [ ] **İlk açılışta geçmiş verisi olan kullanıcılara özel karşılama vurgusu** — Mutfak Karnesi ilk kez göründüğünde, kullanıcının zaten geçmiş takvim kaydı varsa (örn. "İşte mutfak geçmişin! X yemek pişirmişsin") bir kerelik özel bir başlık/rozet göster.
  - Why: Güçlendirilmiş bir ilk izlenim / "vay canına" anı — özellikle bu özellik yayınlandığında aylardır takvim kullanan kişiler için.
  - Pros: Daha akılda kalıcı ilk deneyim, retroaktif olarak dolu gelen bir günlüğü fark ettirir.
  - Cons: Yeni state (banner gösterildi mi bilgisi, kalıcı olarak saklanmalı) + ayrı bir tasarım/kopya işi gerektirir — v1 kapsamı dışında.
  - Context: office-hours + plan-design-review oturumunda (2026-07-04) konuşuldu, bkz. `~/.gstack/projects/nepisirsem/ogulc-nogit-design-20260704-194923.md` Pass 3.
  - Depends on: Mutfak Karnesi v1'in (bkz. tasarım belgesi) önce şart olması.

- [ ] **Takvim kayıtları için budama/limit mekanizması** — `shared_preferences`'ta biriken `CalendarEntry` kayıtları sınırsız büyüyor, hiçbir üst sınır/temizlik yok.
  - Why: Uzun vadede yükleme süresini/belleği etkileyebilir, özellikle Mutfak Karnesi gibi bu veriyi okuyan özellikler eklendikçe.
  - Pros: Gelecekteki bir performans sorununu şimdiden önler.
  - Cons: Şu an gerçek bir sorun değil (hobi kullanımında yıllarca birkaç yüz kayıt birikir) — şimdi yapmak gereksiz erken optimizasyon olur.
  - Context: plan-eng-review outside-voice bulgusu (2026-07-04), bkz. `~/.gstack/projects/nepisirsem/ogulc-nogit-design-20260704-194923.md`.
  - Depends on: Yok — bağımsız, istenildiği zaman ele alınabilir.

## Mutfak Karnesi feature status

**ON HOLD** (2026-07-04, during /plan-eng-review outside voice) — feature is device-local only and cannot back a future public profile without a Firestore migration; app has zero users right now. Founder chose to wait until the profile/auth model settles before building. Full design + eng review preserved in `~/.gstack/projects/nepisirsem/ogulc-nogit-design-20260704-194923.md` as reference for when this is picked back up.
