# Rooftop server chapel room — generation record

- Date: 2026-10-18
- Tool: Codex built-in image generation (`image_gen`)
- Use: rooftop BOSS room production candidate
- Input reference: user-provided gameplay screenshot, used only for pixel density, dark-gold/teal palette and solemn mood
- Superseded source draft: `rooftop_server_chapel_source.png`
- Earlier selected source: `rooftop_server_chapel_source_v2.png`
- Rejected pixel-cleanup source: `rooftop_server_chapel_source_v3.png` — line geometry drifted during the pixel-style pass
- Selected source: `rooftop_server_chapel_source_v4.png` — exact user-provided replacement
- Runtime export: `assets/art/environment/boss/rooftop_server_chapel_base_v4.png`
- Runtime export processing: high-quality bicubic resize from 1672×941 to 960×540; no generative redraw, palette reduction, sharpening or structural edit; saved as RGBA PNG

## Prompt

Create a clean, directly usable pixel-art BOSS room that fuses a server data center with the architectural language of a solemn Christian cathedral. Use a slight three-quarter top-down viewpoint for a four-direction action game. Gold is the dominant color. Tall server racks form left and right aisles; keep a wide uncluttered central nave. Build a raised server altar at the upper center with a large empty niche for a separately layered BOSS statue, with restrained cross-shaped shutter windows behind it. Include a bottom-center maintenance elevator, subtle side maintenance alcoves, hidden cables, and thin gold floor rails. Use crisp hard-edged pixel art, matte aged gold, dark teal-black metal and restrained teal status lights.

Do not include a statue, people, enemies, floating cannons, UI, text, watermark, loose cables, candles, pews, rubble, excessive ornament, realistic religious paintings, a standalone crucifix, photorealism, blur, excessive neon or clutter.

## Revision prompt

Preserve the empty central boss niche, altar base, open combat floor, bottom maintenance elevator, palette and pixel treatment. Remove the mirrored side arches and any three-portal stage composition. Replace them with deep linear server aisles, ventilation banks and low rectangular maintenance alcoves. Keep only one restrained cross-shaped shutter-light arrangement on the central sacred axis. Do not add objects or characters.

## Pixel-cleanup prompt

Preserve the exact framing, camera angle, room geometry, altar, empty niche, shutter cross, rack positions, side aisles, maintenance alcoves, central floor boundaries, entrance, rails, perspective and collision alignment. Remove roughly 70–80 percent of random floor speckles, tiny scratches and isolated bright pixels. Simplify server surface noise while keeping orderly rack doors, ventilation grilles and panel seams. Remove most baked-in indicator lights and leave dark indicator slots for runtime animation. Use chunkier deliberate pixel clusters, hard edges, no antialiasing and approximately the existing 48-color metal depth. Add no objects, text or lights.

## Review

- Technical: pass — 960×540 RGBA PNG, snake_case path, no text or watermark.
- Visual: v4 restores the user-selected straight architectural linework and symmetrical server-room geometry. The v3 pixel-cleanup export is retained only as an unused draft.
- Runtime lighting: not baked into the export; phase darkness, gold awakening light, server pulses and echo fluctuation are authored in Godot.
- Final team/public-build approval: pending playtest review.
