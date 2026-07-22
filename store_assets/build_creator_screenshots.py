"""Build four contribution-focused, App Store-sized screenshots.

The app interface is cross-platform. Android status and navigation chrome are
removed before the capture is placed in the device-neutral store frame.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
OUT = ROOT.parent / "ios" / "fastlane" / "screenshots" / "tr-TR"
OUT.mkdir(parents=True, exist_ok=True)

WIDTH, HEIGHT = 1242, 2688
DARK = "#132033"
MUTED = "#607087"
MINT = "#EAF9F0"

FONT_CANDIDATES = {
    False: [
        Path("C:/Windows/Fonts/segoeui.ttf"),
        Path("/System/Library/Fonts/Supplemental/Arial.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ],
    True: [
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
    ],
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    for candidate in FONT_CANDIDATES[bold]:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    weight = "bold" if bold else "regular"
    raise FileNotFoundError(f"No supported {weight} store screenshot font found")


def add_shadow(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    radius: int = 52,
    blur: int = 26,
    alpha: int = 55,
) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        box,
        radius=radius,
        fill=(15, 60, 34, alpha),
    )
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def crop_device_chrome(image: Image.Image) -> Image.Image:
    border = 4
    status_bar = round(image.width * 0.09)
    # Contribution captures were taken with a test banner at the bottom.
    # Keep only the actual app form/content above that banner.
    content_bottom = round(image.height * 0.84)
    return image.crop(
        (
            border,
            max(border, status_bar),
            image.width - border,
            content_bottom,
        )
    )


def build_screenshots() -> None:
    items = [
        (
            "real_submit_top.png",
            "Kendi tarifini yaz",
            "Fotoğrafını ekle, tarifini kendi adınla paylaş.",
            "07_IPHONE_65_write_your_recipe_1242x2688.png",
        ),
        (
            "real_submit_steps.png",
            "Malzemeden sunuma",
            "Malzemeleri ve yapılış adımlarını kolayca ekle.",
            "08_IPHONE_65_community_variations_1242x2688.png",
        ),
        (
            "real_lahana_detail.png",
            "Tarifler tüm ayrıntılarıyla",
            "Ölçüler, adımlar ve planlama tek ekranda.",
            "09_IPHONE_65_profile_contributions_1242x2688.png",
        ),
        (
            "real_lahana_comments.png",
            "Deneyimini paylaş",
            "Yorum yap, topluluğa ilham ver, yeni lezzetler keşfet.",
            "10_IPHONE_65_inspire_the_community_1242x2688.png",
        ),
    ]

    for source, title, subtitle, output in items:
        canvas = Image.new("RGBA", (WIDTH, HEIGHT), MINT)
        draw = ImageDraw.Draw(canvas)
        draw.text((64, 48), title, font=font(58, True), fill=DARK)
        draw.text((66, 128), subtitle, font=font(28), fill=MUTED)

        capture = crop_device_chrome(Image.open(RAW / source).convert("RGB"))
        target_width = 1120
        target_height = round(capture.height * target_width / capture.width)
        capture = capture.resize(
            (target_width, target_height),
            Image.Resampling.LANCZOS,
        ).convert("RGBA")

        mask = Image.new("L", capture.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, capture.width - 1, capture.height - 1),
            radius=48,
            fill=255,
        )
        capture.putalpha(mask)

        add_shadow(
            canvas,
            (55, 226, 1187, min(HEIGHT - 24, 226 + target_height)),
        )
        canvas.alpha_composite(capture, (61, 220))
        canvas.convert("RGB").save(OUT / output, quality=96)


if __name__ == "__main__":
    build_screenshots()
