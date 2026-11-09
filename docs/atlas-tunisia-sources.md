# Tunesische Gemeindegrenzen

Der Provider importiert die **338 tatsächlichen kommunalen Quellpolygone** von
[Map Tunisia, Alaa Taieb](https://github.com/Alaa-Taieb/map-tunisia/tree/2b704248c6105ceb2d8963ef9cfa052c683d0457).
Der festgeschriebene Commit ist `2b704248c6105ceb2d8963ef9cfa052c683d0457`
vom 24. Oktober 2026. Grundlage ist der OSM-Extrakt vom **16. Oktober 2026,
20:21:21 UTC**; der Quellbericht nennt dafür SHA-256
`444dd6e1e64e1ab4626cde5e54d911876c7761b63f4624a98872421007f50429`.
Das ist ein datierter OSM-Datenstand, kein amtlicher Nachweis eines vollständigen
Gemeindebestands im November 2026.

Die [Produzentenmethodik, Abschnitt 9](https://github.com/Alaa-Taieb/map-tunisia/blob/2b704248c6105ceb2d8963ef9cfa052c683d0457/docs/methodology.md#9-municipalities)
weist diese Baladiyat ausdrücklich als OSM-Relationen mit
`boundary=municipality` aus. Dafür wird **kein `admin_level` vorausgesetzt oder
erzeugt**. Délégations und Imadas sind andere Verwaltungseinheiten; aus ihren
Flächen werden keine Gemeinden abgeleitet. Gemeindegrenzen können mehrere
Délégations schneiden. Der Reader verwendet deshalb `country:TN` als Elternobjekt
und erhält das vom Produzenten zugeordnete Gouvernorat als Quellattribut.

Die unveränderte [kommunale Quell-GeoJSON](https://raw.githubusercontent.com/Alaa-Taieb/map-tunisia/2b704248c6105ceb2d8963ef9cfa052c683d0457/data/source/tunisia-municipalities.geojson)
umfasst 6.702.026 Bytes; ihr SHA-256 ist
`4db4db6a972077cb0cf3a0c470e4c70afdaea9760b18d6b09b76cd039fa90d55`.
Die Namen werden über `municipality-<OSM-Relationsnummer>` mit der ebenfalls
festgeschriebenen CSV verbunden. Die Relationskennung bleibt pro Einheit erhalten.
Der Produzent liefert keine individuellen Relationsversionen; der Import erfindet
keine. Alle 338 Polygone sind gültig: 331 Polygon- und 7 MultiPolygon-Geometrien.
**335 Einheiten** schneiden den Atlas-Ausschnitt `[-12, 33, 52, 72]` mit positiver
Fläche. Der Reader liefert alle 338 Quellobjekte; die allgemeine Atlas-Erzeugung
schneidet die sichtbaren Polygone am Kartenausschnitt ab. Diese Zahlen sind keine
amtlichen Sollzahlen und keine Flächenabdeckungsquoten.

Die [Datenlizenz des Produzenten](https://github.com/Alaa-Taieb/map-tunisia/blob/2b704248c6105ceb2d8963ef9cfa052c683d0457/LICENSE-DATA.md)
weist Geometrien und Attribute als **ODbL 1.0** aus. Die individuelle Herkunft wird
in jeder importierten Einheit und im Manifest mitgeführt:

> Map data © OpenStreetMap contributors · Map Tunisia by Alaa Taieb; ODbL 1.0

Das Manifest enthält die Lizenzadresse, den gepinnten Commit, den OSM-Zeitstempel,
die einzelnen Datei-URLs und SHA-256-Werte. Geometrie, CSV, Lizenz, Quellberichte,
Methodik und Extraktionsskript werden vor jedem Lesen auf ihre festgeschriebenen
Bytes und Hashes geprüft. Der Reader lädt nichts nach und ändert keine Cache-Datei.
`prepare_sources(cache)` lädt bei Bedarf ausschließlich fehlende, gepinnte Dateien
und schreibt nur das eigene Quellenmanifest.

Die [kommunalen Quellberichte](https://github.com/Alaa-Taieb/map-tunisia/blob/2b704248c6105ceb2d8963ef9cfa052c683d0457/data/source/municipalities-report.json)
bleiben Bestandteil des Herkunftsnachweises. Die vom Produzenten gemeldeten
97,86 % beziehen sich auf dessen eigene Landesgeometrie. Der Atlas muss seine
Abdeckung innerhalb des sichtbaren Ausschnitts mit seiner unabhängigen
Landesreferenz messen. Die bekannten Lücken werden nicht aufgefüllt;
`blocks_full_coverage_claim` bleibt gesetzt. Die historischen Angaben zu 350
Gemeinden nach der Reform werden nicht als aktueller Vollständigkeitsmaßstab
verwendet.

Zwei Namensdubletten bleiben getrennte Quellrelationen:

| Quellname | OSM-Relationen | Gouvernorat |
|---|---|---|
| Ben Arous | 7209941, 7304421 | TN-13 |
| Fouchana | 7209947, 7209948 | TN-13 |

Der Produzent vermutet zwei falsche OSM-Namen, behält sie aber bei; auch der Import
benennt keine Gemeinde eigenständig um. Bereits der Produzent hat seine kommunale
Ebene an seiner Landesgeometrie beschnitten und einen 6,468 km² großen Überlapp
von Relation 7304421 zugunsten der kleineren Relation 7209941 entfernt. Der Import
übernimmt genau diese veröffentlichte Quellgeometrie. Er führt keine weitere
Reparatur, Überlappungsauflösung, Zusammenfassung oder Flächenzuweisung aus.

Vorbereitung und Prüfung im Projektverzeichnis:

```powershell
python tools/atlas_tunisia_sources.py
python tools/test_atlas_tunisia_sources.py
```

Der separate Audit-Cache liegt unter
`.tools/atlas_sources/audit/tunisia-municipal-2026/`. Die Produktionsintegration
erfolgt durch den allgemeinen Supplement-Provider; der tunesische Reader ändert
keine fremden Quellen oder deren Prioritäten.
