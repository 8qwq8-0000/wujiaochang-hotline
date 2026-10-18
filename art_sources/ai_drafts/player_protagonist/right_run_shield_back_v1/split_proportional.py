from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Split an approximately six-cell generated strip by proportional boundaries."
    )
    parser.add_argument("--input", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--frames", type=int, default=6)
    parser.add_argument("--width", type=int, default=128)
    parser.add_argument("--height", type=int, default=256)
    args = parser.parse_args()

    source_path = Path(args.input)
    output_dir = Path(args.out)
    output_dir.mkdir(parents=True, exist_ok=True)

    source = Image.open(source_path).convert("RGBA")
    boundaries = [round(index * source.width / args.frames) for index in range(args.frames + 1)]
    records = []

    for index in range(args.frames):
        left, right = boundaries[index], boundaries[index + 1]
        cell = source.crop((left, 0, right, source.height))
        normalized = cell.resize((args.width, args.height), Image.Resampling.NEAREST)
        output_path = output_dir / f"frame-{index + 1:03d}.png"
        normalized.save(output_path)
        records.append(
            {
                "frame": index + 1,
                "source_box": [left, 0, right, source.height],
                "source_size": [cell.width, cell.height],
                "output": str(output_path),
            }
        )

    manifest = {
        "input": str(source_path),
        "input_size": list(source.size),
        "boundaries": boundaries,
        "output_size": [args.width, args.height],
        "records": records,
    }
    manifest_path = output_dir.parent / "split_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
