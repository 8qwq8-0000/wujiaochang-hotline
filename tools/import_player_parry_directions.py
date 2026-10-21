"""Align generated parry sprites without repainting or rotating their source pixels."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_sources/ai_drafts/player_protagonist/parry_cardinal_v2'
OUTPUT = ROOT / 'assets/art/vfx/player/parry_cardinal_v2'
CELL = 104


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for direction in ('left', 'up', 'down'):
        source = Image.open(SOURCE / f'{direction}.png').convert('RGBA')
        frames, records = [], []
        for index in range(9):
            row, col = divmod(index, 3)
            if direction == 'left':
                # The first generated sheet's second row has the correct west-facing arc.
                region = (round(index * source.width / 9), 236,
                          round((index + 1) * source.width / 9), 465)
            else:
                region = (round(col * source.width / 3), round(row * source.height / 3),
                          round((col + 1) * source.width / 3), round((row + 1) * source.height / 3))
            crop = source.crop(region)
            box = crop.getchannel('A').point(lambda a: 255 if a >= 32 else 0).getbbox()
            if box is None:
                raise ValueError(f'Empty {direction} frame {index + 1}')
            # Every effect must be isolated inside its source cell, never cut at a border.
            if box[0] < 2 or box[1] < 2 or box[2] > crop.width - 2 or box[3] > crop.height - 2:
                raise ValueError(f'{direction} frame {index + 1} touches a source-cell boundary')
            frames.append(crop.crop(box))
            records.append({'source_region': region, 'visible_bounds': box})
        factor = 90 / max(max(frame.size) for frame in frames)
        atlas = Image.new('RGBA', (CELL * 3, CELL * 3))
        for index, frame in enumerate(frames):
            frame = frame.resize((max(1, round(frame.width * factor)), max(1, round(frame.height * factor))), Image.Resampling.NEAREST)
            offset = ((CELL - frame.width) // 2, (CELL - frame.height) // 2)
            atlas.alpha_composite(frame, (index % 3 * CELL + offset[0], index // 3 * CELL + offset[1]))
            records[index]['offset'] = offset
        atlas.save(OUTPUT / f'{direction}.png')
        manifest[direction] = {'scale': factor, 'frames': records}
    (SOURCE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Packaged three independent nine-frame atlases; existing right-facing atlas retained.')


if __name__ == '__main__':
    main()
