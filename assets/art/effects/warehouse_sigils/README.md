# Warehouse complete sigils

Four transparent 512×256 PNGs extracted from the existing colored warehouse sigils and completed by exact reflection, as requested by the user. Their original floor-plane perspective is already baked into the images.

- parry_complete.png: cyan; bottom half reflected vertically.
- trial_complete.png: green; bottom half reflected vertically.
- boss_complete.png: purple; bottom half reflected vertically.
- deploy_complete.png: amber; left half reflected horizontally.

Source halves, raw renderer captures and a four-image preview: `art_sources/ai_drafts/warehouse_sigils_extracted_v1/`. Rebuild with `tools/extract_warehouse_sigils.gd`, then `tools/complete_warehouse_sigils.py` (Pillow). These assets reuse project-authored Godot geometry, with no new generated design.

The scene uses complete Sprite2D textures, positioned under real wall and doorway artwork. There is no semicircle crop or Polygon2D half-mask. The wall art is drawn above the sigils on its own layer. Breathing and proximity brightness are handled by `warehouse_door_sigil.gd`.
