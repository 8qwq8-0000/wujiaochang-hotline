"""Describe generated four-direction sprites without repainting source pixels.

Usage: uv run --with pillow --with numpy python tools/import_dragon_animation.py
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / 'assets/art/characters/companions/dragon_gpt_v1/walk_atlas.png'
OUT = ASSET.with_name('frames.tres')
MANIFEST = ROOT / 'docs/art/validation/dragon_gpt_v1/atlas_manifest.json'


def main():
    pixels = np.asarray(Image.open(ASSET).convert('RGBA'))
    assert pixels.shape == (1024, 1536, 4)
    assert np.count_nonzero(pixels[:, :, 3] == 0) > 100_000
    definitions, clips, records = [], [], []
    for row, direction in enumerate(('down', 'left', 'up', 'right')):
        bounds, feet = [], []
        for col in range(6):
            alpha = pixels[row*256:(row+1)*256, col*256:(col+1)*256, 3] > 64
            ys, xs = np.where(alpha)
            assert len(xs) > 1000
            bounds.append((int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1))
            fy, fx = np.where(alpha & (np.indices(alpha.shape)[0] >= ys.max()-12))
            feet.append(float(np.median(fx)))
        # One shared origin per direction preserves actual limb motion, rather
        # than re-centering every stride on the currently extended shoe.
        anchor_x = round(float(np.median(feet)))
        anchor_y = max(b[3] for b in bounds)
        refs = []
        for col, (left, top, right, bottom) in enumerate(bounds):
            width, height = right-left, bottom-top
            margin_x, margin_y = 128-anchor_x+left, 232-anchor_y+top
            assert min(margin_x, margin_y) >= 0
            assert margin_x+width <= 256 and margin_y+height <= 256
            region = (col*256+left, row*256+top, width, height)
            margin = (margin_x, margin_y, 256-width, 256-height)
            name = f'Frame_{row}_{col}'
            definitions.append(f'[sub_resource type="AtlasTexture" id="{name}"]\natlas = ExtResource("atlas")\nregion = Rect2{region}\nmargin = Rect2{margin}\nfilter_clip = true\n')
            refs.append('{"duration": 1.0, "texture": SubResource("%s")}' % name)
            records.append(dict(direction=direction, frame=col, region=region, margin=margin, anchor=[anchor_x, anchor_y]))
        clips.append('{"name": &"walk_%s", "frames": [%s], "loop": true, "speed": 8.0}' % (direction, ', '.join(refs)))
        clips.append('{"name": &"idle_%s", "frames": [%s], "loop": true, "speed": 1.0}' % (direction, refs[2]))
    OUT.write_text('[gd_resource type="SpriteFrames" load_steps=26 format=3]\n\n[ext_resource type="Texture2D" path="res://'+ASSET.relative_to(ROOT).as_posix()+'" id="atlas"]\n\n'+'\n'.join(definitions)+'\n[resource]\nanimations = ['+',\n'.join(clips)+']\n')
    MANIFEST.write_text(json.dumps(dict(dimensions=[1536,1024], grid=[6,4], frame_canvas=[256,256], foot_anchor=[128,232], frames=records), ensure_ascii=False, indent=2)+'\n')
    print('24 atlas frames; 4 walk loops at 8 fps; 4 directional idle poses.')


if __name__ == '__main__':
    main()
