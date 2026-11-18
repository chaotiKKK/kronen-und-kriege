# Produktions- und Versorgungsstrecke · Implementation Plan

**Goal:** Örtliche Produktion, gemeinsame Bauarbeit, konservierten Straßentransport und ein tatsächlich wirksames Frontdepot als zusammenhängende spielbare Entscheidungskette liefern.

**Architecture:** Game besitzt Mutationen und Monatsreihenfolge. Reine Module planen Arbeit, Materialflüsse, Depotversorgung und NPC-Absichten. Save/LAN besitzen explizite Schema-17- und Identitätsverträge; die vorhandene kompakte Oberfläche projiziert dieselben Vorschauen.

**Tech Stack:** Vorhandenes Godot 4.5.1/GDScript, native Windows-x64-EXE und Android-ARM64/ARMv7-APK; vorhandene ENet-Autorität. Keine zusätzliche Engine/Runtime.

**Spec:** `docs/superpowers/specs/2026-11-18-production-construction-design.md`.

**Execution:** Innerhalb der vorhandenen autonomen Freigabe inline mit koordinierten internen Teilaufgaben. Vor jedem Implementierungsschritt reale Rotphase; unabhängiger Review vor Auslieferung. Keine weitere Nutzerfreigabe als Zwischenschritt.

## Global Constraints

- Alle 108 Regionen und alle Häuser bleiben erhalten; wirtschaftliche Mengen werden nach dem bestehenden economic_share gewichtet.
- Genau ein neuer Baustoffbestand; UNIT=1_000_000, Produktionsrest 0..31, keine ganzen Mindestmengen pro Region.
- Game ist einziger Mutationsbesitzer; ungültige Absichten erzeugen weder Zahlungen, IDs, Fortschritt noch Logbuchänderungen.
- Aktuelle beschädigte Schema-17-Felder werden abgewiesen; alte echte Daten erhalten additive Defaults mit bytegleicher Sicherung.
- Live-LAN verlangt identische Regeln; historische Ausnahme ausschließlich für die belegte lokale Schema-16-Familie.
- Version1.9.1, Android-Code20, Schema17, neue Dateien mit Suffix-production. Vorherige Pakete und Spielstände erhalten.
- Die gerade ausgelieferte kompakte UI bleibt maßgeblich; eigener/fremder Besitz, 44-Pixel-Touchflächen und200-Prozent-Text bleiben bedienbar.
- Kein Telefon oder Standard-ADB; nur eigene Profile/zugewiesener Emulator. Sichtbare Windowsfenster ausschließlich rechts.

## Task 1: Reine Produktions- und Materialplanung

**Create:** `scripts/RegionalProduction.gd`, `scripts/MaterialTransport.gd`, `tests/RegionalProductionTest.gd/.tscn`, `tests/MaterialTransportTest.gd/.tscn`.

**Interfaces produced:**

```gdscript
static func weight_u(province: Dictionary) -> int
static func stock_capacity_u(province: Dictionary) -> int
static func labor_capacity_u(province: Dictionary) -> int
static func yield_numerator(province: Dictionary) -> int
static func requirements(province: Dictionary, kind: String, target_level: int) -> Dictionary
static func edge_weight_u(a: Dictionary, b: Dictionary) -> int
static func road_requirements(a: Dictionary, b: Dictionary) -> Dictionary
static func plan_local(province: Dictionary, tasks: Array, month_index: int, blocked: bool = false) -> Dictionary
```

`requirements` returns `material_total_u,work_total_u`. `road_requirements` additionally returns `edge_weight_u,legs`; each leg has province and cumulative material/work fields from the spec. Tasks have `token,priority,started_month` plus those cumulative fields. Local result has `materials_u,rate_carry,produced_u,used_u,work_u,production_work_u,wasted_u,task_updates`; updates preserve the stable token. Every function reads inputs only. All numeric/algorithm defaults are included in immutable `RULES`.

```gdscript
# MaterialTransport.gd
static func plan(provinces: Array, roads: Array, demands: Array, offers: Dictionary, month_index: int, blocked: Dictionary = {}) -> Dictionary
```

Demand has `province,house,amount_u,priority,project_id`. Offers are per-province eligible amounts, bounded by its real current stock. Result has `deltas` per province, `flows` with `from,to,amount_u,path`, and deduplicated `edges` with capacity/usage. Incoming material is never a new offer within the same plan.

- [ ] Write guarded missing-module tests, observe positive assertions fail before implementation; no parser failure counts as Rotphase.
- [ ] Assert concrete base case: weight1 empty balanced province produces500000 micro-units from2000000 labor, carry0. Four quarter-producing micro-work quanta produce exactly one material quantum. Tiny catalog weight rounds to630 micro-weight, not a whole unit.
- [ ] Implement fixed-point requirements, bounded fair local work allocation and maximal feasible work through monotone integer feasibility; material spent must equal cumulative ceiling ratio.
- [ ] Assert input immutability, exact conservation, cap/overflow, blocked preservation, two competing tasks, rotating remainder, reordered input equivalence and stocked-vs-workshop-vs-unassisted completion.
- [ ] Assert real multi-edge delivery, missing/foreign/besieged edges, shared opposite-direction capacity, no relay of imports, source reserve and priority fairness. Run both suites with isolated APPDATA and preserve logs.

## Task 2: Depotversorgung als reine Erweiterung vorhandener Berichte

**Create:** `scripts/DepotSupply.gd`, `tests/DepotSupplyTest.gd/.tscn`.

```gdscript
static func apply(report: Dictionary, provinces: Array, adjacency: Dictionary, armies: Array, house_index: int, blocked: Dictionary = {}) -> Dictionary
```

It duplicates the existing SupplyNetwork report. Uses each existing own network's members and remaining `region.export_available-region.export`; only own completed depot sites adjacent by actual land adjacency can feed foreign army locations. Adds `frontier_deliveries` and exact source exports, target imports and reduced shortfalls. Depot throughput is floor300*w per month. Foreign receivers never join an own network or relay supply. `RULES` pins these semantics.

- [ ] Write a real SupplyNetwork input fixture with spare agricultural export, connected own depot, adjacent foreign receiver and known army deficit; observe unchanged deficit without module support.
- [ ] Implement finite allocation with shared source remainder/depot throughput and stable receiver/source order.
- [ ] Test no depot, no spare food, split ownership, enemy occupation, severed road, missing adjacency, sea-only relation, two depots/multiple armies, no input mutation and exact conservation.
- [ ] Run pure suite; connect no UI or second combat/attrition system in this task.

## Task 3: Schema17, tatsächliche Altdatei und LAN-Inhaltsidentität

**Modify:** `scripts/SaveGame.gd`, `scripts/RegionMigration.gd`, `scripts/LanProtocol.gd`, `scripts/LanSession.gd`. **Create:** `tests/ProductionSaveTest.gd/.tscn`, schema16 original/provenance fixture under `tests/fixtures/`, new exact-family migration cases in `tests/LegacyLanMigrationTest.gd`.

Consumes the state schema in the spec and Task1 numeric rules. SaveGame owns raw strict validation before defaults, defaults for old versions, global serial/ID cross-checks and all bounded current fields. Local historical family uses the exact recorded app/wire/schema/catalog/fingerprint and `.pre-production-schema16.bak`. The raw original file and provenance must be copied before altering schema or fingerprint.

New command definitions are `construction_cancel:{project:sequence}` and `construction_priority:{project:sequence,priority:priority}`; the new priority type accepts only integral0/1. Wire3 remains; rule fingerprints reject mismatched live peers. All new RULES and commands must occur in fingerprint payload and cache identity.

- [ ] Capture the genuine71172-byte schema16 file and its expected SHA256; verify source/provenance hash, preserve bytes using a narrow -text attribute.
- [ ] Add current17 valid roundtrip and malformed-field rejection tests; observe expected failure before migration changes.
- [ ] Implement stock/project/depot preservation, legacy pending-road tags, bounds, exact consumption/target/owner/unique-ID relations, current required field checks and strict unsupported active49→108 conversion rejection.
- [ ] Test old49/108 migration with zero new resources, finished/prepaid roads, duplicate/self legacy routes with original backing, repeated migration/restore without gifts, backup refusal/collision/failure and unmodified originals.
- [ ] Test genuine16 local LAN migration plus live mismatch rejection, new command authority and fingerprint invalidation when rules change at the same data path. Keep states under2MiB.

## Task 4: Autoritative Game-Schleife und Wirtschafts-KI

**Modify:** `scripts/Game.gd`, `scripts/ProvinceEconomy.gd`, `scripts/Infrastructure.gd`, `scripts/UiKernel.gd`, optionally the backwards-compatible blocked-road argument in `scripts/SupplyNetwork.gd`. **Create:** `scripts/EconomyPlanner.gd`, `tests/ConstructionGameTest.gd/.tscn`, `tests/ProductionCommandTest.gd/.tscn`, `tests/ProductionCampaignTest.gd/.tscn`.

```gdscript
# Game APIs; dictionary schemas follow the spec.
func regional_project_preview(id: String, kind: String, house_index: int = -1) -> Dictionary
func start_regional_project(id: String, kind: String, house_index: int = -1) -> Dictionary
func cancel_construction(id: String, project_id: int, house_index: int = -1) -> Dictionary
func prioritize_construction(id: String, project_id: int, priority: int, house_index: int = -1) -> Dictionary
func regional_production_report(house_index: int = -1) -> Dictionary
func construction_sites() -> Array
# Pure EconomyPlanner, no mutation:
static func next_order(game, house_index: int) -> Dictionary
```

Preview returns `ok,reason,province,kind,target_level,gold,material_total_u,work_total_u` plus current production/ongoing project and measured progress. Report returns `regions,roads,flows,ledger`; sites is a compact array for all actual regional/road construction. Existing build/develop/road APIs delegate to paid starts; develop gains optional house argument for equal NPC use. Depot uses kind/depot and separate one-level site, never the old building dictionaries.

- [ ] Observe real Game tests fail on missing API/instant effects; include no resource injections in the regular campaign test.
- [ ] Add initial/restore/snapshot fields, starts, serial and stale-ID guards; capture transition abandons affected new projects and retains actual stocks.
- [ ] Freeze control/roads before monthly work, allocate common local labor, book finite transport, apply final effects once and retain a bounded transient last-month ledger. Research/legacy-road phase remains separate; the old road counter never completes a new project.
- [ ] Add workshops and earlier research times. Connect DepotSupply to the actual supply report used by siege and yearly loss. Keep existing logistics bonus.
- [ ] Implement read-only NPC priorities and one monthly paid command through the same APIs, respecting actual NavalCampaign preparation and military reserve. Verify source/workshop, useful research, paid route/export/target and military result, not just a nonempty queue.
- [ ] Run normal-budget Unetice/Sequana campaign with every income/spending/resource transfer accounted; actual nonhuman world continues. Keep controlled army/edge fixtures separately labeled. Verify Wessex naval funding remains real.

## Task 5: Kompakte Projektdarstellung und Karte

**Modify:** `scripts/ProvinceInspector.gd`, `scripts/ViewModelBuilder.gd`, `scripts/Main.gd`, `scripts/MapView.gd`, `scripts/ResearchPanel.gd`; `scripts/AtlasLayer.gd` only if required by the existing obstacle contract. **Create:** `tests/ProductionUiTest.gd/.tscn`, `tests/ConstructionMapTest.gd/.tscn`.

VM own-region `construction` consumes Game preview/report and exposes stock/capacity, production, tasks, matching options and blockers. Foreign action catalog remains empty. Commands contain only project identity, priority or destination; no trusted amounts/owner/effects from the UI. Main passes a fresh read-only production/site snapshot to MapView on game refresh. MapView retains it while panning.

- [ ] Write real Main UI tests for start-vs-finish, relevant next action, measured work/material progress, stale confirmation, priority, road relocation, no foreign administration and pending host confirmation; observe red assertions.
- [ ] Integrate one compact stock/progress block, actual project actions and collapsible roads in Ausbau; retain three own sections and Details. No additional top-level navigation.
- [ ] Show true project markers before the zoom>=2.5 early return. Register their actual drawing/hit bounds together with army hitboxes, fleets and siege bounds; test2.49/2.5/2.51 and overlap cases.
- [ ] Verify100/200-percent text,44-pixel touch controls, scroll reachability, source and target selections, duplicate command guard and actual world effects. Save actual renderer images to an external proof directory.
- [ ] Measure representative unchanged and active-construction overview/4x pan/redraw; inspect CPU/frame/primitive deltas before making a performance claim.

## Task 6: Vollständige Integration und gesonderte Pakete

**Modify:** `tools/run_all_tests.sh`, affected existing tests for changed timed construction/research/weighted-road contracts, `export_presets.cfg`, README and `docs/releases/1.9.1-production.md`.

- [ ] Register every new suite. Migrate obsolete immediate-build assertions to start/payment/progress/completion checks, without deleting negative or conservation cases. Preserve failed original logs and identify changed expected rules.
- [ ] Independent read-only source review and targeted corrections; complete regression with source manifest tying runtime/test/rule bytes to results.
- [ ] Build separate `banger-queens-1.9.1-production.exe/.apk`, code20. Inventory actual new runtime module count from frozen source, check embedded module/remap bijection and all24data resources, original logo, native resources, CRC/V2/signing/zipalign.
- [ ] Run actual exported EXE from empty work/profile with external unchanged drivers; separate controlled probes from ordinary gameplay. Use only the assigned emulator for Android if available; never imply Poco or real WLAN coverage.
- [ ] Copy verified files hash-identically to Downloads; publish only authorized source/test/docs changes. Preserve existing302 generated import/build changes outside commit. Record actual limits and remaining full-game objectives; do not mark the overall goal complete for this one system.
