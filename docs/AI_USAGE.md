# AI 辅助开发记录

| 日期 | 负责人 | 问题/提示词摘要 | 修改文件 | 审查及验证 | 提交编号/证据 |
|---|---|---|---|---|---|
| 2026-10-12 | 待团队认领 | 读取课程材料，按现有方案配置三人项目 | project.godot、主检查场景、导出预设、.NET 工程、协作文件、tools/ | 编译、启动和 Windows 导出通过；GUI 中文、W/右键输入、1000×800 黑边实测通过；详见 docs/team/SETUP_REPORT.md；合并前须人工复核 | chore/team-environment-setup；尚未提交 |
| 2026-10-13 | yuyu-yuuuu | 实现 R 键重开当前战斗，死亡后可用 | scripts/bootstrap_main.gd、scripts/gameplay/player_controller.gd、project.godot、tests/integration/restart_room_check.gd、tests/README.md | 战斗中/死亡后/清场后连续三次重开通过；10 项原有规则测试通过；尚需人工试玩 | feature/restart-room，尚未提交；/tmp/wujiaochang-restart-test.log |
| 2026-10-19 | 本任务维护者（待团队认领） | 按用户反馈完成双区域装备循环、主菜单、互通房型和开阔车间；炸药桶优先布置在敌人密集处并做种子随机 | scripts/gameplay/rooms/、scripts/gameplay/inventory/、scripts/gameplay/mobility/、scripts/ui/、resources/rooms/、对应场景和测试 | 两区 40、房型 128、炸药桶 170、门窗 48 项及连续三轮流程通过；尚需另一成员实际运行审核 | codex/status-electric；4f6eda6、86e4c6e；docs/technical/开阔车间与炸药桶布置.md |
| 2026-10-19 | 本任务维护者（待团队认领） | 通过内置 imagegen 将用户确认的开阔工业车间效果图转换为独立地板、墙帽、机器、箱体、控制台和两类机器人素材；沿用共享门、终端、炸药箱和电梯素材 | assets/art/environment/workshop/、assets/art/environment/refined/、scripts/presentation/workshop_art.gd、scripts/presentation/refined_environment_art.gd、相关场景 | 已提交干净快照导入、48 项单元、33 项新美术和 19 项共享美术检查通过；图形模式实机截图复核；没有验证 .NET/Windows 导出 | ab43f03、f745437；docs/art/装卸车间美术接入.md（含来源与提示词摘要） |
| 2026-10-20 | 本任务维护者（待团队认领） | 检索并整理《赛博朋克 2077》2.x 义体系统，提炼为本项目组件、词条、协议与构筑设计参考 | docs/research/赛博朋克2077义体系统设计参考.md、docs/AI_USAGE.md | 已核对官方 2.0、2.1 与 2.31 新闻记录，并以两份公开数据库交叉整理；未复制代码或媒体素材，候选效果尚未进入实现范围 | 本地文档，尚未提交 |
| 2026-10-20 | 本任务维护者（待团队认领） | 按 v1.5 文档完成固有突进迁移与智能火控、爆裂弹仓、战术协处理器、光学入侵器四种义体 | player/dash/cyberware、弹丸、敌人/Boss、背包/掉落/敲合/HUD、专项测试与实施说明 | 单元 62/62；固有突进 20/20；无敌 13/13；义体 23/23；Godot 无头编辑器完成资源扫描。运行结束仍有既有插件 user:// 与资源释放警告 | 本地实现，尚未提交 |
| 2026-10-20 | 本任务维护者（待团队认领） | 读取全项目设定并通过逐项盘问，将铁人叛乱后的机器人宗教、算力兼并暗线与三种商业人格饮料整合为 v2 共识 | docs/design/五角场热线_开发流程策划案.md、docs/design/portable-ai-personality-spec-v2.md、docs/design/personality-drinks-design-v2.md、docs/design/赛博朋克UI视觉基线.md；同时归档人格头像、饮料图标与台词表 | 已人工确认人格来源、四次授权、三级二选一天赋、软接管、隐藏关系、三级语义泄漏与无属性遗产记录；只更新设计与素材归档，现有三协议代码尚未迁移 | 本地文档，尚未提交 |

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

## 2026-10-20 — First approved new cyberware: kill heat sink

- The user approved an iterative one-at-a-time design and implementation loop. Added 击破散热器: a player-attributed enemy kill removes 30% of effective maximum weapon heat, can immediately leave overheat through the existing recovery threshold, and is limited to one trigger per 0.5 seconds. Environment and enemy-attributed defeats are excluded through the normal damage-resolution source.
- Added cyan return-link/flash feedback, a combat notice and heat-meter flash. The module participates in ordinary drops, run-local equipment, serialization and irreversible compound fusion. The previously approved compound cap is now enforced at four distinct modules; a fifth-module fusion is rejected.
- Validation: unit checks 63/63, cyberware integration 29/29, synthesis NPC 40/40 and enemy death-drop 23/23. The synthesis/death-drop fixtures were migrated from retired wheel materials and weapon-only quality assumptions to current armor/cyberware contracts. Existing ObjectDB/resource-use exit warnings remain.

## 2026-10-20 — Second approved new cyberware: heat threshold pulser

- The user rejected the proposed status inversion layer and approved 热阈震荡器 instead. Entering overheat now emits a 64-pixel, zero-damage pulse that staggers ordinary enemies for 0.8 seconds. Bosses are excluded, heat and overheat duration are unchanged, and an eight-second controller-owned cooldown survives unequip/re-equip attempts.
- Added two procedural orange-red pulse rings, a spatial shock cue reusing the existing guard-impact sound, a combat notice, ordinary drop/catalog/resource integration and compound-module presentation. Validation: unit checks 63/63, cyberware integration 34/34 and enemy death-drop 23/23. Existing headless user-directory, ObjectDB and resource-use exit warnings remain.

## 2026-10-21 — AI personality state-core migration

- Continued the approved persona-drink design by replacing the three-protocol state model with 深渊忍者／传奇宗师／摇滚奇侠 identities. Each persona now keeps its own level, three-tier talent build, hidden relationship stage and one-time level-three semantic leak while sharing the existing per-floor takeover charge.
- Added state format version 2 plus explicit migration for legacy `assault / defense / mobility` IDs and their talent choices. Player-facing code now exposes persona/drink terminology while retaining compatibility wrappers during the transition; low-pressure operator lines use the fused persona voices.
- Validation: unit checks 65/65, including persona persistence, switch preservation, one-time semantic leaks and legacy snapshot migration. `git diff --check` passed. The existing warehouse integration fixture currently fails in unrelated backpack/chest setup before reaching its persona-state assertions, so no warehouse logic was changed in this slice.

## 2026-10-21 — Persona rest and authorization flow

- Added the mandatory first-through-fourth-floor persona rest flow for persistent warehouse deployments. Each floor grants one physical-DRM drink authorization, blocks departure from the rest panel until it is consumed, refills the shared takeover charge once, and then allows free talent selection for the active persona.
- The full-screen terminal UI uses the three approved 64 px drink icons, distinct non-color silhouettes, persona names, combat summaries, current levels and next drink outcomes. Fresh runs no longer preinstall the transitional master persona; sandbox/non-persistent combat remains unaffected. Level-three semantic leaks are visible inside the rest panel as well as through the operator communication bus.
- Validation: unit checks 66/66 and dedicated cross-floor rest integration 19/19. A rendered 1280×720 preview was visually inspected for card, icon, text and talent-column fit. Existing headless user-directory, ObjectDB and resource-use exit warnings remain.

## 2026-10-21 — Persona combat runtime prototype

- Continued the user-approved three-persona design by adding a player-owned combat runtime rather than distributing persona conditionals across every weapon, projectile and enemy.
- Reused the existing global damage-resolution stream for hit, kill and guard sampling. Added only two narrow integration hooks: pre-resolution persona guard preparation and a forced weapon attack path for successful AI takeover shots.
- Implemented visible execution marks, attack-pattern analysis, stage feedback, cancellable soft takeovers, shared-charge emergency actions and compact HUD state. Relationship sampling, codex persistence, legacy-drink records and predictive trajectory rendering remain explicitly out of scope for this pass.
- Validation: fresh editor parse, unit suite, and `tests/integration/persona_combat_check.gd`; the headless environment still reports its pre-existing `user://`, Dialogic/save-system and exit-time resource warnings.

## 2026-10-21 — Hidden persona rapport and master prediction follow-up

- Added persisted, deliberately non-UI relationship progress to the existing v2 persona snapshot. Combat recognition events are persona-specific, while stage changes surface only through fused-voice wording; AI-performed master guards do not count as player validation.
- Added the Open Model battlefield cue for analyzed live enemies. It stays as a low-detail dashed trajectory and becomes stronger during enemy windup, avoiding an exact countdown or a second timing HUD.
- Validation: editor class scan, unit suite 66/66, and the persona combat integration covering persistent hidden progress, repeated-pattern analysis, prediction-source retention, three manual validations, proxy guard and successful emergency fire.

## 2026-10-21 — Permanent persona codex and legacy drinks

- Finished the approved run boundary: extraction and death harvest discovered personas and level-three semantic leaks into the permanent warehouse codex, then reset all persona levels, talents, rapport, semantic state and run metrics for the next deployment. Existing equipment recovery rules are unchanged.
- Continuing after the fourth cleared floor now loads the production rooftop Boss. Only a persistent run that defeats the Boss can atomically mint one stat-free legacy drink; extraction, death, repeated settlement and the warehouse Boss-test shortcut cannot mint one.
- Added the warehouse archive terminal for read-only persona discoveries, anomaly transcripts and legacy run records. Records include used persona levels, tier-three talents, marked-kill chain, manual perfect guards, rock feedback/attack rhythm, clear time and leaks.
- Updated the broad warehouse/extraction fixtures from the retired `wheel`/mobility assumptions to current armor plus mandatory persona rest. Their cross-scene run also exposed and fixed one stale Deep Ninja mark reference after room cleanup by validating the object before narrowing its type.
- Validation: unit suite 66/66; persona archive persistence 23/23; production floor-four-to-rooftop victory and archive display 14/14; warehouse 57/57; full extraction reports zero failures; persona combat reports zero failures. Editor parse and `git diff --check` pass. Headless exit-time ObjectDB/resource-use warnings remain.
## 2026-10-21 — Minimal combat HUD and holographic AI calls

- Rebuilt the combat HUD around three top-left health lights, a numberless segmented heat strip, and a collapsed persona portrait that expands into a two-line holographic call. Combat calls use a purpose-built priority queue instead of Dialogic: critical takeover/lethal messages interrupt, ordinary traffic keeps one merged pending entry, and the telephone connection cue plays only when opening from the collapsed state.
- Added a small top-right pause control, a 50%-opacity current-weapon view at bottom right, transient weapon-name feedback, HUD scaling at 100/125/150%, reduced-flash accessibility, and a recent-call page in pause. Removed runtime damage numbers, generic combat-notice presentation, persistent objective/enemy counters, and all Boss health/phase labels; the Boss keeps only its in-world halo segments.
- Elemental-reaction gameplay is disabled for the current player-facing pass while its implementation and headless regressions remain preserved. Validation covers health HUD, combat comms, minimal presentation, pause settings and the rooftop Boss. The headless environment continues to emit pre-existing `user://`, Dialogic/save-system and exit-time resource warnings.

## 2026-10-21 — Death-drop ownership and takeover landing recovery

- Fixed the all-drops-missing runtime failure without changing loot balance: the formal `FloorAssembler` now owns its enemy-defeat subscription instead of relying on the player inventory's optional listener. Existing 20% rolls, per-area final-kill guarantee and the complete weapon/cyberware/armor pool remain unchanged; existing enemy metadata still prevents duplicate pickups.
- Deep Ninja emergency takeover now cancels an active locked-direction dash, clears inherited velocity and samples collision-safe landing points with horizontal and vertical escape space. Authored room geometry was not changed because the complete room-layout/navigation suite passed 128/128.
- Validation: editor parse; unit suite 68/68; death-drop integration 24/24 with the player-owned listener deliberately removed; persona combat zero failures; room layouts 128/128; rail-cannon loot 11/11; room transition zero failures. Existing headless `user://`, Dialogic/save-system and exit-time resource warnings remain.

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

## 2026-10-21 — Grow PERFECT! up to its existing size

- User requested small-to-large animation with the existing size as the maximum. Changed popup scaling from an overshoot-and-settle pop to a 0.22-second eased growth from 15% to 100%, capped at the existing 156-pixel width. Retained the existing 0.7-second display and fade.

## 2026-10-21 — Forward fan formation and fixed training projectile speed

- User requested fan placement and explicitly clarified that bullet speed should be fixed with its slider removed. Three stationary robots now occupy the player's forward 120-degree arc; the floor guide uses the same fan geometry.
- Removed speed from sliders and reset payloads; every training projectile uses the fixed 260 px/s constant. Interval and robot HP remain adjustable. Updated the existing integration assertions, player instructions and runtime screenshot.
- Headless and rendered training checks both pass 50/50, including actual reflected hits on all three shooters, fixed projectile speed, removed speed control and R reset. Existing exit-time resource warnings remain.

## 2026-10-21 — Four authored directions for the player parry shield

- User reported the parry animation only had one direction and requested all four. Kept the approved right-facing nine-frame atlas, generated independent up/down/left views with built-in imagegen and preserved their selected sources, exact prompts and import manifest. The importer aligns and packs transparent frames without painting or rotating source pixels.
- GuardArcVisual selects the authored atlas by aim, with residual rotation for diagonals. Upward drawing now uses body-level Z and sibling ordering rather than negative world Z, which could put the shield below the floor. Startup, perfect window, normal block, recovery, damage and reflection rules remain unchanged.
- Validation: four-direction art checks expanded to 78/78, including separate atlas selection, complete state sequences, depth, reflection, pause and engine callbacks; training 50/50 and unit 62/62 passed. Four non-headless screenshots inspected on a normal-Z background. Editor's first scan reported not-yet-imported textures; after import the final editor pass had no script or resource-load errors. Existing exit-time ObjectDB/resource-use warnings remain.

## 2026-10-21 — Confirm and publish four-direction parry preview

- User viewed the four-way Godot runtime recording and explicitly approved using this version in the existing PR. Added the approved recording to the repository and acceptance note, and embedded the animation in PR #12 for review. No runtime behavior changed in this follow-up; prior art 78/78, training 50/50 and unit 62/62 validation still describe the approved implementation.

## 2026-10-21 — Restore PR #12 additions after PR #13 integration

- The user requested direct integration into main after confirming that merged PR #13 included the older PR #11 head, rather than the current PR #12. Merged `codex/enemy-animation-art` into the latest main history, retaining persona/cyberware runtime, archive terminal, optical disruption, paused transitions, door fixes and Boss render ordering.
- Resolved overlapping scene, enemy, warehouse and guard-visual changes. Restored travelling directional shields, ranged cover cooperation, enemy friendly-fire immunity, the five-support Boss phase, cardinal parry art, warehouse parry training and repeat PERFECT feedback. Removed the stale opening-wave one-health override so the shield guard retains three health. Migrated the automatic-door integration fixture from retired wheel mobility to the current DashController.
- Validation: Godot 4.7.2 editor import without script errors; unit suite 68/68; shields/support 61/61; barrier 22/22; player parry 78/78; training 50/50; rooftop Boss 84/84; warehouse 58/58; persona archive 23/23; victory flow 14/14; automatic doors 19/19; room layouts 128/128; Boss shortcut 24/24; Boss patterns 10/10; point-blank shooting 73/73; enemy animations 419/419 and playback 348/348. Persona combat, persona rest, cyberware, enemy combat upgrade and enemy tactics report zero failures. Existing ObjectDB/resource-use shutdown warnings remain; no new visual acceptance or platform export was performed in this integration.

## 2026-10-21 — Minimal combat HUD and holographic AI calls

- Rebuilt the combat HUD around three top-left health lights, a numberless segmented heat strip, and a collapsed persona portrait that expands into a two-line holographic call. Combat calls use a purpose-built priority queue instead of Dialogic: critical takeover/lethal messages interrupt, ordinary traffic keeps one merged pending entry, and the telephone connection cue plays only when opening from the collapsed state.
- Added a small top-right pause control, a 50%-opacity current-weapon view at bottom right, transient weapon-name feedback, HUD scaling at 100/125/150%, reduced-flash accessibility, and a recent-call page in pause. Removed runtime damage numbers, generic combat-notice presentation, persistent objective/enemy counters, and all Boss health/phase labels; the Boss keeps only its in-world halo segments.
- Elemental-reaction gameplay is disabled for the current player-facing pass while its implementation and headless regressions remain preserved. Validation covers health HUD, combat comms, minimal presentation, pause settings and the rooftop Boss. The headless environment continues to emit pre-existing `user://`, Dialogic/save-system and exit-time resource warnings.

## 2026-10-21 — Death-drop ownership and takeover landing recovery

- Fixed the all-drops-missing runtime failure without changing loot balance: the formal `FloorAssembler` now owns its enemy-defeat subscription instead of relying on the player inventory's optional listener. Existing 20% rolls, per-area final-kill guarantee and the complete weapon/cyberware/armor pool remain unchanged; existing enemy metadata still prevents duplicate pickups.
- Deep Ninja emergency takeover now cancels an active locked-direction dash, clears inherited velocity and samples collision-safe landing points with horizontal and vertical escape space. Authored room geometry was not changed because the complete room-layout/navigation suite passed 128/128.
- Validation: editor parse; unit suite 68/68; death-drop integration 24/24 with the player-owned listener deliberately removed; persona combat zero failures; room layouts 128/128; rail-cannon loot 11/11; room transition zero failures. Existing headless `user://`, Dialogic/save-system and exit-time resource warnings remain.

## 2026-10-21 — Modular initial warehouse art

- User approved an underground maintenance safehouse, then explicitly requested separately generated components assembled into a whole map. Built-in image_gen generated ten individual assets: floor, wall, equipment chest, workbench, archive terminal, deployment elevator, training door, parts rack, crates and wall lamp. Original PNGs live in `assets/art/environment/warehouse/`; complete prompts live in `art_sources/ai_drafts/warehouse_safehouse_v1/{components_prompts,supplemental_prompts}.json`. The earlier whole-room concept is reference only.
- Added a presentation adapter with explicit atlas bounds to ignore faint transparent-margin speckles, nearest-neighbor sampling, repeated floor/wall assembly, independent device sprites, engine-rendered labels and three restrained unshadowed lights. Reused the existing dragon mechanic. Added separate scene colliders for the workbench, rack and crate footprints, keeping existing service positions and data behavior.
- Validation: Godot 4.7.2 editor import without script/load errors; warehouse 58/58; synthesis 40/40; parry training 50/50. Static physics-space connectivity probe reached all seven interaction areas from spawn with an 8-pixel-radius query. Non-headless runtime screenshot inspected at `docs/art/validation/warehouse_safehouse_v1/warehouse.png`. All preview/probe runs used isolated save paths. Existing ObjectDB/resource-use exit warnings remain; Windows export was not tested.


## 2026-10-21 — Warehouse wall volume revision

四向墙和四个转角由内置 image_gen 独立生成，原始透明 PNG 保存于 `assets/art/environment/warehouse/*_v2.png`。六件素材从上一聊天找回，两件前侧转角本次补齐。提示词保存在 `art_sources/ai_drafts/warehouse_safehouse_v1/walls_v2_prompts.json` 与 `foreground_corner_prompts.json`。通过 AtlasTexture 选择墙体与弯折接头区域，独立朝向拼装；前墙使用独立遮挡层。Godot 实机截图与仓库 58/58、合成师 40/40、盾反训练 50/50 回归通过；退出仍有原有资源释放诊断。

## 2026-10-21 — Upward flying barrier orientation

- User reported a reversed barrier in a runtime screenshot. Inspected the source atlas and corrected upward flight artwork with a vertical sprite flip; movement and collision transforms remain unchanged. No new generated art. Preserved existing local SpriteFrames and other workspace edits.
- Validation: four cardinal runtime screenshots inspected; shield/support 69/69 and barrier physics 22/22 passed. Added orientation and global visual rotation assertions. Existing support-check shutdown ObjectDB/resource diagnostics remain.


## 2026-10-21 — Warehouse volumetric props and editor placement

用户追加要求为门、储物箱、工作台、档案终端、零件架和货箱统一增加 2.5D 体积感。内置 image_gen 按批准概念图独立生成七件透明组件，保留为 assets/art/environment/warehouse/*_v2.png；完整提示词保存为 art_sources/ai_drafts/warehouse_safehouse_v1/props_v2_prompts.json。按用户要求贴墙布置；随后将图像与碰撞转换为可在 Godot 编辑器拖动保存的场景节点。新增保存/重载验证 59/59，原交互检查 148/148；既有退出资源释放诊断仍在。

## 2026-10-21 — Combat architecture and three bomb boxes

- User approved 2.5D battle scenery and requested three bomb boxes in each room during implementation. Reused separately authored warehouse cardinal walls/corners and existing workshop ground/props. Built-in image_gen produced two independent door orientations; originals live in `assets/art/environment/combat_architecture/`, exact prompts in `art_sources/ai_drafts/combat_architecture_v1/prompts.json`.
- Added ground-contact Y sorting for individual walls/props and actors, separate horizontal/side door artwork, broken jambs and matching fragments, textured passages, and a background layer fix allowing floor art to appear. Physics wall/door dimensions and navigation remain authored. All seven layout variants receive scenery.
- Three bomb boxes per CombatRoom (six per formal two-area floor), with seeded placement using actual expanded room bounds, clearances from doors/entry/enemies/power and earlier boxes. Preserved existing explosion mechanics. Validation: scenery 132/132, bomb placement/explosions 458/458, layouts 128/128, dual area 41/41, doors 19/19, fuel 19/19; restart and shooting zero failures. Updated legacy test assumptions for current combat equipment switching and fixed-effect cyberware; explosion fixture now handles defeated/free enemies and checks all three boxes. Runtime room, doorway and occlusion screenshots inspected.

## 2026-10-21 — Charging station floor sigil and immunity

- User requested a floor sigil to invite buff use and made charging stations non-attackable/non-explosive. Added engine-drawn animated cyan ground rings, rotating segments/runes, pulsing illumination and ground-plane compression. Projection disappears after claim or area clear, and freezes with game pause. No new image generation for the animated effect.
- Charging station retains only interaction collision layer 32 and a no-op direct-hit interface; removed discharge implementation and attack instructions. Actual bullets pass through to enemies behind it. E buff selection, actual modifiers, area ownership and cleanup remain intact.
- Validation: power station 36/36, electric environment 23/23, trial entry 12/12 and two-area progression 41/41. Electric environment coverage now drives an independent scoped reaction event instead of attacking a station. Real projectile and melee immunity, paused sigil, claiming after attack and immediate sigil hiding are covered. Existing exit-time ObjectDB/resource-use warnings remain; Windows export not tested.

## 2026-10-21 — Match combat ground to warehouse

- User reported distracting ground shimmer while walking and explicitly requested the warehouse floor. Combat rooms now reference the same warehouse floor PNG, full-source 32-game-pixel tiling and tint, replacing the workshop quarter-atlas sampling. Connecting passages use the same shared tile drawing rather than a stretched floor image. No new generated assets or gameplay changes.

## 2026-10-21 — Seal observation windows and vary small obstacles

- User requested replacing every observation window with a wall, plus additional small obstacles of varied sizes. Converted the workshop's sole window rectangle to a solid cover segment, using existing cardinal wall art and collision layer 1 to stop projectiles and sight as well as movement. No new art generation.
- Each authored combat layout now receives three seeded physical crate obstacles with 18x18, 28x16 and 16x28 footprints before navigation baking. Placement avoids wall/cover clearance, doorways, entries/exits, enemy spawns and the charging station; existing bomb placement also avoids these new footprints. Reused the existing workshop crate art with ground-contact depth sorting.
- Validation: scenery 154/154 including actual world-layer ray blocking at the former window; layouts 128/128 (reachability and collision clearances), bomb boxes 458/458 and two-area flow 41/41 passed. Updated runtime overview inspected. Existing exit-time resource diagnostics remain.


## 2026-10-21 — Upper row alignment and east-wall elevator

Preserved the user-saved layout and adjusted only the upper row: visible bottom edges align within 0.3 game pixels; clear gaps are 44–45 game pixels. Moved the synthesist name clear of the title. Replaced the right-side front-facing elevator art with a separately generated left-facing east-wall sprite, `assets/art/environment/warehouse/elevator_east_v3.png`, keeping the Deploy service position. Built-in image_gen prompt: `art_sources/ai_drafts/warehouse_safehouse_v1/elevator_east_v3_prompt.json`. Updated the saved AtlasTexture, sprite display offset/scale and matching floor zone. Editor import and non-headless runtime capture passed without script/resource-load errors; existing exit resource diagnostics remain.

## 2026-10-21 — Larger denser obstacles and persistent door debris

- User requested larger and more numerous obstacles, then door breaking animation with fragments on the ground. Increased added obstacles from three to six per layout, using varied 32x32, 48x28, 28x44, 56x28, 36x40 and 44x32 footprints and a mix of existing crates, consoles and machinery. Expanded spacing from existing geometry/enemy spawns and sampled a denser candidate grid to preserve safe placement. No new generated assets.
- Door texture fragments now burst outward, rotate/shrink, fall and settle as dark floor debris instead of fading/deleting after 0.12 seconds. Applied world/local direction conversion for horizontal door nodes. Landed debris renders below actors at Z -1, has no collider, and is freed with its room. Sparks still fade; gameplay breach timing and collision removal remain immediate.
- Validation: scenery 154/154, bomb positions/explosions 458/458, door/break debris 21/21, dual area 41/41, layout paths 128/128. Real engine screenshots inspected before/after breaking, including persistent debris. Existing shutdown resource warnings remain.

## 2026-10-21 — Authored bomb explosion and debris art; denser door fragments

- User asked for better bomb debris art and more door fragments. Built-in image_gen produced separate transparent 4x2 sheets: eight sequential explosion/smoke frames and eight material shards matching the navy/orange crate and red canisters. Raw sheets live in `assets/art/effects/bomb/`; exact prompts live in `art_sources/ai_drafts/bomb_effects_v1/prompts.json`. Engine AtlasTextures select cells without repainting source pixels.
- Replaced procedural block fireballs with AnimatedSprite2D playback and anchored scaling; used authored flame art for lingering fire. Eight separately textured shards spin/fly/fall in 0.4 seconds and remain as non-colliding ground debris until scene unload. Damage remains owned by FuelPatch; repeat hits cannot duplicate effects or damage.
- Door break count increased from 4–6 to 10–14; smaller source subdivisions and slightly larger settled fragments keep the additional pieces visible. No new door images.
- Validation: fuel/explosion 26/26, bomb encounter 458/458, doors/debris 21/21, no import/script errors, runtime explosion and settled debris screenshots inspected. An exploratory legacy presentation_systems_check failed on old HUD assumptions and nonexistent unequip_mobility; it was stopped and is not counted as passed. Existing exit resource warnings remain.

## 2026-10-22 — Prepare scene-art pull request

- User authorized committing, pushing and creating a PR for the completed warehouse/combat work. Included editor-placeable warehouse scene and presentation assets, combat architecture and varied obstacles, immune buff stations with sigils, three bomb boxes per area, textured explosion/debris and shield upward orientation fix. Excluded two semantically unchanged editor-resaved enemy SpriteFrames and pre-existing parry import sidecars.
- Immediately before commit, reran warehouse layout 59/59, warehouse 58/58, synthesis 40/40, parry training 50/50, workshop scenery 154/154, fuel/explosion 26/26 and doors/debris 21/21 (408 assertions). Existing exit-time resource diagnostics remain; Windows export and legacy presentation-system fixture issues are still not verified/fixed.

## 2026-10-22 — Warehouse doorway half-sigils

- User selected a subtle breathing glow that brightens on approach. Added a saved `DoorSigil` child to each of the four warehouse doorways, with downward floor semicircles for the north-row doors and a left-facing semicircle for the east-wall deployment door. Colors follow the doorway roles: cyan, green, purple and amber.
- `scripts/presentation/warehouse_door_sigil.gd` uses Godot ground-plane geometry for rings, runes and glow, and previews in the editor with `@tool`. It follows the doorway transform and uses the existing `can_interact` condition for proximity brightness; it does not create collision or alter entrance actions. Removed the superseded floor arrows.
- Validation: editor import without script/resource errors; live near/far/animation probe passed for 4/4 doors; saved-layout/transform checks 67/67; warehouse integration 58/58. Far/near runtime captures: `docs/art/validation/warehouse_safehouse_v1/warehouse_door_sigils{,_near}.png`. Validation used isolated save paths. Existing ObjectDB/resource-use exit diagnostics remain.


## 2026-10-22 — Bomb reactions-off regression and full sigil occlusion

- Reproduced the reported "shoot bomb, box disappears" bug with a real pistol projectile under disabled elemental reactions. FuelBarrel marked itself broken and hid its artwork before the shared reaction setting aborted debris/patch creation. Basic bomb hazards now run independently of optional oil/element combinations; ordinary oil ignition still follows the setting. Added bomb_runtime_check.gd, explicitly exercising the reactions-off path rather than the headless setting shortcut. Before fix: failed to create blast. After fix: 13/13 in headless mode and 13/13 in a real window using the shipped GameSettings instance; existing fuel tests 26/26 and encounter barrel checks 458/458. Window captures verified explosion art, settled fragments and lingering fire. Existing ObjectDB/resource-use exit diagnostics remain.
- Replaced the doorway half-symbol drawing with complete circle/rune geometry clipped by an invisible Polygon2D wall-plane mask. Removed the diameter seal; only the room-facing half remains visible. Kept breathing, proximity brightness, colors and saved parent transforms. Warehouse layout checks 67/67, four-door runtime brightness/animation probe 4/4, actual window render inspected.


## 2026-10-22 — Extracted, reflected full sigil textures

Following the user's correction, extracted the four existing colored half-sigils at 6× resolution, removed the renderer clip-group black matte, and used exact vertical/horizontal reflection to create four full transparent PNGs. Original floor perspective and colors are preserved; no new design was used. Raw/clean halves and source geometry are archived in art_sources/ai_drafts/warehouse_sigils_extracted_v1; full assets are in assets/art/effects/warehouse_sigils. Replaced half-mask drawing with whole Sprite2D textures positioned under actual architecture. Split wall artwork into a separate layer above the sigils so walls/doorframes provide the occlusion. Four-door animation/proximity probe passed 4/4, layout save/transform checks 67/67, runtime images inspected. Then shifted only Deploy/DoorSigil downward by 8 game pixels per user feedback.

## 2026-10-22 — Projectile door breaking

- User selected bullets breaking automatic doors. Projectile world impacts now notify the owning AutomaticDoor before consuming the bullet. Shared break handling preserves existing fragments, noise and collider removal; projectile breaks do not apply dash knockdown. Repeated hits cannot duplicate fragments, and zero-damage or paused hits do not break doors.
- Regression first reproduced the missing behavior (4 failures). After implementation: automatic doors 28/28 in both headless and windowed runs, shield support 69/69, point-blank shooting 73/73, bomb runtime 13/13. Existing ObjectDB/resource-use diagnostics remain on test exit; no new script errors observed.

## 2026-10-23 — Melee telegraph, warehouse terminal, Codex passage and equipment art

- Fixed normal melee and shield soldiers banking windup during pursuit: only ranged enemies may precharge. Melee enters its full raised-hand windup in range, and leaving range/losing visibility cancels that preparation. Added timing, animation, continuous-precharge and re-entry regressions.
- Restyled storage as a pixel terminal with two bordered inventories, larger item art, quality colors, capacity markers and an inline detail area. Retained native storage buttons, pause ownership and transfer/save behavior.
- Added a service corridor only when continuing after floor two. Reused the warehouse's existing synthesist and bench; four dialogue pages unlock repeatable carried-equipment upgrades and irreversible cyberware fusion. Preserved inventory identities, health, heat and personas into floor three, with no extra persona authorization or permanent-warehouse writes. Props and door are wall-mounted; reused the doorway light ring and aligned floor numbers/guide line to it.
- Used built-in imagegen for buffer armor, six distinct cyberware modules and compound cyberware. Full source art and per-image prompts are versioned in art_sources/ai_drafts/equipment_icons_v1/. Packaged 32px/64px transparent PNGs, wired inventory/workshop/storage/drop textures and upgraded old compound item icons.
- Clean validation against origin/main in an isolated worktree: enemy combat upgrade; enemy native animation 348/348; warehouse 61/61; Codex passage 23/23; cyberware effects; armor blue-health 38/38; defense 40/40; extraction; victory 14/14; persona rest. All ten scripts exited successfully with zero assertion failures. Windowed captures also passed and were visually checked.
- Limits: Godot 4.7.2 GDScript/Compatibility validation on macOS, not .NET/Windows export or another member's review. Existing resource/RID cleanup diagnostics remain; fresh import also emitted two file-access diagnostics while importing unchanged data/fonts. The old component_progression_check.gd still references removed mobility APIs and fails parsing at line 149; it is not counted as passed.
- PR contains only this chat's work. Concurrent floor difficulty, boss-minion health, persona emergency movement, wall/crate navigation, raw reference media and unrelated editor imports remain outside this branch. Generated assets: project-local AI output, no newly imported third-party assets; team ownership pending assignment.

## 2026-10-23 — Resolve PR18 laser merge conflict

- User explicitly selected PR18's implementation for the weapon_controller.gd beam conflict. Merged current origin/main into the PR18 head, retained PR18's 160px formation/penetration corridor and subsequent wall clipping, and did not retain main's conflicting projectile-style automatic-door impact block.
- Updated the newly merged door assertions to match that explicit choice: distant blocking doors stay closed, the beam remains clipped, and the rear door remains protected. Laser beam integration: 33/33. Existing resource-use exit warnings remain; this updates the PR branch only, without merging it into main.
- Settings assertions reported zero failures. The merged presentation_systems_check hits missing HUD affordances and a null get_global_rect call, preventing completion; it is not counted as passing and requires follow-up separate from this laser-conflict choice.

## 2026-10-23 — Sync PR19 with merged PR18

- Resolved the append-only AI_USAGE.md conflict by retaining both PR18's laser-resolution record and PR19's workshop/art record. Gameplay code auto-merged; kept PR18's selected beam behavior and PR19's service passage, melee preparation, storage UI and item art.
- Validation after merging current main: Codex passage 23/23, warehouse 63/63, laser beam 33/33 and enemy combat upgrade zero failures. Existing resource cleanup diagnostics remain. Only the PR19 branch is updated; no direct main merge.
