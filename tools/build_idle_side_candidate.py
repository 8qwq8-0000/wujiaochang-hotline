#!/usr/bin/env python3
"""Normalize a generated six-frame idle sheet against the active walk palette.

The image generator does not guarantee an exactly divisible output canvas. This
tool splits the sheet proportionally, removes isolated transparent-edge noise,
locks the magenta helmet disc and foot baseline, and maps visible pixels to a
palette sampled from the active right-walk sheet.
"""

from __future__ import annotations

import argparse
import math
import statistics
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


FRAME_COUNT = 6
FRAME_SIZE = (128, 256)
TARGET_VISIBLE_HEIGHT = 164
TARGET_FOOT_Y = 243
PALETTE_COLORS = 96


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--generated", required=True, type=Path)
    parser.add_argument("--generated-columns", type=int, default=FRAME_COUNT)
    parser.add_argument("--walk-sheet", required=True, type=Path)
    parser.add_argument("--old-idle-sheet", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    return parser.parse_args()


def split_proportional(image: Image.Image, count: int) -> list[Image.Image]:
    bounds = [round(index * image.width / count) for index in range(count + 1)]
    return [image.crop((bounds[index], 0, bounds[index + 1], image.height))
            for index in range(count)]


def split_regular(image: Image.Image, columns: int) -> list[Image.Image]:
    if image.width % columns:
        raise ValueError(f"Sheet width {image.width} is not divisible by {columns}")
    width = image.width // columns
    return [image.crop((index * width, 0, (index + 1) * width, image.height))
            for index in range(columns)]


def largest_component_bbox(image: Image.Image, alpha_threshold: int = 16) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    width, height = image.size
    occupied = bytearray(width * height)
    alpha_bytes = alpha.tobytes()
    for index, value in enumerate(alpha_bytes):
        occupied[index] = value >= alpha_threshold

    visited = bytearray(width * height)
    largest: list[int] = []
    for start, is_occupied in enumerate(occupied):
        if not is_occupied or visited[start]:
            continue
        queue = deque([start])
        visited[start] = 1
        component: list[int] = []
        while queue:
            current = queue.popleft()
            component.append(current)
            x = current % width
            y = current // width
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if nx < 0 or nx >= width or ny < 0 or ny >= height:
                    continue
                neighbor = ny * width + nx
                if occupied[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    queue.append(neighbor)
        if len(component) > len(largest):
            largest = component

    if not largest:
        raise ValueError("Generated frame contains no visible sprite")
    xs = [index % width for index in largest]
    ys = [index // width for index in largest]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def clean_and_trim(image: Image.Image) -> Image.Image:
    left, top, right, bottom = largest_component_bbox(image)
    padding = 5
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    cropped = image.crop((left, top, right, bottom))

    # Remove generator speckles outside the main component's padded rectangle.
    bbox = cropped.getchannel("A").point(lambda value: 255 if value >= 16 else 0).getbbox()
    if bbox is None:
        raise ValueError("Generated frame became empty after cleanup")
    return cropped.crop(bbox)


def magenta_centroid(image: Image.Image) -> tuple[float, float] | None:
    points: list[tuple[int, int]] = []
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = image.getpixel((x, y))
            if (alpha >= 32 and red >= 70 and blue >= 55
                    and red > green * 1.2 and blue > green * 1.1):
                points.append((x, y))
    if not points:
        return None
    return (
        sum(point[0] for point in points) / len(points),
        sum(point[1] for point in points) / len(points),
    )


def reference_palette(image: Image.Image, colors: int) -> list[tuple[int, int, int]]:
    visible = [pixel[:3] for pixel in image.get_flattened_data() if pixel[3] >= 16]
    if not visible:
        raise ValueError("Walk reference contains no visible pixels")
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    quantized = samples.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    raw_palette = quantized.getpalette()
    used = sorted(set(quantized.get_flattened_data()))
    return [tuple(raw_palette[index * 3:index * 3 + 3]) for index in used]


def map_to_palette(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    output = Image.new("RGBA", image.size)
    mapped: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in image.get_flattened_data():
        if alpha == 0:
            mapped.append((0, 0, 0, 0))
            continue
        source = (red, green, blue)
        target = cache.get(source)
        if target is None:
            target = min(
                palette,
                key=lambda item: ((red - item[0]) ** 2
                                  + (green - item[1]) ** 2
                                  + (blue - item[2]) ** 2),
            )
            cache[source] = target
        mapped.append((*target, alpha))
    output.putdata(mapped)
    return output


def normalize_frame(
    image: Image.Image,
    helmet_anchor_x: float,
    palette: list[tuple[int, int, int]],
) -> Image.Image:
    trimmed = clean_and_trim(image)
    scale = TARGET_VISIBLE_HEIGHT / trimmed.height
    width = max(1, round(trimmed.width * scale))
    resized = trimmed.resize((width, TARGET_VISIBLE_HEIGHT), Image.Resampling.NEAREST)
    resized = map_to_palette(resized, palette)

    centroid = magenta_centroid(resized)
    if centroid is None:
        x = (FRAME_SIZE[0] - resized.width) // 2
    else:
        x = round(helmet_anchor_x - centroid[0])
    y = TARGET_FOOT_Y - resized.height + 1

    # Wide guard poses can exceed the walk-frame helmet anchor by a few pixels.
    # Preserve the complete sprite and clamp it into the runtime cell instead of
    # cropping equipment at the edge.
    x = min(max(0, x), FRAME_SIZE[0] - resized.width)
    output = Image.new("RGBA", FRAME_SIZE)
    output.alpha_composite(resized, (x, y))
    return output


def build_review_board(
    walk_frames: list[Image.Image],
    old_frames: list[Image.Image],
    candidate_frames: list[Image.Image],
    destination: Path,
) -> None:
    scale = 2
    label_height = 24
    row_height = FRAME_SIZE[1] * scale + label_height
    board = Image.new("RGB", (FRAME_COUNT * FRAME_SIZE[0] * scale, row_height * 3), "#e8e5df")
    draw = ImageDraw.Draw(board)
    rows = (("RIGHT WALK REFERENCE", walk_frames), ("OLD IDLE", old_frames), ("CANDIDATE IDLE", candidate_frames))
    for row, (label, frames) in enumerate(rows):
        top = row * row_height
        draw.text((6, top + 5), label, fill="#242424")
        for column, frame in enumerate(frames):
            preview = frame.resize((FRAME_SIZE[0] * scale, FRAME_SIZE[1] * scale), Image.Resampling.NEAREST)
            background = Image.new("RGBA", preview.size, "#e8e5df")
            background.alpha_composite(preview)
            board.paste(background.convert("RGB"), (column * FRAME_SIZE[0] * scale, top + label_height))
    destination.parent.mkdir(parents=True, exist_ok=True)
    board.save(destination)


def main() -> None:
    args = parse_args()
    generated = Image.open(args.generated).convert("RGBA")
    walk_sheet = Image.open(args.walk_sheet).convert("RGBA")
    old_idle_sheet = Image.open(args.old_idle_sheet).convert("RGBA")
    if args.generated_columns < FRAME_COUNT:
        raise ValueError("Generated sheet must contain at least six columns")
    generated_frames = split_proportional(generated, args.generated_columns)[:FRAME_COUNT]
    walk_frames = split_regular(walk_sheet, FRAME_COUNT)
    old_frames = split_regular(old_idle_sheet, 8)[:FRAME_COUNT]

    anchors = [centroid[0] for frame in walk_frames if (centroid := magenta_centroid(frame))]
    if not anchors:
        raise ValueError("Could not locate the magenta helmet anchor in walk references")
    helmet_anchor_x = statistics.median(anchors)
    palette = reference_palette(walk_sheet, PALETTE_COLORS)

    args.out.mkdir(parents=True, exist_ok=False)
    candidate_frames = [normalize_frame(frame, helmet_anchor_x, palette) for frame in generated_frames]
    for index, frame in enumerate(candidate_frames, start=1):
        frame.save(args.out / f"frame-{index:03d}.png")

    build_review_board(
        walk_frames,
        old_frames,
        candidate_frames,
        args.out.parent / "idle_vs_walk_comparison.png",
    )
    print({
        "frames": len(candidate_frames),
        "frameSize": FRAME_SIZE,
        "visibleHeight": TARGET_VISIBLE_HEIGHT,
        "footY": TARGET_FOOT_Y,
        "helmetAnchorX": round(helmet_anchor_x, 2),
        "paletteColors": len(palette),
        "output": str(args.out.resolve()),
    })


if __name__ == "__main__":
    main()
