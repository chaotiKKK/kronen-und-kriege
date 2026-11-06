# Interaktionsmatrix der vier Säulen

> Dokumentversion: 1.0
> Stand: 2026-11-06
> Gültig für Save-Schema: 2
> Status: Soll-Matrix; Welle 0 hat den Speicherpfad, nicht die Gameplay-Verdrahtung

## Legende

Jede Zeile ist genau eine gerichtete Kante. `Quelle` ist das auslösende System, `Ziel` das lesende oder veränderte System, `Zustandsgröße` das konkrete Feld.

| Status | Bedeutung |
|---|---|
| `IST` | Kante ist vollständig implementiert und durch einen Test belegt. |
| `TEIL` | Feld oder Aktion existiert, aber die Wirkung ist unvollständig oder nur einseitig. |
| `PLAN W1/W2/W3` | Kante ist für Welle 1, 2 oder 3 vorgesehen; noch keine Wirkung. |

`Nachweis` nennt den Test, der die Kante künftig belegen muss. Ein Matrix-Eintrag ohne Test darf nicht `IST` werden.

## Matrix

| ID | Quelle | Ziel | Zustandsgröße | Wirkung | Auslöser | Status | Nachweis |
|---|---|---|---|---|---|---|---|
| H1 | Rat | Krieg | `houses[].council.marshal` → `provinces[].levy` | Marschall trainiert Truppen; Bonus abhängig von `courtiers[marshal].martial` | Ratssitzung / Monatswechsel | TEIL | `DepthTest.H1` |
| H2 | Gesetze | Dynastie | `houses[].laws.succession` → `houses[].heir` | Erbfolgegesetz wählt ältestes oder jüngstes Kind | Tod des Herrschers | TEIL | `DepthTest.H2` |
| H3 | Gesetze | Herrschaft | `houses[].laws.tax` → `houses[].gold` | Steuersatz verändert Jahreseinkommen | Jahreswechsel | PLAN W1 | `DepthTest.H3` |
| H4 | Gebäude | Herrschaft | `provinces[].buildings.market` → `houses[].gold` | Markt erhöht Handelseinkommen der Provinz | Jahreswechsel | TEIL | `DepthTest.H4` |
| H5 | Gebäude | Krieg | `provinces[].buildings.barracks` / `walls` → `provinces[].levy` / Verteidigung | Kaserne erhöht Aufgebot, Mauer senkt Belagerungsschaden | Bau abgeschlossen / Angriff | TEIL | `DepthTest.H5` |
| H6 | Legitimität | Herrschaft | `houses[].legitimacy` → `opinion[]` / `factions[].loyalty` | Niedrige Legitimität senkt Haltung und erhöht Fraktionsdruck | Thronwechsel / Gesetzesbruch | PLAN W1 | `DepthTest.H6` |
| H7 | Fraktionen | Herrschaft | `houses[].factions[].power` → `houses[].laws` / `council` | Fraktion erzwingt Gesetz oder Ratsbesetzung | Macht über Schwelle | PLAN W1 | `DepthTest.H7` |
| H8 | Fraktionen | Krieg | `houses[].factions[].power` → `provinces[].levy` | Unruhe hält Aufgebot zurück oder erzwingt Krieg | Ultimatum / Kriegserklärung | PLAN W1 | `DepthTest.H8` |
| D1 | Traits | Herrschaft | `houses[].ruler.traits[]` → `houses[].council` / `gold` | Traits verändern Rats effektivität und Verwaltung | Regierungsantritt / Ratssitzung | PLAN W1 | `DepthTest.D1` |
| D2 | Traits | Krieg | `houses[].ruler.traits[]` → `provinces[].levy` / Angriffsstärke | Kriegerisch erhöht Aufgebot, vorsichtig senkt Risiko | Krieg / Belagerung | PLAN W1 | `DepthTest.D2` |
| D3 | Erziehung | Herrschaft | `houses[].children[].education` → `houses[].ruler` | Erziehung setzt Werte des Erben bei Nachfolge | Nachfolge | PLAN W1 | `DepthTest.D3` |
| D4 | Erziehung | Krieg | `houses[].children[].education.martial` → `provinces[].levy` | Kriegsausbildung erhöht späteres Aufgebot | Nachfolge / Krieg | PLAN W1 | `DepthTest.D4` |
| D5 | Beziehungen | Herrschaft | `houses[].spouse.house` / `opinion[]` → `houses[].prestige` | Ehe und Haltung erzeugen Prestige und Unterstützung | Heirat / Hof | TEIL | `DepthTest.D5` |
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
| AI1 | KI-Rat | Krieg | `houses[i].council.marshal` → `houses[i].provinces[].levy` | KI trainiert mit demselben Ratsamt | KI-Monatswechsel | TEIL | `AiParityTest.AI1` |
| AI2 | KI-Gesetze | Herrschaft | `houses[i].laws.tax` → `houses[i].gold` | KI wählt Steuersatz nach derselben Formel | KI-Jahreswechsel | PLAN W3 | `AiParityTest.AI2` |
| AI3 | KI-Dynastie | Herrschaft | `houses[i].spouse` / `opinion[i]` → `opinion[player]` / `prestige` | KI-Ehen verändern Netzwerk und Haltung des Spielers | KI-Heirat | PLAN W3 | `AiParityTest.AI3` |
| AI4 | KI-Krieg | Dynastie | `houses[i].claims[]` / `armies[]` → `houses[].spouse` / `captive` | KI-Krieg erzeugt Geisel, Zwangsheirat oder Frieden | KI-Frieden | PLAN W3 | `AiParityTest.AI4` |
| AI5 | KI-Geheimnisse | Herrschaft | `houses[i].secrets[]` → `scandal` / `opinion[]` | KI deckt Geheimnisse auf und erzeugt Skandal | KI-Intrige | PLAN W3 | `AiParityTest.AI5` |

## Abdeckung nach DC-1

| Quelle | Beeinflusst mindestens zwei andere Säulen | Belegzeilen |
|---|---|---|
| Herrschaft | Dynastie, Krieg | H2 → Dynastie; H1, H5 → Krieg |
| Dynastie | Herrschaft, Krieg | D1, D3, D5, D7 → Herrschaft; D2, D4, D6, D8 → Krieg |
| Krieg/Diplomatie | Herrschaft, Dynastie | K1, K3, K5 → Herrschaft; K6 → Dynastie |
| Welt/KI | Krieg, Herrschaft, Dynastie | AI1 → Krieg; AI2, AI3, AI5 → Herrschaft; AI4 → Dynastie |

Die Gegenrichtung ist ebenfalls besetzt: Herrschaft liest Dynastie und Krieg, Dynastie liest Herrschaft und Krieg, Krieg liest Herrschaft und Dynastie. Damit ist keine Säule eine reine Senke.

## Prüfregel pro Zeile

Jeder `DepthTest` führt dieselben fünf Schritte aus:

1. Ausgangszustand erzeugen und `snapshot()` nehmen.
2. Nur die Quelle ändern (z. B. `council.marshal` besetzen).
3. Auslöser ausführen (Monat, Jahreswechsel, Krieg, Tod).
4. Zielgröße exakt gegen den erwarteten Wert prüfen; den Wirkungsbeleg im Log prüfen.
5. Speichern, laden, `SaveGame.diff()` muss leer sein.

Ein Test, der nur „kein Absturz“ prüft, gilt nicht als Nachweis.

## Aktueller Ist-Stand

| Kategorie | Anzahl | Zeilen |
|---|---|---|
| `IST` | 0 | — |
| `TEIL` | 8 | H1, H2, H4, H5, D5, D7, K2, AI1 |
| `PLAN` | 20 | alle übrigen |

Die Matrix ist damit die prüfbare Fassung des Auftrags, nicht die Behauptung, die Systeme seien bereits fertig. Welle 1 beginnt mit H1–H8 und D1–D8; Welle 2 mit K1–K7; Welle 3 mit AI1–AI5. Erst wenn eine Zeile `IST` ist und ihr Test im Bericht zitiert wird, darf sie als umgesetzt bezeichnet werden.
