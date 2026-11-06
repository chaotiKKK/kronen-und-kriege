# Save-Schema 4 und Migration

> Dokumentversion: 2.0
> Stand: 2026-11-06
> Aktuelles Schema: 4
> Status: implementiert und getestet

## Datei

`user://spielstand.json` wird von `Main._save()` über `Game.snapshot()` geschrieben und von `Main._load()` über `Game.restore()` gelesen. Schema, Migration, Validierung und Diff liegen ausschließlich in `scripts/SaveGame.gd`.

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

## Schema 4 (Welle 2/3, aktuell)

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

Alle bisherigen Felder bleiben unverändert. Unbekannte Top-Level- und Hausfelder werden nicht verworfen; `Game.restore()` legt sie in `extra_state` ab und `snapshot()` schreibt sie wieder heraus. Unbekannte Provinzfelder werden wie bisher aus `Data.provinces()` rekonstruiert.

## Migrationsregeln

`SaveGame.migrate(data)` arbeitet auf einer tiefen Kopie und ist idempotent für Schema 4.

1. Fehlt `schema_version`, gilt der Stand als Version 1.
2. Versionen `< 1` und `> 4` werden abgelehnt. Zukünftige Schemata werden nicht geraten.
3. Vorhandene Werte werden nie durch Defaults überschrieben; Defaults gelten nur für fehlende Felder.
4. `buildings` wird ergänzt; fehlende Schlüssel werden `0`, vorhandene auf `0..3` geklemmt.
5. `legitimacy`, `factions`, `secrets`, `claims`, `armies` und `truces` werden pro Haus ergänzt und normalisiert.
6. `defense`, `siege` und `siege_owner` werden pro Provinz ergänzt und geklemmt.
7. `ruler.traits` und `children[].education` werden normalisiert.
8. `player` muss nach der Migration auf ein vorhandenes Haus zeigen, sonst lehnt `Game.restore()` den Stand ab.

## Was der Test beweist

`tests/SaveMigrationTest.tscn` führt vier Nachweise:

1. **Echter Altstand:** `tests/fixtures/legacy_v1.json` wird ohne Schema, Gebäude, `victory`, Legitimität und Systemfelder geladen. Jedes alte Top-Level-, Haus- und Provinzfeld bleibt erhalten; die Defaults werden ergänzt.
2. **Synthetischer Altstand:** Ein vollständiger Schema-4-Snapshot wird um alle Schema-2/3/4-Zusätze erleichtert, migriert und mit allen Altfeldern verglichen. Das deckt Felder ab, die im echten Fixture leer sind.
3. **JSON-Roundtrip:** Der migrierte Stand wird mit `JSON.stringify()` gespeichert, neu geparst, geladen und erneut gesnapshottet. `SaveGame.diff()` muss leer sein; `validate()` muss leer bleiben.
4. **Negative Kontrollen:** Entferntes `provinces[0].dev`, `houses[0].legitimacy` und `provinces[0].defense` müssen von `validate()` und `diff()` erkannt werden.

## Ausgabe

```text
ALTSTAND-FIXTURE OK: 10 Häuser, 49 Provinzen, alle Altfelder erhalten, Schema 4, Systemfelder additiv, Roundtrip identisch.
FELDVERLUST-KONTROLLE: provinces[0].dev fehlt.
LEGITIMITÄTS-KONTROLLE: houses[0].legitimacy fehlt.
VERTEIDIGUNGS-KONTROLLE: provinces[0].defense fehlt.
SAVEMIGRATIONTEST OK: v1->v4, 9 Häuser, 49 Provinzen, Altfelder erhalten, legitimacy/factions/defense additiv, JSON-Roundtrip identisch, Feldverlust erkannt.
```

Der Exit-Code ist `0`; die negativen Kontrollen sind Teil des erfolgreichen Laufs.

## Kanonischer Vergleich

`SaveGame.canonical()` sortiert Dictionary-Schlüssel und wandelt ganzzahlige Floats in `int`. `SaveGame.diff()` vergleicht fehlende und unerwartete Felder, Array-Längen, Skalare und Floats mit `is_equal_approx()`. Farben werden als `[r,g,b]` gespeichert. Ein fehlendes Feld wird von der Float-Toleranz nicht verdeckt.

## Grenzen

- Statische Provinzfelder (`kingdom`, `duchy`, `parts`, `label_pos`, `capital`, ...) stehen nicht im Save und werden aus `Data.provinces()` rekonstruiert.
- Das Schema prüft Struktur, nicht Fairness oder Manipulationsfreiheit.
- Ein Stand mit `schema_version > 4` wird abgelehnt, nicht teilweise geladen.
- Die Migration ist additiv; ein neues Grundformat wäre eine eigene Nutzerentscheidung.

## Nächste Schema-Version

Welle 4 benötigt nach aktuellem Stand keine neuen Pflichtfelder. Sollte `ai_memory` persistiert werden, wird daraus Schema 5 mit erneutem Fixture- und Roundtrip-Nachweis.
