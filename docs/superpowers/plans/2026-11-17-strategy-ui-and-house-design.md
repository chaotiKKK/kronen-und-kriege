# Strategieansichten und Hausdesigner – Implementation Plan

> Umsetzung in begrenzten, getrennten Dateibereichen; Root integriert und prüft das Gesamtergebnis. Jeder Arbeitsschritt endet mit einem roten und anschließend grünen Funktionsnachweis, soweit das Verhalten geändert wird.

**Goal:** Fünf aussagekräftige Kartenansichten, sofortige Provinzverwaltung, reichhaltigere Forschung/Ereignisse, stabile Hofverwaltung und vor Spielbeginn gestaltbare Multiplayer-Häuser.

**Architecture:** Reine Präsentationspolitik für Karten, eigenständige Provinz- und Hof-Presenter und ein gemeinsames validiertes HouseDesign. Game bleibt die Regelinstanz, LanSession der autoritative Gründungs-/Befehlsweg. Keine neue Engine und keine Karten-Neupartitionierung.

**Tech Stack:** Godot 4.5.1 / GDScript, vorhandene ENet-Lobby, Android ARM64 und Windows x64.

**Spec:** `docs/superpowers/specs/2026-11-17-strategy-ui-and-house-design.md`

## Globale Bedingungen

- 108 Gebiete und unveränderlicher Katalog bleiben erhalten; keine Geometrieänderung.
- Mutationen ausschließlich über validierte Spiel-/Netzbefehle.
- Walnuss, kompakte Desktop-Navigation, größere Touchflächen, sechs Themes und 200-Prozent-Text erhalten.
- Kein Zugriff auf das Poco; sichtbare Tests ausschließlich auf dem rechten Monitor.

## A – Kartenpolitik und sofortige Provinzseite (Root)

Dateien: neue `scripts/MapModes.gd`, `scripts/ProvinceInspector.gd`; Änderungen an `MapView.gd`, `MapBase.gd`, `ModernInterface.gd`, `Main.gd`, `ViewModelBuilder.gd`; neue `tests/StrategyUiTest.gd/.tscn`.

- [x] Rotnachweis: unverwechselbare Farb-/Grenzpolitiken, alte Modus-Aliase, Rechtsstufen, unveränderte Welt, Provinzklick zeigt Übersicht und lokale Aktionsgruppen.
- [x] `MapModes.canonical(id)`, `fill(game,province,mode,tier,selected)` und `border_styles(mode)` implementieren; `MapView.set_mode()` und MapBase verwenden ausschließlich diese Politik.
- [x] `ViewModelBuilder.province(game,id)` liefert lesende örtliche Daten und Aktionszustände. `ProvinceInspector.configure(main)` und `refresh(game,id)` halten stabile Buttons; Befehle besitzen explizite Selektion.
- [x] Hausnavigation bereinigen, Titel/Reiche über einen Rechtsstufenwähler bündeln, Kurzbefehle und Legenden anpassen.
- [x] Fünf tatsächliche Aufnahmen bei gleichem Spielzustand vergleichen; kleine Fenster, Touch und große Schrift kontrollieren.

## B – Forschung, Ereignisse, Armeedoktrin

Dateien: `Game.gd`, `Infrastructure.gd`, `Data.gd`; neuer `EventDirector.gd`; neue `ResearchDepthTest`, `EventVarietyTest`; bestehende Regeltests.

- [x] Rot: konkrete neue Voraussetzungen/Wirkungen, ungeeignete Ereignisse, direkte Wiederholung, Save-Roundtrip.
- [x] Definitionen und allgemeine Validierung ergänzen; `research_choices()` um `branch`, `description`, `effect_text`, `blocked_reason`, `known`, `active`, `remaining`, `enabled` erweitern, alte Felder erhalten.
- [x] Wirkungen in existierende Regeln integrieren; Defaultzustand bleibt identisch.
- [x] Ereigniskatalog auf mindestens 32 erweitern; Historie pro Haus und kontextabhängige Auswahl implementieren.
- [x] `army_composition(strength,house_index=-1)` und reale Doktrin-Handelsbedingungen auswerten; Stärke nicht kostenlos erhöhen.

## C – Validierter Einzelspieler-/WLAN-Designer

Dateien: neue `HouseDesign.gd`, `HouseDesignerDialog.gd`; `LanSession.gd`, `LanProtocol.gd`, `LanMenu.gd`; neue `HouseDesignTest`, `LanDesignerTest`.

- [x] Rot: Entwurfsbudget, unbekannte Felder, Heimatkonflikte, menschliche Startgebiete, dynamische Sitz-IDs und alte lokale 1.8-Dateien.
- [x] API: `HouseDesign.defaults(data,province_id='')`, `validate(profile,data)` mit `{ok,profile,message}`, `catalog(data)`.
- [x] Dialog-API: `configure(main,initial_profile,callback)`; gültiger Entwurf wird erst bei Übernehmen übergeben, Abbruch verändert nichts.
- [x] Netzwerk-API: `submit_design(profile)`, `clear_design()`, `house_catalog()`. Host reserviert und normalisiert, Änderungen setzen Bereitschaft zurück.
- [x] Stabil geordnete Gründung vor `configure_human_houses`, dynamische Wiederaufnahme und getrennte Dateikompatibilität implementieren.
- [x] Root verbindet denselben Editor mit dem Einzelspielerstart; Entwurfsdialog und Verbindung überleben Abbruch/200-Prozent-Text.

## D – Hofverwaltung

Dateien: neuer `CourtManagementPanel.gd` und `CourtManagementTest`; Root ersetzt ausschließlich den bisherigen Hof-Neuaufbau im Main.

- [x] Rot: Aktionsidentität bleibt über Refresh bestehen, Sperrgrund sichtbar, Bestätigung und genau eine Buchung.
- [x] `configure(main)` montiert einmalig in `main.court_body`; `refresh(game)` aktualisiert Texte/Flags ohne Node-Austausch. Öffentliche Testflächen: `action_buttons`, `status_label`.
- [x] Hoftag, Halle, Reliquien und Ausstattung mit eindeutigen Kosten/Wirkungen/Unterhalt integrieren.
- [x] Layout und Fokus/Scroll bei laufender Zeit und großem Text prüfen.

## E – Gesamtabnahme und Pakete

- [x] Neue Szenen im vollständigen Runner registrieren; betroffene Altprüfungen auf fünf Modi und erweiterten Katalog aktualisieren.
- [x] Spielstandmigration, zwei/vier eigene LAN-Häuser, Wiederaufnahme und alle Regel-/UI-Suiten prüfen.
- [x] Neue Version bauen; tatsächliche EXE/APK mit allen Laufzeitdaten statisch und im Spiel prüfen, bestehende Signaturgrenze dokumentieren.
- [x] Bericht, reproduzierbare Quellen, Artefakte und verbleibende Grenzen übergeben.

Abschlussbelege: docs/releases/1.9.0.md; build/verify/release-190-final2; release-190-final2-features. Physisches Poco und echtes Smartphone-WLAN bleiben ausdrücklich außerhalb der belegten Abnahme.
