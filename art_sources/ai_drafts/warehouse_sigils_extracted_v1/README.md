# Existing sigil extraction and symmetrical completion

2026-10-22. User explicitly requested extraction of the existing four half-sigils, reflection to complete their missing halves, and placement under the room walls. This is deterministic image processing, not a redesigned sigil.

`source_geometry.gd` snapshots the existing shape renderer used for extraction. `*_half_raw.png` are isolated transparent-viewport captures at 6× scale. `*_half.png` have the compatibility renderer's black clip-group matte removed using the known monochrome light tint. The lower half is reflected across y=128 for parry/trial/boss; the left half is reflected across x=256 for deploy. The mirrored full PNGs live in `assets/art/effects/warehouse_sigils/` and are asserted pixel-symmetric by the completion tool. `four_complete_sigils.png` is a preview on a dark background, not a runtime asset.
