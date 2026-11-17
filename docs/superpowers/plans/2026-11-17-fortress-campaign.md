# Fortress Campaign Implementation Plan

> For agentic workers: Execute scoped tasks inline with coordinated workers and independent reviews. The user explicitly authorized autonomous design and execution. Existing authorization overrides additional approval ceremonies; do not ask again. Test-first behavior changes, preserve shared file ownership.

**Goal:** Make walls, actual field armies, relief, supply and paid recovery form a playable tactical campaign loop.

**Architecture:** Pure `SiegeRules`, `FieldBattleRules` and `ArmyRecovery` modules own previews/rules. Game owns mutation and lifecycle. Existing planner, protocol and province UI consume the shared queries; Save/LAN preserve old published state.

**Tech Stack:** Godot4.5.1/GDScript, ENet, existing Windows/Android pipelines.

**Spec:** `docs/superpowers/specs/2026-11-17-fortress-campaign-design.md`

## Global Constraints

- Schema16/no new stored fields; lossless expanded limits100000strength/400base upkeep shared through CampaignLimits. Shared `last_siege_month` across offensive/recovery commands.
- Assault25Gold, relief0, recovery5+ceil(recruits/10); recruit at most100 and leave50 local levy. Existing annual costs stay annual.
- No kingdom-graph or national-levy substitute for actual armies. Every retreat uses a real neighbor or admitted sea route/physical fleet.
- Invalid commands and pure previews preserve world/RNG/log. Resolved battle returns ok=true/won flag.
- Keep original Code17 packages, genuine old saves and backup bytes. Strict peer fingerprint; new rules bound explicitly.
- Existing compact military UI only; German,44pxTouch,100/200% text. Visible Windows rightmost DISPLAY3. No physical phone/defaultADB5037.

### Task1: Pure siege/recovery/battle contracts

Files: create `scripts/SiegeRules.gd`, `scripts/FieldBattleRules.gd`, `scripts/ArmyRecovery.gd`, dependency-free `scripts/CampaignLimits.gd` and focused new tests/scenes for each behavior.

- [x] Write independent expected numeric cases and pure-state/RNG cases; observe meaningful red.
- [x] Implement modules exposing `RULES` plus `preview(game,target,hi)` for Siege/Recovery; Battle exposes `assault_preview`, `relief_preview`, `loss_plan` and `retreat_plan`.
- [x] Test walls vs flat defense, actual garrison/armies, shared supply, chance boundary0/50/100, paid local reserve, actual retreat/encirclement and no privileged house IDs. Run green.

### Task2: Genuine published state and rule identity

Files: `scripts/LanSession.gd`, `scripts/LanProtocol.gd`, genuine naval schema15 fixture/provenance and dedicated migration/command tests.

- [x] Preserve real Code17 LAN file71198Bytes/SHAafa14969367ce1d06333e3e89f2e724674779a0dc022bc65b532b1e2fc91277d before new fingerprint.
- [x] Bind all three RULES and new commands to current fingerprint; implement narrow local old15 backup/resume with raw-byte preservation and strict network rejection.
- [x] Verify old13/14 paths remain pinned and no arbitrary current-schema envelope is relabeled as history.

### Task3: Actual Game field campaign

Files: `scripts/Game.gd`, focused integration/lifecycle test scenes.

- [x] Observe red actual entrypoint cases: bypass, walls/minimum pressure, hostile field army, relief, recovery, costs/month/date restore, peace/death/withdrawal cleanup, no progress theft.
- [x] Integrate pure previews with existing public calls and no duplicated formulas; apply exact mutations, casualties, real retreats and messages.
- [x] Keep successful siege capture, assault capture and owner reaction coherent; preserve unrelated legacy armies/blockades, no free national losses or teleport.
- [x] Run focused old Army/Siege/Supply/Naval/Save regressions; update only observed old-contract expectations with explicit correct fixtures.

### Task4: Real AI and compact UI/command path

Files: `scripts/NavalCampaign.gd`, `scripts/UiKernel.gd`, `scripts/ProvinceInspector.gd`, `scripts/ViewModelBuilder.gd`, `scripts/MapView.gd`, protocol if required, new actual ENet/UI tests.

- [x] Red actual planner/annual/monthly cases for relief route, affordable recovery, blocked siege and retreat, human-seat exception.
- [x] Add target-only relief/recovery commands; preserve won/retreat metadata and real mutating defeat snapshots on Host/Guest.
- [x] Integrate one compact preview and contextual actions, visible siege arc/house; preserve foreign administration hiding and focus restoration.
- [x] Run actual Main desktop/touch/200% and actual ENet commands plus save/resume.

### Task5: Regular play and release evidence

Files: runner registration, exportpreset/code18, release helpers, `docs/releases/1.9.1-campaign.md`, README/planning records.

- [x] Run declared normal108-region campaign with all NPCs, actual costs/income, no seed/resource/ownership injection. Show defeat/recovery/retreat or successful fort campaign; record genuine remaining blockers rather than forcing success.
- [x] Freeze source and verify all necessary regression coverage; preserve every red artifact and report full runs vs targeted closures accurately. Independent review.
- [x] Build separate campaign EXE/APK; compare24data/new compiled modules, versions, signature and old installation identity. Actual packaged gameplay/ENet and project-only Android update when available.
- [x] Deliver hash-identical packages/report and scoped GitHub source. Keep the full gameplay/balance/performance objective active unless actually proven complete.
