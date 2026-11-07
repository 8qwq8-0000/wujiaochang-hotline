"""Package reviewed boss animation drafts into exportable Godot resources.

uv run --with pillow python tools/import_channel_boss_animation.py
Only layout/atlas metadata changes; original RGBA pixels are preserved.
"""
from pathlib import Path
from statistics import median
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_sources/ai_drafts/rooftop_boss'
BODY = ROOT / 'assets/art/characters/bosses/rooftop_whale_goddess/channel_returned_v1'
EFFECTS = ROOT / 'assets/art/effects/channel_boss_v1'
REPORT = ROOT / 'docs/art/validation/channel_boss_duel_v1'


def resource_file(folder, names, duration_sets, looped, anchors):
    externals, resources, clips, records = [], [], [], []
    for name in names:
        path = (folder / f'{name}.png').relative_to(ROOT).as_posix()
        externals.append(f'[ext_resource type="Texture2D" path="res://{path}" id="{name}"]')
        refs = []
        sheet = Image.open(folder / f'{name}.png').convert('RGBA')
        width, height = sheet.width // 4, sheet.height // 2
        anchor_x, anchor_y = anchors.get(name, (width / 2, height / 2))
        for i in range(8):
            frame = sheet.crop((i % 4 * width, i // 4 * height, (i % 4 + 1) * width, (i // 4 + 1) * height))
            box = frame.getchannel('A').point(lambda a: 255 if a >= 32 else 0).getbbox()
            assert box is not None
            left, top, right, bottom = box
            w, h = right-left, bottom-top
            # Fixed origin per clip avoids chasing moving clothing each frame.
            common_x, common_y = (192, 470) if folder == BODY else (width/2, height/2)
            mx, my = common_x-anchor_x+left, common_y-anchor_y+top
            assert min(mx, my) >= 0 and mx+w <= width and my+h <= height
            region = (i % 4 * width+left, i // 4 * height+top, w, h)
            margin = (int(mx), int(my), width-w, height-h)
            identifier = f'{name}_{i}'
            resources.append(f'[sub_resource type="AtlasTexture" id="{identifier}"]\natlas = ExtResource("{name}")\nregion = Rect2{region}\nmargin = Rect2{margin}\nfilter_clip = true\n')
            duration = duration_sets[name][i]
            refs.append('{"duration": %s, "texture": SubResource("%s")}' % (duration, identifier))
            records.append(dict(clip=name, frame=i, region=region, margin=margin))
        clips.append('{"name": &"%s", "frames": [%s], "loop": %s, "speed": 1.0}' % (name, ', '.join(refs), str(name in looped).lower()))
    count = len(externals)+len(resources)+1
    (folder/'frames.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={count} format=3]\n\n'+'\n'.join(externals)+'\n\n'+'\n'.join(resources)+'\n[resource]\nanimations = ['+',\n'.join(clips)+']\n')
    return records


def main():
    for folder in (BODY, EFFECTS, REPORT):
        folder.mkdir(parents=True, exist_ok=True)
    anchors = {}
    for name in ['idle', 'move', 'echo', 'halo', 'protect']:
        folder = SOURCE/'move_front_v2/frames' if name in ['idle', 'move'] else SOURCE/f'skills_v1/{name}/frames'
        prefix = 'move' if name in ['idle', 'move'] else name
        frames = [Image.open(folder/f'{prefix}_{i:02d}.png').convert('RGBA') for i in range(8)]
        feet_x, feet_y = [], []
        sheet = Image.new('RGBA', (1536, 1024))
        for i, frame in enumerate(frames):
            assert frame.size == (384, 512)
            alpha = frame.getchannel('A')
            box = alpha.point(lambda a: 255 if a >= 128 else 0).getbbox()
            left, top, right, bottom = box
            shoe_pixels = [(x, y) for y in range(bottom-8, bottom) for x in range(130, 255) if alpha.getpixel((x, y)) >= 128]
            feet_x.append(median([p[0] for p in shoe_pixels]))
            feet_y.append(bottom)
            sheet.paste(frame, (i % 4*384, i//4*512))
        anchors[name] = (round(median(feet_x)), round(median(feet_y)))
        sheet.save(BODY/f'{name}.png')
    casts = [0.35, 0.16, 0.18, 0.12, 0.16, 0.16, 0.16, 0.25]
    times = {name: ([0.22]*8 if name in ['idle','move'] else casts) for name in anchors}
    body_records = resource_file(BODY, list(anchors), times, {'idle','move'}, anchors)
    for name in ['echo','halo','protect']:
        shutil.copy2(SOURCE/f'attack_vfx_v1/{name}/aligned_sheet_4x2.png', EFFECTS/f'{name}.png')
    effects_times = {
        'echo':[0.26,0.18,0.22,0.14,0.10,0.11,0.14,0.20],
        'halo':[0.32,0.32,0.32,0.10,0.11,0.10,0.14,0.20],
        'protect':[0.16,0.10,0.10,0.10,0.10,0.10,0.14,0.20],
    }
    effect_records = resource_file(EFFECTS, list(effects_times), effects_times, set(), {})
    (REPORT/'atlas_manifest.json').write_text(json.dumps(dict(body_anchors=anchors, body_frames=body_records, effect_frames=effect_records), indent=2)+'\n')
    print('Packaged 40 body frames and 24 VFX frames with exportable SpriteFrames.')


if __name__ == '__main__':
    main()
