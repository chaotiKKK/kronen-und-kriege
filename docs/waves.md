# Wellenplan

> Dokumentversion: 1.1
> Stand: 2026-11-06
> Gültig für Save-Schema: 3
> Status: Welle 0 umgesetzt; Welle 1 als erster Durchstich teilweise umgesetzt; Wellen 2–4 geplant

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
| **1 — Herrschaft & Dynastie** | Erster Durchstich: Rat, Erbfolgegesetz, Kaserne, Ehe und KI-Rat wirken über einen zentralen Resolver; Legitimität als neue Zustandsgröße | `houses[].legitimacy`; Schema 3 | `SystemicDepthTest` für H1, H2, H5 (Kaserne), D5, AI1 inklusive Negativkontrollen; `SaveMigrationTest` v1→v3; Windows-Export | **teilweise umgesetzt (Durchstich)** |
| **2 — Krieg & Diplomatie** | Ansprüche, Armeen, Belagerungen, Frieden und Waffenstillstände; Krieg verändert Provinzen und Dynastie | `houses[].claims[]`, `houses[].armies[]`, `wars[]`, `truces[]`, `provinces[].siege`; Schema 4 | Kanten K1–K7 haben `DepthTest`; `SaveMigrationTest` v3→v4 | geplant |
| **3 — Welt & KI** | KI nutzt Rat, Gesetze, Ehen, Geheimnisse, Ansprüche und Kriege über dieselben Kommandos; keine Cheat-Ressourcen | `houses[].ai_memory` nur falls für Persistenz nötig; sonst Schema 4 | Kanten AI1–AI5; `AiParityTest`; `SaveMigrationTest` v4→v5 nur bei Schemaänderung | geplant |
| **4 — 30-Minuten-Bogen** | Entscheidungsdichte, Ursache-Wirkungs-Log, Onboarding und Erzählfenster; Balance der vier Säulen | keine neuen Pflichtfelder | `StoryRunTest` plus manueller 30-Minuten-Lauf gemäß Depth Contract | geplant |

## Welle 0 — was tatsächlich geliefert ist

| Artefakt | Pfad | Beweis |
|---|---|---|
| Zentrale Migration und Validierung | `scripts/SaveGame.gd` | `CURRENT_VERSION = 3`; `migrate()`, `validate()`, `diff()`; Welle 0 führte Schema 2 ein |
| Snapshot/Restore mit Schema 3 | `scripts/Game.gd` | `snapshot()` schreibt Gebäude, `victory` und `legitimacy`; `restore()` migriert und gibt `bool` zurück |
| Ladeabbruch bei ungültigem Stand | `scripts/Main.gd` | `_load()` prüft den Rückgabewert von `restore()` |
| Echter Altstand | `tests/fixtures/legacy_v1.json` | 10 Häuser, 49 Provinzen, keine `schema_version`, keine `buildings`, kein `victory`, keine `legitimacy` |
| Automatisierter Nachweis | `tests/SaveMigrationTest.gd` | Altstand → Migration → JSON-Roundtrip → Diff; negative Kontrollen entfernen `dev` und `legitimacy` |

Der Nachweis wird mit folgendem Befehl ausgeführt:

```bash
cd mobile-godot/.tools
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/SaveMigrationTest.tscn
```

Erwartete Ausgabe (gekürzt):

```text
ALTSTAND-FIXTURE OK: 10 Häuser, 49 Provinzen, alle Altfelder erhalten, Schema 3, legitimacy=50, Roundtrip identisch.
FELDVERLUST-KONTROLLE: provinces[0].dev fehlt.
LEGITIMITÄTS-KONTROLLE: houses[0].legitimacy fehlt.
SAVEMIGRATIONTEST OK: v1->v3, 9 Häuser, 49 Provinzen, Altfelder erhalten, legitimacy additiv, JSON-Roundtrip identisch, Feldverlust erkannt.
```

## Welle 1 — erster Durchstich (umgesetzt)

Der Durchstich ist bewusst schmal: fünf Kanten, ein zentraler Auflösepunkt, ein gemeinsamer Pfad für Spieler und KI.

| Kante | Quellsystem | Fließende Zustandsgröße | Zielsystem | Auslöser |
|---|---|---|---|---|
| H1 | Rat | `houses[].council.marshal` → `provinces[].levy` | Krieg | Jahreswechsel |
| H2 | Gesetze | `houses[].laws.succession` → `houses[].heir` | Dynastie | Gesetzeswechsel |
| H5 | Gebäude | `provinces[].buildings.barracks` → `provinces[].levy` | Krieg | Bau |
| D5 | Beziehungen | `houses[].spouse` → `houses[].legitimacy`, `prestige`, `opinion[]` | Herrschaft | Ehe |
| AI1 | KI-Rat | KI-`council.marshal` → KI-`provinces[].levy` | Krieg | KI-Jahreswechsel |

Zentraler Auflösepunkt ist `scripts/SystemicResolver.gd`. Er verarbeitet Effekte der Arten `levy`, `gold`, `prestige`, `legitimacy`, `opinion`, `building` und `heir`. Jeder angewandte Effekt erzeugt einen Beleg in `Game.effect_log` mit `edge`, `source`, `target`, `state`, `before`, `after`, `delta`, `house` und `reason`. Die Kante `H5` ist nur für die Kaserne belegt; der Maueranteil bleibt offen.

Der Spieler erreicht die Mechanik über das neue Modal „Herrschaft“ im Hofpanel: Ratsämter wechseln, Erbfolgegesetz ändern, Kaserne oder Mauern bauen. Die KI ruft im Jahreswechsel `run_ai_turn()` auf und benutzt dieselben Methoden `assign_council()`, `set_law()` und `build()` sowie denselben Resolver. Es gibt keinen KI-Sonderpfad.

Nachweis:

```bash
cd mobile-godot/.tools
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/SystemicDepthTest.tscn
```

Erwartete Ausgabe (gekürzt):

```text
H1 OK: Rat/Marschall -> Krieg/levy +11 ...
NEGATIV H1 OK: deaktivierte Kante erzeugt keinen Marschall-Effekt.
H2 OK: Erbfolgegesetz -> Dynastie/heir Alt -> Jung.
NEGATIV H2 OK: deaktivierte Kante lässt den Erben unverändert.
H5 OK: Gebäude Kaserne -> Krieg/levy +60 (Stufe 1).
NEGATIV H5 OK: Gebäude entsteht, aber die Levy-Kante bleibt aus.
D5 OK: Ehe -> Herrschaft/legitimität 50 -> 55, Prestige +10.
NEGATIV D5 OK: Ehe besteht, aber Legitimität bleibt unverändert.
AI1 OK: KI-Marschall -> Krieg/levy +12 über denselben Resolver.
NEGATIV AI1 OK: deaktivierte KI-Kante erzeugt keinen Trainingsbeleg.
SYSTEMICDEPTHTEST OK: H1, H2, H5, D5, AI1 positiv; alle fünf Negativkontrollen ohne Zieländerung; 38 Prüfungen.
```

## Welle 1 — noch offen

1. **Rat vollständig:** Kanzler → `opinion[]` und Verwalter → `gold` sind noch nicht an den Resolver angeschlossen.
2. **Gesetze vollständig:** `laws.tax` und `laws.levy` haben noch keine Jahreswirkung.
3. **Gebäude vollständig:** `market` → `gold` und Mauern → Belagerungsverteidigung fehlen; H5 bleibt deshalb `TEIL`.
4. **Legitimität und Fraktionen:** H6–H8, D1–D4 und D6–D8 sind noch nicht verdrahtet.
5. **30-Monats-Smoke:** Der Durchstich hat Kantentests, aber noch keinen Story-Lauf über 30 Monate.

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

Der Unterschied liegt nur in der Bewertungsfunktion. `AiParityTest` prüft, dass eine KI-Aktion dieselben Kosten, Abklingzeiten und Zustandsänderungen auslöst wie die Spieleraktion. Der erste Pfad dafür ist mit `AI1` bereits belegt.

## Welle 4 — Abnahme der Erzählung

Die Messlatte steht im [`depth-contract.md`](depth-contract.md). Kurzfassung:

- mindestens 12 Entscheidungen aus mindestens drei Säulen in 30 Minuten,
- mindestens sechs nachvollziehbare Ursache-Wirkungs-Ketten mit Log-Eintrag,
- mindestens drei dynastische Ereignisse und zwei Krieg-/Diplomatie-Ereignisse,
- drei Save/Load-Checkpoints ohne Diff.

## Versionsregel

Jede Änderung an einer der vier Architekturdateien erhöht deren Dokumentversion und trägt den Grund in [`save-schema.md`](save-schema.md) ein, wenn das Speicherformat betroffen ist. Die Matrix-Zeile bekommt bei Umsetzung den Status `IST` und einen konkreten Testnamen; `TEIL` und `PLAN` bleiben sichtbar, bis der Test grün ist.
