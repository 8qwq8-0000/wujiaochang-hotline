from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def alpha_bbox(image: Image.Image, threshold: int = 16) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    y_positions, x_positions = np.nonzero(alpha >= threshold)
    if not len(x_positions):
        raise ValueError("Frame has no visible pixels")
    return (
        int(x_positions.min()),
        int(y_positions.min()),
        int(x_positions.max()) + 1,
        int(y_positions.max()) + 1,
    )


def nearest_source_colors(
    image: Image.Image,
    source_palette: np.ndarray,
    chunk_size: int = 128,
) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    visible = rgba[..., 3] > 0
    colors, inverse = np.unique(rgba[..., :3][visible], axis=0, return_inverse=True)
    mapped = np.empty_like(colors)
    palette = source_palette.astype(np.int16)

    for start in range(0, len(colors), chunk_size):
        chunk = colors[start : start + chunk_size].astype(np.int16)
        delta = chunk[:, None, :] - palette[None, :, :]
        distances = np.sum(delta.astype(np.int32) ** 2, axis=2)
        mapped[start : start + len(chunk)] = source_palette[
            np.argmin(distances, axis=1)
        ]

    rgba[..., :3][visible] = mapped[inverse]
    return Image.fromarray(rgba, mode="RGBA")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Align generated frames to source frame scale/baseline and map colors."
    )
    parser.add_argument("--source", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    source_dir = Path(args.source)
    candidate_dir = Path(args.candidate)
    output_dir = Path(args.out)
    aligned_dir = output_dir / "aligned"
    palette_dir = output_dir / "palette-mapped"
    aligned_dir.mkdir(parents=True, exist_ok=True)
    palette_dir.mkdir(parents=True, exist_ok=True)

    source_paths = sorted(source_dir.glob("frame-*.png"))
    candidate_paths = sorted(candidate_dir.glob("frame-*.png"))
    if len(source_paths) != len(candidate_paths):
        raise ValueError(
            f"Frame count mismatch: {len(source_paths)} source, "
            f"{len(candidate_paths)} candidate"
        )

    source_images = [Image.open(path).convert("RGBA") for path in source_paths]
    candidate_images = [Image.open(path).convert("RGBA") for path in candidate_paths]
    if not source_images:
        raise ValueError("No source frames found")

    visible_source_rgb = []
    for image in source_images:
        rgba = np.asarray(image, dtype=np.uint8)
        visible_source_rgb.append(rgba[..., :3][rgba[..., 3] > 0])
    source_palette = np.unique(np.concatenate(visible_source_rgb, axis=0), axis=0)

    records = []
    for index, (source, candidate) in enumerate(
        zip(source_images, candidate_images), start=1
    ):
        source_bbox = alpha_bbox(source)
        candidate_bbox = alpha_bbox(candidate)
        source_height = source_bbox[3] - source_bbox[1]
        candidate_subject = candidate.crop(candidate_bbox)
        scale = source_height / candidate_subject.height
        resized_width = max(1, round(candidate_subject.width * scale))
        resized = candidate_subject.resize(
            (resized_width, source_height), Image.Resampling.NEAREST
        )

        source_center_x = (source_bbox[0] + source_bbox[2]) / 2
        paste_x = round(source_center_x - resized.width / 2)
        paste_y = source_bbox[3] - resized.height
        paste_x = min(max(0, paste_x), source.width - resized.width)
        paste_y = min(max(0, paste_y), source.height - resized.height)

        canvas = Image.new("RGBA", source.size, (0, 0, 0, 0))
        canvas.alpha_composite(resized, (paste_x, paste_y))
        aligned_path = aligned_dir / f"frame-{index:03d}.png"
        canvas.save(aligned_path)

        palette_mapped = nearest_source_colors(canvas, source_palette)
        palette_path = palette_dir / f"frame-{index:03d}.png"
        palette_mapped.save(palette_path)

        records.append(
            {
                "frame": index,
                "source_bbox": list(source_bbox),
                "candidate_bbox": list(candidate_bbox),
                "scale": scale,
                "output_position": [paste_x, paste_y],
                "output_size": list(resized.size),
            }
        )

    manifest = {
        "source_frames": len(source_paths),
        "source_palette_rgb_colors": int(len(source_palette)),
        "records": records,
    }
    (output_dir / "alignment.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
