# Player placeholder sprites

The files in this directory are unlicensed temporary development placeholders supplied locally by the team.

- They may be committed only while the repository remains private.
- They must not be included in a public build or public repository.
- Replace them with team-authored or properly licensed player art before release.

## Gemini motion v1

`gemini_motion_v1/` contains the runtime-ready derivatives of the supplied Gemini sequence:

- `player_walk_down.png`: six front-facing movement frames;
- `player_walk_up.png`: six back-facing movement frames;
- `player_walk_left.png`: six left-facing movement frames plus front/back idle references;
- `player_idle_side.png`: six left-facing idle frames.

Each atlas cell is 128×256. The import helper removes the border-connected white canvas and large high-purity enclosed matte regions such as the front-facing arm/waist gaps. It reconstructs semi-transparent contour colors from the original white matte to prevent pale fringes, keeps the authored pixels at their original resolution, and aligns the used cells to a shared foot baseline. Godot displays the sheets at 0.25 scale with nearest-neighbor filtering.

The pack has no authored right-facing sequence. `walk_right` and `idle_right` deliberately reuse their left-facing counterparts and are mirrored by `PlayerVisualController` at runtime. Renamed source sheets and individual source frames are preserved under `art_sources/ai_drafts/player_protagonist/gemini_motion_v1/`.
