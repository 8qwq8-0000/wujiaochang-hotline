"""Align generated cells and insert the approved source as frame five.

Only layout, proportional nearest-neighbor sizing and sheet assembly are done
here. Final PNG frame and GIF export uses the FrameRonin skill.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / 'parry_shield_v1/parry_shield_right_static_v1.png'
SIDE = 418


def visible_box(image):
    return image.getchannel('A').point(lambda a: 255 if a >= 16 else 0).getbbox()


sheet = Image.new('RGBA', (SIDE * 3, SIDE * 3))
records = []
for index in range(9):
    image = Image.open(ROOT / 'source_split' / f'frame-{index + 1:03}.png').convert('RGBA')
    if index == 4:
        image = Image.open(SOURCE).convert('RGBA')
        box = visible_box(image)
        scale = 350 / (box[3] - box[1])
        image = image.resize(tuple(round(v * scale) for v in image.size), Image.Resampling.NEAREST)
    box = visible_box(image)
    offset = (round(SIDE / 2 - (box[0] + box[2]) / 2),
              round(SIDE / 2 - (box[1] + box[3]) / 2))
    frame = Image.new('RGBA', (SIDE, SIDE))
    frame.alpha_composite(image, offset)
    aligned_box = visible_box(frame)
    assert aligned_box[2] - aligned_box[0] == box[2] - box[0]
    assert aligned_box[3] - aligned_box[1] == box[3] - box[1]
    sheet.paste(frame, (index % 3 * SIDE, index // 3 * SIDE))
    records.append({'frame': index + 1, 'visibleBounds': aligned_box,
                    'source': str(SOURCE) if index == 4 else 'generated',
                    'layoutOffset': offset})
sheet.save(ROOT / 'aligned_sheet.png')
(ROOT / 'layout.json').write_text(json.dumps(records, indent=2))
print(json.dumps({'frames': 9, 'frameSize': [SIDE, SIDE],
                  'frame5': 'approved original, proportional nearest-neighbor resize',
                  'sheet': str(ROOT / 'aligned_sheet.png')}))
