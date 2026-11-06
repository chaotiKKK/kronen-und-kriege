# Interaktionsmatrix der vier Säulen

> Dokumentversion: 1.1
> Stand: 2026-11-06
> Gültig für Save-Schema: 3
> Status: erster Welle-1-Durchstich; H1, H2, D5 und AI1 sind `IST`, H5 ist teilweise belegt

## Legende

Jede Zeile ist genau eine gerichtete Kante. `Quelle` ist das auslösende System, `Ziel` das lesende oder veränderte System, `Zustandsgröße` das konkrete Feld.

| Status | Bedeutung |
|---|---|
| `IST` | Kante ist vollständig implementiert und durch einen Test belegt. |
| `TEIL` | Feld oder Aktion existiert, aber die Wirkung ist unvollständig oder nur einseitig. |
| `PLAN W1/W2/W3` | Kante ist für Welle 1, 2 oder 3 vorgesehen; noch keine Wirkung. |

`Nachweis` nennt den Test, der die Kante belegt. Ein Matrix-Eintrag ohne Test darf nicht `IST` werden.

## Matrix

| ID | Quelle | Ziel | Zustandsgröße | Wirkung | Auslöser | Status | Nachweis |
|---|---|---|---|---|---|---|---|
| H1 | Rat | Krieg | `houses[].council.marshal` → `provinces[].levy` | Marschall trainiert Truppen; Bonus abhängig von `courtiers[marshal].martial` und `houses[].legitimacy` | Jahreswechsel | IST | `SystemicDepthTest.H1` |
| H2 | Gesetze | Dynastie | `houses[].laws.succession` → `houses[].heir` | Erbfolgegesetz wählt ältestes oder jüngstes Kind; dieselbe Wahl trifft die Nachfolge | Gesetzeswechsel / Tod des Herrschers | IST | `SystemicDepthTest.H2` |
| H3 | Gesetze | Herrschaft | `houses[].laws.tax` → `houses[].gold` | Steuersatz verändert Jahreseinkommen | Jahreswechsel | PLAN W1 | `DepthTest.H3` |
| H4 | Gebäude | Herrschaft | `provinces[].buildings.market` → `houses[].gold` | Markt erhöht Handelseinkommen der Provinz | Jahreswechsel | TEIL | `DepthTest.H4` |
| H5 | Gebäude | Krieg | `provinces[].buildings.barracks` / `walls` → `provinces[].levy` / Verteidigung | Kaserne erhöht Aufgebot; Mauer senkt Belagerungsschaden | Bau abgeschlossen / Angriff | TEIL | `SystemicDepthTest.H5` (nur Kaserne → `levy`) |
| H6 | Legitimität | Herrschaft | `houses[].legitimacy` → `opinion[]` / `factions[].loyalty` | Niedrige Legitimität senkt Haltung und erhöht Fraktionsdruck | Thronwechsel / Gesetzesbruch | PLAN W1 | `DepthTest.H6` |
| H7 | Fraktionen | Herrschaft | `houses[].factions[].power` → `houses[].laws` / `council` | Fraktion erzwingt Gesetz oder Ratsbesetzung | Macht über Schwelle | PLAN W1 | `DepthTest.H7` |
| H8 | Fraktionen | Krieg | `houses[].factions[].power` → `provinces[].levy` | Unruhe hält Aufgebot zurück oder erzwingt Krieg | Ultimatum / Kriegserklärung | PLAN W1 | `DepthTest.H8` |
| D1 | Traits | Herrschaft | `houses[].ruler.traits[]` → `houses[].council` / `gold` | Traits verändern Rats effektivität und Verwaltung | Regierungsantritt / Ratssitzung | PLAN W1 | `DepthTest.D1` |
| D2 | Traits | Krieg | `houses[].ruler.traits[]` → `provinces[].levy` / Angriffsstärke | Kriegerisch erhöht Aufgebot, vorsichtig senkt Risiko | Krieg / Belagerung | PLAN W1 | `DepthTest.D2` |
| D3 | Erziehung | Herrschaft | `houses[].children[].education` → `houses[].ruler` | Erziehung setzt Werte des Erben bei Nachfolge | Nachfolge | PLAN W1 | `DepthTest.D3` |
| D4 | Erziehung | Krieg | `houses[].children[].education.martial` → `provinces[].levy` | Kriegsausbildung erhöht späteres Aufgebot | Nachfolge / Krieg | PLAN W1 | `DepthTest.D4` |
| D5 | Beziehungen | Herrschaft | `houses[].spouse` / `opinion[]` → `houses[].legitimacy` / `prestige` | Erfolgreiche Ehe erhöht Legitimität +5, Prestige +10 und Haltung +20 | Heirat | IST | `SystemicDepthTest.D5` |
| D6 | Beziehungen | Krieg | `opinion[]` → `can_attack` / `truces[]` | Allianz oder Freundschaft blockiert Angriff | Kriegserklärung | PLAN W2 | `DepthTest.D6` |
| D7 | Geheimnisse | Herrschaft | `houses[].secrets[]` → `scandal` / `opinion[]` | Entdecktes Geheimnis erzeugt Skandal und Haltungsverlust | Aufdeckung / Monatswechsel | TEIL | `DepthTest.D7` |
| D8 | Geheimnisse | Krieg | `houses[].secrets[]` → `claims[]` / `truces[]` | Geheimnis liefert Anspruch oder Friedenshebel | Intrige / Friedensverhandlung | PLAN W2 | `DepthTest.D8` |
| K1 | Ansprüche | Herrschaft | `houses[].claims[]` → `houses[].legitimacy` / `factions[].power` | Durchgesetzter Anspruch stärkt oder belastet Herrschaft | Kriegserklärung / Frieden | PLAN W2 | `DepthTest.K1` |
| K2 | Ansprüche | Krieg | `houses[].claims[]` → `can_attack` / `provinces[].owner` | Nur ein Anspruch erlaubt Eroberung | Angriff | TEIL | `DepthTest.K2` |
| K3 | Armeen | Herrschaft | `houses[].armies[].upkeep` → `houses[].gold` | Heer kostet Unterhalt und erzwingt Steuerentscheidung | Monatswechsel | PLAN W2 | `DepthTest.K3` |
| K4 | Armeen | Krieg | `houses[].armies[].strength` → `provinces[].siege` / `owner` | Armeestärke bestimmt Belagerung und Einnahme | Belagerung | PLAN W2 | `DepthTest.K4` |
| K5 | Belagerungen | Herrschaft | `provinces[].siege` → `provinces[].dev` / `buildings` | Belagerung zerstört Entwicklung und Gebäude | Belagerungsrunde | PLAN W2 | `DepthTest.K5` |
| K6 | Frieden | Dynastie | `truces[]` / Friedensvertrag → `houses[].spouse` / `opinion[]` | Frieden erzwingt Heirat, Geisel oder Haltungsänderung | Friedensschluss | PLAN W2 | `DepthTest.K6` |
| K7 | Frieden | Krieg | `truces[].until` → `can_attack` | Waffenstillstand blockiert Angriff bis zum Datum | Angriff | PLAN W2 | `DepthTest.K7` |
| AI1 | KI-Rat | Krieg | `houses[i].council.marshal` → `houses[i].provinces[].levy` | KI trainiert mit demselben Ratsamt und demselben Resolver | KI-Jahreswechsel | IST | `SystemicDepthTest.AI1` |
| AI2 | KI-Gesetze | Herrschaft | `houses[i].laws.tax` → `houses[i].gold` | KI wählt Steuersatz nach derselben Formel | KI-Jahreswechsel | PLAN W3 | `AiParityTest.AI2` |
| AI3 | KI-Dynastie | Herrschaft | `houses[i].spouse` / `opinion[i]` → `opinion[player]` / `prestige` | KI-Ehen verändern Netzwerk und Haltung des Spielers | KI-Heirat | PLAN W3 | `AiParityTest.AI3` |
| AI4 | KI-Krieg | Dynastie | `houses[i].claims[]` / `armies[]` → `houses[].spouse` / `captive` | KI-Krieg erzeugt Geisel, Zwangsheirat oder Frieden | KI-Frieden | PLAN W3 | `AiParityTest.AI4` |
| AI5 | KI-Geheimnisse | Herrschaft | `houses[i].secrets[]` → `scandal` / `opinion[]` | KI deckt Geheimnisse auf und erzeugt Skandal | KI-Intrige | PLAN W3 | `AiParityTest.AI5` |

## Welle-1-Belege

`tests/SystemicDepthTest.gd` prüft jede der folgenden Ketten positiv und danach mit deaktivierter Kante:

| Kante | Eingriff | Zielgröße | Positiv | Negativkontrolle |
|---|---|---|---|---|
| H1 | Marschall im Rat besetzen | `provinces[].levy` | `H1`-Beleg, Levy steigt | `set_edge_enabled("H1", false)` ⇒ kein `H1`-Beleg, kein Trainingsdelta |
| H2 | `laws.succession` auf `youngest` setzen | `houses[].heir` | Erbe wechselt von „Alt“ zu „Jung“ | `set_edge_enabled("H2", false)` ⇒ Gesetz ändert sich, Erbe bleibt |
| H5 | Kaserne bauen | `provinces[].levy` | `H5`-Beleg, Levy steigt | `set_edge_enabled("H5", false)` ⇒ Gebäude entsteht, Levy bleibt |
| D5 | Ehe schließen | `houses[].legitimacy` | Legitimität +5, Prestige +10 | `set_edge_enabled("D5", false)` ⇒ Ehe besteht, Legitimität bleibt |
| AI1 | KI-Marschall einsetzen, Jahreswechsel | `houses[1].provinces[].levy` | `AI1`-Beleg, KI-Levy steigt | `set_edge_enabled("AI1", false)` ⇒ kein KI-Beleg |

Der Kreislauf D5 → H1 ist zusätzlich belegt: Eine Ehe hebt die Legitimität von 39 auf 44 und erhöht dadurch den Trainingsbetrag des Marschalls. Alle fünf Ketten laufen über `scripts/SystemicResolver.gd` und schreiben einen Beleg mit `edge`, `source`, `target`, `state`, `before`, `after`, `delta`, `house` und `reason` in `Game.effect_log`.

H5 bleibt in der Matrix `TEIL`, weil der Test nur Kaserne → `levy` beweist. Der Maueranteil (Belagerungsverteidigung) ist noch nicht verdrahtet.

## Ist-Abdeckung nach DC-1

| Quelle | Ist-Kanten | Tatsächlich erreichte Zielsäulen |
|---|---|---|
| Herrschaft | H1, H2, H5 (Kaserne) | Krieg, Dynastie |
| Dynastie | D5 | Herrschaft |
| Krieg/Diplomatie | noch keine `IST`-Kante | — |
| Welt/KI | AI1 | Krieg |

DC-1 ist damit **noch nicht vollständig erfüllt**: Herrschaft beeinflusst bereits zwei andere Säulen; Dynastie und KI beeinflussen je eine; Krieg/Diplomatie hat noch keine belegte ausgehende Kante. Die Matrix bleibt die prüfbare Fassung des Auftrags, nicht die Behauptung, alle vier Säulen seien fertig.

## Prüfregel pro Zeile

Jeder `SystemicDepthTest` führt für eine Kante dieselben Schritte aus:

1. Ausgangszustand erzeugen und die Quellgröße gezielt ändern.
2. Den regulären Auslöser ausführen (Jahreswechsel, Gesetzeswechsel, Bau, Ehe).
3. Zielgröße exakt gegen den erwarteten Wert prüfen und den Wirkungsbeleg im `effect_log` prüfen.
4. Dieselbe Aktion mit `set_edge_enabled(edge, false)` wiederholen. Die Aktion bleibt legal, aber die Zielgröße darf sich nicht über diese Kante ändern.
5. Den neuen Zustand über `snapshot()`/`restore()` und `SaveGame.diff()` verlustfrei prüfen; das übernimmt `SaveMigrationTest` für die neuen Pflichtfelder.

Ein Test, der nur „kein Absturz“ prüft, gilt nicht als Nachweis. Eine Kante ist erst `IST`, wenn Positiv- und Negativkontrolle grün sind und die Zustandsgröße im Save-Schema liegt.

## Aktueller Ist-Stand

| Kategorie | Anzahl | Zeilen |
|---|---|---|
| `IST` | 4 | H1, H2, D5, AI1 |
| `TEIL` | 4 | H4, H5, D7, K2 |
| `PLAN` | 20 | alle übrigen |

Welle 1 beginnt mit H1–H8 und D1–D8; Welle 2 mit K1–K7; Welle 3 mit AI1–AI5. Der erste Durchstich belegt vier vollständige Kanten und eine Teilkante. Die übrigen Zeilen bleiben sichtbar offen.
