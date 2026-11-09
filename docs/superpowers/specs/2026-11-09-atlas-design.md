# Banger Queens: lesbarer geografischer Atlas

Der Nutzer verlangt eine grundlegende Kartenüberarbeitung mit deutlich lesbaren Städten, mehr Verwaltungsunterteilung und einer Dichte mindestens auf dem Niveau der vorhandenen Pergamentvorlage `reference/reference_3.jpg`. AAA ist das gestalterische Ziel, kein durch einen einzelnen Screenshot belegbarer Abnahmestatus. Die bestehende Karte zeigt Europa und Nachbargebiete, nicht die gesamte Erde.

## Verbindliches Ergebnis

- Gemeinsame Projektion für echte Flüsse, Orte, Verwaltungsgrenzen und bestehende Spielgebiete: Länge −12 bis 52°, Breite 33 bis 72°, Kartenraum 1200×760.
- Echte Verwaltungsdaten: europäische Regionen aus Natural Earth, Deutschland zusätzlich Bundesländer, Kreise und Gemeinden aus BKG VG250. Städte aus GeoNames; alle Daten offline in der APK.
- Die 49 vorhandenen Spielgebiete und ihre Speicherkennungen bleiben die Simulationsebene. Neue geografische Objekte verweisen auf diese Gebiete. Heutige Namen und Verwaltungsgrenzen sind ausdrücklich Referenzgeografie und keine behaupteten Grenzen oder Stadtgründungen im Jahr 2000 v. Chr.
- Übersicht zeigt Reiche; beim Zoomen erscheinen Regionen, Städte, Kreise und schließlich Gemeinden. Unsichtbare Geometrie und Beschriftungen werden verworfen. Keine gezeichnete Schrift unter 13 Canvas-Pixeln; vorhandene Textskalierung bis 200 % gilt auch für den Atlas.
- Orte werden nach Bedeutung und Auswahl priorisiert, Texte kollisionsfrei platziert und mit Kontrastkontur gezeichnet. Zu dichte Namen erscheinen beim Zoomen beziehungsweise bei Auswahl, statt auf wenige Pixel verkleinert zu werden.
- Falsch projizierte Flüsse entfernen und durch echte Linienzüge ersetzen. Flüsse erhalten zurückhaltende natürliche Farben und sind keine Transport- oder politischen Grenzen.
- Zoom bis 64×; Kreise ab 6×, Gemeinden ab 24× und nur bei mindestens 256 Pixel² projizierter Begrenzungsfläche. Ein vergrößerter Kartenmodus schafft Platz für Ortsdetails; ESC stellt die normale Ansicht wieder her.
- Die Hauptkarte clippt auf ihren sichtbaren Ausschnitt. Minimap und Hauptkarte aktualisieren politische Änderungen zusammen.
- Orts-/Regionensuche und ein lesbarer ausgewählter Orts-/Regionenname erschließen Details auch auf Touchgeräten. Originale Spielhandlungen bleiben erreichbar.
- Rohdaten werden während des Builds normalisiert, nach amtlichen Schlüsseln vereinigt, vereinfacht und mit Quellen-/Lizenz-/Hashbelegen eingebettet. Keine Netzverbindung beim Spielstart.

## Datenvertrag

`data/atlas.json`: `schema=1`, `projection` mit `size=[1200,760]` und `bounds=[-12,33,52,72]`, `geometry="res://data/atlas_geometry.bin"`, `sources`, `features`, `cities`, `rivers`.

Geometriepool: little-endian Float32-Paare x/y. Ein Pfad ist `[offset,count]`, offset zählt Punkte, keine Bytes. Jeder Feature-Datensatz hat `id`, `name`, `kind` (`country`, `region`, `district`, `municipality`), `parent_id`, `province_id`, `center=[x,y]`, `bounds=[x,y,width,height]`, `paths` mit Pfadverweisen. Pfade sind Umrisslinien, keine unabhängig triangulierten Füllpolygone. Deutsche Verwaltungseinheiten werden anhand AGS zusammengeführt; Datensatzzahlen werden nicht als Zahl eigenständiger Gemeinden ausgegeben.

Städte haben `id`, `name`, `point=[x,y]`, `population`, `country`, `province_id`. Flüsse haben `name`, `bounds` und `paths` im selben Geometriepool. Quellen nennen URL, abgerufenen Stand, Lizenz und SHA-256. Die Datumsangaben werden aus den real verwendeten Produkten übernommen.

## Komponentengrenzen

- `tools/build_atlas_data.py`: reproduzierbarer Import und kompaktes Datenformat; Python-Tests prüfen Projektion, Zusammenführung, Pfadoffsets und bekannte Orte.
- `scripts/AtlasData.gd`: Daten laden, Pfade materialisieren, sichtbare Features, Suche und Ortsauflösung; keine Darstellung und keine Spielregeln.
- `scripts/AtlasLayer.gd`: eigene kartografische Grenzen und lesbare Ortsschilder im sichtbaren Viewport; keine Spielzustandsänderung.
- `scripts/MapView.gd`, `MapBase.gd`: gemeinsame Integration, Zoom, Clipping, natürliche Kartenfarben, tatsächliche Flüsse; bestehende Eigentums-/Kriegs-/Straßenfunktionen bleiben die maßgeblichen Spielhandlungen.
- `scripts/ModernInterface.gd`, `Main.gd`: deutsche Suche und Detailbedienung.

## Prüfung

Zuerst rote Tests für reale Geodaten, lesbare Beschriftungen, Viewport-Clipping, Flussposition, Zoom und Minimapänderungen; danach Implementierung. Fenstertests ausschließlich auf dem rechten Monitor. Übersicht und Deutschland-Nahansicht als echte Renderbilder prüfen, auf überlappende Namen und fehlerhafte Gewässer achten. Bestehende Spiel-, Touch-, Save- und Rendering-Suiten bestehen. Android-Signierung/Einbettung gesondert prüfen; ohne verbundenen und tatsächlich bedienten Poco keine Geräteabnahme behaupten.
