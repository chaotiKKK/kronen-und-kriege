# Wellenplan

> Dokumentversion: 7.0
> Stand: 2026-11-09
> Gültig für Save-Schema: 11
> Status: Wellen 0–10 umgesetzt; Welle 10 vollständig geprüft; Windows-30-Minuten-Abnahme BESTANDEN, Android offen

## Zweck

Der Plan legt die Reihenfolge fest, in der aus dem Prototyp eine verzahnte Bronzezeit-Grand-Strategy wird. Jede Welle verändert Spielzustand, Speicherformat und Tests gemeinsam. Die Matrix in [`interaction-matrix.md`](interaction-matrix.md) ist die verbindliche Soll-Liste; der [`depth-contract.md`](depth-contract.md) definiert, wann eine Kante als umgesetzt gilt.

## Leitplanken

- Kein CK3-Code und keine CK3-Assets.
- Save-Änderungen sind additiv, versioniert und haben Migration plus Test.
- `Game.gd` bleibt die einzige Regel- und Zustandsinstanz. UI und KI rufen dieselben Kommandos auf.
- Jede Welle liefert einen spielbaren Schnitt, nicht nur ein Datenmodell.
- `Main.gd` bleibt Composition Root; die UiKernel-Extraktion ist in `docs/ui-kernel.md` dokumentiert und abgeschlossen.

## Wellen

| Welle | Lieferung | Zustandsgrößen | Exit-Gate | Status |
|---|---|---|---|---|
| **0 — Fundament** | Versionierte Dokumente, zentrale Save-Schicht, Schema 2, Migration v1→v2, echter Altstand | `schema_version`, `buildings`, `victory` | `SaveMigrationTest`, bestehende Suiten, Build | **umgesetzt** |
| **1 — Herrschaft & Dynastie** | Rat, Erbfolge, Steuern, Märkte, Gebäude, Legitimität, Fraktionen, Traits, Erziehung, Geheimnisse | `legitimacy`, `factions`, `secrets`, `ruler.traits`, `children[].education`; Schema 3/4 | H1–H8, D1–D8, AI1–AI2 | **umgesetzt** |
| **2 — Krieg & Diplomatie** | Ansprüche, Armeen, Belagerungen, Frieden, Waffenstillstände, Verteidigung, Seekrieg | `claims`, `armies`, `fleets`, `truces`, `provinces[].defense/siege/siege_owner/blockade`; Schema 5 | K1–K7, H5-Mauern, NavalTest | **umgesetzt** |
| **3 — Welt & KI** | KI nutzt Rat, Steuern, Ehen, Ansprüche, Armeen, Belagerungen und Geheimnisse über dieselben Methoden | dieselben Felder für KI-Häuser | AI1–AI5; `FullDepthTest` | **umgesetzt** |
| **4 — 30-Minuten-Bogen** | Automatisierte Story-Probe mit Entscheidungen, Chronik und Save-Checkpoints | keine neuen Pflichtfelder | `StoryTest` plus manueller 30-Minuten-Lauf | **automatisiert geprüft; Windows BESTANDEN; Android offen** |
| **5 — Dynastie-Vermächtnis** | Ruhm, drei Vermächtniszweige mit je drei Stufen, KI-Käufe, Herrschafts-UI und drei Blender-Token | `houses[].renown`, `houses[].legacies`; Schema 6 | L1–L3, `DynastyTest`, SaveMigration, Asset-Gate | **umgesetzt** |
| **6 — Vasallenverträge und Rat** | Drei Vertragsstufen, vier Ratssitze, vier Beschlüsse, KI-Nutzung, echte Buttons und sieben Blender-Token | `houses[].vassals`, `houses[].council`, `houses[].council_effects`; Schema 7 | V1–V3, C1–C5, `CouncilTest`, `CouncilUiTest`, SaveMigration, Asset-Gate | **umgesetzt** |
| **7 — Hofpracht und Reliquien** | Drei einzigartige Reliquien, dreistufige Hofhalle, Hofpracht, Hofbildschirm und vier Blender-Assets | `houses[].court.relics/hall/grandeur`; Schema 8 | R1–R6, `CourtTest`, `CourtUiTest`, SaveMigration, Asset-Gate | **umgesetzt** |
| **8 — Glaube und Kirche** | Drei Konfessionen, Frömmigkeit, heilige Stätten, Kirchenmacht, Wallfahrt, Weihe, Bekehrung, Glaubensbildschirm und vier Blender-Assets | `houses[].faith.confession/piety/holy_sites/church_power`; Schema 9 | F1–F7, `FaithTest`, `FaithUiTest`, `FaithShotTest`, SaveMigration, Asset-Gate | **umgesetzt** |
| **9 — Ketzerei, Reform und Religionskrieg** | Ketzerei, Ketzergericht, drei Reformstufen, heiliger Krieg mit Anspruch auf die Zielhauptstadt, Glaubensbildschirm-Erweiterung und Wiederverwendung der Welle-8-Assets | `houses[].faith.heresy/reform/holy_war`; Schema 10 | F8–F12, `FaithTest`, `FaithUiTest`, `FaithShotTest`, SaveMigration, Asset-Gate | **umgesetzt** |
| **10 — Hofpracht 2.0** | Erwartete Hofpracht aus Provinzbesitz und Legitimität, sichtbarer Zielkorridor und Zielmarke in der bestehenden Hallenvorschau, drei Ausstattungslinien mit je drei Stufen, jährlicher Unterhalt, sekundäre Resolver-Effekte für Spieler und KI | `houses[].court.amenities`, abgeleitete `court.grandeur`; Schema 11 | R7–R8, `CourtTest`, `CourtUiTest`, `CourtShotTest`, SaveMigration, Asset-Gate | **umgesetzt** |

## Welle 1 — Herrschaft und Dynastie

Der erste Durchstich ist inzwischen vollständig:

| Kante | Wirkung | Nachweis |
|---|---|---|
| H1 | Marschall trainiert Levy | `SystemicDepthTest.H1` |
| H2 | Erbfolgegesetz wählt Erben | `SystemicDepthTest.H2` |
| H3 | Steuersatz verändert Gold | `FullDepthTest.H3` |
| H4 | Markt erzeugt Gold | `FullDepthTest.H4` |
| H5 | Kaserne erhöht Levy, Mauern erhöhen Verteidigung | `SystemicDepthTest.H5`, `FullDepthTest.H5(Mauern)` |
| H6 | Niedrige Legitimität senkt Meinung und Fraktionstreue | `FullDepthTest.H6` |
| H7 | Fraktionsdruck erzwingt Steuersatz | `FullDepthTest.H7` |
| H8 | Fraktionsunruhe senkt Levy | `FullDepthTest.H8` |
| D1/D2 | Traits verändern Gold und Levy | `FullDepthTest.D1/D2` |
| D3/D4 | Erziehung verändert Herrscher und Levy | `FullDepthTest.D3/D4` |
| D5 | Ehe erhöht Legitimität, Prestige und Meinung | `SystemicDepthTest.D5` |
| D6 | Freundschaft blockiert Angriff | `FullDepthTest.D6` |
| D7/D8 | Geheimnis erzeugt Skandal und Anspruch | `FullDepthTest.D7/D8` |

Der zentrale Effektpunkt bleibt `scripts/SystemicResolver.gd`. Er verarbeitet `gold`, `prestige`, `legitimacy`, `renown`, `legacy`, `levy`, `opinion`, `council_intrigue`, `court_grandeur`, `building`, `heir`, `scandal`, `dev`, `defense`, `siege`, `faction_power`, `faction_loyalty`, `law`, `ruler_stat` und `truce`. Jeder Beleg enthält `edge`, `source`, `target`, `state`, `before`, `after`, `delta`, `house` und `reason`.

## Welle 2 — Krieg und Diplomatie

1. **Ansprüche:** `houses[].claims[]` speichert Provinz, Stärke und Ablauf. Ein Anspruch ist Voraussetzung für `can_attack()` und `advance_siege()`.
2. **Armeen:** `houses[].armies[]` speichert Provinz, Stärke, Unterhalt und Moral. Unterhalt schreibt jährlich Gold; Stärke treibt Belagerungen.
3. **Belagerungen:** `provinces[].siege` und `siege_owner` halten den Fortschritt. Die Einnahme wechselt `owner` und beschädigt `dev` sowie ein Gebäude.
4. **Frieden:** `houses[].truces` blockiert Angriffe; `make_peace()` verändert Haltung und kann eine Ehe stiften.
5. **Mauern:** `provinces[].defense` erhöht die Verteidigung im Angriff und wird durch H5 geschrieben.

Die sieben Kanten K1–K7 sind positiv und mit deaktivierter Kante in `FullDepthTest` belegt. Es gibt keinen separaten Sofortangriff ohne Anspruch; der alte `attack`-Pfad nutzt dieselben Prüfungen.

## Welle 3 — Welt und KI

Die KI hat kein Sonderrecht auf Ressourcen. `run_ai_turn()` benutzt für alle Systeme dieselben Methoden:

- `assign_council()`, `set_law()`, `build()`
- `settle_marriage()` über den gemeinsamen Ehepfad
- `fabricate_claim()`, `raise_army()`, `advance_siege()`
- `discover_secret()`, `expose_secret()`

Der Unterschied liegt nur in der Bewertungsfunktion. AI1–AI5 sind in `SystemicDepthTest` und `FullDepthTest` belegt; `StoryTest` sieht alle fünf KI-Kanten in einer laufenden Partie.

## Welle 4 — Story und Abnahme

`tests/StoryTest.gd` spielt 120 Monate mit festem Seed, trifft 101 Entscheidungen, sieht 47 verschiedene Kanten, davon 7 dynastische, 6 Krieg-/Diplomatie- und 5 KI-Kanten, und prüft drei Save/Load-Roundtrips ohne Diff.

Das ist die automatisierte CI-Probe, keine Wall-Clock-Messung. Der Windows-30-Minuten-Lauf bei x3 ist am 2026-11-08 gegen den 1.3-Build **BESTANDEN** ([Protokoll](manual-acceptance.md#windows-lauf-2026-11-08), 12/12 Aktionen, 3/3 Roundtrips, AI2+AI3). Der Android-Lauf bleibt offen und wird nicht als geprüft ausgegeben.

## Welle 5 — Dynastie-Vermächtnis

Jedes Haus besitzt `renown` und drei Zweige (`war`, `crown`, `guile`) mit je drei Stufen. Der monatliche Ruhmgewinn hängt von Prestige, Provinzbesitz und Diplomatie ab; Ehen und Geburten geben zusätzlichen Ruhm. Der Kauf läuft über `Game.unlock_legacy()`, kostet `80/160/240` Ruhm und schreibt Kosten und Stufe über den Resolver. Die KI nutzt dieselbe Methode und dieselben Kosten.

- **L1 Krieg:** +10 % Armeestärke und Angriffskraft je Stufe.
- **L2 Krone:** +2 Gold jährlich je Stufe und +2 Legitimität bei Freischaltung.
- **L3 Ränke:** +3 Prozentpunkte Intrigenchance je Stufe.

Die drei Blender-Token `legacy_war`, `legacy_crown` und `legacy_guile` sind im Manifest, im Herrschaftsbildschirm und in der Asset-Prüfung verdrahtet.

## Welle 6 — Vasallenverträge und Rat

Jeder Vasall hat eine Vertragsstufe `0..2`. Steuern (`2/5/8`), Aufgebot (`0/30/60`) und Meinung werden daraus abgeleitet; Erhöhen kostet `60/80` Gold, Legitimität `50/60` und Prestige `8/16`, Senken kostet nichts und gibt `+10` Meinung. Die Wirkung läuft über V1 (Gold), V2 (Armee) und V3 (Legitimität).

Der Rat hat vier Sitze: Marschall (Truppentraining), Kanzler (Vasallenmeinung), Kämmerer (Gold) und Spionmeister (Intrigenchance). Vier Beschlüsse (Kriegsaufgebot, Landfrieden, Kronsteuer, Schattennetz) brauchen drei von vier Stimmen und das zustimmende Schlüsselamt; Kosten und Wirkung laufen über C1–C5. Spieler und KI benutzen `change_vassal_contract()`, `assign_council()` und `enact_council_resolution()` mit denselben Kosten.

Die sieben Token `council_marshal`, `council_chancellor`, `council_steward`, `council_spymaster`, `contract_0`, `contract_1` und `contract_2` sind im Manifest und Asset-Gate.

## Welle 7 — Hofpracht und Reliquien

Jedes Haus erhält einen persistenten Hof: `houses[].court` mit `relics` (maximal je einmal `crown`, `blade`, `seal`), `hall` (`0..3`) und der daraus abgeleiteten `grandeur` (`0..100`). Der Startwert ist 20; jede Reliquie gibt +15, jede Hallenstufe +15. Die drei Reliquien kosten Gold und Prestige und wirken über R1–R3:

- **Krone der Ahnen (R1):** +10 Legitimität.
- **Klinge des ersten Königs (R2):** +80 Aufgebot in der Hauptstadt.
- **Siegel des Schattenrats (R3):** +2 Prozentpunkte Intrigenchance.

Die Hofhalle kostet `80/140/220` Gold und `5/10/15` Prestige und schreibt über R4 auf die Hofpracht. Jährlich fließen über R5 `grandeur / 25` Prestige und über R6 ab Hofpracht 60 eine Vasallenmeinung von +1 (ab 80 +2). Der neue Bildschirm wird über „Hof & Reliquien“ im Seitenpanel geöffnet; er zeigt Hofpracht, Reliquien, Kosten, Besitz und den Hallenausbau. Spieler und KI rufen dieselben Methoden `forge_relic()` und `upgrade_court_hall()` auf.

Die drei Reliquien-Token `relic_crown`, `relic_blade`, `relic_seal` und die opake Hofhallen-Kulisse `court_hall` entstehen in der Blender-Pipeline und sind im Manifest und Asset-Gate.

## Welle 8 — Glaube und Kirche

Jedes Haus erhält `houses[].faith` mit `confession` (`sun`, `moon`, `earth`), `piety` (`0..100`), bis zu drei `holy_sites` und der daraus abgeleiteten `church_power` (`0..100`). Startfrömmigkeit ist 20; die Startkirchenmacht folgt aus `5 + Frömmigkeit/4 + 10 je Stätte + 5 je Reliquie + Konfessionsbonus` (Sonne 6, Mond 3, Erde 0).

Drei Kommandos verändern den Zustand, für Spieler und KI mit identischen Kosten:

- **Wallfahrt:** 30 Gold, `+12` Frömmigkeit.
- **Heilige Stätte weihen:** 60 Gold, `-15` Frömmigkeit, `+6` Prestige; höchstens drei eigene Provinzen.
- **Konfession wechseln:** 80 Gold, 15 Prestige, `-6` Vasallenmeinung je Vasall.

Die sieben Kanten F1–F7 verbinden den Glauben mit den bestehenden Systemen:

- **F1 Sonnenbund:** jährlich +1 Legitimität.
- **F2 Mondorakel:** jährlich +1 Intrigenpunkt (maximal 10).
- **F3 Erdbund:** jährlich +1 Prestige.
- **F4 Heilige Stätte:** jährlich +1 Prestige je Stätte, beim Weihen +6 Prestige.
- **F5 Kirchenmacht:** ab 60 +1, ab 80 +2 Vasallenmeinung je Vasall.
- **F6 Reliquien:** jede Reliquie aus Welle 7 gibt +5 Kirchenmacht.
- **F7 Frömmigkeit:** Frömmigkeit/4 fließt in die Kirchenmacht.

Der Bildschirm „Glaube & Kirche“ wird über den Seitenpanel-Button geöffnet und zeigt Konfession, Frömmigkeit, Kirchenmacht, Stätten, Kosten, drei Konfessionstoken und die Tempelkulisse. Die KI nutzt pro Jahr höchstens eine Glaubenshandlung; seit Welle 9 prüft sie zuerst Ketzergericht, Reform und heiligen Krieg und fällt danach auf Bekehrung, Weihe oder Wallfahrt zurück.

Die drei Token `faith_sun`, `faith_moon`, `faith_earth` und die opake Tempelkulisse `faith_temple` entstehen in der Blender-Pipeline und sind im Manifest und Asset-Gate.

## Welle 9 — Ketzerei, Reform und Religionskrieg

Jedes Haus erhält drei persistente Glaubensfelder: `faith.heresy` (`0..100`), `faith.reform` (`0..3`) und `faith.holy_war` mit `target` (`-1` oder Hausindex) und `months` (`0..24`).

- **Ketzerei:** jährlich `+4`, wenn die Kirchenmacht unter 40 liegt, `-3` ab 70, zusätzlich `+2` bei Legitimität unter 35 und `-2` je Reformstufe (F11). Ab 40 Ketzerei sinkt die Legitimität jährlich um 1, ab 70 um 2 (F8). Ab 30 Ketzerei sinkt die Vasallenmeinung um 1 je 30 Punkte, maximal 3 (F9).
- **Ketzergericht:** 50 Gold, 10 Prestige, `-25` Ketzerei.
- **Reform:** drei Stufen für `100/150/200` Gold, `25/30/35` Frömmigkeit und `10/15/20` Prestige. Jede Stufe gibt +4 Kirchenmacht (F10), senkt die Ketzerei um 10 und die Vasallenmeinung um 4. Ab 60 Ketzerei ist die Reform gesperrt.
- **Heiliger Krieg:** 60 Gold, 20 Frömmigkeit, 10 Prestige, `-3` Vasallenmeinung; Ziel muss andersgläubig oder ketzerisch (Ketzerei ab 50) sein und darf keinen Waffenstillstand haben. Der Krieg erhebt 24 Monate Anspruch auf die Zielhauptstadt und nutzt damit K1/K2. Eine Eroberung gibt +10 Prestige und +5 Legitimität (F12); das Ziel wird danach zurückgesetzt.

Die KI ruft dieselben Kommandos `suppress_heresy()`, `reform_faith()` und `declare_holy_war()` auf und zahlt dieselben Kosten. Der Glaubensbildschirm zeigt Ketzerei samt jährlicher Veränderung, das Ketzergericht, die Reformkosten, den laufenden Krieg und für jedes gültige Ziel einen echten Button. Die Welle ergänzt keine neuen Blender-Bilder; Token und Tempelkulisse aus Welle 8 bleiben unverändert, der Asset-Zähler bleibt 55/36/33.

## Nachweise

```bash
cd mobile-godot/.tools
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/SaveMigrationTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/DynastyTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/DynastyUiTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/CouncilTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/CouncilUiTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/CourtTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/CourtUiTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/FaithTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/FaithUiTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --path .. res://tests/FaithShotTest.tscn --resolution 1280x720
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/SystemicDepthTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/FullDepthTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/StoryTest.tscn
```

`tools/run_all_tests.sh` entdeckt alle 30 Suiten (23 headless, 7 mit Fenster), prüft je Log eine positive Assertion-Zahl ohne `skip`/`pending`/`todo`/`ignored` und schreibt die Logs sowie den Summary-Report nach `build/tests/`.

## Versionsregel

Jede Änderung an einer Architekturdatei erhöht die Dokumentversion. Bei Save-Änderungen wird zusätzlich [`save-schema.md`](save-schema.md) aktualisiert. Eine Matrixzeile wird nur `IST`, wenn Positiv- und Negativkontrolle grün sind und die Zustandsgröße im Save-Schema liegt.
