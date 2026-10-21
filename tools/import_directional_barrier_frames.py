"""Package generated RGBA art into aligned SpriteFrames; source pixels are not repainted."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_sources/ai_drafts/enemies/shield_barrier_cast_v2'
OUTPUT = ROOT / 'assets/art/characters/enemies/shield_barrier_cast_v2'
CELL = 384
GENERATED = None  # Source PNGs are committed; no machine-local generation path is required.
FILES = {
 'down': 'exec-3e277456-a708-43df-910a-c322087e9bf4.png',
 'up': 'exec-85313b61-e9d7-45e5-85cd-8662647d5686.png',
 'left': 'exec-ebf248bc-9415-41bf-a523-b634b5489326.png',
 'right': 'exec-3d5b7dad-b304-499a-a73c-1cdbc68c908a.png',
}
# Transparent gutters are measured from these four generated sheets.
ROWS = {'down': [0, 372, 794, 1086], 'up': [0, 370, 779, 1086], 'left': [0, 367, 754, 1086], 'right': [0, 360, 750, 1086]}


def main():
 OUTPUT.mkdir(parents=True, exist_ok=True)
 SOURCE.mkdir(parents=True, exist_ok=True)
 atlas = Image.new('RGBA', (CELL * 8, CELL * 6))
 animations = []
 manifest = {}
 for row, (heading, filename) in enumerate(FILES.items()):
  source = SOURCE / (heading + '.png')
  if not source.exists():
   raise FileNotFoundError(f"Missing generated source sheet: {source}")
  image = Image.open(source).convert('RGBA')
  records = []
  for index in range(12):
   r, c = divmod(index, 4)
   left, right = round(c * image.width / 4), round((c + 1) * image.width / 4)
   crop = image.crop((left, ROWS[heading][r], right, ROWS[heading][r + 1]))
   canvas = Image.new('RGBA', (CELL, CELL))
   if index < 8:
    rgba = np.asarray(crop).astype(int)
    mask = (rgba[:, :, 3] > 100) & ~((rgba[:, :, 2] - rgba[:, :, 0] > 55) & (rgba[:, :, 1] - rgba[:, :, 0] > 45))
    ys, xs = np.where(mask)
    # Lock to armored boots rather than the expanding cyan effect.
    bottom = int(ys.max()) + 1
    near_feet = xs[ys > bottom - 22]
    center = float(np.median(near_feet)) if len(near_feet) else float(np.median(xs))
    factor = 0.88
    resized = crop.resize((round(crop.width * factor), round(crop.height * factor)), Image.Resampling.NEAREST)
    offset = (round(192 - center * factor), round(320 - bottom * factor))
    canvas.alpha_composite(resized, offset)
    atlas.alpha_composite(canvas, (index * CELL, row * CELL))
    records.append({'source_cell': index, 'foot_anchor': [192, 320], 'offset': offset})
   else:
    bbox = crop.getbbox()
    crop = crop.crop(bbox)
    factor = 364 / (crop.width if heading in ('down', 'up') else crop.height)
    resized = crop.resize((round(crop.width * factor), round(crop.height * factor)), Image.Resampling.NEAREST)
    canvas.alpha_composite(resized, ((CELL - resized.width) // 2, (CELL - resized.height) // 2))
    atlas.alpha_composite(canvas, (((index - 8) + (row % 2) * 4) * CELL, (4 + row // 2) * CELL))
  manifest[heading] = records
  animations.append((f'cast_barrier_{heading}', False, [(i * CELL, row * CELL) for i in range(8)], 10.0))
  animations.append((f'flight_{heading}', True, [((i + row % 2 * 4) * CELL, (4 + row // 2) * CELL) for i in range(4)], 9.0))
 atlas.save(OUTPUT / 'atlas.png')
 lines = ['[gd_resource type="SpriteFrames" format=3]', '[ext_resource type="Texture2D" path="res://assets/art/characters/enemies/shield_barrier_cast_v2/atlas.png" id="1"]']
 clips=[]; counter=0
 for name, loop, cells, fps in animations:
  entries=[]
  for x,y in cells:
   counter+=1
   lines += [f'[sub_resource type="AtlasTexture" id="F{counter}"]', 'atlas = ExtResource("1")', f'region = Rect2({x}, {y}, {CELL}, {CELL})']
   entries.append('{"duration": 1.0, "texture": SubResource("F%d")}' % counter)
  clips.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}' % (','.join(entries),str(loop).lower(),name,fps))
 lines += ['[resource]', 'animations = [' + ',\n'.join(clips) + ']']
 (OUTPUT/'frames.tres').write_text('\n\n'.join(lines)+'\n')
 (SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (SOURCE/'prompt.txt').write_text('Built-in imagegen; four separate identity-preserving edits of shield_barrier_cast_v1/cast_sheet.png. Same navy armor, amber lights, cyan honeycomb barrier. Each image: 4 columns x 3 rows; eight stationary cast/recovery frames plus four standalone flying barrier frames. Each direction is redrawn using the same overhead camera, real alpha, no text. Preserve armored foot anchors when packaging.\n')
 print('Packaged 32 casting frames and 16 detached shield frames; four cast and four flight clips.')

if __name__ == '__main__':
 main()
