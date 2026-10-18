"""Prepare the supplied Gemini player sheets for Godot.

The source images use an opaque near-white canvas.  Only matte-colored pixels
connected to the image border are processed.  Their alpha and foreground color
are reconstructed from the white matte, preserving light armor inside the
character silhouette while avoiding a pale outline in game.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


SHEETS = {
    "source_player_walk_down_sheet.png": ("player_walk_down.png", range(6)),
    "source_player_walk_up_sheet.png": ("player_walk_up.png", range(6)),
    "source_player_walk_left_sheet.png": ("player_walk_left.png", range(8)),
    "source_player_idle_side_sheet.png": ("player_idle_side.png", range(6)),
}

FRAME_SIZE = (128, 256)
FRAME_CENTER_X = 64
FRAME_BASELINE_Y = 244
ENCLOSED_MATTE_MIN_PIXELS = 48
ENCLOSED_MATTE_MIN_PURE_RATIO = 0.60


def remove_connected_white_matte(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def is_white_matte(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        darkest = min(red, green, blue)
        chroma = max(red, green, blue) - darkest
        return alpha > 0 and darkest >= 180 and chroma <= 64

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if visited[index] or not is_white_matte(x, y):
            return
        visited[index] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    # Arm/waist gaps can be completely enclosed by the dark outline, so they
    # never join the border flood.  Admit only large, mostly pure-white matte
    # components; pale armor components have varied gray values and stay out.
    component_seen = bytearray(visited)
    for start_y in range(height):
        for start_x in range(width):
            start_index = start_y * width + start_x
            if component_seen[start_index] or not is_white_matte(start_x, start_y):
                continue
            component_seen[start_index] = 1
            component_queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
            component: list[tuple[int, int]] = []
            pure_white_count = 0
            while component_queue:
                x, y = component_queue.popleft()
                component.append((x, y))
                red, green, blue, _alpha = pixels[x, y]
                if min(red, green, blue) >= 245 and max(red, green, blue) - min(red, green, blue) <= 20:
                    pure_white_count += 1
                for neighbor_x, neighbor_y in (
                    (x - 1, y),
                    (x + 1, y),
                    (x, y - 1),
                    (x, y + 1),
                ):
                    if not (0 <= neighbor_x < width and 0 <= neighbor_y < height):
                        continue
                    neighbor_index = neighbor_y * width + neighbor_x
                    if component_seen[neighbor_index] or not is_white_matte(neighbor_x, neighbor_y):
                        continue
                    component_seen[neighbor_index] = 1
                    component_queue.append((neighbor_x, neighbor_y))

            if (
                len(component) >= ENCLOSED_MATTE_MIN_PIXELS
                and pure_white_count / len(component) >= ENCLOSED_MATTE_MIN_PURE_RATIO
            ):
                for x, y in component:
                    visited[y * width + x] = 1

    for y in range(height):
        for x in range(width):
            if not visited[y * width + x]:
                continue
            red, green, blue, source_alpha = pixels[x, y]
            matte = min(red, green, blue)
            reconstructed_alpha = 255 - matte
            if reconstructed_alpha <= 12:
                pixels[x, y] = (0, 0, 0, 0)
                continue

            # Reverse C = A * foreground + (1 - A) * white.  Using the
            # darkest channel estimates A and removes the white contribution
            # instead of merely making the pale edge translucent.
            def reconstruct(channel: int) -> int:
                return max(
                    0,
                    min(255, round((channel - matte) * 255 / reconstructed_alpha)),
                )

            pixels[x, y] = (
                reconstruct(red),
                reconstruct(green),
                reconstruct(blue),
                round(reconstructed_alpha * source_alpha / 255),
            )

    return image


def align_frame_cells(image: Image.Image, used_indices: range) -> Image.Image:
    """Align authored cells to one center and foot baseline without resampling."""
    frame_width, frame_height = FRAME_SIZE
    aligned = Image.new("RGBA", image.size, (0, 0, 0, 0))
    for index in used_indices:
        left = index * frame_width
        frame = image.crop((left, 0, left + frame_width, frame_height))
        bounds = frame.getchannel("A").getbbox()
        if bounds is None:
            continue
        center_x = (bounds[0] + bounds[2]) // 2
        offset = (FRAME_CENTER_X - center_x, FRAME_BASELINE_Y - bounds[3])
        aligned.alpha_composite(frame, (left + offset[0], offset[1]))
    return aligned


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    args.destination.mkdir(parents=True, exist_ok=True)
    for source_name, (destination_name, used_indices) in SHEETS.items():
        source = args.source / source_name
        if not source.is_file():
            raise FileNotFoundError(source)
        image = align_frame_cells(
            remove_connected_white_matte(source),
            used_indices,
        )
        output = args.destination / destination_name
        image.save(output, optimize=True)
        print(f"{source.name} -> {output}")


if __name__ == "__main__":
    main()
