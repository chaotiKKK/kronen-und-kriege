# Depth Contract

> Dokumentversion: 1.1
> Stand: 2026-11-06
> Verbindlich ab: Welle 1
> Status Welle 1: erster Durchstich belegt (H1, H2, D5, AI1 `IST`; H5 teilweise); DC-1 noch nicht vollständig

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
    "edge": "H1",
    "source": "Rat",
    "target": "Krieg",
    "state": "provinces[alba].levy",
    "kind": "levy",
    "house": 0,
    "before": 820,
    "after": 900,
    "delta": 80,
    "reason": "Marschallstraining",
}
```

Der Beleg landet in `Game.effect_log`; die UI zeigt die daraus abgeleitete erzählerische Zeile, nicht den Debug-Dump. `before` und `after` werden vom zentralen `SystemicResolver` vor und nach der Zustandsänderung gelesen.

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
| `SaveMigrationTest` | Schema 1/2→3, echter Altstand, Roundtrip, negative Feldkontrollen | Exit 0; `diff()` leer; entferntes `dev` und entfernte `legitimacy` erzeugen Fehler |
| `SystemicDepthTest` | H1, H2, H5 (Kaserne), D5, AI1 | positive Kette plus Negativkontrolle mit `set_edge_enabled()`; Beleg im `effect_log` |
| `DepthTest.H*` (offen) | H3, H4, H6–H8 | Kante H1–H8: Quelle ändern, Zielwert exakt prüfen, Save/Load ohne Diff |
| `DepthTest.D*` (offen) | D1–D4, D6–D8 | Kante D1–D8: gleiche Prüfung |
| `DepthTest.K*` (offen) | Ansprüche, Armeen, Belagerungen, Frieden | Kante K1–K7: gleiche Prüfung |
| `AiParityTest` (offen) | KI nutzt alle dieselben Kommandos | AI1 ist im `SystemicDepthTest` belegt; AI2–AI5 folgen |
| `StoryRunTest` (offen) | 360 Monate, fester Seed | Schwellen der 30-Minuten-Messlatte |
| `SaveMigrationTest` ab Welle 2 | v3→v4 usw. | jede Version hat einen Fixture-Stand und einen Roundtrip |

## Ist-Stand und ehrliche Lücke

Welle 0 erfüllt DC-6 für das aktuelle Schema und die bekannten Felder. Der Welle-1-Durchstich belegt jetzt einen Teil der Systemtiefe:

- `council.marshal` trainiert `provinces[].levy` über `H1`; Kanzler und Verwalter haben noch keine Wirkung.
- `laws.succession` schreibt `houses[].heir` über `H2`; `laws.tax` und `laws.levy` haben noch keine Jahreswirkung.
- `barracks` erhöht `provinces[].levy` über `H5`; `market` und die Mauer-Verteidigung fehlen noch.
- `houses[].legitimacy` existiert, wird durch die Ehe (`D5`) geschrieben und vom Marschallstraining gelesen; Fraktionen, Geheimnisse, Traits und Erziehung fehlen.
- Ansprüche, Armeen, Belagerungen und Frieden fehlen; `attack` ist ein sofortiger Vergleich.
- Die KI benutzt für `AI1` denselben Rat und denselben Resolver; Gesetze, Ehen, Ansprüche und Kriege folgen.

DC-1 ist noch nicht vollständig erfüllt: Herrschaft beeinflusst Dynastie und Krieg, Dynastie beeinflusst Herrschaft, KI beeinflusst Krieg, aber Krieg/Diplomatie hat noch keine ausgehende belegte Kante. Die Mission ist erst erfüllt, wenn alle vier Säulen mindestens zwei andere nach DC-1 beeinflussen und die 30-Minuten-Messlatte belegt ist.

## Entscheidungslog

Jede Welle führt ein kurzes Entscheidungslog im Bericht:

| Datum | Entscheidung | Grund | verworfene Alternative |
|---|---|---|---|
| 2026-11-06 | Schema 2 additiv, nicht neues Format | Altstand muss ohne Zustandsverlust laden | neues Save-Format ohne Migration |
| 2026-11-06 | `SaveGame.gd` zentral | eine Wahrheit für Migration, Validierung, Diff | Migration in `Game.gd` |
| 2026-11-06 | UiKernel nur UI-Zustand | Regeln bleiben in `Game.gd` | zweiter Spielzustand in Panels |
| 2026-11-06 | Ein zentraler `SystemicResolver` für Welle-1-Kanten | Effekte, Belege und Negativkontrollen an einer Stelle | verteilte Sonderfälle in `Game.gd` |
| 2026-11-06 | `legitimacy` additiv in Schema 3 | Altstände und `legacy_v1.json` müssen verlustfrei bleiben | neues Save-Format ohne Migration |
