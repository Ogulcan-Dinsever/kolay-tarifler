"""Create the required 13-inch iPad App Store screenshot.

The composition uses a real Kolay Tarifler app capture and only adds the
store-page headline, background, and framing around it.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "raw" / "01_ingredients_result2.png"
OUTPUT = (
    ROOT.parent
    / "ios"
    / "fastlane"
    / "screenshots"
    / "tr-TR"
    / "01_IPAD_PRO_13_ingredient_based_recipes_2048x2732.png"
)

WIDTH, HEIGHT = 2048, 2732
GREEN = "#20C866"
DARK = "#132033"
MUTED = "#607087"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    filename = "segoeuib.ttf" if bold else "segoeui.ttf"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / filename), size)


def vertical_gradient(top: str, bottom: str) -> Image.Image:
    canvas = Image.new("RGB", (WIDTH, HEIGHT), top)
    draw = ImageDraw.Draw(canvas)
    start = tuple(int(top[index : index + 2], 16) for index in (1, 3, 5))
    end = tuple(int(bottom[index : index + 2], 16) for index in (1, 3, 5))
    for y in range(HEIGHT):
        ratio = y / (HEIGHT - 1)
        color = tuple(
            round(start[channel] * (1 - ratio) + end[channel] * ratio)
            for channel in range(3)
        )
        draw.line((0, y, WIDTH, y), fill=color)
    return canvas.convert("RGBA")


def main() -> None:
    canvas = vertical_gradient("#F5FFF8", "#E7F6EE")
    draw = ImageDraw.Draw(canvas)

    draw.ellipse((1650, -220, 2200, 330), fill=(32, 200, 102, 30))
    draw.rounded_rectangle((110, 90, 550, 162), radius=36, fill=GREEN)
    draw.text((145, 108), "MALZEMEYE GÖRE TARİF", font=font(31, True), fill="#073D20")
    draw.text((110, 205), "Dolabındakileri seç,", font=font(82, True), fill=DARK)
    draw.text((110, 305), "tarifini kolayca bul", font=font(82, True), fill=DARK)
    draw.text(
        (114, 420),
        "Elindeki malzemelere uygun tarifleri ve eksiklerini anında gör.",
        font=font(34),
        fill=MUTED,
    )

    frame_box = (220, 555, 1828, 2825)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        frame_box,
        radius=72,
        fill=(20, 48, 35, 65),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(36)))

    # Remove the emulator status bar so the promotional frame contains only
    # the app interface and remains device-neutral on the App Store page.
    capture = Image.open(SOURCE).convert("RGB").crop((4, 100, 1076, 1771))
    target_width = 1500
    target_height = round(capture.height * target_width / capture.width)
    capture = capture.resize((target_width, target_height), Image.Resampling.LANCZOS)

    mask = Image.new("L", capture.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, capture.width - 1, capture.height - 1),
        radius=64,
        fill=255,
    )
    capture = capture.convert("RGBA")
    capture.putalpha(mask)
    canvas.alpha_composite(capture, ((WIDTH - target_width) // 2, 585))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUTPUT, quality=96)
    print(OUTPUT)


if __name__ == "__main__":
    main()
