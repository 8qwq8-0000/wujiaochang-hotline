# AI usage log

## 2026-10-18 — Rooftop server chapel BOSS room

- Tool: Codex built-in image generation (`image_gen`).
- Purpose: produce a pixel-art environment candidate combining a server room with restrained cathedral architecture.
- Reference: user-provided gameplay screenshot, used only for pixel density, dark-gold/teal palette and solemn atmosphere.
- Generated/modified files: `art_sources/ai_drafts/rooftop_boss_room/rooftop_server_chapel_source.png`, `assets/art/environment/boss/rooftop_server_chapel_base.png`, BOSS arena scene and lighting implementation.
- Human decisions preserved: 960×540 world space, open central nave, empty statue niche, hidden cabling, matte aged gold, phase-one darkness, phase-two gold illumination, small telegraphs and separate future floating-cannon design.
- Validation: automated scene/unit checks plus visual inspection at native runtime size; final public-build acceptance remains a team review item.

### Pixel-cleanup revision

- Edited the selected room source with Codex built-in image generation while locking architecture and collision alignment.
- Removed most floor speckle and baked indicator noise, then exported through a 480×270 to 960×540 nearest-neighbor pipeline with exactly 48 colors.
- Moved server indicator behavior into a runtime 12 FPS pixel-light layer using phase-dependent cyan and amber states.

### User-selected background restoration

- Replaced the active v3 pixel-cleanup background after review because its architectural linework had drifted.
- Adopted the exact user-provided 1672×941 image as `rooftop_server_chapel_source_v4.png` and produced the 960×540 runtime export with deterministic high-quality resizing only; no AI redraw or palette reduction was applied.
- Retained the runtime server indicators, phase darkness and phase-two colored lighting as separate Godot layers; the indicator clock now updates at 12 FPS after playtest feedback requested double-speed blinking.
