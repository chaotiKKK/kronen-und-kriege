# Wellenplan

> Dokumentversion: 2.0
> Stand: 2026-11-06
> Gültig für Save-Schema: 4
> Status: Wellen 0–3 umgesetzt; Welle 4 automatisiert geprüft, manuelle 30-Minuten-Abnahme offen

## Zweck

Der Plan legt die Reihenfolge fest, in der aus dem Prototyp eine verzahnte Bronzezeit-Grand-Strategy wird. Jede Welle verändert Spielzustand, Speicherformat und Tests gemeinsam. Die Matrix in [`interaction-matrix.md`](interaction-matrix.md) ist die verbindliche Soll-Liste; der [`depth-contract.md`](depth-contract.md) definiert, wann eine Kante als umgesetzt gilt.

## Leitplanken

- Kein CK3-Code und keine CK3-Assets.
- Save-Änderungen sind additiv, versioniert und haben Migration plus Test.
- `Game.gd` bleibt die einzige Regel- und Zustandsinstanz. UI und KI rufen dieselben Kommandos auf.
- Jede Welle liefert einen spielbaren Schnitt, nicht nur ein Datenmodell.
- `Main.gd` bleibt vorerst Composition Root; die UiKernel-Extraktion ist dokumentiert, aber nicht Voraussetzung für die Systemtiefe.

## Wellen

| Welle | Lieferung | Zustandsgrößen | Exit-Gate | Status |
|---|---|---|---|---|
| **0 — Fundament** | Versionierte Dokumente, zentrale Save-Schicht, Schema 2, Migration v1→v2, echter Altstand | `schema_version`, `buildings`, `victory` | `SaveMigrationTest`, bestehende Suiten, Build | **umgesetzt** |
| **1 — Herrschaft & Dynastie** | Rat, Erbfolge, Steuern, Märkte, Gebäude, Legitimität, Fraktionen, Traits, Erziehung, Geheimnisse | `legitimacy`, `factions`, `secrets`, `ruler.traits`, `children[].education`; Schema 3/4 | H1–H8, D1–D8, AI1–AI2 | **umgesetzt** |
| **2 — Krieg & Diplomatie** | Ansprüche, Armeen, Belagerungen, Frieden, Waffenstillstände, Verteidigung | `claims`, `armies`, `truces`, `provinces[].defense/siege/siege_owner`; Schema 4 | K1–K7, H5-Mauern | **umgesetzt** |
| **3 — Welt & KI** | KI nutzt Rat, Steuern, Ehen, Ansprüche, Armeen, Belagerungen und Geheimnisse über dieselben Methoden | dieselben Felder für KI-Häuser | AI1–AI5; `FullDepthTest` | **umgesetzt** |
| **4 — 30-Minuten-Bogen** | Automatisierte Story-Probe mit Entscheidungen, Chronik und Save-Checkpoints | keine neuen Pflichtfelder | `StoryTest` plus manueller 30-Minuten-Lauf | **automatisiert geprüft; manuell offen** |

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

Der zentrale Effektpunkt bleibt `scripts/SystemicResolver.gd`. Er verarbeitet `gold`, `prestige`, `legitimacy`, `levy`, `opinion`, `building`, `heir`, `scandal`, `dev`, `defense`, `siege`, `faction_power`, `faction_loyalty`, `law`, `ruler_stat` und `truce`. Jeder Beleg enthält `edge`, `source`, `target`, `state`, `before`, `after`, `delta`, `house` und `reason`.

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

`tests/StoryTest.gd` spielt 120 Monate mit festem Seed, trifft 104 Entscheidungen, sieht 24 verschiedene Kanten, davon 7 dynastische, 6 Krieg-/Diplomatie- und 5 KI-Kanten, und prüft drei Save/Load-Roundtrips ohne Diff.

Das ist die automatisierte CI-Probe, keine Wall-Clock-Messung. Der manuelle 30-Minuten-Lauf bei x3 auf Windows oder Android bleibt offen und wird im Abschlussbericht nicht als geprüft ausgegeben.

## Nachweise

```bash
cd mobile-godot/.tools
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/SaveMigrationTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/SystemicDepthTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/FullDepthTest.tscn
APPDATA="$PWD/appdata" ./godot.exe --headless --path .. res://tests/StoryTest.tscn
```

## Versionsregel

Jede Änderung an einer Architekturdatei erhöht die Dokumentversion. Bei Save-Änderungen wird zusätzlich [`save-schema.md`](save-schema.md) aktualisiert. Eine Matrixzeile wird nur `IST`, wenn Positiv- und Negativkontrolle grün sind und die Zustandsgröße im Save-Schema liegt.
