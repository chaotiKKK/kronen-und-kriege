# Jordanien: tatsächliche örtliche Zuständigkeit im Kartenausschnitt

Prüfstand: 10. November 2026. Die Karte beginnt bei 33° Nord und zeigt damit nur rund 1.598 km² des äußersten Nordostens Jordaniens, keinen landesweiten Gemeindeatlas.

Der neue Provider übernimmt genau die originale Geofabrik-/OSM-Relation **13376111**, `لواء الرويشد`, als **district / Liwa**. Eine zusätzliche, ausdrücklich **dekonzentrierte lokale Verwaltungszuständigkeit** wird dokumentiert; daraus entsteht weder ein gewählter Gemeinderat noch eine neue Gemeindegrenze. Der fast deckungsgleiche ältere Admin6-Datensatz 13376112 wird nicht als zweite örtliche Behörde gezählt.

Die amtliche [DOS-Verwaltungsgliederung 2025, veröffentlicht Januar 2026](https://dosweb.dos.gov.jo/databank/Population/Population_Estimares/PopulationEstimates.pdf) führt Ruwaished als Liwa. Das [Organigramm des Kulturministeriums für Mafraq](https://culture.gov.jo/AR/ListDetails/أرشيف_مدن_الثقافة_الأردنية/96/4) ordnet die tatsächlichen Qadaa den anderen drei Liwa zu. Das [Innenministerium, Verwaltungsorganisationsverordnung 47/2000 mit Änderungen](https://www.moi.gov.jo/ebv4.0/root_storage/ar/eb_list_page/نظام_التشكيلات_الادارية_.pdf) belegt die staatliche Verwaltungsrolle und Aufgaben; sie wird ausdrücklich von kommunaler Selbstverwaltung unterschieden.

Eine flächendeckende Gemeindeausweisung wäre hier falsch: Die [Royal Society for the Conservation of Nature zur Burqu-Reserve](https://www.rscn.org.jo/public/reserve/5) beschreibt deren Gebiet ausdrücklich außerhalb kommunaler Grenzen. Der Provider behauptet deshalb **keine nachgewiesene Gemeindegrenze**. Diese Einschränkung steht zusätzlich als `municipal_boundary_status` am Objekt und in `nonmunicipal_terminal_administration` bei der gemessenen Verwaltungsabdeckung.

Die unveränderte Liwa-Geometrie deckt gegen die bisherige unabhängige Natural-Earth-Landreferenz **95,8170 %** des dargestellten jordanischen Landanteils. Der Wert beschreibt die örtliche staatliche Zuständigkeit im Kartenausschnitt. Er belegt keine vollständige jordanische Gemeindegliederung und keine Grenzen der Ruwaished-Gemeinde.

Quelle: [Geofabrik Jordanien, Snapshot 8. November 2026](https://download.geofabrik.de/asia/jordan-261108-free.shp.zip), OSM-Zeitstempel `2026-11-08T21:21:00Z`. Lizenz: [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/), © OpenStreetMap contributors / Geofabrik GmbH. Alle fünf ursprünglichen SHP-Komponenten werden vor Verwendung mit festgehaltenen Größen und SHA-256 geprüft. Das ursprüngliche Polygon bleibt unverändert; es wird weder an Gemeindegrenzen angepasst noch aus einer Restfläche erzeugt.

Reproduzierbare Vorbereitung: `python tools/atlas_jordan_sources.py`. Der normale Atlasbuild liest ausschließlich das vorbereitete Manifest und den hashgeprüften lokalen Cache.
