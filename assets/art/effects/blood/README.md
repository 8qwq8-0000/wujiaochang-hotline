# Static floor blood

`floor_stain_v1.png` is an unchanged copy of the user-approved image_gen draft in `art_sources/ai_drafts/blood_stain_v1/`.

`scripts/presentation/floor_blood_decals.gd` scatters a few decals on available floor space in ordinary combat rooms. Placement uses a separate deterministic RNG per run/floor/room, avoids wall geometry and interactables, and adds no collision, navigation changes, animation or per-frame processing. Instances vary in scale, small rotation, horizontal reflection and opacity.
