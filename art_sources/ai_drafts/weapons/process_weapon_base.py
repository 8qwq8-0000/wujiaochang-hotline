from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "weapon_base_unpainted_v1.png"
OUTPUT = ROOT / "weapon_base_unpainted_v3"

# The generated source is a free-layout concept sheet, not a declared grid.
# Bounds were established by visual inspection and deliberately stop in the
# transparent gaps between weapons.
WEAPONS = (
    ("arm_lock_baton", (0, 0, 1536, 332), (48, 16), 1.55),
    ("service_pistol", (0, 332, 1536, 621), (40, 16), 1.0),
    ("scattergun", (0, 621, 1536, 1024), (48, 20), 1.0),
)


def alpha_bbox(image: Image.Image, threshold: int = 32) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("weapon row is empty")
    return bbox


def crop_subject(image: Image.Image, row: tuple[int, int, int, int]) -> tuple[Image.Image, tuple[int, int, int, int]]:
    strip = image.crop(row)
    local_bbox = alpha_bbox(strip)
    subject = strip.crop(local_bbox)
    source_bbox = (
        row[0] + local_bbox[0],
        row[1] + local_bbox[1],
        row[0] + local_bbox[2],
        row[1] + local_bbox[3],
    )
    return subject, source_bbox


def fit_pixel_sprite(
    subject: Image.Image, canvas_size: tuple[int, int], vertical_scale: float = 1.0
) -> Image.Image:
    canvas_width, canvas_height = canvas_size
    usable_width = canvas_width - 2
    usable_height = canvas_height - 2
    scale = min(usable_width / subject.width, usable_height / subject.height)
    target_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    # BOX preserves the dominant high-resolution color masses when reducing;
    # the result is then quantized and given a binary pixel-art alpha edge.
    reduced = subject.resize(target_size, Image.Resampling.BOX)
    if vertical_scale != 1.0:
        target_size = (
            target_size[0],
            min(usable_height, max(1, round(target_size[1] * vertical_scale))),
        )
        reduced = reduced.resize(target_size, Image.Resampling.NEAREST)
    reduced = ImageEnhance.Contrast(reduced).enhance(1.22)
    alpha = reduced.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    palette = reduced.convert("RGB").quantize(
        colors=16,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    palette.putalpha(alpha)
    palette = add_dark_outline(palette)
    result = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    position = (
        (canvas_width - target_size[0]) // 2,
        (canvas_height - target_size[1]) // 2,
    )
    result.alpha_composite(palette, position)
    return result


def add_dark_outline(image: Image.Image) -> Image.Image:
    result = image.copy()
    source = image.load()
    target = result.load()
    width, height = image.size
    outline = (18, 21, 25, 255)
    for y in range(height):
        for x in range(width):
            if source[x, y][3] == 0:
                continue
            neighbors = ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            if any(
                nx < 0 or ny < 0 or nx >= width or ny >= height or source[nx, ny][3] == 0
                for nx, ny in neighbors
            ):
                target[x, y] = outline
    return result


def visible_colors(image: Image.Image) -> int:
    pixels = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return len({pixel[:3] for pixel in pixels if pixel[3]})


def make_preview(sprites: list[tuple[str, Image.Image]]) -> Image.Image:
    scale = 8
    cell_width = 360
    cell_height = 152
    preview = Image.new("RGB", (cell_width, cell_height * len(sprites)), "#111820")
    draw = ImageDraw.Draw(preview)
    for index, (name, sprite) in enumerate(sprites):
        top = index * cell_height
        tile = 16
        for y in range(top, top + cell_height, tile):
            for x in range(0, cell_width, tile):
                fill = "#26333d" if ((x // tile) + ((y - top) // tile)) % 2 == 0 else "#1b252e"
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=fill)
        enlarged = sprite.resize((sprite.width * scale, sprite.height * scale), Image.Resampling.NEAREST)
        x = (cell_width - enlarged.width) // 2
        y = top + 10
        preview.paste(enlarged, (x, y), enlarged)
        draw.rectangle((x - 1, y - 1, x + enlarged.width, y + enlarged.height), outline="#536875")
        draw.text(
            (12, top + cell_height - 18),
            f"{name}  {sprite.width}x{sprite.height}  {visible_colors(sprite)} colors",
            fill="#d7e0e5",
        )
    return preview


def main() -> None:
    if OUTPUT.exists():
        raise FileExistsError(f"refusing to overwrite {OUTPUT}")
    OUTPUT.mkdir(parents=True)
    raw_dir = OUTPUT / "raw_crops"
    sprite_dir = OUTPUT / "sprites"
    raw_dir.mkdir()
    sprite_dir.mkdir()

    source = Image.open(SOURCE).convert("RGBA")
    sprites: list[tuple[str, Image.Image]] = []
    records = []
    for name, row, canvas_size, vertical_scale in WEAPONS:
        subject, source_bbox = crop_subject(source, row)
        subject.save(raw_dir / f"{name}.png")
        sprite = fit_pixel_sprite(subject, canvas_size, vertical_scale)
        sprite.save(sprite_dir / f"{name}.png", optimize=True)
        sprites.append((name, sprite))
        records.append(
            {
                "id": name,
                "source_bbox": source_bbox,
                "raw_size": list(subject.size),
                "canvas": list(canvas_size),
                "vertical_readability_scale": vertical_scale,
                "visible_bbox": list(alpha_bbox(sprite, 1)),
                "visible_colors": visible_colors(sprite),
                "transparent": sprite.getchannel("A").getextrema()[0] == 0,
            }
        )

    preview = make_preview(sprites)
    preview.save(OUTPUT / "review_8x.png", optimize=True)
    manifest = {
        "source": str(SOURCE.relative_to(ROOT.parent.parent.parent.parent)),
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "mode": "manually-declared-row-crops",
        "palette_colors_before_outline": 16,
        "alpha_threshold": 96,
        "weapons": records,
    }
    (OUTPUT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
