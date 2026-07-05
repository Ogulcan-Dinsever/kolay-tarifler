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

## QA follow-ups (2026-07-05, code-audit)

- [ ] **Orphaned Storage images after recipe rejection** — `PendingRecipeService.rejectRecipe()` never calls the existing `deleteImages()` helper, so every rejected submission's photos stay in Firebase Storage forever.
  - Why: Storage cost accumulates with nothing pointing to the files; no user-visible bug, purely backend hygiene.
  - Pros: Keeps Storage usage matched to actually-published content, avoids a slow-growing bill for orphaned files.
  - Cons: Not urgent at current scale (a handful of unpublished photos costs pennies) — fixing now is optional cleanup, not a fire.
  - Context: Found during `/qa` code-audit (browser automation unavailable in the dev sandbox). See `~/.gstack/projects/nepisirsem/ogulc-main-test-outcome-20260705.md` (ISSUE-002).
  - Depends on: None — independent, can be picked up anytime. Fix is: pass the submission's `imageUrls` into `rejectRecipe()` and call `deleteImages()` after the Firestore update succeeds.

- [ ] **Set up Firebase Rules Unit Testing** — this session found two independent, real production security-rule gaps (Firestore admin bootstrap letting anyone self-escalate, Storage rules missing paths/admin checks) purely by manual code reading. Neither `firestore.rules` nor `storage.rules` has any automated test coverage.
  - Why: Both bugs found this session were "the rule doesn't match what the code/comment actually intends" — exactly the class of bug rules unit tests catch automatically, before deploy, instead of by an incidental QA pass.
  - Pros: Would have caught ISSUE-003/004/005 before they ever reached production; cheap to write with `@firebase/rules-unit-testing`; runs fast, no real Firebase project needed (uses the emulator).
  - Cons: New test infra + emulator setup to learn/configure; real effort, not a one-liner.
  - Context: `/qa` code-audit session, 2026-07-05. See `~/.gstack/projects/nepisirsem/ogulc-main-test-outcome-20260705.md` (ISSUE-003, 004, 005).
  - Depends on: None — independent, but high-value given what was just found.

- [x] **Manually verify "Kendi Versiyonumu Paylaş" now actually works** — **VERIFIED on Android emulator (Pixel 10), 2026-07-05.** Registered a test account (`qatest_20260705` / `qatest.kolaytarifler.20260705@gmail.com`), submitted a community recipe version with a photo on "Düğün Çorbası", and it appeared correctly in the Topluluk tab with the photo, description, author name, and duration all correct. Confirms the `storage.rules` fix actually unblocked the feature — it was genuinely broken before. **Test data left live for the founder to clean up themselves** (their choice): the test account and the "QA test versiyonu" community recipe on Düğün Çorbası.
  - admin "Malzeme Ekle" (ingredient photo upload) — still NOT verified live, only the rules gap was closed. Needs a separate admin-account test.

- [x] **Ingredient thumbnail images mismatched — root-caused and fixed, 2026-07-05.** Two independent bugs, both fixed:
  1. **ID-matching bug (the big one):** `ingredients` collection had been re-seeded from a re-ordered `turk_malzemeleri.json` at some point after `recipes` were seeded, so 899 of 1015 (89%) embedded `ingredientId` references across all 100 recipes pointed at the wrong ingredient doc. Fixed via a one-time in-app admin migration (temporary "Düzelt" tab, admin-gated, removed after use) that re-matches every recipe's ingredients by name against the live `ingredients` collection, with parenthetical-suffix stripping for recipe-specific variants (e.g. "Tuz (hamur)" → "Tuz"). Also had to bump each touched recipe's `modifiedAt`, since `cachedRecipeStream()`'s cache-invalidation is gated on that field and a plain field update alone left every device's local cache stuck on the old (wrong) mapping.
  2. **Wrong source photos:** independent of the above, ~78 of 142 ingredients in `turk_malzemeleri.json` had a valid but content-wrong Unsplash photo (e.g. "Su" → coffee-maker photo, "Maydanoz" → a stock photo of a couple cooking, "Soğan" → potato) — likely hallucinated photo IDs from whatever generated the original dataset. Re-sourced and visually verified real Unsplash photos for all 78 (a few are reasonable proxies where no exact free photo exists, e.g. "Çam fıstığı"/pine nuts reuses the almond photo, "Kaymak" clotted cream is an imperfect match) — see `assets/data/turk_malzemeleri.json`. Applied to both the seed file and live Firestore via the same temporary admin migration tool.
  - Why this matters: every screen showing ingredient thumbnails (recipe detail, shopping list, ingredient picker, admin panel) was affected — this was a trust/polish issue across the whole app, not one recipe.
  - Verified live on the Android emulator after a cold app restart: multiple recipes ("Su Böreği", "Ekmek Kadayıfı", "Acılı Ezme") now show fully correct ingredient images.
  - Depends on: None — done. If new ingredients are added later, double-check their photo actually matches before publishing (no automated check exists for this).

## Security fixes shipped (2026-07-05, /qa code-audit)

Three production security/functional bugs found and fixed same-session, all deployed to `kolaytarifler-37c45`:
1. **Firestore admin self-escalation** — anyone could grant themselves admin via the bootstrap rule (scoped to any email, not just the founder's). Fixed, commit `474d749`.
2. **Super-admin removable by other admins** — no protection against a legitimately-added admin removing the founder. Fixed, commit `926e283`.
3. **Storage rules: unenforced admin check + two missing paths** — `recipes/` write didn't actually check admin status; `recipe_images/{userId}` and `ingredients/` had no rule at all (likely broke community-recipe-version and admin-ingredient-photo uploads since those features were built). Fixed, commit `836146a`.

Full detail: `~/.gstack/projects/nepisirsem/ogulc-main-test-outcome-20260705.md` (ISSUE-003, 004, 005).

## Mutfak Karnesi feature status

**ON HOLD** (2026-07-04, during /plan-eng-review outside voice) — feature is device-local only and cannot back a future public profile without a Firestore migration; app has zero users right now. Founder chose to wait until the profile/auth model settles before building. Full design + eng review preserved in `~/.gstack/projects/nepisirsem/ogulc-nogit-design-20260704-194923.md` as reference for when this is picked back up.
