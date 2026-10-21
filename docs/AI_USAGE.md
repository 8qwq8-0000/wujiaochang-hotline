# AI 辅助开发记录

| 日期 | 负责人 | 问题/提示词摘要 | 修改文件 | 审查及验证 | 提交编号/证据 |
|---|---|---|---|---|---|
| 2026-10-12 | 待团队认领 | 读取课程材料，按现有方案配置三人项目 | project.godot、主检查场景、导出预设、.NET 工程、协作文件、tools/ | 编译、启动和 Windows 导出通过；GUI 中文、W/右键输入、1000×800 黑边实测通过；详见 docs/team/SETUP_REPORT.md；合并前须人工复核 | chore/team-environment-setup；尚未提交 |
| 2026-10-13 | yuyu-yuuuu | 实现 R 键重开当前战斗，死亡后可用 | scripts/bootstrap_main.gd、scripts/gameplay/player_controller.gd、project.godot、tests/integration/restart_room_check.gd、tests/README.md | 战斗中/死亡后/清场后连续三次重开通过；10 项原有规则测试通过；尚需人工试玩 | feature/restart-room，尚未提交；/tmp/wujiaochang-restart-test.log |
| 2026-10-19 | 本任务维护者（待团队认领） | 按用户反馈完成双区域装备循环、主菜单、互通房型和开阔车间；炸药桶优先布置在敌人密集处并做种子随机 | scripts/gameplay/rooms/、scripts/gameplay/inventory/、scripts/gameplay/mobility/、scripts/ui/、resources/rooms/、对应场景和测试 | 两区 40、房型 128、炸药桶 170、门窗 48 项及连续三轮流程通过；尚需另一成员实际运行审核 | codex/status-electric；4f6eda6、86e4c6e；docs/technical/开阔车间与炸药桶布置.md |
| 2026-10-19 | 本任务维护者（待团队认领） | 通过内置 imagegen 将用户确认的开阔工业车间效果图转换为独立地板、墙帽、机器、箱体、控制台和两类机器人素材；沿用共享门、终端、炸药箱和电梯素材 | assets/art/environment/workshop/、assets/art/environment/refined/、scripts/presentation/workshop_art.gd、scripts/presentation/refined_environment_art.gd、相关场景 | 已提交干净快照导入、48 项单元、33 项新美术和 19 项共享美术检查通过；图形模式实机截图复核；没有验证 .NET/Windows 导出 | ab43f03、f745437；docs/art/装卸车间美术接入.md（含来源与提示词摘要） |

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

## 2026-10-19 — PR #9 follow-up integration

- User requested old-baton retirement, directional standing aim, native muzzle flashes, wrist-style rail-cannon preview, persistent consumed-insurance tint, new-save difficulty selection, and reuse of PR #8 environment art in member C's test room.
- Preserved PR #9 combat rebalance and three difficulty levels while applying these fixes in an isolated worktree. Rail cannon remains preview-only. Generated source and prompt: art_sources/ai_drafts/weapons/arm_lock_rail_cannon_v1/.
- Unit tests: 62/62 after incorporating b147f38. Targeted checks and known limitations: docs/technical/腕锁武器与盾反训练实施说明.md. Member C attribution and actual asset wiring: docs/technical/PR9成员C提交核查.md.
- Known failures remain: week1 room drop-count assertions (F6 and Main); b147f38 addresses post-door enemy pathing and is included. Some test exits still report ObjectDB/resource-use warnings; .NET/Windows export not checked.

- Final user instruction: do not push parry training yet. Excluded its sandbox controls, enemy behavior, and guard_training_check from this commit; original desktop working copy retains them.

## 2026-10-20 — Five-seal whale Boss and storm phase

- User approved five independent halo hits, simultaneous cross lasers, five mandatory reinforcements shielding the core, whale-song waves, rain/lightning, and overhead segmented health. Implemented locally without committing or pushing; preserved the pre-existing project.godot window-mode edit.
- Added shared per-activation damage identity for pellets/reactions and a Boss-only health gate. Added reachable physical core target, pause-safe hazard timing, guarded phase transitions, and a full-arena camera view. Existing Boss/art assets are reused; thunder is deterministically synthesized by tools/audio/build_boss_thunder.py, without external recordings.
- Implementation, tuning and validation scope: docs/technical/楼顶Boss战斗实施说明.md. Checks cover real projectiles and scattergun, phase gates, wave/strike geometry, pause/death cancellation, isolated saves and actual restart input. Non-headless runtime screenshots checked; existing ObjectDB/resource-use warnings remain. No ordinary-floor Boss scheduling, reward changes, or .NET/Windows export claim.

- Follow-up UI correction: overhead health is one continuous bar scaled to five halo hits (100/80/60/40/20/0 percent); the core is text-only status, not a sixth health slot. Removed the 6-point total from the arena HUD.

## 2026-10-20 — Final Boss simplification and linked guard damage

- Later user instructions supersede the earlier storm/core design: five opening guards each remove 20% halo; preserve the camera push, glow and awakening; phase two has six Boss health and three supports, each with three health, fighting simultaneously.
- Boss is immune to direct damage while supports remain. Their nine health points proportionally consume half of Boss health; clearing them leaves exactly 3/6 health for the final direct fight. Kept original oracle strike and simultaneous horizontal/vertical lasers, continuous overhead bar and pause/restart fixes.
- Removed the uncommitted storm controller, generated thunder assets/tool and per-activation weapon identity changes from the discarded design. Final rules and test scope: docs/technical/楼顶Boss战斗实施说明.md. No commits or pushes; original project.godot window-mode change preserved.

- Final validation: rooftop_boss_check 73/73, boss_patterns_check 10/10, boss_shortcut_check 24/24, unit checks 62/62. Non-headless screenshots confirm the awakening camera push, linked shield damage and final 3/6 health display. Existing exit-time ObjectDB/resource-use warnings remain.

## 2026-10-20 — Opening wave reduced independently

- User explicitly limited this follow-up to phase one: three opening guards, one health each, no opening-guard/halo/Boss health linkage. The independent count reaches zero before the retained statue camera push and awakening animation. Hide the statue health bar until phase two.
- Phase two is unchanged: six Boss health, three three-health supports, Boss directly immune while supports survive, their health losses leave exactly 3/6 Boss health for the remaining fight. No commits or pushes.

- Opening-only follow-up validation: rooftop Boss flow 66/66, isolated shortcut/restart 24/24, unit checks 62/62; non-headless captures confirm exactly three opening guards, no opening statue-health display and the retained zoom toward the statue. Existing exit-time resource warnings remain.

## 2026-10-20 — Arena guard awareness and teammate camera restoration

- User requested maximum awareness for all Boss guards and the teammate-provided camera. Restored _configure_arena_camera, _push_camera_to_altar and _restore_player_camera from original Boss commit 8de1acd, removing the added zoom logic.
- Boss-only cloned enemy profiles opt into full-room visual detection, 360-degree FOV and maximum awareness/hearing/ally-alert/memory parameters. The ordinary viewport cap and shared profiles remain unchanged; wall occlusion and room isolation remain active.

## 2026-10-20 — Point-blank gunfire fix

- User added the point-blank shooting bug to the camera/awareness request. Reproduced misses when a rendered barrel extends through an enemy before projectile creation. Muzzle obstruction query now includes actor hurtboxes, excludes the shooter's own hurtbox and skips non-actor areas, while keeping walls as first obstructions.
- Added real firing checks for pistol/scattergun and the preview-only rail-cannon view across eight directions, plus self-ignore and wall blocking. The ordinary alert regression fixture now explicitly has enough HP to survive its test hit and explicitly equips a quiet baton; prior assumptions about runtime one-hit enemies and starter equipment caused that test to fail/hang independently of Boss overrides.

- Camera/awareness and shooting validation: Boss flow/awareness 77/77, point-blank shooting 73/73, weapon wrist alignment 818/818, unit checks 62/62; ordinary alert and shooting-input regressions report zero failures. Three restored camera functions match teammate commit 8de1acd verbatim. Non-headless original-camera capture checked. Exit-time resource-use warnings remain.

## 2026-10-20 — Slightly wider phase-two view

- User requested a slightly wider phase-two view to see the overhead bar more easily. Keep phase one and the teammate statue cinematic at scale 1; blend to camera zoom 0.8 over the existing 0.45-second return to player. Visible width/height increase by 25%; does not force a full-arena view or guarantee the statue remains on screen at the far bottom.

- Latest presentation adjustment: moved the phase-two Boss health bar and its status caption from above the head to immediately below the statue pedestal; health and combat rules are unchanged.

## 2026-10-20 — Rail cannon enters ordinary loot

- User requested making the preview cannon obtainable through normal drops. Added runtime rail_cannon weapon data, component catalog/icon and the ordinary floor drop pool; editor-authored pickups can also select it. Existing quality, affixes, equipment and serialization rules apply.
- User clarified that the cannon must fire a long, wide area laser. Replaced the temporary projectile implementation with a dedicated BEAM attack: 1000 length, 48 width, 3 damage per target once per shot, 1.10-second cooldown and 35 heat. A full-width wall sweep clips both the damage rectangle and world-space beam to the same endpoint. The beam penetrates actors, ignores its source, uses the normal area damage pipeline and fades after 0.32 seconds. The weapon-mounted preview flash is suppressed for BEAM attacks.
- Validation: beam area/length/width/multiple targets/single-hit/wall/cleanup checks 22/22, ordinary loot/pickup/equip/fire/serialization checks 11/11, actual runtime weapons across eight point-blank directions 73/73, weapon art 24/24 and unit checks 62/62. Non-headless beam capture visually checked. Existing ObjectDB/resource-use exit warnings remain.

- User requested a slightly narrower beam: reduced visible and damage width from 64 to 48; length remains 1000.

- Fixed beam hits filtering out environmental receive_hit areas: barrels now break and explode through the existing damage interface. Actor deduplication, source exclusion and room boundaries remain enforced. Beam regression 26/26 covers actual barrel explosion, wall protection and out-of-width exclusion.

## 2026-10-20 — Restore dragon synthesist wiring

- User reported the warehouse still showed Lao Zhou instead of the previously authored dragon character. Found the missing warehouse RefinedArt/gpt adapter and GPT workshop labels in preserved stash 0f45c20. Restored only those warehouse scene and panel changes; kept the stash and unrelated changes intact. Existing gpt_synthesist artwork and adapter are reused.
- Synthesis NPC integration 40/40 and non-headless warehouse capture confirm the dragon character and GPT name are visible with working E interaction and upgrades. Shared refined-art regression reports 18/19: the hinged-door _pose expectation fails in untouched door-adapter code; this change does not alter that adapter. Existing exit resource warnings remain.

## 2026-10-20 — Publish remaining integration fixes

- User explicitly authorized pushing all remaining useful changes and canceled shield-parry training. No training toggle, stationary trainer behavior or training test is included. Retained historical stashes as backups without applying obsolete scenes, deleted tests or superseded difficulty code.
- Restored the old editor/Git formatting and ignore rules, Windows environment-check script and current GPT art implementation note. Updated the existing wrist-weapon note instead of restoring the obsolete duplicate document. The local maximize-window preference remains outside the commit as before. Windows/PowerShell and .NET execution are not validated on this macOS session.

- Pre-push validation: laser beam 26/26, loot/equipment 11/11, synthesis NPC 40/40, point-blank shooting 73/73 and unit checks 62/62 passed. git diff --check passed. Known shared hinged-door art regression and existing exit resource warnings remain as recorded above.

## 2026-10-21 — Purple arcade feedback for paired perfect parries

- User approved the generated purple pixel PERFECT! wordmark and clarified that it triggers after two consecutive perfect parries. Preserved the prompt and source bitmap, imported the transparent runtime copy, and subscribed presentation to resolved player damage events.
- Pair window is 1.2 seconds; ordinary blocks, damage, timeout and scene changes break the chain. The popup lasts 0.7 seconds with a scale pop, upward movement and fade; it inherits pause behavior and does not change combat resolution.

## 2026-10-21 — Adjustable warehouse parry training room

- User requested a warehouse passage into a ring of three ranged robots, approved sequential single shots every 0.9 seconds, and asked for sliders including enemy HP. Added the training passage, isolated scene and temporary run; robots start at three HP and dead targets are skipped.
- Interval (0.4–2 seconds), projectile speed (120–600 px/s) and robot HP (1–10) are adjustable. Changes clear old bullets; HP changes rebuild targets. R resets player, targets and counters while retaining settings. Return and training death preserve the warehouse profile.
- Validation: new training integration 46/46 with actual reflected projectiles hitting all three shooters, live damage-resolution feedback, real R input, settings persistence, pause and save isolation. Existing unit 62/62, warehouse 55/55, Boss shortcut 24/24 and player parry art 42/42 passed. Non-headless screenshot inspected; existing ObjectDB/resource-use exit warnings remain.

## 2026-10-21 — Keep PERFECT! active throughout a successful streak

- User clarified that every perfect parry starting with the second consecutive success must show the popup. Removed the post-popup combo reset; subsequent successful parries restart the popup until damage, normal block, timeout or scene change breaks the streak.
- Training integration expanded to 50 checks, including the third/fourth consecutive popup and rebuilding the streak after a normal block.
