from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
FINAL = ROOT / "final"
APP_STORE = FINAL / "app_store"
GOOGLE_PLAY = FINAL / "google_play"
APP_STORE.mkdir(parents=True, exist_ok=True)
GOOGLE_PLAY.mkdir(parents=True, exist_ok=True)

W, H = 1242, 2688
GREEN = "#20C866"
DARK = "#132033"
MUTED = "#607087"
MINT = "#EAF9F0"
CORAL = "#FF8C6B"


def font(size: int, bold: bool = False):
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), size)


def gradient(size, top, bottom):
    image = Image.new("RGB", size, top)
    draw = ImageDraw.Draw(image)
    t = tuple(int(top[i : i + 2], 16) for i in (1, 3, 5))
    b = tuple(int(bottom[i : i + 2], 16) for i in (1, 3, 5))
    for y in range(size[1]):
        p = y / max(1, size[1] - 1)
        color = tuple(round(t[i] * (1 - p) + b[i] * p) for i in range(3))
        draw.line((0, y, size[0], y), fill=color)
    return image


def fit_cover(image, size):
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def rounded_image(image, size, radius):
    image = fit_cover(image, size).convert("RGBA")
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    image.putalpha(mask)
    return image


def add_shadow(canvas, box, radius=58, blur=32, alpha=60):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=(20, 48, 35, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(layer)


def draw_headline(draw, title, subtitle, badge):
    badge_font = font(25, True)
    title_font = font(72, True)
    subtitle_font = font(31)
    bx, by = 74, 60
    badge_w = draw.textbbox((0, 0), badge, font=badge_font)[2] + 44
    draw.rounded_rectangle((bx, by, bx + badge_w, by + 48), radius=24, fill=GREEN)
    draw.text((bx + 22, by + 9), badge, font=badge_font, fill="#073D20")
    draw.multiline_text((74, 135), title, font=title_font, fill=DARK, spacing=4)
    draw.text((76, 326), subtitle, font=subtitle_font, fill=MUTED)


def build_screenshot(source, output, title, subtitle, badge):
    canvas = gradient((W, H), "#F5FFF8", "#E7F6EE").convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((930, -130, 1320, 260), fill=(32, 200, 102, 25))
    draw.ellipse((-170, 2200, 280, 2650), fill=(255, 140, 107, 20))
    draw_headline(draw, title, subtitle, badge)

    raw = Image.open(RAW / source).convert("RGB")
    # Emulator debug capture has a thin lime device-outline; remove it.
    raw = raw.crop((4, 4, raw.width - 4, raw.height - 4))
    phone_w = 1058
    phone_h = round(phone_w * raw.height / raw.width)
    x, y = (W - phone_w) // 2, 430
    add_shadow(canvas, (x - 10, y - 8, x + phone_w + 10, y + phone_h + 10))
    framed = rounded_image(raw, (phone_w, phone_h), 58)
    canvas.alpha_composite(framed, (x, y))
    canvas.convert("RGB").save(APP_STORE / output, quality=96)


def build_promo_portrait():
    canvas = gradient((W, H), "#F5FFF8", "#E4F5EB").convert("RGBA")
    food = Image.open(RAW / "feature_food_generated.png").convert("RGB")
    food = fit_cover(food, (W, 960)).convert("RGBA")
    fade = Image.new("L", (W, 960), 255)
    fade_draw = ImageDraw.Draw(fade)
    for y in range(650, 960):
        fade_draw.line((0, y, W, y), fill=round(255 * (960 - y) / 310))
    food.putalpha(fade)
    canvas.alpha_composite(food, (0, 0))

    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.rounded_rectangle((62, 86, 710, 635), radius=48, fill=(247, 255, 249, 232))
    d.text((105, 135), "DAHA AZ REKLAM", font=font(27, True), fill="#117A3E")
    d.multiline_text((102, 205), "Daha çok tarif.\nDaha çok keyif.", font=font(66, True), fill=DARK, spacing=8)
    d.text((105, 420), "700+ tarif • Dünya mutfakları", font=font(31, True), fill="#117A3E")
    d.text((105, 480), "Sade, hızlı ve yemeğe odaklı.", font=font(29), fill=MUTED)
    canvas.alpha_composite(overlay)

    screen = Image.open(RAW / "01_home_world_cuisines.png").convert("RGB")
    screen = screen.crop((4, 4, screen.width - 4, screen.height - 4))
    phone_w = 900
    phone_h = round(phone_w * screen.height / screen.width)
    x, y = (W - phone_w) // 2, 760
    add_shadow(canvas, (x - 12, y - 12, x + phone_w + 12, y + phone_h + 12), blur=38, alpha=75)
    canvas.alpha_composite(rounded_image(screen, (phone_w, phone_h), 64), (x, y))
    canvas.convert("RGB").save(APP_STORE / "06_less_ads_more_recipes_1242x2688.png", quality=96)


def build_feature_graphic():
    fw, fh = 1024, 500
    food = fit_cover(Image.open(RAW / "feature_food_generated.png").convert("RGB"), (fw, fh)).convert("RGBA")
    overlay = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for x in range(0, 680):
        p = x / 680
        alpha = round(242 * (1 - p) ** 1.7)
        od.line((x, 0, x, fh), fill=(245, 255, 248, alpha))
    food.alpha_composite(overlay)
    draw = ImageDraw.Draw(food)
    logo = Image.open("assets/images/app_header_logo.png").convert("RGBA")
    logo.thumbnail((315, 105), Image.Resampling.LANCZOS)
    food.alpha_composite(logo, (45, 40))
    draw.text((48, 166), "700+ tarif.", font=font(54, True), fill=DARK)
    draw.text((48, 228), "Dünyanın mutfakları.", font=font(43, True), fill=DARK)
    draw.rounded_rectangle((46, 315, 431, 374), radius=29, fill=GREEN)
    draw.text((72, 327), "Daha az reklam, daha çok tarif", font=font(24, True), fill="#073D20")
    draw.text((49, 406), "Malzemeni seç • Planla • Listele", font=font(25), fill="#355A46")
    food.convert("RGB").save(GOOGLE_PLAY / "google_play_feature_graphic_1024x500.png", quality=96)


def build_google_play_portraits():
    # Google Play requires the long edge to be no more than twice the short edge.
    # 1242x2208 is an exact 9:16 portrait and preserves the headline + core UI.
    for source in sorted(APP_STORE.glob("*.png")):
        image = Image.open(source).convert("RGB").crop((0, 0, 1242, 2208))
        target_name = source.name.replace("1242x2688", "1242x2208")
        image.save(GOOGLE_PLAY / target_name, quality=96)


def main():
    items = [
        ("01_home_world_cuisines.png", "01_700_plus_world_cuisines_1242x2688.png", "700+ tarif,\ndünyanın lezzetleri", "Türk mutfağından Japonya'ya her gün yeni fikir.", "DÜNYA MUTFAKLARI"),
        ("01_ingredients_result2.png", "02_ingredient_based_recipes_1242x2688.png", "Dolabındakileri seç,\ntarifini bul", "Eksik malzemeyi de anında gör.", "MALZEMEYE GÖRE TARİF"),
        ("02_recipe_detail.png", "03_quality_recipe_detail_1242x2688.png", "İştah açan,\nadım adım tarifler", "Malzemeler ve ölçüler tek yerde.", "DETAYLI TARİFLER"),
        ("03_calendar.png", "04_meal_calendar_1242x2688.png", "Haftanı önceden\nplanla", "Ne pişireceğini takvime ekle.", "YEMEK TAKVİMİ"),
        ("04_shopping_list.png", "05_shopping_list_1242x2688.png", "Listen otomatik\nhazırlansın", "Planladığın tariflerin malzemeleri tek listede.", "ALIŞVERİŞ LİSTESİ"),
    ]
    for item in items:
        build_screenshot(*item)
    build_promo_portrait()
    build_feature_graphic()
    build_google_play_portraits()


if __name__ == "__main__":
    main()
