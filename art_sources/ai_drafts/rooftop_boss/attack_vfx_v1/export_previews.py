"""Slice and package generated VFX sheets without repainting their pixels."""
from pathlib import Path
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent
GENERATED = Path('/Users/yangjiayao/.codex/generated_images/01a1a506-a999-72f2-a6a4-0992e616353e')
SPECS = [
    ('echo', 'exec-377ee4c4-24c1-45d7-bf79-5e26cbbd2b4c.png', [260, 180, 220, 140, 100, 110, 140, 400], 4),
    ('halo', 'exec-480a46bc-cc64-40cf-a65f-ac180505467c.png', [260, 220, 200, 100, 110, 100, 140, 420], 3),
    ('protect', 'exec-22c12a59-e229-4b65-8134-c7b39e82055c.png', [160, 100, 100, 100, 100, 100, 140, 420], 1),
]
PREVIEW_SIZE = 444
preview_sets = []

for name, filename, durations, release_frame in SPECS:
    folder = ROOT / name
    (folder / 'frames').mkdir(parents=True, exist_ok=True)
    source = folder / 'source_sheet_4x2.png'
    if not source.exists():
        shutil.copy2(GENERATED / filename, source)
    sheet = Image.open(source).convert('RGBA')
    assert sheet.getchannel('A').getextrema()[0] == 0
    frames, previews, gif_frames, boxes, offsets = [], [], [], [], []
    for i in range(8):
        col, row = i % 4, i // 4
        # Generated sheet is 1774x887: rounded boundaries retain every pixel.
        box = (round(col * sheet.width / 4), round(row * sheet.height / 2),
               round((col + 1) * sheet.width / 4), round((row + 1) * sheet.height / 2))
        raw = sheet.crop(box)
        # Keep three ground footprints fixed across the generated second row.
        dy = 36 if name == 'halo' and row == 1 else 0
        frame = Image.new('RGBA', (PREVIEW_SIZE, PREVIEW_SIZE))
        frame.alpha_composite(raw, (0, dy))
        alpha = frame.getchannel('A')
        bounds = alpha.point(lambda a: 255 if a >= 128 else 0).getbbox()
        assert bounds and 0 < bounds[0] < bounds[2] < PREVIEW_SIZE and 0 < bounds[1] < bounds[3] < PREVIEW_SIZE, (name, i, bounds)
        frame.save(folder / 'frames' / f'{name}_{i:02d}.png')
        frames.append(frame)
        boxes.append(bounds)
        offsets.append([0, dy])
        background = Image.new('RGBA', frame.size, (24, 29, 43, 255))
        background.alpha_composite(frame)
        previews.append(background.convert('RGB'))
        indexed = frame.convert('RGB').quantize(colors=255)
        indexed.paste(255, mask=alpha.point(lambda a: 255 if a < 128 else 0))
        indexed.info['transparency'] = 255
        gif_frames.append(indexed)
    aligned = Image.new('RGBA', (PREVIEW_SIZE * 4, PREVIEW_SIZE * 2))
    for i, frame in enumerate(frames):
        aligned.alpha_composite(frame, (i % 4 * PREVIEW_SIZE, i // 4 * PREVIEW_SIZE))
    aligned.save(folder / 'aligned_sheet_4x2.png')
    previews[0].save(folder / 'preview.gif', save_all=True, append_images=previews[1:], duration=durations, loop=0, optimize=False)
    gif_frames[0].save(folder / 'transparent.gif', save_all=True, append_images=gif_frames[1:], duration=durations, loop=0, transparency=255, disposal=2, optimize=False)
    frames[0].save(folder / 'transparent.webp', save_all=True, append_images=frames[1:], duration=durations, loop=0, lossless=True)
    metadata = {
        'name': name, 'frame_count': 8, 'frame_size': [PREVIEW_SIZE, PREVIEW_SIZE],
        'frame_duration_ms': durations, 'release_frame_zero_based': release_frame,
        'loop_in_game': False, 'preview_loop': True, 'draft': True,
        'offsets': offsets, 'alpha_bounds': boxes,
    }
    (folder / 'animation.json').write_text(json.dumps(metadata, indent=2))
    with Image.open(folder / 'preview.gif') as check:
        assert check.n_frames == 8 and check.info['loop'] == 0
    preview_sets.append(previews)
    print(f'{name}: verified 8 RGBA PNGs and 8 GIF frames; solid effects inside cells')

combined = []
for i in range(8):
    canvas = Image.new('RGB', (PREVIEW_SIZE * 3 + 32, PREVIEW_SIZE), (24, 29, 43))
    for j, previews in enumerate(preview_sets):
        canvas.paste(previews[i], (j * (PREVIEW_SIZE + 16), 0))
    combined.append(canvas)
combined[0].save(ROOT / 'attack_effects_preview.gif', save_all=True, append_images=combined[1:], duration=[260, 180, 200, 110, 110, 110, 140, 450], loop=0, optimize=False)
print(ROOT / 'attack_effects_preview.gif')
