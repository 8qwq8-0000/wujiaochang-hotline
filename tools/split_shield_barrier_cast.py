"""Split the reviewed 4x2 generated cast sheet and assemble its GIF preview.

Requires Pillow. Coordinates describe this specific generated source sheet.
PNG frames retain partial alpha; GIF preview is composited over a grid because
GIF supports only binary transparency.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_sources/ai_drafts/enemies/shield_barrier_cast_v1"
OUTPUT = ROOT / "assets/art/characters/enemies/shield_barrier_cast_v1"
CELL = 512
ANCHOR = (256, 400)
DURATIONS = [100, 100, 110, 90, 90, 90, 110, 650]
# Measured empty gutters exclude the neighbouring effect, unlike a blind grid.
ROWS = [(110, 470, [0, 455, 887, 1331, 1774]),
        (510, 866, [0, 424, 882, 1330, 1774])]
ROOT_X = [230, 670, 1110, 1550, 230, 670, 1110, 1550]
ROOT_Y = [430, 430, 430, 430, 802, 802, 802, 802]


def run():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    image = Image.open(SOURCE / "generated_sheet.png").convert("RGBA")
    assert image.size == (1774, 887), "Re-measure gutters for a different source"
    frames, previews, manifest = [], [], []
    atlas = Image.new("RGBA", (CELL * 4, CELL * 2))
    for index in range(8):
        row, column = divmod(index, 4)
        top, bottom, edges = ROWS[row]
        rect = (edges[column], top, edges[column + 1], bottom)
        crop = image.crop(rect)
        # Remove only nearly invisible generated alpha dust, retain shield alpha.
        alpha = crop.getchannel("A").point(lambda a: 0 if a < 8 else a)
        crop.putalpha(alpha)
        offset = (ANCHOR[0] - (ROOT_X[index] - rect[0]),
                  ANCHOR[1] - (ROOT_Y[index] - rect[1]))
        frame = Image.new("RGBA", (CELL, CELL))
        frame.alpha_composite(crop, offset)
        frame.save(OUTPUT / f"cast_{index + 1:02d}.png")
        atlas.alpha_composite(frame, (column * CELL, row * CELL))
        frames.append(frame)
        preview = Image.new("RGBA", (CELL, CELL), "#17242e")
        draw = ImageDraw.Draw(preview)
        for position in range(0, CELL, 32):
            draw.line((position, 0, position, CELL), fill="#233641")
            draw.line((0, position, CELL, position), fill="#233641")
        preview.alpha_composite(frame)
        previews.append(preview.convert("RGB"))
        manifest.append({"frame": index + 1, "source_rect": rect,
                         "source_actor_root": [ROOT_X[index], ROOT_Y[index]],
                         "canvas_anchor": ANCHOR, "duration_ms": DURATIONS[index]})
    atlas.save(OUTPUT / "cast_sheet.png")
    previews[0].save(OUTPUT / "cast_preview.gif", save_all=True,
                     append_images=previews[1:], duration=DURATIONS,
                     loop=0, disposal=2)
    board = Image.new("RGB", (CELL * 4, CELL * 2))
    for index, preview in enumerate(previews):
        board.paste(preview, ((index % 4) * CELL, (index // 4) * CELL))
    board.save(SOURCE / "split_review.png")
    (SOURCE / "frames.json").write_text(json.dumps({"canvas": [CELL, CELL],
        "frames": manifest, "note": "Front-facing cast, body and shield combined; not wired to gameplay."}, indent=2) + "\n")
    lines = ['[gd_resource type="SpriteFrames" load_steps=10 format=3]',
             '[ext_resource type="Texture2D" path="res://assets/art/characters/enemies/shield_barrier_cast_v1/cast_sheet.png" id="1"]']
    for index in range(8):
        lines.extend([f'[sub_resource type="AtlasTexture" id="F{index}"]',
                      'atlas = ExtResource("1")',
                      f'region = Rect2({index % 4 * CELL}, {index // 4 * CELL}, {CELL}, {CELL})'])
    entries = ',\n'.join('{"duration": %.2f, "texture": SubResource("F%d")}' % (duration / 100, i)
                          for i, duration in enumerate(DURATIONS))
    lines += ['[resource]', 'animations = [{"frames": [' + entries +
              '], "loop": false, "name": &"cast_barrier_down", "speed": 10.0}]']
    (OUTPUT / "cast_frames.tres").write_text('\n'.join(lines) + '\n')
    print("Saved 8 RGBA frames, atlas, SpriteFrames resource and GIF:", OUTPUT)


if __name__ == "__main__":
    run()
