# OSM-Verwaltungsflächen: getrennte Datenquelle

## Vertrag und Landesrollen

`tools/atlas_osm_sources.py` verarbeitet ausschließlich belegte Relationen mit `boundary=administrative`: RU8 sowie TR7/TR8 innerhalb Länge −12 bis 52° und Breite 33 bis 72°. Die Auswahl erfolgt zuerst anhand einer Metadatenabfrage innerhalb der ISO-Landesfläche und des geografischen Ausschnitts. Geometrien von Siedlungen ohne Verwaltungs-Tags werden verworfen.

| Auswahl | Atlasrolle | Erhaltene lokale Bedeutung |
|---|---|---|
| RU8 | `municipality` | `official_status`, beispielsweise Stadt-/Landgemeinde oder innerstädtisches kommunales Gebiet |
| TR7 | `municipality` | Belde; Level 7 ist im ersten Geometriepilot noch ungescannt |
| TR8 | `local_admin` | Mahalle/Köy, einschließlich der ursprünglichen Tags; keine Umbenennung in Belediye |

Grundlagen sind die [russischen OSM-Verwaltungsregeln](https://wiki.openstreetmap.org/wiki/RU:Tag:boundary%3Dadministrative), die [aktuelle OSM-Ländertabelle](https://wiki.openstreetmap.org/wiki/Template:Admin_level) und das [türkische Gesetz 5393, Art. 3 und 9](https://mevzuat.adalet.gov.tr/mevzuat/102940). Türkische Gemeinde und Mahalle haben unterschiedliche Verwaltungsfunktionen. Die ältere türkische OSM-Unterseite nennt teilweise andere Level; die tatsächlichen Quelltags und die lokale Bezeichnung bleiben deshalb sichtbar.

## Reproduzierbare Verarbeitung

```powershell
C:\Python314\python.exe -m unittest discover -s tools -p test_atlas_osm_sources.py
C:\Python314\python.exe tools\atlas_osm_sources.py --mode pilot --batch-size 2 --max-relations 6
C:\Python314\python.exe tools\atlas_osm_sources.py --mode metadata --countries TR RU --max-tiles 2
C:\Python314\python.exe tools\atlas_osm_sources.py --mode tiles --batch-size 4 --max-tiles 1 --max-relations 20
```

Ohne Begrenzungsoptionen setzt der Kachelmodus den Scan fort. Russland hat 72 feste Kacheln zu höchstens 4×4 Grad im relevanten Ausschnitt, die Türkei zehn. Ein Relationsobjekt, das mehrere Kacheln berührt, wird über seine OSM-Kennung dedupliziert. Das abschließende Flächenaudit muss unabhängig prüfen, ob OSM die erwarteten Verwaltungsgebiete überhaupt erfasst.

`--mode metadata` erfasst zunächst ausschließlich Relationskennungen, Versionen und Tags aller angeforderten festen Kacheln. Es lädt keine Member-Geometrie. Bereits erfasste Metadatenkacheln werden wiederverwendet; der spätere Kachel-Geometrielauf lädt deren Rohantwort aus demselben Cache. Bekannte Gebiete ohne gelesene Geometrie bleiben ausdrücklich offen. Nur ein wirklich leerer beziehungsweise schon vollständig vorbereiteter Kachelausschnitt kann dabei bereits geometrisch abgearbeitet sein.

`prepare_sources(cache, ...)` bereitet die getrennte Quelle vor; `iter_boundaries(cache, sources)` liefert geografische Shapely-Flächen. Diese Schnittstellen starten Godot nicht und ändern die bestehende Atlasdatei nicht. Ein späterer Auftrag für nur ein Land entfernt bereits vorbereitete andere Länder nicht aus dem gemeinsamen Manifest.

Öffentliche Anfragen werden durch eine gemeinsame Prozesssperre serialisiert. Kleine Relations-ID-Batches und ein fester Snapshot begrenzen die Geometrieabfragen. `--endpoint` wählt ausdrücklich eine andere Overpass-Instanz; Endpoint, vollständige QL, QL-Hash, Rohantwort-Hash und Bytes bleiben im Cache belegbar. Es gibt keinen stillen Wechsel der Herkunft. Die [offizielle OSM-Instanzenliste](https://wiki.openstreetmap.org/wiki/Overpass_API#Public_Overpass_API_instances) nennt mehrere öffentliche Anbieter und deren Nutzungsbedingungen.

Die Standardquelle ist Overpass. Der explizite Schalter `--geometry-provider osm-api` ist auf den sechs Relationen umfassenden Pilot begrenzt. Er liest `https://api.openstreetmap.org/api/0.6/relation/<ID>/full.json` und expandiert deren wirkliche Way-/Node-Referenzen. Die ursprüngliche Verwaltungsrelation muss zur vorher geprüften Metadatenversion passen. Sämtliche zurückgegebenen Node-, Way- und Relationsversionen müssen spätestens zum gepinnten Snapshot geändert worden sein; neuere oder unvollständige Elemente werden gemeldet. Dieser begrenzte Fallback ersetzt keinen großflächigen Overpass- oder Regionalextrakt.

Äußere Teilwege werden unabhängig von ihrer Richtung verbunden und polygonisiert. Innere Ringe bleiben Löcher; eine Insel innerhalb eines verschachtelten inneren Relationsobjekts bleibt erhalten. Nicht geschlossene Ringe, fehlende Mitglieder, zyklische Beziehungen, außerhalb liegende Löcher und widersprüchliche Länderangaben sind Fehler. Es werden keine Grenzpunkte ergänzt. Beim Beschnitt an der Atlasgrenze bleiben nur echte Polygonanteile bestehen.

## Nachgewiesener Stand vom 9. November 2026

Der Produktionsreader hat sechs reale Flächen ohne Geometriefehler vorbereitet. Der gemeinsame Snapshot ist `2026-11-09T20:00:06Z`; alle Mitglieder der sechs API-Antworten bestanden dessen Zeitprüfung.

| Kennung | Version | Name | Atlasrolle |
|---|---:|---|---|
| `r339228` | 75 | округ Московская застава | `municipality` |
| `r1306580` | 77 | Всеволожское городское поселение | `municipality` |
| `r1650682` | 20 | Копорское сельское поселение | `municipality` |
| `r3403828` | 29 | İçerenköy Mahallesi | `local_admin` |
| `r8852697` | 20 | Kozyatağı Mahallesi | `local_admin` |
| `r9286607` | 17 | Bostancı Mahallesi | `local_admin` |

Die dafür zuvor erfolgreich gelesenen Metadaten umfassen 121 RU8- und 62 TR8-Relationen. Nur die sechs ausdrücklich gewählten Relationskennungen wurden im Geometriepilot bearbeitet. TR7 bleibt ungescannt. Die ursprünglichen erfolgreichen Antworten wurden unter exakt derselben QL und mit geprüftem Originalhash in den unveränderlichen Readercache übernommen; die Receipts nennen diesen Import ausdrücklich. Das ist keine neue Serverantwort für eine andere Abfrage.

| Ursprüngliche Metadatenantwort | SHA-256 |
|---|---|
| RU, 400.645 Bytes, Stand `2026-11-09T20:00:06Z` | `e4cb19a8db3349faf1b6533e958767ccdac5d8e16b4f7a3392dd24851216ca6e` |
| TR, 57.612 Bytes, Stand `2026-11-09T20:01:05Z` | `44bd865fa488dfec7699596ddb4bee0e3beec34bd2010e2ecb729374c9753c49` |

Die sechs Flächen liegen als vier hashgeprüfte GZip-Dateien im separaten Cache; zusammen 20.566 Bytes. Rohmetadaten und sechs echte relation/full-Antworten umfassen zusammen 925.631 Bytes. Das Manifest enthält die genauen Datei- und Provenienz-Hashes. Der lokale Cache liegt unter `.tools/atlas_sources/osm-administration/`; er ist kein verpflichtend veröffentlichter Spielinhalt.

Die erneuten Overpass-Anfragen verwendeten bereits URL-kodiertes GET. Die Hauptinstanz lieferte HTTP 502 beziehungsweise Zeitüberschreitungen, eine weitere offiziell gelistete Instanz blieb ohne Antwort und VK Maps lieferte HTTP 504. Die offizielle OSM-Lese-API lieferte für die kleinen Geometrieanfragen HTTP 200. Fehlversuche bleiben im Checkpoint und Manifest dokumentiert; sie sind keine Aussage über nicht vorhandene Verwaltungsgrenzen.

### Fortsetzung über den Pilot hinaus

Die Instanz `https://overpass.private.coffee/api/interpreter` hat anschließend die erste feste Türkei-Kachel tatsächlich beantwortet. Der erste begrenzte Kachellauf ergänzte zehn weitere echte TR-Verwaltungsflächen, wiederum ohne Geometriefehler. Dieser Checkpoint enthält insgesamt 16 reale Gebietsflächen (RU3/TR13), 121 bekannte RU- und 1.762 bekannte TR-Verwaltungsrelationen. Die erste TR-Kachel ist damit erst teilweise geometrisch bearbeitet, keine der zehn Landes-Kacheln ist bereits vollständig abgearbeitet. Der weitere Import nutzt Overpass-Batches zu 20 Kennungen.

Das Manifest unterscheidet `prepared_area_count`, `metadata_unit_count`, `pending_geometry_count`, `failed_geometry_count`, `metadata_selections` und vollständig abgearbeitete `completed_tiles`. Ein bloß erfolgreicher Metadatenabruf ist keine abgeschlossene Geometriekachel. Alle 16 Geometrien dieses Checkpoints wurden nochmals aus den tatsächlichen Rohantworten mit dem aktuellen Normalisierer aufgebaut und topologisch mit dem Cache verglichen; keine Abweichung.

## Teilstände, Lizenz und offene Arbeit

`replacement_scope="feature"` verhindert, dass dieser Teilstand vorhandene Landesdaten eines anderen Anbieters verdrängt. `blocks_full_coverage_claim=true` bleibt gesetzt, solange Kacheln oder erkannte Relationsgeometrien fehlen. Selbst ein vollständiger technischer Scan ersetzt das unabhängige Flächenaudit nicht. Die Kontrollen zählen tatsächliche Geometrien und offene Kennungen; eine Metadatenzahl allein begründet keine Vollständigkeit.

Die Tests wurden zunächst rot und anschließend grün beobachtet. Sie prüfen Verwaltungsrollen, echte verbundene/reverse Teilwege, Löcher, verschachtelte Inseln, Beschnitt, fehlende Mitglieder, Snapshotverletzungen, Offlinecache und Byte-Manipulation, Providertrennung, Prozesssperre sowie den vollständigen begrenzten Importpfad. Die Tests verwenden keinen öffentlichen Netzwerkzugriff.

Für weitere echte Flächen fehlen weiterhin der erfolgreiche vollständige RU/TR-Kachelscan und die Geometrieabfrage aller dort nachgewiesenen IDs. Die Parent-Hierarchie ist bisher nur auf Landesebene belegt; feinere Bezirkszuordnungen sind offen. Auf dem Bildschirm geprüfte Kartendarstellung und Gesamtflächenabnahme gehören in die anschließende Atlas-Integration.

Die Daten stehen unter [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). Bei Veröffentlichung sind „© OpenStreetMap contributors“ und die [zutreffenden OSM-Lizenzbedingungen für abgeleitete Datenbanken](https://www.openstreetmap.org/copyright) zu beachten; diese Quelle wird deshalb separat attribuiert und manifestiert.
