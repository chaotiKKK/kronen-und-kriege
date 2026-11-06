# Wellenplan

> Dokumentversion: 1.0
> Stand: 2026-11-06
> Gültig für Save-Schema: 2
> Status: Welle 0 umgesetzt; Wellen 1–4 geplant

## Zweck

Der Plan legt die Reihenfolge fest, in der aus dem Prototyp eine verzahnte Bronzezeit-Grand-Strategy wird. Jede Welle verändert Spielzustand, Speicherformat und Tests gemeinsam. Eine Welle beginnt erst, wenn das Exit-Gate der vorherigen Welle grün ist.

Die Matrix in [`interaction-matrix.md`](interaction-matrix.md) ist die verbindliche Soll-Liste der Systemkanten. Der [`depth-contract.md`](depth-contract.md) definiert, wann eine Kante als umgesetzt gilt.

## Leitplanken

- Kein CK3-Code und keine CK3-Assets. Alle Daten, Grafiken und Regeln bleiben Eigenbau.
- Save-Schema-Änderungen sind additiv und bekommen eine Migration plus Test. Ein bestehender Spielstand wird nie stillschweigend verworfen.
- `Game.gd` bleibt die einzige Instanz für Regeln und Spielzustand. UI und KI rufen dieselben Kommandos auf; keine zweite Wahrheit.
- Jede Welle liefert einen horizontalen, spielbaren Schnitt. Keine Welle ist nur Datenmodell ohne sichtbare Wirkung.
- Die UI wird schrittweise aus `Main.gd` gelöst. Der Zuschnitt steht in [`ui-kernel.md`](ui-kernel.md); kein Big-Bang-Refactor.

## Wellen

| Welle | Lieferung | Neue oder aktivierte Zustandsgrößen | Exit-Gate | Status |
|---|---|---|---|---|
| **0 — Fundament** | Versionierte Architektur-Dokumente; zentrale Save-Schicht; Schema 2; Migration v1→v2; echter Altstand als Fixture | `schema_version`, `provinces[].buildings`, `victory`; alle bisherigen Felder bleiben | `SaveMigrationTest` grün, bestehende Tests grün, Build grün | **umgesetzt** |
| **1 — Herrschaft & Dynastie** | Rat, Gesetze und Gebäude wirken; Legitimität und Fraktionen; Herrscher-Traits, Erziehung, Geheimnisse; Beziehungen verzahnen | `houses[].legitimacy`, `houses[].factions[]`, `houses[].secrets[]`, `houses[].ruler.traits[]`, `houses[].children[].education`; Schema 3 | Kanten H1–H8 und D1–D8 haben `DepthTest`; `SaveMigrationTest` v2→v3; 30-Monats-Smoke | geplant |
| **2 — Krieg & Diplomatie** | Ansprüche, Armeen, Belagerungen, Frieden und Waffenstillstände; Krieg verändert Provinzen und Dynastie | `houses[].claims[]`, `houses[].armies[]`, `wars[]`, `truces[]`, `provinces[].siege`; Schema 4 | Kanten K1–K7 haben `DepthTest`; `SaveMigrationTest` v3→v4 | geplant |
| **3 — Welt & KI** | KI nutzt Rat, Gesetze, Ehen, Geheimnisse, Ansprüche und Kriege über dieselben Kommandos; keine Cheat-Ressourcen | `houses[].ai_memory` nur falls für Persistenz nötig; sonst Schema 4 | Kanten AI1–AI5; `AiParityTest`; `SaveMigrationTest` v4→v5 nur bei Schemaänderung | geplant |
| **4 — 30-Minuten-Bogen** | Entscheidungsdichte, Ursache-Wirkungs-Log, Onboarding und Erzählfenster; Balance der vier Säulen | keine neuen Pflichtfelder | `StoryRunTest` plus manueller 30-Minuten-Lauf gemäß Depth Contract | geplant |

## Welle 0 — was tatsächlich geliefert ist

| Artefakt | Pfad | Beweis |
|---|---|---|
| Zentrale Migration und Validierung | `scripts/SaveGame.gd` | `CURRENT_VERSION = 2`, `migrate()`, `validate()`, `diff()` |
| Snapshot/Restore mit Schema 2 | `scripts/Game.gd` | `snapshot()` schreibt Gebäude und `victory`; `restore()` migriert und gibt `bool` zurück |
| Ladeabbruch bei ungültigem Stand | `scripts/Main.gd` | `_load()` prüft den Rückgabewert von `restore()` |
| Echter Altstand | `tests/fixtures/legacy_v1.json` | 10 Häuser, 49 Provinzen, keine `schema_version`, keine `buildings`, kein `victory` |
| Automatisierter Nachweis | `tests/SaveMigrationTest.gd` | Altstand → Migration → JSON-Roundtrip → Diff; negative Kontrolle entfernt `dev` |

Der Nachweis wird mit folgendem Befehl ausgeführt:

```bash
cd mobile-godot/.tools
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/SaveMigrationTest.tscn
```

Erwartete Ausgabe (gekürzt):

```text
ALTSTAND-FIXTURE OK: 10 Häuser, 49 Provinzen, alle Altfelder erhalten, Schema 2, Roundtrip identisch.
FELDVERLUST-KONTROLLE: provinces[0].dev fehlt.
SAVEMIGRATIONTEST OK: v1->v2, 9 Häuser, 49 Provinzen, Altfelder erhalten, JSON-Roundtrip identisch, Feldverlust erkannt.
```

## Welle 1 — konkreter Zuschnitt

1. **Rat:** Die drei Ratsämter werden mit realen Werten besetzt. `council.marshal` trainiert `provinces[].levy`, `council.chancellor` beeinflusst `opinion[]`, `council.steward` beeinflusst `houses[].gold`.
2. **Gesetze:** `laws.tax` verändert jährliches `gold`, `laws.levy` verändert `provinces[].levy`, `laws.succession` wählt zwischen ältestem und jüngstem Kind und schreibt `houses[].heir`.
3. **Gebäude:** `market` erhöht `houses[].gold`, `barracks` erhöht `provinces[].levy`, `walls` erhöht die Verteidigung und senkt Belagerungsschaden.
4. **Legitimität und Fraktionen:** `houses[].legitimacy` und `houses[].factions[].power` erzwingen Entscheidungen zwischen Rat, Gesetz und Krieg.
5. **Dynastie:** `ruler.traits[]`, `children[].education`, `houses[].secrets[]` und `opinion[]` werden zu lesenden und schreibenden Größen der anderen Säulen.

Welle 1 darf `Game.gd` in Module schneiden, aber nur entlang der in [`ui-kernel.md`](ui-kernel.md) definierten Grenze. Der Save-Test läuft nach jedem Schnitt.

## Welle 2 — konkreter Zuschnitt

1. **Ansprüche:** `houses[].claims[]` enthält Provinz-ID, Quelle, Stärke und Verfallsdatum. Ein Anspruch ist Voraussetzung für einen Angriff und kann Legitimität oder Fraktionen beeinflussen.
2. **Armeen:** `houses[].armies[]` bündelt Provinzen, Unterhalt und Moral. Unterhalt schreibt `houses[].gold`; Stärke schreibt Belagerung und Provinzbesitz.
3. **Belagerungen:** `provinces[].siege` hält Fortschritt, Angreifer und Verteidiger. Fortschritt verändert `buildings` und `dev`; eine Einnahme wechselt `owner`.
4. **Frieden:** `truces[]` blockiert `can_attack`; Friedensbedingungen können `claims`, `gold`, `opinion[]` und dynastische Ehen verändern.

## Welle 3 — konkreter Zuschnitt

Die KI erhält kein Sonderrecht auf Ressourcen. Sie benutzt dieselbe Kommando-Tabelle wie der Spieler:

- `council.assign`, `law.change`, `building.build`
- `claim.press`, `army.raise`, `army.move`, `siege.advance`
- `peace.offer`, `peace.accept`
- `marriage.propose`, `secret.discover`, `secret.expose`

Der Unterschied liegt nur in der Bewertungsfunktion. `AiParityTest` prüft, dass eine KI-Aktion dieselben Kosten, Abklingzeiten und Zustandsänderungen auslöst wie die Spieleraktion.

## Welle 4 — Abnahme der Erzählung

Die Messlatte steht im [`depth-contract.md`](depth-contract.md). Kurzfassung:

- mindestens 12 Entscheidungen aus mindestens drei Säulen in 30 Minuten,
- mindestens sechs nachvollziehbare Ursache-Wirkungs-Ketten mit Log-Eintrag,
- mindestens drei dynastische Ereignisse und zwei Krieg-/Diplomatie-Ereignisse,
- drei Save/Load-Checkpoints ohne Diff.

## Versionsregel

Jede Änderung an einer der vier Architekturdateien erhöht deren Dokumentversion und trägt den Grund in [`save-schema.md`](save-schema.md) ein, wenn das Speicherformat betroffen ist. Die Matrix-Zeile bekommt bei Umsetzung den Status `IST` und einen konkreten Testnamen; `TEIL` und `PLAN` bleiben sichtbar, bis der Test grün ist.
