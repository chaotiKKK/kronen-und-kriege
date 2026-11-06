# Save-Schema 2 und Migration

> Dokumentversion: 1.0
> Stand: 2026-11-06
> Aktuelles Schema: 2
> Status: implementiert und getestet

## Datei

`user://spielstand.json` wird von `Main._save()` über `Game.snapshot()` geschrieben und von `Main._load()` über `Game.restore()` gelesen. Die Schema-, Migrations- und Diff-Logik liegt ausschließlich in `scripts/SaveGame.gd`.

## Schema 1 (bisheriger Stand)

Schema 1 hat keinen `schema_version`-Schlüssel. Die Provinzen enthalten nur die dynamischen Felder:

```text
year, month, player, speed, event_timer, game_over, log, pending,
houses, provinces, opinion, cooldowns, captive, scandal, custom
```

`provinces[]` enthält:

```text
id, name, owner, dev, levy
```

Häuser enthalten bereits ihre vollständige Struktur (`ruler`, `spouse`, `children`, `heir`, `council`, `laws`, `courtiers`, `gold`, `prestige`, `crest`, `realm`, `capital`, `pregnant`, `lover_house`).

## Schema 2 (aktuell)

Schema 2 ergänzt additiv:

| Feld | Typ | Default bei Migration | Bedeutung |
|---|---|---|---|
| `schema_version` | int | `2` | Formatversion; fehlt in Schema 1 |
| `provinces[].buildings` | Dictionary | `{"market":0,"barracks":0,"walls":0}` | Gebäudestufen, geklemmt auf `0..3` |
| `victory` | bool | `false` | Siegmarke; wird nicht aus alten Daten geraten |

Alle Schema-1-Felder bleiben unverändert. Unbekannte Top-Level- und Hausfelder bleiben beim Migrieren erhalten; `Game.restore()` legt sie in `extra_state` ab und `snapshot()` schreibt sie wieder heraus. Unbekannte Provinzfelder gehören nicht zum Save-Vertrag: Provinzen werden aus `Data.provinces()` rekonstruiert und nur mit den sechs Save-Feldern überschrieben.

## Migrationsregeln

`SaveGame.migrate(data)` arbeitet auf einer tiefen Kopie und ist idempotent für Schema 2.

1. Fehlt `schema_version`, gilt der Stand als Version 1.
2. Versionen `< 1` und `> 2` werden abgelehnt. Es wird nicht geraten, was ein zukünftiges Schema bedeutet.
3. Vorhandene Werte werden nie durch Defaults überschrieben; Defaults gelten nur für fehlende Felder.
4. `buildings` wird für jede Provinz ergänzt. Fehlende Gebäudeschlüssel werden `0`, vorhandene Werte auf `0..3` geklemmt.
5. `victory` wird nur ergänzt, wenn es fehlt.
6. `houses` und `provinces` werden als Arrays geprüft; ungültige Einträge erzeugen einen Fehler statt eines stillen Datenverlusts.
7. `player` muss nach der Migration auf ein vorhandenes Haus zeigen, sonst lehnt `Game.restore()` den Stand ab.

## Was der Test beweist

`tests/SaveMigrationTest.tscn` führt vier Nachweise:

1. **Echter Altstand:** `tests/fixtures/legacy_v1.json` ist ein 18.737-Byte-Spielstand ohne `schema_version`, ohne `buildings` und ohne `victory`. Er hat 10 Häuser und 49 Provinzen. Der Test lädt ihn, vergleicht jedes alte Top-Level-, Haus- und Provinzfeld und prüft die neuen Defaults.
2. **Synthetischer Altstand:** Ein vollständiger Schema-2-Snapshot wird um die Schema-2-Zusätze erleichtert, migriert und mit allen Altfeldern verglichen. Das deckt Felder ab, die im echten Fixture zufällig leer sind.
3. **JSON-Roundtrip:** Der migrierte Stand wird mit `JSON.stringify()` gespeichert, neu geparst, geladen und erneut gesnapshottet. `SaveGame.diff()` muss leer sein.
4. **Negative Kontrolle:** Aus dem migrierten Stand wird `provinces[0].dev` entfernt. `validate()` und `diff()` müssen den Verlust melden. Der Test endet dann mit Exit 1.

Der Test würde bei einem verlorenen Feld fehlschlagen, weil:

- `_assert_same()` für jedes alte Feld `SaveGame.diff()` aufruft,
- `validate()` die Pflichtfelder **am Rohstand vor der Migration** prüft, damit Defaults einen Verlust nicht verdecken,
- die negative Kontrolle den Fehlerpfad selbst auslöst.

## Ausgabe

```text
ALTSTAND-FIXTURE OK: 10 Häuser, 49 Provinzen, alle Altfelder erhalten, Schema 2, Roundtrip identisch.
FELDVERLUST-KONTROLLE: provinces[0].dev fehlt.
SAVEMIGRATIONTEST OK: v1->v2, 9 Häuser, 49 Provinzen, Altfelder erhalten, JSON-Roundtrip identisch, Feldverlust erkannt.
```

Der Exit-Code ist `0`. Die negative Kontrolle ist im erfolgreichen Lauf enthalten; sie ist kein separater Fehlerlauf.

## Kanonischer Vergleich

`SaveGame.canonical()` sortiert Dictionary-Schlüssel und wandelt ganzzahlige Floats in `int`. `SaveGame.diff()` vergleicht danach:

- fehlende Felder,
- unerwartete Felder,
- Array-Längen,
- skalare Werte,
- Fließkommazahlen mit `is_equal_approx()`, weil ein JSON-Roundtrip wenige Float-Bits verlieren kann.

Farben werden als `[r,g,b]` gespeichert. Der echte Altstand zeigt beispielsweise `0.680000007152557`, nach JSON `0.68000000715256`; das ist kein Zustandsverlust und wird von der Toleranz abgedeckt. Ein fehlendes Feld wird davon nicht verdeckt.

## Grenzen

- Statische Provinzfelder (`kingdom`, `duchy`, `parts`, `label_pos`, `capital`, ...) stehen nicht im Save. Sie werden beim Laden aus `Data.provinces()` rekonstruiert. Ändert sich die Kartendatenquelle, sieht ein alter Stand die neue Geografie; das ist eine bewusste Trennung von Spielzustand und statischen Daten.
- Das Schema schützt keine manipulationsfreien Spielstände. Es prüft Struktur, nicht Fairness.
- Ein Stand mit `schema_version > 2` wird abgelehnt, nicht teilweise geladen.
- Die Migration ist additiv. Ein grundlegend anderes Save-Format wäre eine Nutzerentscheidung und ist nicht stillschweigend Teil von Schema 2.

## Nächste Schema-Versionen

| Welle | Schema | Neue Pflichtfelder | Migration |
|---|---|---|---|
| 1 | 3 | `houses[].legitimacy`, `factions[]`, `secrets[]`, `ruler.traits[]`, `children[].education` | v2→v3 mit Defaults und Fixture |
| 2 | 4 | `claims[]`, `armies[]`, `wars[]`, `truces[]`, `provinces[].siege` | v3→v4 mit Fixture |
| 3 | 5 nur falls nötig | `houses[].ai_memory` | v4→v5, sonst Schema 4 |

Jede neue Version bekommt vor dem Merge einen echten Fixture-Stand der Vorgängerversion und denselben dreistufigen Nachweis: laden, migrieren, Roundtrip ohne Diff.
