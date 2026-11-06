# Depth Contract

> Dokumentversion: 1.0
> Stand: 2026-11-06
> Verbindlich ab: Welle 1
> Status Welle 0: Speicherpfad erfüllt; Systemkanten noch Soll

## Definition

Ein System ist tief, wenn es Entscheidungen erzwingt, deren Folgen in einem anderen System sichtbar werden und dort wieder eine Entscheidung auslösen. Ein Wert, der nur angezeigt oder nur von einem einzelnen Bildschirm geschrieben wird, ist keine Tiefe.

Die normativen Kanten stehen in [`interaction-matrix.md`](interaction-matrix.md). Jede Zeile dort ist eine gerichtete Kante mit Quelle, Ziel und konkreter Zustandsgröße.

## Harte Regeln

| ID | Regel | Verstoß |
|---|---|---|
| DC-1 | Jede Säule beeinflusst mindestens zwei **andere** Säulen. | Eine Säule schreibt nur in sich selbst. |
| DC-2 | Jede Kante hat mindestens einen lesenden und einen schreibenden Zugriff auf die genannte Zustandsgröße. | Ein Feld existiert, wird aber nie gelesen. |
| DC-3 | Jede dauerhafte Zustandsgröße gehört genau einem System. Andere Systeme schreiben nur über dessen Kommando. | Zwei Manager schreiben `gold` unabhängig. |
| DC-4 | Jede Zustandsänderung erzeugt einen Log-Eintrag mit Quelle, Ziel, Größe, Vorher, Nachher und Auslöser. | Ein Wert ändert sich, ohne im Log erklärbar zu sein. |
| DC-5 | Zufall ist seedbar und außerhalb der UI. Gleicher Snapshot plus gleicher Seed ergibt denselben Übergang. | `randf()` in einem Panel oder nicht reproduzierbarer Krieg. |
| DC-6 | Jede dauerhafte Größe steht im Save-Schema und überlebt Migration plus JSON-Roundtrip. | Ein Feld fehlt im Snapshot oder wird beim Laden still auf Default gesetzt. |
| DC-7 | KI und Spieler benutzen dieselben Kommandos, Kosten, Abklingzeiten und Prüfungen. KI hat keine versteckten Ressourcen. | KI ignoriert `gold` oder `can_attack`. |
| DC-8 | Eine Entscheidung muss innerhalb von 24 Spielmonaten mindestens eine sichtbare Folge in einem anderen System haben. | Ein Wert ändert sich, aber keine spätere Entscheidung liest ihn. |

## Zustandsbesitz

| Bereich | Besitzt | Liest | Schreibt über |
|---|---|---|---|
| Herrschaft | `houses[].gold`, `prestige`, `laws`, `council`, `legitimacy`, `factions` | Dynastie, Krieg, Provinz | `Game`-Kommandos für Rat, Gesetz, Bau, Hof |
| Dynastie | `houses[].ruler`, `spouse`, `children`, `heir`, `pregnant`, `lover_house`, `secrets` | Herrschaft, Krieg | Heirat, Erziehung, Intrige, Nachfolge |
| Krieg/Diplomatie | `houses[].claims`, `armies`, `wars`, `truces`; `provinces[].owner`, `levy`, `siege` | Herrschaft, Dynastie, Provinz | Anspruch, Armee, Belagerung, Frieden |
| Welt/KI | dieselben Felder für KI-Häuser; optional `houses[].ai_memory` | alle | ausschließlich dieselben Kommandos |
| Provinz-Substrat | `provinces[].buildings`, `dev`, `name` | alle | Herrschaft (Bau), Krieg (Besitz/Schaden) |

`Game.gd` bleibt die Transaktionsgrenze. Ein System darf nicht direkt in ein fremdes Feld schreiben; es ruft die Methode des Besitzers auf.

## Wirkungsbeleg

Jede schreibende Aktion erzeugt genau einen Beleg:

```gdscript
{
    "source": "council.marshal",
    "target": "provinces[alba].levy",
    "before": 820,
    "after": 900,
    "delta": 80,
    "cause": "training",
    "decision_id": "council_assign_0042",
}
```

Der Beleg landet im Spiel-Log und optional im `decision_log` des Save-Schemas, sobald Welle 1 ihn persistiert. Die UI zeigt ihn als erzählerische Zeile, nicht als Debug-Dump.

## 30-Minuten-Messlatte

Die Wall-Clock-Messung ist nicht deterministic genug für CI. Deshalb gibt es zwei Messungen:

| Messung | Fenster | Schwelle | Werkzeug |
|---|---|---|---|
| CI-Story-Probe | 360 Spielmonate, Seed fest | mindestens 12 Entscheidungen, 6 Kanten, 3 dynastische Ereignisse, 2 Krieg-/Diplomatie-Ereignisse | `StoryRunTest` (Welle 4) |
| Manuelle Partie | 30 Minuten bei x3, Ereignisse pausieren | dieselben Schwellen; zusätzlich 3 Save/Load-Checkpoints ohne Diff | Prüfprotokoll im Bericht |

Eine „Entscheidung“ ist eine Wahl mit mindestens zwei legalen Optionen und unterschiedlichen Zielzuständen. Ein reiner Bestätigungsdialog zählt nicht.

Eine „Kette“ ist:

1. Entscheidung ändert Zustand A,
2. innerhalb von 24 Monaten liest ein anderes System A,
3. daraus folgt eine neue Entscheidung oder ein sichtbares Ereignis,
4. der Log-Beleg nennt A als Ursache.

## Testgates

| Gate | Umfang | Bestehenskriterium |
|---|---|---|
| `SaveMigrationTest` | Schema 1→2, echter Altstand, Roundtrip, negative Feldkontrolle | Exit 0; `diff()` leer; ein entfernter Pflichtwert erzeugt Fehler |
| `DepthTest.H*` | Rat, Gesetz, Gebäude, Legitimität, Fraktionen | Kante H1–H8: Quelle ändern, Zielwert exakt prüfen, Save/Load ohne Diff |
| `DepthTest.D*` | Traits, Erziehung, Beziehungen, Geheimnisse | Kante D1–D8: gleiche Prüfung |
| `DepthTest.K*` | Ansprüche, Armeen, Belagerungen, Frieden | Kante K1–K7: gleiche Prüfung |
| `AiParityTest` | KI nutzt dieselben Kommandos | gleiche Kosten und Zustandsänderungen wie Spieleraktion |
| `StoryRunTest` | 360 Monate, fester Seed | Schwellen der 30-Minuten-Messlatte |
| `SaveMigrationTest` ab Welle 1 | v2→v3, v3→v4 usw. | jede Version hat einen Fixture-Stand und einen Roundtrip |

## Ist-Stand und ehrliche Lücke

Welle 0 erfüllt DC-6 für das aktuelle Schema und die bekannten Felder. Die Dokumente und die Matrix sind die prüfbare Fassung der Systemtiefe, aber **noch nicht deren Umsetzung**:

- `council` und `laws` existieren als Daten, haben aber keine Regelwirkung.
- `buildings` existiert im Schema, aber es gibt noch keine Bauaktion und keine Erntewirkung.
- `legitimacy`, `factions`, `secrets`, `ruler.traits` und `education` fehlen.
- Ansprüche, Armeen, Belagerungen und Frieden fehlen; `attack` ist ein sofortiger Vergleich.
- Die KI benutzt weder Rat noch Gesetze, Ansprüche oder Kriege.

Diese Lücken sind Welle 1–3. Eine Matrix-Zeile wird erst `IST`, wenn ihr `DepthTest` grün ist. Die Mission ist erst erfüllt, wenn alle vier Säulen mindestens zwei andere nach DC-1 beeinflussen und die 30-Minuten-Messlatte belegt ist.

## Entscheidungslog

Jede Welle führt ein kurzes Entscheidungslog im Bericht:

| Datum | Entscheidung | Grund | verworfene Alternative |
|---|---|---|---|
| 2026-11-06 | Schema 2 additiv, nicht neues Format | Altstand muss ohne Zustandsverlust laden | neues Save-Format ohne Migration |
| 2026-11-06 | `SaveGame.gd` zentral | eine Wahrheit für Migration, Validierung, Diff | Migration in `Game.gd` |
| 2026-11-06 | UiKernel nur UI-Zustand | Regeln bleiben in `Game.gd` | zweiter Spielzustand in Panels |
