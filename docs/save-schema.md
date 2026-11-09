# Save-Schema 12 und Migration

> Dokumentversion: 8.0
> Stand: 2026-11-09
> Aktuelles Schema: 12
> Status: implementiert und getestet

## Datei

`user://spielstand.json` wird von `Main._save()` über `Game.snapshot()` geschrieben und von `Main._load()` über `Game.restore()` gelesen. Schema, Migration, Validierung und Diff liegen ausschließlich in `scripts/SaveGame.gd`.

## Schema 12: Banger Queens

Kalenderfelder: `calendar_version = 1`, `month_index` (Januar 2000 v. Chr. = 0; Dezember 2200 = 50399) und `campaign_sandbox`. Jahr null wird ausgelassen. Die Umstellung alter Saves erhält vergangene Dauer und Fristen: altes Jahr 0 wird 1 n. Chr., altes Jahr 1 wird 2 n. Chr.; `_now()` bleibt für bestehende absolute Fristen einsbasiert.

Forschung liegt pro Haus in `research = {known, active, months}`. Aktuell sind `surveying` und `road_building` definiert. `roads[]` enthält sortierte Endpunkte `from/to`, `builder`, `months` und `state` (`building`/`complete`). Unbekannte Innovationen, fehlende Voraussetzungen, doppelte oder nicht benachbarte Verbindungen sowie widersprüchliche Datums-/Indexfelder werden abgewiesen. Altdaten bekommen leere Forschung und ein leeres Straßennetz. Aktuelle Saves dürfen diese Felder nicht still verlieren.

`CampaignTest` und `InfrastructureTest` prüfen diese Erweiterungen zusätzlich zu den bestehenden Migrationsprüfungen. Die folgenden Abschnitte dokumentieren die schrittweise Entstehung der älteren Schemas.

## Schema 1 (Altstand)

Schema 1 hat keinen `schema_version`-Schlüssel. `provinces[]` enthält nur `id`, `name`, `owner`, `dev`, `levy`; Häuser enthalten ihre Grundstruktur. `tests/fixtures/legacy_v1.json` ist ein echter Stand dieser Form mit 10 Häusern und 49 Provinzen.

## Schema 2 (Welle 0)

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `schema_version` | int | `2` | Formatversion |
| `provinces[].buildings` | Dictionary | `{"market":0,"barracks":0,"walls":0}` | Gebäudestufen, `0..3` |
| `victory` | bool | `false` | Siegmarke |

## Schema 3 (Welle 1)

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].legitimacy` | int | `50` | Legitimität, `0..100` |
| `houses[].ruler.traits` | Array | `["Loyal"]` | Traits des Herrschers |
| `houses[].children[].education` | String | `"martial"` | Erziehungsweg des Kindes |

## Schema 4 (Welle 2/3)

Schema 4 ergänzt additiv:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].factions` | Array | Adel/Krieger mit Macht 20, Treue 65/60 | Fraktionen mit `name`, `power`, `loyalty` |
| `houses[].secrets` | Array | `[]` | Geheimnisse mit `id`, `target`, `kind`, `known` |
| `houses[].claims` | Array | `[]` | Ansprüche mit `province`, `strength`, `expires` |
| `houses[].armies` | Array | `[]` | Armeen mit `id`, `province`, `strength`, `upkeep`, `morale` |
| `houses[].truces` | Dictionary | `{}` | Zielhaus → Monatsende des Waffenstillstands |
| `provinces[].defense` | int | `0` | Mauerverteidigung, `0..100` |
| `provinces[].siege` | int | `0` | Belagerungsfortschritt, `0..100` |
| `provinces[].siege_owner` | int | `-1` | Belagerer; `-1` = niemand |

## Schema 5 (Seekrieg)

Schema 5 ergänzt additiv:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].fleets` | Array | `[]` | Flotten mit `id`, `province`, `station`, `ships`, `upkeep`, `morale` |
| `provinces[].blockade` | int | `0` | verbleibende Blockademonate, `0..24` |
| `provinces[].blockade_owner` | int | `-1` | blockierendes Haus; `-1` = niemand |

`fleets[].province` ist der Heimathafen, `fleets[].station` der aktuelle
Ankerplatz (Hafen oder Blockadeziel). `blockade_owner` wird bei `blockade = 0`
automatisch auf `-1` normalisiert. Alle bisherigen Felder bleiben unverändert. Unbekannte Top-Level- und Hausfelder werden nicht verworfen; `Game.restore()` legt sie in `extra_state` ab und `snapshot()` schreibt sie wieder heraus. Unbekannte Provinzfelder werden wie bisher aus `Data.provinces()` rekonstruiert.

## Schema 6 (Dynastie)

Schema 6 ergänzt additiv:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].renown` | int | `80` | dynastischer Ruhm; monatlich aus Prestige, Besitz und Diplomatie, dazu Ehen und Geburten |
| `houses[].legacies` | Dictionary | `{"war":0,"crown":0,"guile":0}` | drei Vermächtniszweige, Stufen `0..3` |

`renown` wird nie negativ. Jeder Zweig wird auf `0..3` geklemmt. Die Kaufkosten liegen bei `80/160/240` Ruhm; `unlock_legacy()` schreibt Kosten und Stufe über den zentralen Resolver mit den Kanten `L1` (Krieg), `L2` (Krone) und `L3` (Ränke). Alle bisherigen Felder bleiben unverändert.

## Schema 7 (Vasallenverträge und Rat)

Schema 7 ergänzt additiv:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].vassals` | Array | drei Einträge | je `name`, `courtier`, `level` (`0..2`), `opinion` (`0..100`) |
| `houses[].council` | Dictionary | vier Sitze | `marshal`, `chancellor`, `steward`, `spymaster` als Höflingsindex |
| `houses[].council_effects` | Dictionary | `{"intrigue":0,"history":[]}` | aktive Intrigenstufe und die letzten acht Beschlüsse |

Die Migration ergänzt fehlende Vasallen aus den Höflingen, setzt die Startstufe auf `1`, die Meinung auf `50` und besetzt fehlende Ratssitze mit dem jeweiligen Höflingsindex (geklemmt auf den vorhandenen Hof). Vorhandene Verträge, Meinungen und Ratsbesetzungen bleiben unverändert. Der vierte Sitz `spymaster` ist rein additiv: alte Drei-Sitz-Stände behalten ihre Werte und erhalten einen neuen Sitz.

## Schema 8 (Hofpracht und Reliquien, Welle 7)

Schema 8 ergänzt additiv:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].court.relics` | Array | `[]` | höchstens je einmal `crown`, `blade`, `seal` |
| `houses[].court.hall` | int | `0` | Hofhallenstufe `0..3` |
| `houses[].court.grandeur` | int | `20` | abgeleitete Hofpracht `0..100`: 20 + 15 je Reliquie + 15 je Halle |

`grandeur` ist eine abgeleitete Größe. `SaveGame.validate()` prüft am Rohstand, dass sie exakt aus Reliquien und Halle berechnet ist; eine manipulierte Hofpracht wird abgelehnt. Die Migration ergänzt fehlende Höfe, filtert unbekannte oder doppelte Reliquien, klemmt die Halle auf `0..3` und berechnet die Hofpracht neu. Vorhandene Werte bleiben erhalten.

## Schema 9 (Glaube und Kirche, Welle 8)

Schema 9 ergänzt additiv:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].faith.confession` | String | `"sun"` | `sun` (Sonnenbund), `moon` (Mondorakel) oder `earth` (Erdbund) |
| `houses[].faith.piety` | int | `20` | Frömmigkeit `0..100` |
| `houses[].faith.holy_sites` | Array | `[]` | bis zu drei geweihte Provinz-IDs, jede höchstens einmal |
| `houses[].faith.church_power` | int | abgeleitet | `0..100`: 5 + Frömmigkeit/4 + 10 je Stätte + 5 je Reliquie + Konfessionsbonus (Sonne 6, Mond 3, Erde 0) |

`church_power` ist eine abgeleitete Größe. `SaveGame.validate()` prüft sowohl am Rohstand als auch nach der Normalisierung, dass sie exakt aus Konfession, Frömmigkeit, heiligen Stätten und der Reliquienzahl des Hofes berechnet ist; eine manipulierte Kirchenmacht wird abgelehnt. Die Migration ergänzt fehlende Glaubensdaten, setzt die Startfrömmigkeit auf 20, entfernt leere, doppelte und überzählige Stätten, klemmt die Frömmigkeit auf `0..100` und berechnet die Kirchenmacht neu. Die Spielnormalisierung verwirft anschließend Stätten, deren Provinz nicht existiert. Vorhandene Konfessionen, Frömmigkeit und Stätten bleiben erhalten.

## Schema 10 (Ketzerei, Reform und Religionskrieg)

Schema 10 ergänzt additiv:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].faith.heresy` | int | `0` | Ketzerei `0..100` |
| `houses[].faith.reform` | int | `0` | Reformstufe `0..3` |
| `houses[].faith.holy_war` | Dictionary | `{"target":-1,"months":0}` | laufender heiliger Krieg: Zielhaus und Restlaufzeit `0..24` |

Die Kirchenmacht erweitert die Formel aus Schema 9 um `+4` je Reformstufe. `holy_war.target` ist `-1` ohne Krieg und sonst ein vorhandenes, fremdes Haus; `months` ist genau dann 0, wenn kein Ziel gesetzt ist. `SaveGame.validate()` prüft am Rohstand Bereich, Zielhaus, Selbstziel und Monatskonsistenz, bevor die Migration Werte normalisiert. Die Migration ergänzt fehlende Felder, klemmt Ketzerei auf `0..100`, die Reformstufe auf `0..3` und die Restlaufzeit auf `0..24`; ein ungültiges oder eigenes Ziel wird zu `-1/0`. Vorhandene Werte bleiben erhalten. Der heilige Krieg endet mit der Eroberung der Zielhauptstadt oder nach Ablauf der 24 Monate.

## Schema 11 (Hofpracht 2.0: Erwartung und Ausstattung, Welle 10)

Schema 11 ergänzt additiv:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `houses[].court.amenities` | Dictionary | `{"table":0,"chambers":0,"retinue":0}` | Ausstattungsstufen für Tafel, Gemächer und Gefolge, je `0..3` |
| `houses[].court.grandeur` | int | abgeleitet | `20 + 15 je Reliquie + 15 je Hallenstufe + 5 je Ausstattungsstufe`, geklemmt auf `0..100` |

Die erwartete Hofpracht wird **nicht gespeichert**. Sie wird aus dem Besitz und der Legitimität des Hauses abgeleitet:

```text
erwartet = clamp(5 + 2 * Anzahl eigener Provinzen + Legitimität / 5, 0, 100)
```

Damit ist Hofpracht relativ: Ein kleiner Hof mit 30 Hofpracht kann über Erwartung liegen, ein großer Hof mit 70 Hofpracht darunter. Der Zielkorridor ist `erwartet ± 5`.

Jede Ausstattungsstufe kostet einmalig `50 / 90 / 140` Gold (Stufe 1/2/3) und danach `8` Gold Unterhalt pro Stufe und Jahr. Der Ausbau läuft über Kante `R7`, der jährliche Unterhalt über denselben R7-Pfad im Jahreswechsel. Jede Stufe gibt `+5` Hofpracht und einen dauerhaften Sekundäreffekt:

| Linie | Einmaliger Effekt je Stufe |
|---|---|
| Tafel | `+2` Vasallenmeinung |
| Gemächer | `+1` Diplomatie |
| Gefolge | `+40` Aufgebot in der Hauptstadt |

Über oder auf Erwartung zahlt `R8` jährlich einen Bonus, darunter einen Malus. Die Stärke ist `min(5, 1 + |Delta| / 15)` Prestige; die Vasallenmeinung ändert sich um `+1` über/auf Erwartung bzw. `-1` darunter. Erwartung, Delta und Effekt sind reine Ableitungen; nur `court.amenities` und die daraus berechnete `court.grandeur` stehen im Save.

`SaveGame.validate()` prüft die Ausstattungsstufen und die exakt abgeleitete Hofpracht aus Reliquien, Halle und Ausstattung. Die Migration ergänzt fehlende Ausstattungslinien mit 0, klemmt vorhandene Stufen auf `0..3` und berechnet die Hofpracht neu; bestehende Reliquien, Hallenstufen und Hofpracht-Zustände bleiben erhalten. KI-Häuser rufen dieselben `upgrade_court_amenity()`- und Resolver-Pfade auf und halten eine Goldreserve ein.

## Migrationsregeln

`SaveGame.migrate(data)` arbeitet auf einer tiefen Kopie und ist idempotent für Schema 12.

1. Fehlt `schema_version`, gilt der Stand als Version 1.
2. Versionen `< 1` und `> 12` werden abgelehnt. Zukünftige Schemata werden nicht geraten.
3. Vorhandene Werte werden nie durch Defaults überschrieben; Defaults gelten nur für fehlende Felder.
4. `buildings` wird ergänzt; fehlende Schlüssel werden `0`, vorhandene auf `0..3` geklemmt.
5. `legitimacy`, `renown`, `legacies`, `vassals`, `council`, `council_effects`, `court` mit Reliquien, Halle und Ausstattung, `faith` mit Ketzerei, Reform und heiligem Krieg, `factions`, `secrets`, `claims`, `armies`, `fleets` und `truces` werden pro Haus ergänzt und normalisiert.
6. `defense`, `siege`, `siege_owner`, `blockade` und `blockade_owner` werden pro Provinz ergänzt und geklemmt.
7. `ruler.traits` und `children[].education` werden normalisiert.
8. `player` muss nach der Migration auf ein vorhandenes Haus zeigen, sonst lehnt `Game.restore()` den Stand ab.

## Was der Test beweist

`tests/SaveMigrationTest.tscn` führt vier Nachweise:

1. **Echter Altstand:** `tests/fixtures/legacy_v1.json` wird ohne Schema, Gebäude, `victory`, Legitimität und Systemfelder geladen. Jedes alte Top-Level-, Haus- und Provinzfeld bleibt erhalten; die Defaults werden ergänzt.
2. **Synthetischer Altstand:** Ein vollständiger Schema-11-Snapshot wird um alle Schema-2/3/4/5/6/7/8/9/10/11-Zusätze erleichtert, migriert und mit allen Altfeldern verglichen. Das deckt Felder ab, die im echten Fixture leer sind.
3. **JSON-Roundtrip:** Der migrierte Stand wird mit `JSON.stringify()` gespeichert, neu geparst, geladen und erneut gesnapshottet. `SaveGame.diff()` muss leer sein; `validate()` muss leer bleiben.
4. **Negative Kontrollen:** Entferntes `provinces[0].dev`, `houses[0].legitimacy`, `houses[0].renown`, `provinces[0].defense`, eine manipulierte `houses[0].court.grandeur` (auch bei veränderten Ausstattungsstufen) und eine manipulierte `houses[0].faith.church_power`, eine manipulierte `houses[0].faith.heresy` und ein unbekanntes Kriegsziel müssen von `validate()` und `diff()` erkannt werden.

## Ausgabe

```text
ALTSTAND-FIXTURE OK: 10 Häuser, 49 Provinzen, alle Altfelder erhalten, Schema 11, Systemfelder additiv, Roundtrip identisch.
FELDVERLUST-KONTROLLE: provinces[0].dev fehlt.
RUHM-KONTROLLE: houses[0].renown fehlt.
LEGITIMITÄTS-KONTROLLE: houses[0].legitimacy fehlt.
HOFPRACHT-KONTROLLE: houses[0].court.grandeur ist nicht aus Reliquien, Halle und Ausstattung abgeleitet.
VERTEIDIGUNGS-KONTROLLE: provinces[0].defense fehlt.
SAVEMIGRATIONTEST OK: v1->v11, 9 Häuser, 49 Provinzen, Altfelder erhalten, legitimacy/renown/legacies/vassals/council/court/amenities/faith mit Ketzerei/Reform/Krieg/defense/fleets additiv, JSON-Roundtrip identisch, Feldverlust und Glaubensmanipulation erkannt.
```

Der Exit-Code ist `0`; die negativen Kontrollen sind Teil des erfolgreichen Laufs.

## Kanonischer Vergleich

`SaveGame.canonical()` sortiert Dictionary-Schlüssel und wandelt ganzzahlige Floats in `int`. `SaveGame.diff()` vergleicht fehlende und unerwartete Felder, Array-Längen, Skalare und Floats mit `is_equal_approx()`. Farben werden als `[r,g,b]` gespeichert. Ein fehlendes Feld wird von der Float-Toleranz nicht verdeckt.

## Grenzen

- Statische Provinzfelder (`kingdom`, `duchy`, `parts`, `label_pos`, `capital`, ...) stehen nicht im Save und werden aus `Data.provinces()` rekonstruiert.
- Das Schema prüft Struktur, nicht Fairness oder Manipulationsfreiheit.
- Ein Stand mit `schema_version > 12` wird abgelehnt, nicht teilweise geladen.
- Die Migration ist additiv; ein neues Grundformat wäre eine eigene Nutzerentscheidung.

## Nächste Schema-Version

Welle 10 ist mit Hofpracht 2.0, Erwartung und Ausstattung in Schema 11 abgeschlossen.
Sollte `ai_memory` persistiert werden, wird daraus Schema 13 mit erneutem Fixture-
und Roundtrip-Nachweis.
