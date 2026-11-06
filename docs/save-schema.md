# Save-Schema 3 und Migration

> Dokumentversion: 1.1
> Stand: 2026-11-06
> Aktuelles Schema: 3
> Status: implementiert und getestet

## Datei

`user://spielstand.json` wird von `Main._save()` über `Game.snapshot()` geschrieben und von `Main._load()` über `Game.restore()` gelesen. Die Schema-, Migrations- und Diff-Logik liegt ausschließlich in `scripts/SaveGame.gd`.

## Schema 1 (Altstand)

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

## Schema 2 (Welle 0)

Schema 2 ergänzte additiv:

| Feld | Typ | Default bei Migration | Bedeutung |
|---|---|---|---|
| `schema_version` | int | `2` | Formatversion; fehlt in Schema 1 |
| `provinces[].buildings` | Dictionary | `{"market":0,"barracks":0,"walls":0}` | Gebäudestufen, geklemmt auf `0..3` |
| `victory` | bool | `false` | Siegmarke; wird nicht aus alten Daten geraten |

## Schema 3 (aktuell, Welle 1)

Schema 3 ergänzt additiv:

| Feld | Typ | Default bei Migration | Bedeutung |
|---|---|---|---|
| `houses[].legitimacy` | int | `50` | Herrschaftslegitimität, geklemmt auf `0..100`; wird von der Ehe erhöht und vom Marschallstraining gelesen |

Alle Schema-1- und Schema-2-Felder bleiben unverändert. `legitimacy` wird bei jeder Migration ergänzt, falls es fehlt, und ein vorhandener Wert bleibt erhalten (nur auf `0..100` geklemmt). Unbekannte Top-Level- und Hausfelder bleiben beim Migrieren erhalten; `Game.restore()` legt sie in `extra_state` ab und `snapshot()` schreibt sie wieder heraus. Unbekannte Provinzfelder gehören nicht zum Save-Vertrag: Provinzen werden aus `Data.provinces()` rekonstruiert und nur mit den Save-Feldern überschrieben.

## Migrationsregeln

`SaveGame.migrate(data)` arbeitet auf einer tiefen Kopie und ist idempotent für Schema 3.

1. Fehlt `schema_version`, gilt der Stand als Version 1.
2. Versionen `< 1` und `> 3` werden abgelehnt. Es wird nicht geraten, was ein zukünftiges Schema bedeutet.
3. Vorhandene Werte werden nie durch Defaults überschrieben; Defaults gelten nur für fehlende Felder.
4. `buildings` wird für jede Provinz ergänzt. Fehlende Gebäudeschlüssel werden `0`, vorhandene Werte auf `0..3` geklemmt.
5. `victory` wird nur ergänzt, wenn es fehlt.
6. `houses[].legitimacy` wird nur ergänzt, wenn es fehlt; der Default ist `50`, vorhandene Werte werden auf `0..100` geklemmt.
7. `houses` und `provinces` werden als Arrays geprüft; ungültige Einträge erzeugen einen Fehler statt eines stillen Datenverlusts.
8. `player` muss nach der Migration auf ein vorhandenes Haus zeigen, sonst lehnt `Game.restore()` den Stand ab.

## Was der Test beweist

`tests/SaveMigrationTest.tscn` führt vier Nachweise:

1. **Echter Altstand:** `tests/fixtures/legacy_v1.json` ist ein 18.737-Byte-Spielstand ohne `schema_version`, ohne `buildings`, ohne `victory` und ohne `legitimacy`. Er hat 10 Häuser und 49 Provinzen. Der Test lädt ihn, vergleicht jedes alte Top-Level-, Haus- und Provinzfeld und prüft die neuen Defaults, inklusive `legitimacy = 50` für jedes Haus.
2. **Synthetischer Altstand:** Ein vollständiger Schema-3-Snapshot wird um die Schema-2- und Schema-3-Zusätze erleichtert, migriert und mit allen Altfeldern verglichen. Das deckt Felder ab, die im echten Fixture zufällig leer sind.
3. **JSON-Roundtrip:** Der migrierte Stand wird mit `JSON.stringify()` gespeichert, neu geparst, geladen und erneut gesnapshottet. `SaveGame.diff()` muss leer sein; `validate()` muss leer bleiben.
4. **Negative Kontrollen:** Aus dem migrierten Stand werden `provinces[0].dev` und `houses[0].legitimacy` entfernt. `validate()` und `diff()` müssen beide Verluste melden. Der Test endet bei einem Verlust mit Exit 1.

Der Test würde bei einem verlorenen Feld fehlschlagen, weil:

- `_assert_same()` für jedes alte Feld `SaveGame.diff()` aufruft,
- `validate()` die Pflichtfelder **am Rohstand vor der Migration** prüft, damit Defaults einen Verlust nicht verdecken,
- die negativen Kontrollen die Fehlerpfade selbst auslösen.

## Ausgabe

```text
ALTSTAND-FIXTURE OK: 10 Häuser, 49 Provinzen, alle Altfelder erhalten, Schema 3, legitimacy=50, Roundtrip identisch.
FELDVERLUST-KONTROLLE: provinces[0].dev fehlt.
LEGITIMITÄTS-KONTROLLE: houses[0].legitimacy fehlt.
SAVEMIGRATIONTEST OK: v1->v3, 9 Häuser, 49 Provinzen, Altfelder erhalten, legitimacy additiv, JSON-Roundtrip identisch, Feldverlust erkannt.
```

Der Exit-Code ist `0`. Die negativen Kontrollen sind im erfolgreichen Lauf enthalten; sie sind kein separater Fehlerlauf.

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
- Ein Stand mit `schema_version > 3` wird abgelehnt, nicht teilweise geladen.
- Die Migration ist additiv. Ein grundlegend anderes Save-Format wäre eine Nutzerentscheidung und ist nicht stillschweigend Teil von Schema 3.

## Nächste Schema-Versionen

| Welle | Schema | Neue Pflichtfelder | Migration |
|---|---|---|---|
| 2 | 4 | `claims[]`, `armies[]`, `wars[]`, `truces[]`, `provinces[].siege` | v3→v4 mit Fixture |
| 3 | 5 nur falls nötig | `houses[].ai_memory` | v4→v5, sonst Schema 4 |

Jede neue Version bekommt vor dem Merge einen echten Fixture-Stand der Vorgängerversion und denselben dreistufigen Nachweis: laden, migrieren, Roundtrip ohne Diff.
