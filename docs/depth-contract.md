# Depth Contract

> Dokumentversion: 2.1
> Stand: 2026-11-08
> Verbindlich ab: Welle 1
> Status: alle 28 Matrixkanten `IST`; DC-1 erfüllt; automatisierte Story-Probe grün; Windows-30-Minuten-Lauf BESTANDEN, Android offen

## Definition

Ein System ist tief, wenn es Entscheidungen erzwingt, deren Folgen in einem anderen System sichtbar werden und dort wieder eine Entscheidung auslösen. Ein Wert, der nur angezeigt oder nur von einem einzelnen Bildschirm geschrieben wird, ist keine Tiefe.

Die normativen Kanten stehen in [`interaction-matrix.md`](interaction-matrix.md).

## Harte Regeln

| ID | Regel | Verstoß |
|---|---|---|
| DC-1 | Jede Säule beeinflusst mindestens zwei **andere** Säulen. | Eine Säule schreibt nur in sich selbst. |
| DC-2 | Jede Kante hat mindestens einen lesenden und einen schreibenden Zugriff auf die genannte Zustandsgröße. | Ein Feld existiert, wird aber nie gelesen. |
| DC-3 | Jede dauerhafte Zustandsgröße gehört genau einem System. Andere Systeme schreiben nur über dessen Kommando. | Zwei Manager schreiben `gold` unabhängig. |
| DC-4 | Jede Zustandsänderung erzeugt einen Log-Eintrag mit Quelle, Ziel, Größe, Vorher, Nachher und Auslöser. | Ein Wert ändert sich, ohne im Log erklärbar zu sein. |
| DC-5 | Zufall ist seedbar und außerhalb der UI. Gleicher Snapshot plus gleicher Seed ergibt denselben Übergang. | `randf()` in einem Panel oder nicht reproduzierbarer Krieg. |
| DC-6 | Jede dauerhafte Größe steht im Save-Schema und überlebt Migration plus JSON-Roundtrip. | Ein Feld fehlt im Snapshot oder wird beim Laden still auf Default gesetzt. |
| DC-7 | KI und Spieler benutzen dieselben Kommandos, Kosten, Abklingzeiten und Prüfungen. | KI ignoriert `gold` oder `can_attack`. |
| DC-8 | Eine Entscheidung muss innerhalb von 24 Spielmonaten mindestens eine sichtbare Folge in einem anderen System haben. | Ein Wert ändert sich, aber keine spätere Entscheidung liest ihn. |

## Zustandsbesitz

| Bereich | Besitzt | Liest | Schreibt über |
|---|---|---|---|
| Herrschaft | `gold`, `prestige`, `laws`, `council`, `legitimacy`, `factions` | Dynastie, Krieg, Provinz | Rat, Gesetz, Bau, Hof |
| Dynastie | `ruler`, `spouse`, `children`, `heir`, `pregnant`, `lover_house`, `secrets` | Herrschaft, Krieg | Heirat, Erziehung, Intrige, Nachfolge |
| Krieg/Diplomatie | `claims`, `armies`, `truces`, `provinces[].owner/levy/siege` | Herrschaft, Dynastie, Provinz | Anspruch, Armee, Belagerung, Frieden |
| Welt/KI | dieselben Felder für KI-Häuser | alle | ausschließlich dieselben Kommandos |
| Provinz-Substrat | `buildings`, `dev`, `defense`, `name` | alle | Herrschaft (Bau), Krieg (Einnahme/Schaden) |

`Game.gd` bleibt die Transaktionsgrenze.

## Wirkungsbeleg

```gdscript
{
    "edge": "H1",
    "source": "Rat",
    "target": "Krieg",
    "state": "provinces[boiohaemum].levy",
    "kind": "levy",
    "house": 0,
    "before": 640,
    "after": 673,
    "delta": 33,
    "reason": "Marschallstraining",
}
```

Der Beleg landet in `Game.effect_log`; der Test prüft ihn. `before` und `after` werden vom zentralen `SystemicResolver` gelesen und geschrieben. Bei deaktivierter Kante wird der Effekt vollständig übersprungen.

## 30-Minuten-Messlatte

| Messung | Fenster | Schwelle | Werkzeug | Status |
|---|---|---|---|---|
| CI-Story-Probe | 120 Spielmonate, Seed `20261106` | ≥12 Entscheidungen, ≥10 Kanten, ≥3 dynastisch, ≥3 Krieg/Diplomatie, ≥2 KI, 3 Save-Roundtrips | `StoryTest` | **grün** |
| Manuelle Partie | 30 Minuten bei x3 | dieselben Schwellen plus visuelle Prüfung | Prüfprotokoll | **Windows BESTANDEN; Android offen** |

`StoryTest` erreicht 104 Entscheidungen, 24 Kanten, 7 dynastische, 6 Krieg-/Diplomatie- und 5 KI-Kanten sowie drei Roundtrips ohne Diff. Das ist ein automatisierter Proxy, keine Wall-Clock-Messung.

Eine „Entscheidung“ ist eine Wahl mit mindestens zwei legalen Optionen und unterschiedlichen Zielzuständen. Ein reiner Bestätigungsdialog zählt nicht.

Das ausführbare Prüfprotokoll für die manuelle Partie steht in [`manual-acceptance.md`](manual-acceptance.md).

## Testgates

| Gate | Umfang | Bestehenskriterium | Status |
|---|---|---|---|
| `SaveMigrationTest` | v1→v4, echter Altstand, Roundtrip, negative Feldkontrollen | Exit 0; `diff()` leer; entfernte Pflichtfelder werden erkannt | **grün** |
| `SystemicDepthTest` | H1, H2, H5 (Kaserne), D5, AI1 | positive Kette plus Negativkontrolle; Beleg im `effect_log` | **grün** |
| `FullDepthTest` | H3–H8 (Mauern), D1–D4, D6–D8, K1–K7, AI2–AI5, Gelände/Versorgung | 74 positive/negative Prüfungen | **grün** |
| `StoryTest` | 120 Monate, fester Seed | Schwellen der automatisierten Story-Probe | **grün** |
| `TouchTest` / `ShotTest` | Touch-Auswahl, Ausbau, elf UI-Bilder | Exit 0 | **grün** |
| Manuelle 30-Minuten-Partie | Windows/Android | Story-Schwellen plus visuelle Prüfung | **Windows BESTANDEN; Android offen** |

## Ist-Stand

Alle 28 Matrixzeilen sind `IST`:

- Herrschaft beeinflusst Dynastie (H2) und Krieg (H5, H8).
- Dynastie beeinflusst Herrschaft (D1, D3, D5, D7) und Krieg (D2, D4, D6, D8).
- Krieg/Diplomatie beeinflusst Herrschaft (K1, K3), Dynastie (K6), Welt (K5) und Krieg (K2, K4, K7).
- KI beeinflusst Herrschaft (AI2, AI3, AI5) und Krieg (AI1, AI4).

DC-1 ist damit erfüllt. Der Windows-30-Minuten-Lauf ist am 2026-11-08 gegen den 1.3-Build **BESTANDEN** ([Protokoll](manual-acceptance.md#windows-lauf-2026-11-08)); offen bleibt nur der Android-Lauf. Er ist kein automatischer Test und wird nicht als solcher behauptet.

## Entscheidungslog

| Datum | Entscheidung | Grund | verworfene Alternative |
|---|---|---|---|
| 2026-11-06 | Schema 2 additiv | Altstand muss ohne Verlust laden | neues Format ohne Migration |
| 2026-11-06 | `SaveGame.gd` zentral | eine Wahrheit für Migration, Validierung, Diff | Migration in `Game.gd` |
| 2026-11-06 | Ein zentraler `SystemicResolver` | Effekte, Belege und Negativkontrollen an einer Stelle | verteilte Sonderfälle |
| 2026-11-06 | `legitimacy` additiv in Schema 3 | Altstände müssen verlustfrei bleiben | neues Save-Format |
| 2026-11-06 | Schema 4 für Fraktionen, Geheimnisse, Ansprüche, Armeen, Truces, Verteidigung und Belagerung | alle neuen Kanten brauchen persistente Zustandsgrößen | flüchtige UI-Werte |
| 2026-11-06 | Ansprüche sind Pflicht für Angriff und Belagerung | K2 wird eine echte Entscheidung statt einer Anzeige | Angriff ohne Anspruch |
| 2026-11-06 | KI nutzt dieselben Kommandos | DC-7 und keine versteckten Ressourcen | eigener KI-Sonderpfad |
| 2026-11-06 | H5 zählt erst mit Kaserne **und** Mauern als `IST` | beide Zielgrößen sind getestet | H5 weiter `TEIL` lassen |
