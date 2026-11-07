"""Export ImageGen casting sheets; preserve generated pixels and alpha."""
from pathlib import Path
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent
GENERATED = Path('/Users/yangjiayao/.codex/generated_images/01a1a506-a999-72f2-a6a4-0992e616353e')
SPECS = [
    ('echo', 'exec-c3acd7c5-b0e7-49c1-9274-3d0a21d2645d.png', 3),
    ('halo', 'exec-6819915c-a865-489b-802b-1831b5cba851.png', 4),
    ('protect', 'exec-71526f8a-c7b7-48b1-9b72-21a578d808dd.png', 3),
]
DURATIONS = [350, 160, 180, 120, 160, 160, 160, 550]
previews_by_skill = []

for name, filename, release_frame in SPECS:
    out = ROOT / name
    (out / 'frames').mkdir(parents=True, exist_ok=True)
    source = out / 'source_sheet_4x2.png'
    if not source.exists():
        shutil.copy2(GENERATED / filename, source)
    sheet = Image.open(source).convert('RGBA')
    assert sheet.size == (1536, 1024)
    assert sheet.getchannel('A').getextrema()[0] == 0
    frames, previews, gifs, bounds = [], [], [], []
    for i in range(8):
        x, y = i % 4 * 384, i // 4 * 512
        frame = sheet.crop((x, y, x + 384, y + 512))
        alpha = frame.getchannel('A')
        box = alpha.point(lambda a: 255 if a >= 128 else 0).getbbox()
        assert box and 0 < box[0] < box[2] < 384 and 0 < box[1] < box[3] < 512, (name, i, box)
        bounds.append(box)
        frame.save(out / 'frames' / f'{name}_{i:02d}.png')
        frames.append(frame)
        background = Image.new('RGBA', frame.size, (24, 29, 43, 255))
        background.alpha_composite(frame)
        previews.append(background.convert('RGB'))
        palette = frame.convert('RGB').quantize(colors=255)
        palette.paste(255, mask=alpha.point(lambda a: 255 if a < 128 else 0))
        palette.info['transparency'] = 255
        gifs.append(palette)
    previews[0].save(out / 'preview.gif', save_all=True, append_images=previews[1:], duration=DURATIONS, loop=0, optimize=False)
    gifs[0].save(out / 'transparent.gif', save_all=True, append_images=gifs[1:], duration=DURATIONS, loop=0, transparency=255, disposal=2, optimize=False)
    frames[0].save(out / 'transparent.webp', save_all=True, append_images=frames[1:], duration=DURATIONS, loop=0, lossless=True)
    metadata = {
        'name': name, 'frame_count': 8, 'frame_size': [384, 512],
        'frame_durations_ms': DURATIONS, 'release_frame_zero_based': release_frame,
        'game_animation_loop': False, 'preview_loop': True, 'draft': True,
        'alpha_bounds': bounds,
    }
    (out / 'animation.json').write_text(json.dumps(metadata, indent=2))
    with Image.open(out / 'preview.gif') as check:
        assert check.n_frames == 8 and check.info['loop'] == 0
    previews_by_skill.append(previews)
    print(f'{name}: 8 RGBA frames, 8 GIF frames, no clipped solid silhouettes')

combined = []
for i in range(8):
    canvas = Image.new('RGB', (1184, 512), (24, 29, 43))
    for j, previews in enumerate(previews_by_skill):
        canvas.paste(previews[i], (j * 400, 0))
    combined.append(canvas)
combined[0].save(ROOT / 'skills_preview.gif', save_all=True, append_images=combined[1:], duration=DURATIONS, loop=0, optimize=False)
print('Combined preview:', ROOT / 'skills_preview.gif')
