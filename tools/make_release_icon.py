"""Crop the main-menu mech head into transparent desktop and Android icons."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_sources/ai_drafts/ui/start_menu_v1/chassis_source.png"
OUTPUT = ROOT / "assets/art/ui/game_icon.png"
WINDOWS = ROOT / "assets/art/ui/game_icon.ico"
ANDROID_FOREGROUND = ROOT / "assets/art/ui/game_icon_android_foreground.png"
ANDROID_BACKGROUND = ROOT / "assets/art/ui/game_icon_android_background.png"


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    # The source is transparent. This polygon cuts away the shoulders and neck
    # that enter the square crop, keeping the helmet and face alone.
    box = (305, 0, 670, 370)
    head = source.crop(box)
    mask = Image.new("L", head.size)
    draw = ImageDraw.Draw(mask)
    draw.polygon(
        [
            (215, 13), (253, 0), (283, 0), (307, 51), (324, 103),
            (344, 155), (351, 215), (330, 250), (315, 258),
            (312, 282), (296, 305), (268, 324), (240, 347),
            (189, 360), (147, 350), (109, 333), (82, 308),
            (57, 288), (23, 264), (12, 242), (17, 207),
            (37, 162), (52, 112), (91, 76), (148, 40),
        ],
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(1.0))
    head.putalpha(ImageChops.multiply(head.getchannel("A"), mask))
    bounds = head.getbbox()
    if bounds is None:
        raise RuntimeError("The head crop is empty")
    head = head.crop(bounds)

    def canvas(size: int, occupancy: float) -> Image.Image:
        result = Image.new("RGBA", (size, size))
        scale = min(size * occupancy / head.width, size * occupancy / head.height)
        resized = head.resize(
            (round(head.width * scale), round(head.height * scale)),
            Image.Resampling.LANCZOS,
        )
        result.alpha_composite(resized, ((size - resized.width) // 2, (size - resized.height) // 2))
        return result

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas(512, 0.88).save(OUTPUT)
    canvas(432, 0.68).save(ANDROID_FOREGROUND)
    Image.new("RGBA", (432, 432), (12, 18, 26, 255)).save(ANDROID_BACKGROUND)
    canvas(256, 0.88).save(WINDOWS, sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
    print(OUTPUT)
    print(WINDOWS)
    print(ANDROID_FOREGROUND)
    print(ANDROID_BACKGROUND)


if __name__ == "__main__":
    main()
