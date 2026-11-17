# Provinzschwerpunkte und Versorgungslinien Implementation Plan

**Goal:** Örtliche Wirtschaftsentscheidungen und kontrollierbare Straßen verbinden Einkommen mit einem tatsächlich versorgbaren Feldzug.

**Architecture:** `SupplyNetwork` berechnet ein endliches deterministisches Transportnetz ohne Seiteneffekte. `Game` besitzt Ausgaben, Bindung, Erträge und Verluste, `SaveGame`/`SaveStore` sichern die Migration, der vorhandene Kernel bleibt der einzige lokale/autoritative Befehlsweg. Provinzinspektor und Wirtschaftskarte zeigen dieselbe Bilanz.

**Tech Stack:** Godot 4.5.1/GDScript, vorhandene 108 Regionen, Android/Windows, bestehendes ENet.

**Spec:** `docs/superpowers/specs/2026-11-17-province-economy-and-supply-design.md`.

## Global Constraints

- Pro Provinz genau ein Schwerpunkt: `balanced`, `agriculture`, `trade`.
- Landwirtschaft: −15 % regionaler Grund-/Marktertrag, +50 % örtliche Versorgung. Handel: +15 % regionaler Grund-/Marktertrag, −20 % örtliche Versorgung.
- Wechsel: `max(1, round(20 * economic_share))` Gold und zwölf Monate Bindung; Erstwechsel sofort.
- Export ist auf den tatsächlich übrigen Landwirtschaftsbonus begrenzt; örtlicher Bedarf zuerst. Keine Vervielfachung und keine neuen Vorratsbestände.
- Nur fertige Straßen mit eigenen, nicht feindlich belagerten Endpunkten bilden ein Transportnetz.
- Eigene und fremde Provinzverwaltung bleiben getrennt. Deutsche Oberfläche, Touch und 200 % Schrift.
- Schema 14, bytegleiches Originalbackup vor Überschreiben; alter ausgewogener Wirtschaftsstand bleibt erhalten. Kein Poco.

## Task 1: Militärische Sackgassen und tatsächliche Taktung

Files: `scripts/Game.gd`, `scripts/SaveGame.gd`, `tests/ArmyCampaignTest.gd`, `tests/CampaignTest.gd`.

- [x] Rotfälle aus echten Abläufen: 1-Mann-Niederlage → Aufstellung; `advance_month()` über mehrere Monate bewegt die KI; historischer Jahr-null-Stand mit inzwischen erzeugtem Armeedatum migriert korrekt.
- [x] Zero-Armeen dürfen den neuen Verband nicht sperren. Jahresausgaben bleiben jährlich, militärische Bewegung/Belagerung monatlich; dieselbe Monatsgrenze schützt Januar vor doppeltem Schritt.
- [x] Bestehende `CampaignTest`, `SaveMigrationTest`, `ArmyCampaignTest`, `FullDepthTest`, `LanGameStateTest` grün ausführen. Ursprüngliche Fehlerlogs erhalten.

## Task 2: Reine endliche Versorgung

Files: create `scripts/SupplyNetwork.gd`, `tests/SupplyNetworkTest.gd`, `.tscn`.

Produces:

```gdscript
static func calculate(provinces: Array, roads: Array, armies: Array,
        house_index: int, local_capacities: Dictionary,
        agriculture_bonuses: Dictionary) -> Dictionary:
```

Result: `regions` nach ID mit `demand`, `local_capacity`, `export_available`, `export`, `import`, `shortfall`; `roads` mit `from`, `to`, `active`, `reason`; stabile `networks`.

- [x] Zuerst kleines echtes Netz testen: Kornkammerkapazität 900/Bonus300 ohne Heer und verbundener Bergregion200 mit500Mann; Import300, Defizit0, gesamter Export=gesamter Import.
- [x] Roter Nachweis vor Modulimplementierung; dann lokale Reservierung, anteilige Verteilung, deterministische Ganzzahlreste, mehrere Armeen, Inselnetz, fremde Endpunkte, Baustelle, Unterbrechung durch Belagerung/Besitz und unveränderte Eingaben abdecken.
- [x] Berechnung aus der Spec implementieren. Doppelroad und andere Arrayreihenfolge dürfen Versorgung nicht vervielfachen oder Ergebnisse ändern.
- [x] Headless `res://tests/SupplyNetworkTest.tscn` mit eigenem `APPDATA` grün ausführen.

## Task 3: Wirtschaft und Schema

Files: `scripts/ProvinceEconomy.gd` (reine Definitionen), `scripts/Game.gd`, `scripts/SaveGame.gd`, `scripts/SaveStore.gd`, `tests/ProvinceEconomyTest.*`, `tests/SaveMigrationTest.gd`.

Produces Game APIs:

```gdscript
func province_focus_choices(id: String, hi: int = -1) -> Array:
func province_focus_reason(id: String, focus: String, hi: int = -1) -> String:
func set_province_focus(id: String, focus: String, hi: int = -1) -> Dictionary:
func province_economy_preview(id: String, focus: String = "", hi: int = -1) -> Dictionary:
func supply_report(hi: int = -1) -> Dictionary:
```

- [x] Zuerst realer Startkassenfall: Goldabzug genau einmal, fremde/ungültige/gleiche Auswahl ohne Mutation abweisen, zwölf Monate Sperre einschließlich JSON-Roundtrip.
- [x] Reine Definitionen kapseln Namen/Multiplikatoren/Kosten; Game delegiert darauf. Vorschau meldet aktuelle/alternative Grund- plus Markteinnahme, örtliche Versorgung, Kosten und verbleibende Bindung.
- [x] Schema 14 und explizite Provinzfelder im Snapshot implementieren. Rohe aktuelle Werte strikt prüfen; alte Schema13-Datei ergänzt ausgewogen/−1 ohne Änderung alter Ökonomie. Zukunft, Bruchzahlen und unbekannte Fokus-ID zurückweisen.
- [x] SaveStore sichert unveränderte regionale Altdateien vor Überschreiben. Fehler beim Backup oder Validieren ändert weder Datei noch laufende Partie.
- [x] Gemeinsame Versorgung nach Task2 auf die bestehenden jährlichen Verluste anwenden, Defizit anteilig auf alle Heere am Ort verteilen. Forschung geht in die Basis ein; Fokus multipliziert diese Basis genau einmal.
- [x] Kern- und Altstandregression grün ausführen. Kein Aufruf einer UI-Funktion im Spielmodell.

## Task 4: Autoritative Kommandos und Altpartien

Files: `scripts/UiKernel.gd`, `scripts/LanProtocol.gd`, `scripts/LanSession.gd`, `tests/ProvinceEconomyCommandTest.*`, `tests/LegacyLanMigrationTest.gd`, bestehende ENet-Suite.

- [x] Roter Protokollfall: `{"id":"province_focus","focus":"agriculture","selection":own_id}` zugelassen, mitgesendete Kosten/Haus/Fortschritt oder fremde Auswahl abgewiesen.
- [x] Kernel routet ausschließlich `game.set_province_focus(selection,focus)`; Hostkontext hält den Besitzer. Reine Definitionen in den Inhaltsfingerprint aufnehmen.
- [x] Tatsächliche alte1.9.0/1.9.1-Dateien mit unverändertem Originalbackup auf Schema14 migrieren. Auf dem Draht bleiben aktuelle Fingerprints zwingend; lokale Ausnahme darf keinen gefälschten Altstand zulassen.
- [x] Echter Zwei-Peer-Fall: Gast stellt eigene Kornkammer um; Weltzustände stimmen nach Bestätigung und Save/Resume überein. Fremde Provinz verändert weder Kosten noch Fokus.

## Task 5: Eine kompakte Bedienung

Files: `scripts/ProvinceInspector.gd`, `scripts/ViewModelBuilder.gd`, `scripts/MapView.gd`, `scripts/MapModes.gd`, `tests/ProvinceEconomyUiTest.*`.

- [x] UI-Rotfall: Auswahl und Vorschau sind ohne Buchung möglich; bewusster Wechselbutton bucht über den echten Dispatcher; fremdes Land enthält keinen Wähler.
- [x] Ausbau-Seite: ein Wähler, Vorher/Nachher, Kosten/Bindung und ein Bestätigungsbutton. Militärseite: gemeinsamer Bedarf, lokale Deckung, Import, Defizit, jährlicher Termin.
- [x] Wirtschaftskarte: kleines Schwerpunktsymbol, brauchbare/unterbrochene Straßen und passende Legende. Kein neuer Hauptreiter. Anzeige verwendet dasselbe `supply_report` wie die Regeln.
- [x] Desktop-/Touch-/200%-Prüfung bei realem Viewport; Bedienelemente per Scroll erreichbar. Army-/Strategy-/Compact-/Research-/Court-Suiten erneut ausführen.

## Task 6: Integrierte Partie und Pakete

Files: `tools/run_all_tests.sh`, `docs/releases/1.9.1-gameplay.md`, Buildbelege unter `build/verify/`.

- [x] End-to-end-Start mit echter Startkasse: Schwerpunkt, bestehende Forschung, Straße3Monate, Heer zur Front, Bilanzänderung und Verlust einer Zwischenprovinz; Save/Load und Netzwerkbeleg.
- [x] Neue Szenen im Runner registrieren. Vollständige Quellenregression mit festgehaltenem endgültigem Stand; rote Vorläufe bleiben als solche erhalten.
- [x] EXE/APK unter neuen Dateinamen erstellen, frühere1.9.1-Artefakte erhalten. PCK/APK-Integrität, Androidsignatur, Version und Datenvollständigkeit prüfen; tatsächliche exportierte Laufzeit testen.
- [x] Grenzen im Bericht benennen: eigener Emulator ersetzt kein reales Smartphone-WLAN; Spielspaßbewertung bleibt vom funktionalen Nachweis getrennt. Ziel erst bei belegter Gesamtfertigstellung schließen.

## Abnahmebelege vom 17. November 2026

Die Aufgaben dieses begrenzten Schwerpunkte-/Versorgungsmeilensteins sind umgesetzt und geprüft. Gesamtregression: 76 Suiten, nach zwei dokumentierten Korrekturen 36.902 Prüfungen; unabhängige Review 8.307. Tatsächliche neue Windows-EXE: 380 Basisprüfungen und 49 Gameplayprüfungen; zwei Prozesse: 130 Netzwerkprüfungen. APK/PCK einschließlich vollständiger Daten, Signatur und Inhalts-Hashes geprüft. Belege unter `build/verify/gameplay-191-final/` und `build/verify/gameplay-191-features/`; genauer Status und verbleibende Hardware-/Leistungsgrenzen im [Gameplay-Bericht](../../releases/1.9.1-gameplay.md). Das übergeordnete Spielspaßziel ist damit nicht als abgeschlossen erklärt.
