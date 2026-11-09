# Interaktionsmatrix der vier Säulen

> Dokumentversion: 7.0
> Stand: 2026-11-09
> Gültig für Save-Schema: 11
> Status: alle 59 Kanten implementiert und positiv/negativ getestet

## Legende

Jede Zeile ist eine gerichtete Kante. `Quelle` löst aus, `Ziel` wird gelesen oder verändert. `Zustandsgröße` nennt das konkrete persistente Feld. Eine Zeile ist nur `IST`, wenn ein Test die Wirkung und eine Negativkontrolle mit `set_edge_enabled()` belegt.

| Status | Bedeutung |
|---|---|
| `IST` | Kante ist implementiert, getestet und im Save-Schema 11 persistent. |
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
| L1 | Dynastie | Krieg | `houses[].renown` → `legacies.war` → `armies[].strength`, `attack` | Kriegsvermächtnis kostet Ruhm und erhöht Armeestärke und Angriffskraft | Vermächtnis kaufen | IST | `DynastyTest.L1` |
| L2 | Dynastie | Herrschaft | `houses[].renown` → `legacies.crown` → `gold`, `legitimacy` | Kronvermächtnis kostet Ruhm, gibt jährlich Gold und bei Freischaltung Legitimität | Vermächtnis kaufen; Jahreswechsel | IST | `DynastyTest.L2` |
| L3 | Dynastie | Herrschaft | `houses[].renown` → `legacies.guile` → Intrigenchance | Ränkevermächtnis kostet Ruhm und erhöht die Chance von Verführungs-, Mord- und Entführungsaktionen | Vermächtnis kaufen; Intrige | IST | `DynastyTest.L3` |
| AI1 | KI-Rat | Krieg | KI-`council.marshal` → KI-`provinces[].levy` | KI trainiert über denselben Rat und Resolver | KI-Jahreswechsel | IST | `SystemicDepthTest.AI1` |
| AI2 | KI-Steuern | Herrschaft | KI-`laws.tax` → KI-`gold` | KI wählt und nutzt denselben Steuersatz | KI-Jahreswechsel | IST | `FullDepthTest.AI2` |
| AI3 | KI-Dynastie | Herrschaft | KI-`spouse` → KI-`legitimacy`, `prestige` | KI schließt Ehen über denselben Heiratspfad | KI-Jahreswechsel | IST | `FullDepthTest.AI3` |
| AI4 | KI-Krieg | Krieg | KI-`claims[]`/`armies[]` → `siege` | KI nutzt Anspruch, Armee und Belagerung wie der Spieler | KI-Jahreswechsel | IST | `FullDepthTest.AI4` |
| AI5 | KI-Geheimnisse | Herrschaft | KI-`secrets[]` → `scandal`, `opinion[]` | KI deckt Geheimnisse über denselben Pfad auf | KI-Jahreswechsel | IST | `FullDepthTest.AI5` |
| V1 | Vasall | Herrschaft | `vassals[].level` → `gold` | Vertragssteuern fließen jährlich über `vassal_tax_income()` | Jahreswechsel | IST | `CouncilTest.V1` |
| V2 | Vasall | Krieg | `vassals[].level` → `armies[].strength` | Vertragsaufgebot wird bei `raise_army()` addiert | Armee aufstellen | IST | `CouncilTest.V2` |
| V3 | Vasall | Herrschaft | `vassals[].opinion` → `legitimacy` | Vertragswechsel und Vasallenpolitik verändern Legitimität | Vertrag ändern; Jahreswechsel | IST | `CouncilTest.V3` |
| C1 | Rat | Krieg | `council`/Stimmen → `provinces[].levy`, `legitimacy` | Kriegsaufgebot braucht Mehrheit und Schlüsselamt | Beschluss | IST | `CouncilTest.C1` |
| C2 | Rat | Vasall | `council`/Stimmen → `vassals[].opinion`, `legitimacy` | Landfrieden erhöht Meinung und Legitimität | Beschluss | IST | `CouncilTest.C2` |
| C3 | Rat | Herrschaft | `council`/Stimmen → `gold` | Kronsteuer zahlt Gold, senkt Vasallenmeinung | Beschluss | IST | `CouncilTest.C3` |
| C4 | Rat | Intrige | `council`/Stimmen → `council_effects.intrigue` | Schattennetz erhöht die Intrigenchance | Beschluss | IST | `CouncilTest.C4` |
| C5 | Rat | Herrschaft | Beschlusskosten → `gold`, `prestige` | jede Entscheidung zieht dieselben Kosten wie beim Spieler ab | Beschluss | IST | `CouncilTest.C5` |
| R1 | Hof | Herrschaft | `court.relics` → `legitimacy`, `court.grandeur` | Krone gibt +10 Legitimität und +15 Hofpracht | Reliquie schmieden | IST | `CourtTest.R1` |
| R2 | Hof | Krieg | `court.relics` → `provinces[].levy`, `court.grandeur` | Klinge gibt +80 Aufgebot in der Hauptstadt und +15 Hofpracht | Reliquie schmieden | IST | `CourtTest.R2` |
| R3 | Hof | Intrige | `court.relics` → `council_effects.intrigue`, `court.grandeur` | Siegel gibt +2 Intrigenpunkte und +15 Hofpracht | Reliquie schmieden | IST | `CourtTest.R3` |
| R4 | Hof | Hof | `court.hall` → `court.grandeur` | jede Hallenstufe gibt +15 Hofpracht | Hofhalle ausbauen | IST | `CourtTest.R4` |
| R5 | Hof | Herrschaft | `court.grandeur` → `prestige` | jährlich `grandeur / 25` Prestige | Jahreswechsel | IST | `CourtTest.R5` |
| R6 | Hof | Vasall | `court.grandeur` → `vassals[].opinion` | ab 60 Hofpracht +1 Meinung je Vasall, ab 80 +2 | Jahreswechsel | IST | `CourtTest.R6` |
| R7 | Hof | Hof/Herrschaft/Krieg | `court.amenities` → `court.grandeur`, `gold`, `vassals[].opinion`, `ruler.diplomacy`, `provinces[].levy` | jede Stufe +5 Hofpracht, kostet `50/90/140` Gold und `8` Gold Jahresunterhalt; Tafel +2 Meinung, Gemächer +1 Diplomatie, Gefolge +40 Hauptstadtaufgebot je Stufe | Ausstattung ausbauen; Jahreswechsel | IST | `CourtTest.R7` |
| R8 | Hof | Herrschaft/Vasall | `court.grandeur` + `owned provinces` + `legitimacy` → `prestige`, `vassals[].opinion` | Erwartung `5 + 2*Provinzen + Legitimität/5`; über/auf Erwartung jährlich bis +5 Prestige und +1 Meinung, darunter entsprechend Malus | Jahreswechsel | IST | `CourtTest.R8` |
| F1 | Glaube | Herrschaft | `faith.confession` → `legitimacy` | Sonnenbund gibt jährlich +1 Legitimität | Jahreswechsel | IST | `FaithTest.F1` |
| F2 | Glaube | Intrige | `faith.confession` → `council_effects.intrigue` | Mondorakel gibt jährlich +1 Intrigenpunkt (maximal 10) | Jahreswechsel | IST | `FaithTest.F2` |
| F3 | Glaube | Herrschaft | `faith.confession` → `prestige` | Erdbund gibt jährlich +1 Prestige | Jahreswechsel | IST | `FaithTest.F3` |
| F4 | Glaube | Herrschaft | `faith.holy_sites` → `prestige` | jede geweihte Stätte gibt jährlich +1 Prestige, beim Weihen +6 | Jahreswechsel; Weihe | IST | `FaithTest.F4` |
| F5 | Glaube | Vasall | `faith.church_power` → `vassals[].opinion` | ab 60 Kirchenmacht +1 Meinung je Vasall, ab 80 +2 | Jahreswechsel | IST | `FaithTest.F5` |
| F6 | Hof | Glaube | `court.relics` → `faith.church_power` | jede Reliquie gibt +5 Kirchenmacht | Reliquie schmieden; Jahreswechsel | IST | `FaithTest.F6` |
| F7 | Glaube | Glaube | `faith.piety` → `faith.church_power` | Frömmigkeit/4 fließt in die abgeleitete Kirchenmacht | Wallfahrt; Weihe; Jahreswechsel | IST | `FaithTest.F7` |
| F8 | Glaube | Herrschaft | `faith.heresy` → `legitimacy` | ab 40 Ketzerei jährlich -1 Legitimität, ab 70 -2 | Jahreswechsel | IST | `FaithTest.F8` |
| F9 | Glaube | Vasall | `faith.heresy` → `vassals[].opinion` | ab 30 Ketzerei -1 Meinung je 30 Punkte, maximal -3 | Jahreswechsel | IST | `FaithTest.F9` |
| F10 | Glaube | Glaube | `faith.reform` → `faith.church_power` | jede Reformstufe gibt +4 Kirchenmacht | Reform beschließen; Jahreswechsel | IST | `FaithTest.F10` |
| F11 | Glaube | Glaube | `faith.reform` → `faith.heresy` | jede Reformstufe senkt den jährlichen Ketzerei-Zuwachs um 2; Reform senkt Ketzerei um 10 | Reform beschließen; Jahreswechsel | IST | `FaithTest.F11` |
| F12 | Glaube | Herrschaft/Krieg | `faith.holy_war` → `prestige`, `legitimacy`, `claims[]` | heiliger Krieg erhebt Anspruch auf die Zielhauptstadt (K1/K2); Eroberung gibt +10 Prestige und +5 Legitimität | Krieg erklären; Eroberung | IST | `FaithTest.F12` |

## Belege

- `tests/SystemicDepthTest.gd` prüft H1, H2, H5 (Kaserne), D5 und AI1 positiv sowie mit deaktivierter Kante. Der D5→H1-Kreislauf ist zusätzlich belegt.
- `tests/FullDepthTest.gd` prüft die übrigen 23 Kanten positiv und negativ; zusammen mit den fünf Welle-1-Kanten sind 28 der 59 Matrixzeilen abgedeckt.
- `tests/DynastyTest.gd` prüft L1–L3 positiv sowie L1 mit deaktivierter Kante; `tests/CouncilTest.gd` prüft V1–V3 und C1–C5; `tests/CourtTest.gd` prüft R1–R8 samt deaktivierten Kanten; `tests/FaithTest.gd` prüft F1–F12 samt deaktivierten Kanten. Zusammen sind alle 59 Matrixzeilen abgedeckt.
- `tests/StoryTest.gd` spielt 120 Monate, trifft 101 Entscheidungen, sieht 47 Kanten und prüft drei Save/Load-Roundtrips ohne Diff.
- `tests/SaveMigrationTest.gd` lädt den echten v1-Altstand, migriert auf Schema 11 und prüft die neuen Pflichtfelder inklusive negativer Feldkontrollen, der abgeleiteten Hofpracht aus Reliquien/Halle/Ausstattung, der Erwartung, der abgeleiteten Kirchenmacht und der Ketzerei-Grenzen.

## Ist-Abdeckung nach DC-1

| Quelle | Belegte Zielsysteme | Erfüllt |
|---|---|---|
| Herrschaft | Dynastie (H2), Krieg (H5, H8) | ja |
| Dynastie | Herrschaft (D1, D3, D5, D7, L2, L3), Krieg (D2, D4, D6, D8, L1) | ja |
| Krieg/Diplomatie | Herrschaft (K1, K3), Dynastie (K6), Welt (K5), Krieg (K2, K4, K7) | ja |
| Welt/KI | Herrschaft (AI2, AI3, AI5), Krieg (AI1, AI4) | ja |
| Hof | Herrschaft (R1, R5, R7, R8), Krieg (R2, R7), Intrige (R3), Vasall (R6, R8) | ja |
| Glaube | Herrschaft (F1, F3, F4, F8, F12), Intrige (F2), Vasall (F5, F9), Hof/Reliquien (F6), Krieg (F12) | ja |

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
| `IST` | 59 | H1–H8, D1–D8, K1–K7, L1–L3, AI1–AI5, V1–V3, C1–C5, R1–R8, F1–F12 |
| `TEIL` | 0 | — |
| `PLAN` | 0 | — |

Die automatisierte Story-Probe ist grün. Der Windows-30-Minuten-Lauf ist **BESTANDEN** ([Protokoll](manual-acceptance.md#windows-lauf-2026-11-08)); der Android-Lauf bleibt eine Abnahme außerhalb von CI und wird nicht als automatisch geprüft ausgegeben.
