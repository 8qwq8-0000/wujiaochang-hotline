"""Extract and align the reviewed enemy sheets; no sprite painting or generation.

The generated art is not a precise grid. Rows use measured transparent gutters,
and the anchor is measured from the armored boots, never from attack effects.
Run with Python + Pillow + numpy. Original source sheets remain untouched.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_sources/ai_drafts/enemies"
OUTPUT = ROOT / "assets/art/characters/enemies/animated"
REVIEW = SOURCE / "animation_review_v1"
CELL = 192
ANCHOR = (96, 168)
ROLES = {
    "melee": (SOURCE / "melee_sprite_sheet_v1/melee_sprite_sheet_v1.png", 84),
    "ranged": (SOURCE / "ranged_sprite_sheet_v1/ranged_sprite_sheet_v1.png", 84),
    "shield": (SOURCE / "shield_robot_v1/shield_sprite_sheet_v1.png", 88),
}
ANIMATIONS = ["walk_down", "walk_left", "walk_up", "walk_right",
              "attack_down", "attack_left", "attack_up", "attack_right"]


def row_ranges(image: Image.Image, expected: int) -> list[tuple[int, int]]:
    mask = np.asarray(image)[:, :, 3] > 100
    occupied = mask.sum(axis=1) > 8
    ys = np.where(occupied)[0]
    # A transparent gutter of at least eight source pixels separates rows.
    splits = np.where(np.diff(ys) > 8)[0]
    starts = [int(ys[0]), *[int(ys[i + 1]) for i in splits]]
    ends = [*[int(ys[i] + 1) for i in splits], int(ys[-1] + 1)]
    bands = [(a, b) for a, b in zip(starts, ends) if b - a > 25]
    if len(bands) != expected:
        raise ValueError(f"Expected {expected} separated rows, got {bands}")
    # Mid-gutter boundaries retain antialiased edge pixels but exclude neighbors.
    return [(0 if i == 0 else (bands[i - 1][1] + a) // 2,
             image.height if i == expected - 1 else (b + bands[i + 1][0]) // 2)
            for i, (a, b) in enumerate(bands)]


def cut(image: Image.Image, rows: list[tuple[int, int]], row: int, column: int, columns: int) -> Image.Image:
    # Use actual empty gutters rather than assuming the generated columns have
    # mathematically exact widths. A long baton can cross the nominal grid.
    band = np.asarray(image)[rows[row][0]:rows[row][1], :, 3] > 100
    density = band.sum(axis=0)
    edges = [0]
    for index in range(1, columns):
        expected = index * image.width / columns
        radius = image.width / columns * .27
        start, end = round(expected - radius), round(expected + radius)
        empty = np.where(density[start:end] == 0)[0] + start
        groups = np.split(empty, np.where(np.diff(empty) > 1)[0] + 1) if len(empty) else []
        groups = [g for g in groups if len(g) >= 3]
        if groups:
            gap = min(groups, key=lambda g: abs(float(np.mean(g)) - expected) - .2 * len(g))
            edges.append(round(float(np.mean(gap))))
        else:
            edges.append(start + int(np.argmin(density[start:end])))
    edges.append(image.width)
    return image.crop((edges[column], rows[row][0], edges[column + 1], rows[row][1]))


def anchors(frame: Image.Image) -> tuple[float, int, int]:
    data = np.asarray(frame).astype(np.int16)
    r, g, b, a = [data[:, :, n] for n in range(4)]
    solid = a > 100
    ys, xs = np.where(solid)
    if not len(xs):
        raise ValueError("Empty frame")
    top, bottom = int(ys.min()), int(ys.max())
    # Feet are dark blue armor. Red/amber trails and silver shield rims must
    # never drag the foot anchor or make a slash define the body width.
    navy = solid & (b > r + 5) & (b > g) & (r < 170)
    near_floor = navy.copy()
    near_floor[:top + int((bottom - top) * .78)] = False
    fy, fx = np.where(near_floor)
    if not len(fx):
        raise ValueError("Cannot locate armored boots")
    foot_y = int(fy.max()) + 1
    low_boots = near_floor & (np.indices(near_floor.shape)[0] >= foot_y - max(6, int((bottom - top) * .07)))
    _by, bx = np.where(low_boots)
    # Boot midpoint is stable even when a shield or barrel extends to one side.
    center_x = (float(np.percentile(bx, 5)) + float(np.percentile(bx, 95))) * .5
    return center_x, foot_y, foot_y - top


def align(frame: Image.Image, scale: float) -> tuple[Image.Image, dict]:
    center, foot, height = anchors(frame)
    # Nearest-neighbor is essential at the game's small display size.
    size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
    resized = frame.resize(size, Image.Resampling.NEAREST)
    rgba = np.array(resized)
    rgba[rgba[:, :, 3] < 96] = 0
    resized = Image.fromarray(rgba)
    offset = (ANCHOR[0] - round(center * scale), ANCHOR[1] - round(foot * scale))
    bounds = resized.getchannel("A").getbbox()
    placed = (bounds[0] + offset[0], bounds[1] + offset[1], bounds[2] + offset[0], bounds[3] + offset[1])
    if min(placed) < 1 or placed[2] >= CELL or placed[3] >= CELL:
        raise ValueError(f"Frame would clip: {placed}")
    cell = Image.new("RGBA", (CELL, CELL))
    cell.alpha_composite(resized, offset)
    return cell, {"source_anchor": [round(center, 2), foot], "source_body_height": height,
                  "scale": round(scale, 6), "offset": list(offset), "alpha_bounds": list(placed)}


def run() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    manifest = {"cell_size": CELL, "foot_anchor": ANCHOR, "animations": ANIMATIONS, "roles": {}}
    all_frames: dict[str, list[list[Image.Image]]] = {}
    for role, (source, body_height) in ROLES.items():
        original = Image.open(source).convert("RGBA")
        supplement_path = SOURCE / f"animation_supplements_v1/{role}.png"
        supplement = Image.open(supplement_path).convert("RGBA")
        for name, im in [("original", original), ("supplement", supplement)]:
            if np.asarray(im)[:, :, 3].min() != 0:
                raise ValueError(f"{role} {name} lacks genuine transparency")
        original_rows = row_ranges(original, 4)
        supplement_rows = row_ranges(supplement, 5)
        base_heights = [anchors(cut(original, original_rows, 0, i, 8))[2] for i in range(8)]
        sup_heights = [anchors(cut(supplement, supplement_rows, 0, i, 6))[2] for i in range(6)]
        base_scale = body_height / float(np.median(base_heights))
        sup_scale = body_height / float(np.median(sup_heights))
        atlas = Image.new("RGBA", (CELL * 8, CELL * 8))
        role_data = {"sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in [source, supplement_path]}, "frames": {}}
        animations = []
        for row, animation in enumerate(ANIMATIONS):
            if row < 3:
                cells = [cut(original, original_rows, row, i, 8) for i in range(8)]
                scale = base_scale
            else:
                source_row = {3: 0, 4: 1, 5: 3, 6: 2, 7: 4}[row]
                cells = [cut(supplement, supplement_rows, source_row, i, 6) for i in range(6)]
                scale = sup_scale
            frames = []
            role_data["frames"][animation] = []
            for i, raw in enumerate(cells):
                try:
                    aligned, data = align(raw, scale)
                except ValueError as exc:
                    raise ValueError(f"{role} {animation} frame {i + 1}: {exc}") from exc
                atlas.alpha_composite(aligned, (i * CELL, row * CELL))
                role_data["frames"][animation].append(data)
                frames.append(aligned)
            animations.append(frames)
        all_frames[role] = animations
        atlas.save(OUTPUT / f"{role}.png", optimize=True)
        manifest["roles"][role] = role_data
        board = Image.new("RGB", (CELL * 8, CELL * 8), "#26313a")
        draw = ImageDraw.Draw(board)
        for row, frames in enumerate(animations):
            for i, cell in enumerate(frames):
                x, y = i * CELL, row * CELL
                board.paste(cell, (x, y), cell)
                draw.line((x, y + ANCHOR[1], x + CELL - 1, y + ANCHOR[1]), fill="#45605c")
                draw.text((x + 3, y + 3), f"{ANIMATIONS[row]} {i + 1}", fill="white")
        board.save(REVIEW / f"{role}_aligned.png")
        for row, frames in enumerate(animations):
            previews = []
            for frame in frames:
                bg = Image.new("RGBA", frame.size, "#26313a")
                bg.alpha_composite(frame)
                previews.append(bg.convert("RGB").resize((256, 256), Image.Resampling.NEAREST))
            previews[0].save(REVIEW / f"{role}_{ANIMATIONS[row]}.gif", save_all=True,
                             append_images=previews[1:], loop=0, duration=110 if row < 4 else 100,
                             disposal=2)
        print(role, "base", round(base_scale, 3), "supplement", round(sup_scale, 3), "frames", sum(map(len, animations)))
    (REVIEW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    run()
