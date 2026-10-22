"""Mirror the four extracted original halves, preserving their floor perspective.

Run after: godot --path . --script res://tools/extract_warehouse_sigils.gd
Uses Pillow. No image generation service or redesign is involved.
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_sources/ai_drafts/warehouse_sigils_extracted_v1"
OUTPUT = ROOT / "assets/art/effects/warehouse_sigils"
COLORS = {"parry": (102, 230, 255), "trial": (92, 255, 184),
          "boss": (191, 140, 255), "deploy": (255, 191, 89)}
OUTPUT.mkdir(parents=True, exist_ok=True)
preview = Image.new("RGBA", (1024, 600), (11, 17, 26, 255))
for index, (name, color) in enumerate(COLORS.items()):
    raw = Image.open(SOURCE / f"{name}_half_raw.png").convert("RGBA")
    # The compatibility renderer's clip group bakes a black matte. Recover
    # its coverage from the known monochrome tint, retaining every stroke.
    red, green, blue, _ = raw.split()
    coverage = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    extracted = Image.new("RGBA", raw.size, color + (0,))
    extracted.putalpha(coverage)
    extracted.save(SOURCE / f"{name}_half.png")
    full = Image.new("RGBA", raw.size)
    if name == "deploy":
        half = extracted.crop((0, 0, 256, 256))
        full.paste(half, (0, 0))
        full.paste(ImageOps.mirror(half), (256, 0))
        assert full.tobytes() == ImageOps.mirror(full).tobytes()
    else:
        half = extracted.crop((0, 128, 512, 256))
        full.paste(half, (0, 128))
        full.paste(ImageOps.flip(half), (0, 0))
        assert full.tobytes() == ImageOps.flip(full).tobytes()
    full.save(OUTPUT / f"{name}_complete.png")
    x, y = index % 2 * 512, index // 2 * 300
    preview.alpha_composite(full, (x, y + 28))
    ImageDraw.Draw(preview).text((x + 20, y + 8), name, fill="white")
preview.convert("RGB").save(SOURCE / "four_complete_sigils.png")
print("Four original half-sigils mirrored into complete transparent sprites.")
