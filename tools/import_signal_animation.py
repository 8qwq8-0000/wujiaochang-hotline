"""Describe an unmodified generated sprite atlas as aligned Godot textures.

Reads bitmap alpha for bounds/boot anchors; never repaints or resizes the art.
Run with the bundled Python/Pillow/NumPy runtime after image generation.
"""
from pathlib import Path
import json
import statistics
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets/art/characters/enemies/animated/signal_herald_v3.png"
OUTPUT = ASSET.with_name("signal_herald_v3_frames.tres")
MANIFEST = ROOT / "docs/art/validation/signal_herald_v3/atlas_manifest.json"
CELL = 256
FOOT = (128, 224)


def main():
    image = Image.open(ASSET).convert("RGBA")
    pixels = np.asarray(image)
    if not np.any(pixels[:, :, 3] == 0):
        raise ValueError("Atlas must have genuine transparent background")
    definitions = []
    records = []
    clips = []
    for row in range(8):
        refs = []
        for col in range(6):
            x0, x1 = round(col * image.width / 6), round((col + 1) * image.width / 6)
            y0, y1 = round(row * image.height / 8), round((row + 1) * image.height / 8)
            alpha = pixels[y0:y1, x0:x1, 3] > 64
            ys, xs = np.where(alpha)
            if len(xs) < 100:
                raise ValueError(f"Empty or incomplete sprite: row {row}, col {col}")
            left, top, right, bottom = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
            bottom_band = alpha & (np.indices(alpha.shape)[0] >= bottom - max(5, (bottom - top) // 14))
            rgb = pixels[y0:y1, x0:x1, :3].astype(float)
            navy_boots = bottom_band & (rgb[:, :, 2] > rgb[:, :, 0] * 1.05) & (rgb[:, :, 2] > rgb[:, :, 1] * 1.05)
            boot_y, boot_x = np.where(navy_boots if np.any(navy_boots) else bottom_band)
            foot_x = round((np.percentile(boot_x, 5) + np.percentile(boot_x, 95)) / 2)
            width, height = right - left, bottom - top
            pad_x, pad_y = FOOT[0] - (foot_x - left), FOOT[1] - height
            if min(pad_x, pad_y) < 0 or pad_x + width > CELL:
                raise ValueError(f"Sprite exceeds aligned canvas: row {row}, col {col}")
            index = row * 6 + col + 1
            region = (x0 + left, y0 + top, width, height)
            margin = (pad_x, pad_y, CELL - width, CELL - height)
            definitions.append(
                f'[sub_resource type="AtlasTexture" id="Frame_{index}"]\n'
                f'atlas = ExtResource("1")\nregion = Rect2{region}\nmargin = Rect2{margin}\nfilter_clip = true\n'
            )
            refs.append('{"duration": 1.0, "texture": SubResource("Frame_%d")}' % index)
            records.append({"row": row, "col": col, "region": region, "margin": margin, "foot": [foot_x + x0, bottom + y0], "height": height})
        direction = ["down", "left", "up", "right"][row % 4]
        name = ("walk_" if row < 4 else "attack_") + direction
        clips.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}' % (", ".join(refs), "true" if row < 4 else "false", name, "8.0" if row < 4 else "12.0"))
        if row >= 4:
            clips.append('{"frames": [%s], "loop": true, "name": &"idle_%s", "speed": 1.0}' % (refs[0], direction))
    resource_path = "res://" + ASSET.relative_to(ROOT).as_posix()
    OUTPUT.write_text(
        '[gd_resource type="SpriteFrames" load_steps=50 format=3]\n\n'
        f'[ext_resource type="Texture2D" path="{resource_path}" id="1"]\n\n'
        + "\n".join(definitions) + '\n[resource]\nanimations = [' + ",\n".join(clips) + ']\n'
    )
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    scale = round(78.0 / statistics.median(record["height"] for record in records), 6)
    MANIFEST.write_text(json.dumps({"source_dimensions": image.size, "grid": [6, 8], "canvas": CELL, "foot_anchor": FOOT, "suggested_scale": scale, "frames": records}, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote 48 frame descriptors, 12 clips. Suggested scale: {scale}")


if __name__ == "__main__":
    main()
