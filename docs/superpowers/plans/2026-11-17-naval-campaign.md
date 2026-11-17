# Naval Campaign Implementation Plan

> For agentic workers: Execute the scoped tasks inline with coordinated workers and independent review. The user has explicitly authorized autonomous decisions and execution; no additional approval question is needed. Test-first applies to each behavior change.

**Goal:** Enable a paid, regular Wessex expedition and return through a verified water route, with coherent monthly actions, AI, touch UI and preserved saves.

**Architecture:** NavalRoutes owns admitted route data. NavalTransport owns shared pure rules; Game owns public commands and world mutations. Existing Save/LAN and province UI consume those public queries and commands.

**Tech Stack:** Godot 4.5.1/GDScript, existing Windows/Android exports, ENet, offline Python/Shapely geometry evidence.

**Spec:** `docs/superpowers/specs/2026-11-17-naval-campaign-design.md`

## Global Constraints

- Keep 108-region geometry, land adjacency, original context exports and current genuine save bytes unchanged.
- Capacity 100 soldiers/ship; fleet minimum morale20; army50/fleet60/claim40Gold; zero extra crossing fare.
- One shared army action and fleet action per one-based calendar month. Invalid preview/commands preserve state and RNG.
- Real combat outcomes may mutate on failed landing; report `ok=true, landed=false` or `blockaded=false`.
- German contextual controls, existing military tab, touch44px and large-text scrolling; no new global tab.
- Physical phone untouched; use only project emulator when testing Android. Visible Windows only rightmost DISPLAY3.
- Keep every genuine local13/14 migration and original backup path; schema15 cannot silently reset used fleet dates.

### Task 1: Admit the proved route

Files: create `data/naval_routes.json`, `scripts/NavalRoutes.gd`, `tests/NavalRouteTest.gd/.tscn`.

Interfaces: `load_data()->bool`, `load_bytes(raw:String)->bool`, `error_message:String`, `route(from,to)->Dictionary`, `destinations(id)->Array[String]`, `is_port(id)->bool`, `fingerprint()->String`. Route keys: id/from/to/points/length_map_units/proof. Reads real catalog and input hashes, never a runtime sea texture.

- [x] Write literal positive/negative direction and decoder cases, run headless and observe missing/invalid behavior.
- [x] Rehash the five actual inputs, rerun the existing offline water proof, then embed the admitted London–Brussels route and both true anchors.
- [x] Implement fail-closed decoding, copied outputs, stable destination order and no mutation of land adjacency. Run the same tests green.

### Task 2: Preserve real schema14 state before schema15

Files: modify `scripts/SaveGame.gd`, `scripts/RegionMigration.gd`, `scripts/LanSession.gd`; add `tests/NavalSaveTest.gd/.tscn`, extend `tests/LegacyLanMigrationTest.gd` and genuine fixtures.

- [x] Secure exact current exported schema14 LAN bytes/provenance before changing definitions; inspect an actual old fleet save if available or generate one through legal actions in the frozen previous EXE.
- [x] Add red tests: current used fleet date survives JSON+restore, old14 defaults−1, future/fractional dates rejected, old49-region migration ends at15, all pinned old13/14 files load and back up exactly, backup failure preserves file/live state.
- [x] Implement15 and explicit fixed-field migration; generalize local version guards without broadening unknown fingerprints. Use actual old context fingerprint, not a fabricated metadata fixture.
- [x] Include route/rule definitions in current fingerprint once model component exists; run migration suites green.

### Task 3: Transport, claims and resolved combat

Files: create `scripts/NavalTransport.gd`; modify `scripts/Game.gd`; add `tests/NavalTransportTest.gd/.tscn`, extend `tests/NavalTest.gd` for the changed resolved-combat contract.

Interfaces: `Game.naval_routes()`, `Game.naval_transport_preview(target,house=-1)`, `Game.transport_army(target,house=-1)`, `Game.claim_reason(target,house=-1)`, `Game.coastal_claim_reason(target,house=-1)`. Preview includes ok/reason/origin/target/route_id/route_points/army_id/fleet_id/strength/capacity/ships_required/ships_available.

- [x] Red test real region Wessex port and target: raise army50, fleet60, await ordinary income for claim40; unchanged-state invalid target, wrong house, capacity, morale, truce and monthly cases.
- [x] Red test own return with gold0 and no enemy claim, shared fleet guard across two selectable armies, and preserved date after snapshot/restore.
- [x] Red test expired land/sea claim renewal and ordinary active claim refusal.
- [x] Implement pure preview and Game command: pin original fleet reference, spend month before battle, recheck that fleet after losses, move three place fields only on landing, clear only unsupported origin siege.
- [x] Add and implement station-only defending fleet, scoped blockade cleanup and mutating blockade-loss success envelope. Validate unchanged RNG on pure failures.
- [x] Run existing naval/march/siege/army tests and the new real model suite green. Root also preserves date in `Game._normalize_fleets`, initializes it in `raise_fleet`, and marks snapshots current.

### Task 4: Coherent AI expedition

Files: create a focused campaign planner if needed; modify Game AI entry points; add `tests/NavalCampaignTest.gd/.tscn`.

- [x] Red tests: unreachable first claim plus reachable second; monthly path through own land and one genuine sea edge; no foreign intermediate shortcut; blockade/expiry causes replanning; island preparation uses normal funds and does not send needed escort blockading.
- [x] Implement stable planning across all active claims and explicit marine preparation reserve. Use existing command methods for all mutations.
- [x] Run a bounded regular Wessex campaign with active NPCs, event choices recorded and no direct funds/troop injection; prove paid landing and later siege or retreat. Keep controlled combat fixtures separate.

### Task 5: Protocol and contextual UI

Files: modify `scripts/UiKernel.gd`, `scripts/LanProtocol.gd`, `scripts/LanAuthority.gd` if required, `scripts/ProvinceInspector.gd`, `scripts/MapView.gd`; extend UI/real ENet tests.

- [x] Red tests: unknown/extra client transport fields rejected, actor comes from seat, actual host result reaches guest, fleet position/month preserved after save/resume.
- [x] Route target-only command to Game and add canonical rule/route fingerprint.
- [x] Red UI tests: context button only for admitted routes, capacity/reason visible, actual transport advances model, no build/research controls leak onto foreign land, desktop/touch/200% remains usable.
- [x] Add one military action and restrained selected route indication. Preserve existing main navigation and army picker.

### Task 6: Integrate and verify delivered behavior

Files: `tools/run_all_tests.sh`, release helpers, export preset Androidcode17, new naval release report, README and planning files.

- [x] Register every new scene, inspect all current-suite consumers of schema14, retain genuine historical14 expectations and update only current-schema assertions.
- [x] Freeze actual source/data; run necessary full regression and focused corrections with honest separate receipts. Review rules and migration independently.
- [x] Build separate `1.9.1-naval` EXE/APK only after source checks. Verify embedded data/logic, native branding/version, Android sign/alignment and previous signing identity.
- [x] Run exported ordinary Wessex flow, save/restore, two real peers, and project-only Android emulator when resources permit. No physical phone claim.
- [x] Deliver actual packages/report and push only scoped source/docs. Keep overall gameplay objective active until broader balance/fun/performance requirements are verified.

Self-review: Every spec unit has a task above. Runtime routes and raw data ownership are isolated. Unknown route IDs cannot create land edges, schema changes are coordinated with both fixed-field fleet rebuilders, and current tests must not rewrite genuine old file metadata. Specifying one admitted first crossing is a data gate and meaningful first integration, not a narrowed definition of the overall game objective.
