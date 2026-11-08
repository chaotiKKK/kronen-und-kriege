# Interaktionsmatrix der vier Säulen

> Dokumentversion: 2.0
> Stand: 2026-11-06
> Gültig für Save-Schema: 4
> Status: alle 28 Kanten implementiert und positiv/negativ getestet

## Legende

Jede Zeile ist eine gerichtete Kante. `Quelle` löst aus, `Ziel` wird gelesen oder verändert. `Zustandsgröße` nennt das konkrete persistente Feld. Eine Zeile ist nur `IST`, wenn ein Test die Wirkung und eine Negativkontrolle mit `set_edge_enabled()` belegt.

| Status | Bedeutung |
|---|---|
| `IST` | Kante ist implementiert, getestet und im Save-Schema 4 persistent. |
| `TEIL` | Feld oder Aktion existiert, die Wirkung ist aber unvollständig. |
| `PLAN` | Kante ist noch nicht verdrahtet. |

## Matrix

| ID | Quelle | Ziel | Zustandsgröße | Wirkung | Auslöser | Status | Nachweis |
|---|---|---|---|---|---|---|---|
| H1 | Rat | Krieg | `council.marshal` → `provinces[].levy` | Marschallstraining abhängig von Martial und Legitimität | Jahreswechsel | IST | `SystemicDepthTest.H1` |
| H2 | Gesetze | Dynastie | `laws.succession` → `heir` | Erbfolge wählt ältestes oder jüngstes Kind | Gesetzeswechsel | IST | `SystemicDepthTest.H2` |
| H3 | Gesetze | Herrschaft | `laws.tax` → `gold` | Steuersatz verändert das Jahreseinkommen | Jahreswechsel | IST | `FullDepthTest.H3` |
| H4 | Gebäude | Herrschaft | `buildings.market` → `gold` | Markt erhöht Handelseinkommen | Jahreswechsel | IST | `FullDepthTest.H4` |
| H5 | Gebäude | Krieg | `buildings.barracks` → `levy`; `buildings.walls` → `defense` | Kaserne erhöht Aufgebot, Mauern erhöhen Verteidigung | Bau | IST | `SystemicDepthTest.H5`, `FullDepthTest.H5(Mauern)` |
| H6 | Legitimität | Herrschaft | `legitimacy` → `opinion[]`, `factions[].loyalty` | Niedrige Legitimität senkt Haltung und Fraktionstreue | Jahreswechsel | IST | `FullDepthTest.H6` |
| H7 | Fraktionen | Herrschaft | `factions[].power` → `laws.tax` | Fraktionsdruck erzwingt den höchsten Steuersatz | Jahreswechsel | IST | `FullDepthTest.H7` |
| H8 | Fraktionen | Krieg | `factions[].power` → `provinces[].levy` | Fraktionsunruhe senkt das Aufgebot der Hauptstadt | Jahreswechsel | IST | `FullDepthTest.H8` |
| D1 | Traits | Herrschaft | `ruler.traits[]` → `gold` | „Gelehrsam“ erhöht das Jahreseinkommen | Jahreswechsel | IST | `FullDepthTest.D1` |
| D2 | Traits | Krieg | `ruler.traits[]` → `provinces[].levy` | „Kriegserprobt“ erhöht das Aufgebot | Jahreswechsel | IST | `FullDepthTest.D2` |
| D3 | Erziehung | Herrschaft | `children[].education` → `ruler` | Erziehung erhöht den passenden Herrscherwert bei Nachfolge | Nachfolge | IST | `FullDepthTest.D3` |
| D4 | Erziehung | Krieg | `children[].education.martial` → `provinces[].levy` | Militärische Erziehung erhöht das Aufgebot bei Nachfolge | Nachfolge | IST | `FullDepthTest.D4` |
| D5 | Beziehungen | Herrschaft | `spouse` / `opinion[]` → `legitimacy`, `prestige` | Ehe erhöht Legitimität +5, Prestige +10 und Haltung +20 | Heirat | IST | `SystemicDepthTest.D5` |
| D6 | Beziehungen | Krieg | `opinion[]` → `can_attack` | Freundschaft (Meinung ≥ 60) blockiert einen Angriff | Kriegserklärung | IST | `FullDepthTest.D6` |
| D7 | Geheimnisse | Herrschaft | `secrets[]` → `scandal`, `opinion[]` | Veröffentlichtes Geheimnis erzeugt Skandal und Haltungsverlust | Geheimnis ausnutzen | IST | `FullDepthTest.D7` |
| D8 | Geheimnisse | Krieg | `secrets[]` → `claims[]` | Geheimnis liefert einen Anspruch auf die Zielhauptstadt | Geheimnis ausnutzen | IST | `FullDepthTest.D8` |
| K1 | Ansprüche | Herrschaft | `claims[]` → `legitimacy`, `factions[].power` | Erhobener Anspruch stärkt Legitimität und Fraktionsmacht | Anspruch erheben | IST | `FullDepthTest.K1` |
| K2 | Ansprüche | Krieg | `claims[]` → `can_attack`, `owner` | Nur ein Anspruch ermöglicht Angriff und Eroberung | Angriff | IST | `FullDepthTest.K2` |
| K3 | Armeen | Herrschaft | `armies[].upkeep` → `gold` | Armeeunterhalt wird jährlich abgezogen | Jahreswechsel | IST | `FullDepthTest.K3` |
| K4 | Armeen | Krieg | `armies[].strength` → `siege`, `owner` | Stärke treibt Belagerungsfortschritt und Einnahme | Belagerung | IST | `FullDepthTest.K4` |
| K5 | Belagerungen | Welt | `siege` → `dev`, `buildings` | Einnahme beschädigt Entwicklung und ein Gebäude | Einnahme | IST | `FullDepthTest.K5` |
| K6 | Frieden | Dynastie | `truces[]` → `spouse`, `opinion[]` | Frieden erzeugt Waffenstillstand, Haltung und ggf. Ehe | Frieden | IST | `FullDepthTest.K6` |
| K7 | Frieden | Krieg | `truces[].until` → `can_attack` | Laufender Waffenstillstand blockiert Angriffe | Angriff | IST | `FullDepthTest.K7` |
| AI1 | KI-Rat | Krieg | KI-`council.marshal` → KI-`provinces[].levy` | KI trainiert über denselben Rat und Resolver | KI-Jahreswechsel | IST | `SystemicDepthTest.AI1` |
| AI2 | KI-Steuern | Herrschaft | KI-`laws.tax` → KI-`gold` | KI wählt und nutzt denselben Steuersatz | KI-Jahreswechsel | IST | `FullDepthTest.AI2` |
| AI3 | KI-Dynastie | Herrschaft | KI-`spouse` → KI-`legitimacy`, `prestige` | KI schließt Ehen über denselben Heiratspfad | KI-Jahreswechsel | IST | `FullDepthTest.AI3` |
| AI4 | KI-Krieg | Krieg | KI-`claims[]`/`armies[]` → `siege` | KI nutzt Anspruch, Armee und Belagerung wie der Spieler | KI-Jahreswechsel | IST | `FullDepthTest.AI4` |
| AI5 | KI-Geheimnisse | Herrschaft | KI-`secrets[]` → `scandal`, `opinion[]` | KI deckt Geheimnisse über denselben Pfad auf | KI-Jahreswechsel | IST | `FullDepthTest.AI5` |

## Belege

- `tests/SystemicDepthTest.gd` prüft H1, H2, H5 (Kaserne), D5 und AI1 positiv sowie mit deaktivierter Kante. Der D5→H1-Kreislauf ist zusätzlich belegt.
- `tests/FullDepthTest.gd` prüft die übrigen 23 Kanten positiv und negativ; zusammen mit den fünf Welle-1-Kanten sind alle 28 Matrixzeilen abgedeckt.
- `tests/StoryTest.gd` spielt 120 Monate, trifft 104 Entscheidungen, sieht 24 Kanten und prüft drei Save/Load-Roundtrips ohne Diff.
- `tests/SaveMigrationTest.gd` lädt den echten v1-Altstand, migriert auf Schema 4 und prüft die neuen Pflichtfelder inklusive negativer Feldkontrollen.

## Ist-Abdeckung nach DC-1

| Quelle | Belegte Zielsysteme | Erfüllt |
|---|---|---|
| Herrschaft | Dynastie (H2), Krieg (H5, H8) | ja |
| Dynastie | Herrschaft (D1, D3, D5, D7), Krieg (D2, D4, D6, D8) | ja |
| Krieg/Diplomatie | Herrschaft (K1, K3), Dynastie (K6), Welt (K5), Krieg (K2, K4, K7) | ja |
| Welt/KI | Herrschaft (AI2, AI3, AI5), Krieg (AI1, AI4) | ja |

DC-1 ist damit erfüllt: Jede der vier Säulen beeinflusst mindestens zwei andere. Die Matrix bleibt die prüfbare Fassung des Auftrags.

## Prüfregel pro Zeile

1. Ausgangszustand erzeugen und die Quellgröße gezielt verändern.
2. Den regulären Auslöser ausführen (Jahreswechsel, Bau, Heirat, Kriegserklärung, Belagerung, Frieden, Intrige, Nachfolge).
3. Zielgröße exakt prüfen und den Beleg im `effect_log` prüfen.
4. Dieselbe Aktion mit `set_edge_enabled(edge, false)` wiederholen. Die Aktion bleibt legal, aber die Zielgröße darf sich nicht über diese Kante ändern.
5. Den Zustand über `snapshot()`/`restore()` und `SaveGame.diff()` verlustfrei prüfen; `SaveMigrationTest` deckt die Pflichtfelder ab.

## Aktueller Ist-Stand

| Kategorie | Anzahl | Zeilen |
|---|---|---|
| `IST` | 28 | H1–H8, D1–D8, K1–K7, AI1–AI5 |
| `TEIL` | 0 | — |
| `PLAN` | 0 | — |

Die automatisierte Story-Probe ist grün. Der Windows-30-Minuten-Lauf ist **BESTANDEN** ([Protokoll](manual-acceptance.md#windows-lauf-2026-11-07)); der Android-Lauf bleibt eine Abnahme außerhalb von CI und wird nicht als automatisch geprüft ausgegeben.
