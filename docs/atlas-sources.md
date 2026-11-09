# Quellen und Buildnachweis des Offline-Atlas

Der Atlas umfasst Länge −12 bis 52° und Breite 33 bis 72° im Kartenraum 1200×760. Alle Laufzeitdaten liegen unter `data/` und werden vollständig offline mit dem Spiel verpackt. Die heutigen Verwaltungsgrenzen und Ortsnamen sind Referenzgeografie, keine behaupteten Grenzen oder Stadtgründungen der bronzezeitlichen Kampagne.

## Eingebetteter Umfang

| Objekt | Anzahl |
|---|---:|
| country | 69 |
| district | 400 |
| municipality | 10949 |
| region | 1958 |
| Städte (GeoNames) | 23463 |
| Flussnamen/-gruppen | 175 |

Deutschland enthält genau 16 Länder nach AGS. Kreise und Gemeinden werden nach dem fünf- beziehungsweise achtstelligen AGS vereinigt; führende Nullen bleiben erhalten. GF=4 wählt gemäß der [BKG-Dokumentation](https://sgx.geodatenzentrum.de/web_public/gdz/dokumentation/deu/vg250.pdf) die Landflächen. Zusätzliche Gewässerdatensätze werden nicht als weitere Gemeinden gezählt.

## Originalquellen und Lizenzen

Die folgende Tabelle nennt den tatsächlich benutzten Stand und den SHA-256 der gecachten Originaldatei beziehungsweise des vollständig aus WFS-Seiten zusammengesetzten GeoJSON-Exports. Die Hashes und URLs jeder unveränderten WFS-Antwortseite stehen zusätzlich in `data/atlas.json`.

| Quelle | Stand | Lizenz | Bytes | SHA-256 |
|---|---|---|---:|---|
| [natural-earth-countries](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_50m_admin_0_countries.geojson) | v5.1.2 | [Public Domain](https://www.naturalearthdata.com/about/terms-of-use/) | 3083490 | `3e458fc036ad0a66411f2c1e6cac49c5d7bfb81cb1123bc513b22511a2b7fdeb` |
| [natural-earth-regions](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_1_states_provinces.geojson) | v5.1.2 | [Public Domain](https://www.naturalearthdata.com/about/terms-of-use/) | 40726851 | `22d0e3ad85eb3e27f17cabf8ba2d50e554fbc27a87796ff891d958185da62fb5` |
| [natural-earth-rivers](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_rivers_lake_centerlines.geojson) | v5.1.2 | [Public Domain](https://www.naturalearthdata.com/about/terms-of-use/) | 7307743 | `bb854a900ecbd3b408df46d5e16e3e0f974ba55993f9d8b5c26e855273c0905a` |
| [geonames-cities5000](https://download.geonames.org/export/dump/cities5000.zip) | 2026-11-09 | [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) | 5726119 | `550ec920954e46b7d2ff004354857383db49db4b07d848a0de80cb07b13117dd` |
| [bkg-vg250-vg250_lan](https://sgx.geodatenzentrum.de/wfs_vg250?service=WFS&version=2.0.0&request=GetFeature&typeNames=vg250%3Avg250_lan&outputFormat=application%2Fjson&srsName=EPSG%3A4326&CQL_FILTER=gf%3D4&sortBy=objid) | 2025-01-01 | [DL-DE-BY-2.0](https://www.govdata.de/dl-de/by-2-0) | 2658048 | `205e86d6016f93c7fc9446a9b9e906d3647436d86d64fe0c9e12de6c7424886e` |
| [bkg-vg250-vg250_krs](https://sgx.geodatenzentrum.de/wfs_vg250?service=WFS&version=2.0.0&request=GetFeature&typeNames=vg250%3Avg250_krs&outputFormat=application%2Fjson&srsName=EPSG%3A4326&CQL_FILTER=gf%3D4&sortBy=objid) | 2025-01-01 | [DL-DE-BY-2.0](https://www.govdata.de/dl-de/by-2-0) | 9288008 | `0c301c12f3f6e896775d0a2264b00241d74d1a43350577223f851fee71fdd147` |
| [bkg-vg250-vg250_gem](https://sgx.geodatenzentrum.de/wfs_vg250?service=WFS&version=2.0.0&request=GetFeature&typeNames=vg250%3Avg250_gem&outputFormat=application%2Fjson&srsName=EPSG%3A4326&CQL_FILTER=gf%3D4&sortBy=objid) | 2025-01-01 | [DL-DE-BY-2.0](https://www.govdata.de/dl-de/by-2-0) | 39633224 | `312f044c05430a743fb56caa7761864e9cd71cee0c4de490e901624822f3feff` |

BKG-Quellenvermerk: © BKG (2026), dl-de/by-2-0; projiziert, auf Landflächen begrenzt und vereinfacht. [Datenquellen](https://sgx.geodatenzentrum.de/web_public/gdz/datenquellen/datenquellen_vg_nuts.pdf). Der verwendete freie WFS dokumentiert Stand 01.01.2025; neuere getrennte Downloadprodukte wurden nicht damit vermischt.

GeoNames: © GeoNames, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), [Datenbeschreibung](https://download.geonames.org/export/dump/readme.txt). Koordinaten und Datenauswahl wurden projiziert und auf den Kartenausschnitt begrenzt; einige geläufige deutsche Orts- und Flussnamen wurden normalisiert. Ortsalias-Regeln gelten ausschließlich für das jeweils passende Quellland (beispielsweise Brüssel/Antwerpen/Lüttich in Belgien, Straßburg in Frankreich, Sankt Petersburg in Russland, Mailand/Florenz/Neapel/Venedig in Italien sowie Den Haag und Luxemburg). Gleichnamige Orte in anderen Ländern behalten ihren Originalnamen.

Natural Earth: Made with Natural Earth. Public-Domain-Vektoren aus dem versionierten Repository-Tag `v5.1.2`; [Nutzungsbedingungen](https://www.naturalearthdata.com/about/terms-of-use/). Die Flüsse stammen aus `ne_10m_rivers_lake_centerlines`, nicht aus erfundenen Pixel-Linien.

## Verarbeitung und Reproduktion

Die Pipeline clippt echte Geometrien im geografischen Koordinatenraum, projiziert sie anschließend gemeinsam und vereinfacht die Umrisslinien topologieerhaltend mit maximal 0,08 Kartenpixeln (Gemeinden 0,02). Die Ausgabe enthält Float32-Paare, little endian; `[offset,count]` zählt Punkte, keine Bytes. Identische Pfade teilen sich einen Pooleintrag. Die 49 ursprünglichen Simulationsgebiete werden nicht ersetzt; `province_id` wird ausschließlich durch räumliches Enthaltensein bestimmt. Orte außerhalb dieser Gebiete behalten eine leere Zuordnung.

Rohdaten und unveränderte WFS-Seiten liegen ausschließlich im ignorierten Verzeichnis `.tools/atlas_sources/`. Downloads verwenden `curl.exe` mit Zertifikatsprüfung durch Windows; es gibt keinen TLS-Bypass. Ein erneuter Build benutzt den Cache; `--refresh` ruft die Quellen ausdrücklich neu ab. GeoNames und der WFS sind veränderliche Dienste: für einen bytegleichen Neuaufbau den Cache mit den dokumentierten Quellhashes verwenden.

```powershell
python tools/build_atlas_data.py
python tools/test_atlas_data.py
```

Der Python-Test umfasst zehn gezielte Pipelinefälle und vier Prüfungen des vollständigen realen Ausgabedatensatzes: Projektion, AGS-Zusammenführung, Land-/Wassertrennung, fehlende Natural-Earth-Länderkennungen, Pfadoffsets, Budget, Elternhierarchie, alle 16 deutschen Länder, mehr als 10.000 Gemeinden, bekannte Positionen von Wiesbaden/Berlin, bestehende Spielgebietszuordnung, echte Flüsse und Quellenhashes. Vier neue Aliasfälle wurden zunächst rot beobachtet; Negativkontrollen verhindern die Umbenennung gleichnamiger Orte in anderen Ländern. Ein Geodatentest belegt keine gerenderte Karte und keinen Android-Gerätelauf.

| Builddatei | Bytes | SHA-256 |
|---|---:|---|
| `data/atlas.json` | 7527855 | `45d27dbe8a7f88d7cbb6ae9d6b059de27098072b26d0bc349a5d4b546b610a8a` |
| `data/atlas_geometry.bin` | 7772504 | `c8fa05ddbc4a63f0a5cdd3571849e4c31fa811824a485c783accca3eac29847e` |
