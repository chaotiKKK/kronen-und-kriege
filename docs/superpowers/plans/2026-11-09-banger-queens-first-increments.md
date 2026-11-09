# Banger Queens: erste Ausbaustufen – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Der Nutzer hat autonome Ausführung freigegeben. Ausführung in dieser Sitzung; die referenzierten superpowers-Ausführungsskills sind hier nicht installiert. Die folgenden Schritte werden direkt und mit TDD bearbeitet.

**Goal:** Den vorhandenen Spielstand als Banger Queens mit korrekter Kampagnenzeit weiterentwickeln und danach einen echten Forschungs-/Straßenbaupfad ergänzen.

**Architecture:** Bestehende `Game`-Transaktionsgrenze, UI-Kernel und Kartenlayer erhalten. Kalender sowie Forschungs-/Infrastrukturregeln bekommen kleine reine Helfer; persistenter Zustand bleibt im Save. Straße und Baustelle werden aus demselben Spielzustand gezeichnet, der Wirtschaft und Baufortschritt steuert.

**Tech Stack:** Vorhandenes Godot/GDScript, 2D-Compatibility, native Windows-/Android-Exporte.

**Spec:** `docs/superpowers/specs/2026-11-09-banger-queens-design.md`

## Global Constraints

- Deutsch ist die einzige angebotene Sprache.
- Android wird nativ für ARM64 gebaut; alle Laufzeitinhalte sind in einer APK enthalten, ohne manuellen Datenimport.
- `Game.gd` bleibt Transaktionsgrenze.
- Das frühere Fünf-Minuten-Limit ist aufgehoben.
- Sichtbare Windows-Läufe ausschließlich auf dem rechten Monitor.
- Bestehender Arbeitsbaum wird bewahrt; Sicherung unter `build/checkpoints/20261109-banger-queens-before/`.

## Aufgabe 1: Kalender und Produktkontinuität (BQ-01)

**Dateien:** neu `scripts/CampaignCalendar.gd`, `tests/CampaignTest.gd/.tscn`; ändern `scripts/Game.gd`, `scripts/SaveGame.gd`, `scripts/Main.gd`, `scripts/AcceptanceDriver.gd`, `project.godot`, `export_presets.cfg`, `tools/run_all_tests.sh`.

**Schnittstelle:** `CampaignCalendar.to_index(year: int, month: int) -> int`, `from_index(index: int) -> Dictionary`; nullbasiert, Startindex 0; `Game._now()` bleibt die gemeinsame Fristquelle und liefert für Altfristen Index plus eins. `year/month` bleiben als Legacy-Fassade erhalten.

- [ ] Roter Integrationstest: `g.year = -1; g.month = 12; g.advance_month(); assert(g.year == 1 and g.month == 1)`; Nachweis einer Jahreswirkung genau einmal, 2-Monats-Frist über den Übergang und Save-Roundtrip.
- [ ] Minimal implementieren: statt `year += 1` `year = 1 if year == -1 else year + 1`; Kalenderfunktion `(year + 2000 - (1 if year > 0 else 0)) * 12 + month - 1`; alle absoluten Uhrzugriffe über Kalender vereinheitlichen.
- [ ] Grenztests: `to_index(-2000,1)==0`, `to_index(-1,12)==23999`, `to_index(1,1)==24000`, `to_index(2200,12)==50399`; 50.400 eindeutige Hin-/Rückumrechnungen. Ungültiges Jahr 0 oder Monat außerhalb 1..12 wird abgelehnt.
- [x] Migration testen und implementieren: Schema 12; Altjahr 0→1 und 1→2; einsbasierte absolute Altfristen/Chronikwerte über `_now()` kompatibel halten; relative Dauern unverändert. Aktuelle Datums-/Index-Widersprüche werden abgewiesen.
- [ ] Regulärer Endmonat stoppt Zeitlauf und bietet „Als Sandbox fortsetzen“; Sandbox-Flag persistieren. Zeitfortschritt muss nach dem letzten Monatszustand anhalten, nicht eine Sekunde lang automatisch darüber hinauslaufen.
- [ ] Sichtbaren Namen und Dateinamen ändern; Paketkennung `org.example.kronen`, vorhandene Signatur und `user://`-Speicherort erhalten. Kein neuer Test für bloße Beschriftung; tatsächlichen Appstart kontrollieren.
- [ ] Passende Regressionen und vollständigen Suite-Lauf ausführen. BQ-01 separat im Prüfbericht abschließen.

## Aufgabe 2: Forschung und sichtbare Straßen (BQ-02)

**Dateien:** neu `scripts/Infrastructure.gd`, `tests/InfrastructureTest.gd/.tscn`; ändern `Game.gd`, `SaveGame.gd`, `UiKernel.gd`, `ViewModelBuilder.gd`, `Main.gd`, `MapView.gd`/`MapBase.gd` und Testregistrierung.

**Schnittstellen:** `Game.start_research(innovation: String, house_index: int = -1) -> Dictionary`, `Game.build_road(from_id: String, to_id: String, house_index: int = -1) -> Dictionary`, `Game.road_segments() -> Array`. Spieler und KI verwenden dieselben Eingaben/Kosten. Diese APIs werden vor Nutzung getestet.

- [ ] Rote Regeltests schreiben: ohne Forschung oder Besitz keine Straße; fehlendes Gold und nicht benachbarte Endpunkte ändern keinen Zustand; vertauschte Endpunkte erzeugen kein Duplikat.
- [ ] Vermessung und Straßenbau als zwei feste Innovations-IDs mit echter monatlicher Dauer (6/12 Monate), Kosten (20/40 Gold) und Voraussetzung implementieren; Status/Restdauer im Spielstand.
- [ ] Forschung tickt jeden Monat; neue Forschung kann nach Abschluss beginnen. Neue UI-Kommandos `research` und `road` leiten an Game weiter. Fehlversuche erklären die konkrete Ursache.
- [ ] Eine Straße kostet 30 Gold und dauert 3 Monate; Endpunkte müssen benachbart und im Besitz des bauenden Hauses sein. Besitzverlust während Bau pausiert ihn; erneuter gültiger Besitz setzt fort. Fertige Straße erhöht jährliches Einkommen des aktuellen gemeinsamen Besitzers um 2 Gold; kein Bonus über geteilte Grenzen.
- [ ] Straße als stabile sortierte Endpunktkante speichern; Zustand `building`/`complete`, Restmonate und Erbauer validieren. Nachbar-/Besitz-/Doppelbau-/Migrationsprüfungen und JSON-Roundtrip ergänzen.
- [ ] Karte zeichnet eine gestrichelte Baustelle und eine fertige durchgehende zweifarbige Linie zwischen Provinzmittelpunkten; Endpunkte, Auswahl und Labels bleiben lesbar. Zoom/Pan verwenden vorhandenen Kartenraum. Die Übersicht behandelt den Verlauf als abstrahierte Verbindung, nicht als vermessene reale Trasse.
- [ ] Forschung/Bau im Provinzpanel mit Kosten, Sperrgrund und Fortschritt anbieten. Jeder Monat aktualisiert sichtbare Bauzustände. Negative Kontrollen: Straße entfernt → Bonus entfällt; Forschung fehlt → Bau gesperrt; Save neu laden → sichtbare Linie und Bonus identisch.
- [ ] Headless-Regeltests, echte UI-Eingaben und Ingame-Bildprüfung durchführen. Erst dann Windows/Android exportieren und Artefakte prüfen.

## Abschluss und Berichte

- [ ] `docs/banger-queens-progress.md` dokumentiert umgesetzte Funktionen, Testbefehle, belegte Ergebnisse und weiterhin offene Stufen.
- [ ] Lokale Dokumente nur gezielt committen; vorhandene fremde Änderungen nicht als eigene Arbeit ausgeben. Codeänderungen gegenüber dem Sicherungsstand beschreiben.
- [ ] Kein Vollkampagnen-, AAA- oder Poco-Erfolg ohne entsprechendes Laufprotokoll behaupten.
