# Pausierter Arbeitsstand – 2026-11-09

Die Arbeit wurde auf ausdrücklichen Nutzerwunsch pausiert, weil der Rechner mitgenommen wird und vorübergehend kein Internet verfügbar ist. Keine automatische Fortsetzung, keine laufenden eigenen Tests oder Transfers. Unteragenten wurden unterbrochen. Beim Fortsetzen zuerst diesen Stand und den aktuellen Git-Diff prüfen.

## Bereits abgeschlossen und veröffentlicht

- Banger Queens 1.5.2: Holz/Walnuss als Standard, helle Eiche und Pergament zusätzlich zu den drei bisherigen Themes. 38/38 Godot-Suiten mit 3.722 Prüfungen bestanden; Windows-Start und Android-Paketprüfung bestanden.
- GitHub-Quellstand `2cf78b996b56da00a1dd3203483643e70a10f7ba`, Tag `v1.5.2`.
- Release: https://github.com/chaotiKKK/kronen-und-kriege/releases/tag/v1.5.2
- APK und EXE wurden vollständig hochgeladen; GitHub-Asset-Digests stimmen mit den lokalen SHA-256 überein.
- `F:\banger-queens.apk` ist weiterhin 1.5.2, Versionscode 8, 204.862.841 Bytes, SHA-256 `9ee52449ab15ea5ea1d4cc0e12da6a40b70638691e8fbfe3682ce3002a94f072`.
- `F:\banger-queens.exe` ist weiterhin 1.5.2, 142.853.392 Bytes, SHA-256 `377335ad7ac6560076a7fe878de41e57f43bbf7fe0eb7624c29701090fdf0a69`.

## Lokal weiterentwickelter Atlas 1.6.0

Diese Fassung ist Quellarbeit, noch kein neu ausgelieferter APK-/EXE-Build. Die Version im Projekt wurde auf 1.6.0/Android-Code 9 gesetzt; die Prüfroutine erwartet diese nächste Version.

- 69 Länder-/Gebietsobjekte, 1.958 Regionen einschließlich 16 deutscher Länder, 400 deutsche Kreise, 10.949 Gemeinden, 23.463 GeoNames-Orte, 175 Flussgruppen.
- JSON und Float32-Geometriepool liegen fertig unter `data/`. `docs/atlas-sources.md` enthält Quellen, Lizenzen, Stände und Hashes. Alle Originaldaten liegen im ignorierten `.tools/atlas_sources/`-Cache.
- Neuer geografisch zugeschnittener Natural-Earth-II-Untergrund `assets/map/atlas_terrain.webp`, 4800×3040. `data/atlas_terrain_source.json` dokumentiert die Verarbeitung des vollständig heruntergeladenen Originals. Kein weiterer Download für lokale Prüfungen erforderlich.
- `AtlasData.gd` und `AtlasLayer.gd`: räumlicher Index, tatsächliche Flüsse/Verwaltungsgrenzen, lesbare kollisionsgeprüfte Ortsnamen. Gemeinden erst ab 24× und mindestens 256 Pixel² Begrenzungsfläche; Zoom bis 64×. Dünne zurückhaltende Grenzen statt dichter goldener Doppelkonturen.
- Die Atlasebene liegt hinter den Spielbeschriftungen; Hauptkarte clippt auf den Viewport. Der Minimap-Key berücksichtigt Besitzer-/Entwicklungsänderungen derselben Spielinstanz.
- `AtlasSearch.gd`: echte Orts-/Regionensuche, begrenzte schwebende Treffer-/Quellenpanels mit Rollbereich, Enter/Escape und Kartenfokus. Quellenhinweis enthält BKG-Datenstand und Lizenz.
- „Karte groß“ in `ModernInterface.gd` vergrößert die Kartenfläche und kann per ESC zurückgeschaltet werden. Die früheren Sichtbarkeiten werden wiederhergestellt.
- Gegenstand ist weiterhin der Europa-/Nachbarschaftsausschnitt. Moderne Verwaltungsdaten sind ausdrücklich Referenzgeografie; die 49 bestehenden Spielgebiete bleiben die Simulation. Dies ist keine bereits nachgewiesene vollständige AAA- oder Weltkommunensimulation.

## Bereits belegte neue Prüfungen

- 14 Python-Tests des Datenimports grün; 3 Tests der Raster-Georeferenz grün.
- `AtlasDataTest` nach LOD-Korrektur grün: 11.593 Prüfungen.
- `AtlasIntegrationTest` nach Kartenfokus-Einbau headless grün: 1.391 Prüfungen.
- Letzter Fenstertest mit neuem Untergrund und Fokusmodus grün: 828 Prüfungen, `MAIN_READY version=1.6.0`, OpenGL Compatibility auf RTX 5070 Laptop GPU. Abweichende Assertionzahlen ergeben sich aus sichtbaren Labelpaaren und Bildausgaben; sie sind keine konstante Funktionsanzahl.
- Aktuelle Renderbilder liegen unter `build/verify/atlas-overview.png`, `atlas-germany.png`, `atlas-gemeinden.png`, `atlas-text-200.png` und `atlas-fullscreen.png`.

## Beim Fortsetzen noch offen

1. Den aktuellen Stand von `AtlasIntegrationTest.gd` prüfen: Der Unteragent war zuletzt mit zusätzlichen 200-%-Popupprüfungen für „ber“ und Quellenanzeige beauftragt und wurde pausiert. Keine unfertigen Teständerungen als geprüft behandeln.
2. Neueste Renderbilder mit Natural Earth II visuell beurteilen; die ältere Gemeinde-Spaghetti-Ansicht wurde korrigiert, die letzten neuen Bilder wurden vor der Pause noch nicht vollständig gesichtet.
3. Ortsuche, Quellenpopup, Kartenfokus und Rückkehr bei 200 % im Fenster prüfen. Die Quellen-/BKG-Hinweise erhalten.
4. Vollständigen aktuellen Godot-Sammellauf mit allen registrierten Atlas-Suiten durchführen. Der letzte vollständige Sammellauf gilt nur für 1.5.2; die 1.6.0-Prüfungen sind bisher gezielte Läufe.
5. README und neuen Atlas-Prüfbericht fertigstellen; der dafür zuständige Unteragent wurde vor Abschluss unterbrochen. Design und Implementationsplan liegen in `docs/superpowers/`.
6. Windows und Android sequenziell neu exportieren, `.bin`-Einbettung tatsächlich im Paket prüfen, Signatur/Version/ABIs und Windows-Start validieren. Kein Poco-Spieltest für diesen Stand behaupten.
7. Erst danach den fertigen 1.6.0-Stand auf GitHub veröffentlichen. Aktuell ist nur 1.5.2 veröffentlicht; der Pausen-Commit bleibt lokal.

Alle Godot-Fenster ausschließlich auf dem rechten physischen Monitor öffnen. Gemeinsamen Godot-/Importcache nicht durch parallele Instanzen verwenden. Keine fremden Agenten-/Projektprozesse oder Gerätebelegungen unterbrechen.
