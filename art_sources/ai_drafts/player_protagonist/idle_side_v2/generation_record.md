# Right-facing idle candidate v1

## Locked character

- Right-facing armored mechanical protagonist.
- Head size, shoulder width, torso length, limb thickness, pixel density, and apparent scale follow the active `player_walk_right.png` sequence.
- Dark charcoal and cool-gray armor, cyan visor/core light, and sparse worn magenta accents.
- Anatomical-left arm uses a short integrated forearm guard; no separate handheld shield.
- Six 128×256 frames on a transparent background, 4 FPS, with a fixed foot baseline.

## Motion

1. Combat-ready base pose.
2. Subtle weight settle; free hand begins moving toward the chest.
3. Free hand approaches the core.
4. Restrained core charge.
5. Small cyan pulse confined to the core and wrist seam.
6. Relaxed return close to the first pose.

## Generation and processing

- Built-in image generation/editing calls: 5.
- The user selected the first generated sheet, `raw/idle_sheet_attempt_01.png`, as the visual and motion basis.
- The fifth call edited that first sheet only to reduce the helmet, lengthen the torso proportion, and turn the separate shield silhouette into a short integrated forearm guard. The selected source is `raw/idle_sheet_round1_proportion_fix.png`.
- Later independently generated idle designs are retained as alternates but are not the selected candidate.
- `tools/build_idle_side_candidate.py` split the non-divisible generated canvas, removed isolated edge noise, normalized each visible sprite to 164 px height, locked the foot baseline at y=243 and the helmet magenta-disc anchor, and mapped visible RGB values to a 96-color palette sampled from the active right-walk sheet.
- `frameronin-codex/scripts/sprite_tools.py` produced the audit, preview, sprite sheet, PNG frames, GIF, and animation metadata.

## Validation

- `round1_base_v1/candidate_audit.json`: 6/6 frames readable; no errors or warnings.
- Every frame: 128×256 canvas, visible y-range 80–243, footY 243, transparent background.
- Visible height: 164 px, matching the active right-walk reference.
- Review board: `round1_base_v1/idle_vs_walk_comparison.png`.
- Selected export: `round1_base_v1/export/`.
- The selected `round1_base_v1/export/sprite-sheet.png` was promoted to the
  runtime `player_idle_side.png` after user approval.
