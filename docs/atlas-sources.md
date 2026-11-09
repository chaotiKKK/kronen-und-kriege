# Quellen und Buildnachweis des Offline-Atlas

Der Atlas umfasst Länge −12 bis 52° und Breite 33 bis 72° im Kartenraum 1200×760. Alle Laufzeitdaten liegen unter `data/` und werden vollständig offline mit dem Spiel verpackt. Die heutigen Verwaltungsgrenzen und Ortsnamen sind Referenzgeografie, keine behaupteten Grenzen oder Stadtgründungen der bronzezeitlichen Kampagne.

## Eingebetteter Umfang

| Objekt | Anzahl |
|---|---:|
| country | 70 |
| district | 4520 |
| local_admin | 17531 |
| municipality | 116652 |
| region | 986 |
| Städte (GeoNames) | 23463 |
| Flussnamen/-gruppen | 175 |

Deutschland enthält genau 16 Länder nach AGS. Kreise und Gemeinden werden nach dem fünf- beziehungsweise achtstelligen AGS vereinigt; führende Nullen bleiben erhalten. GF=4 wählt gemäß der [BKG-Dokumentation](https://sgx.geodatenzentrum.de/web_public/gdz/dokumentation/deu/vg250.pdf) die Landflächen. Zusätzliche Gewässerdatensätze werden nicht als weitere Gemeinden gezählt.

## Originalquellen und Lizenzen

Die folgende Tabelle nennt den tatsächlich benutzten Stand und den SHA-256 der gecachten Originaldatei beziehungsweise des vollständig aus WFS-Seiten zusammengesetzten GeoJSON-Exports. Die Hashes und URLs jeder unveränderten WFS-Antwortseite stehen zusätzlich in `data/atlas.json`.

| Quelle | Stand | Lizenz | Bytes | SHA-256 |
|---|---|---|---:|---|
| [natural-earth-countries](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson) | v5.1.2 | [Public Domain](https://www.naturalearthdata.com/about/terms-of-use/) | 13287234 | `239eec57ac17f100a11e2536cffc56752c318b50ae765b0918ff7aab4ce8f255` |
| [natural-earth-regions](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_1_states_provinces.geojson) | v5.1.2 | [Public Domain](https://www.naturalearthdata.com/about/terms-of-use/) | 40726851 | `22d0e3ad85eb3e27f17cabf8ba2d50e554fbc27a87796ff891d958185da62fb5` |
| [natural-earth-rivers](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_rivers_lake_centerlines.geojson) | v5.1.2 | [Public Domain](https://www.naturalearthdata.com/about/terms-of-use/) | 7307743 | `bb854a900ecbd3b408df46d5e16e3e0f974ba55993f9d8b5c26e855273c0905a` |
| [geonames-cities5000](https://download.geonames.org/export/dump/cities5000.zip) | 2026-11-09 | [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) | 5726119 | `550ec920954e46b7d2ff004354857383db49db4b07d848a0de80cb07b13117dd` |
| [swisstopo-land-LI-2026](https://api3.geo.admin.ch/rest/services/ech/MapServer/identify?geometryType=esriGeometryPoint&geometry=9.55%2C47.15&sr=4326&layers=all%3Ach.swisstopo.swissboundaries3d-land-flaeche.fill&imageDisplay=1000%2C1000%2C96&mapExtent=9.45%2C47.0%2C9.65%2C47.3&tolerance=0&returnGeometry=true&geometryFormat=geojson) | 2026-01-01 | [Federal Office of Topography swisstopo License](https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices) | 58286 | `b9e80b16c1a144b02c3d869e4bcd1ba9d21f05d8af74f301f3f896ad8bbbbbb8` |
| [istat-italy-enclave-SM-2023](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/ITA/ADM4/geoBoundaries-ITA-ADM4_simplified.geojson) | 2023 | [Creative Commons Attribution 3.0 License](https://creativecommons.org/licenses/by/3.0/) | 3887 | `66e979729eea5e183744d2d248501c4b0b999b60b27d3cf7e5696ee3708566bd` |
| [syke-physical-land-AX-MML2025](https://paikkatiedot.ymparisto.fi/geoserver/syke_rantaviiva/wfs) | SYKE Ranta10 (MML topographic basis 2000–2008), coastal package 2025; MML region 2025-01-01 | [CC BY 4.0 (SYKE coastline and MML administrative regional frame)](https://creativecommons.org/licenses/by/4.0/) | 88881304 | `bdaa1fcbefa781ca5f1b15a967ae2620dbcda8a5f4a145932d584d7626b690d1` |
| [act-national-LU-20261105](https://download.data.public.lu/resources/limites-administratives-du-grand-duche-de-luxembourg/20261105-042000/limadmin-shp.zip) | 2026-11-05 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 1349004 | `a8d8afcd3c85d154105568e17e946dc656429822449c04bfce738ccad16bf0aa` |
| [us-physical-islands-FO-20261109](https://gis.us.fo/arcgis/rest/services/lendiskort/us_lendiskort/MapServer/15/query?where=1%3D1&outFields=OBJECTID%2Cname%2Cfeature_id%2Cfeature_type%2Cimported_from_usgis%2Ccollection_date%2Cmodified_date&returnGeometry=true&outSR=4326&orderByFields=OBJECTID&f=geojson) | 2026-11-09 | [Faroese Environment Agency free maps/data terms, June 2019](https://www.foroyakort.fo/um-foeroyakort/terms-and-conditions-in-english) | 26173726 | `3d960a8e16c1da0f39b86e9050be3ed946ab2cb1f81478d3139f0f6797660e67` |
| [maaruum-physical-land-EE-20261101](https://s3.pilw.io/rp-kemit-kataster/EHAK/eesti_mask_json.zip) | 2026-11-01 | [Maa- ja Ruumiamet public data-service terms (Maatoimingute platvorm), 2024-03](https://kataster.ee/sites/default/files/documents/2024-03/MTP_andmeteenuste_kasutustingimused.pdf) | 88160252 | `527f3f0526f946da49a99659383e0b3c2fb9f5d7010ef1a0d75922ddcf4c32eb` |
| [eea-physical-islands-GG-v3-2017](https://marine.discomap.eea.europa.eu/arcgis/rest/services/Marine/EEA_coastline_2017/MapServer/0) | 2017-03-01 | [CC BY 4.0 (EEA physical coastline); ODbL 1.0 (separate OSM national territorial reference)](https://creativecommons.org/licenses/by/4.0/) | 221935 | `8eea76d18e835dcb85ce8c16c2e381ef3ee57d031464bf28d95927c352f77b96` |
| [eea-physical-islands-JE-v3-2017](https://marine.discomap.eea.europa.eu/arcgis/rest/services/Marine/EEA_coastline_2017/MapServer/0) | 2017-03-01 | [CC BY 4.0 (EEA physical coastline); ODbL 1.0 (separate OSM national territorial reference)](https://creativecommons.org/licenses/by/4.0/) | 76880 | `ad77aeefc1bafecc00fffd71b07a4b05d01e1c556b8d7fcc0d517c867ca1d700` |
| [bkg-vg250-vg250_lan](https://sgx.geodatenzentrum.de/wfs_vg250?service=WFS&version=2.0.0&request=GetFeature&typeNames=vg250%3Avg250_lan&outputFormat=application%2Fjson&srsName=EPSG%3A4326&CQL_FILTER=gf%3D4&sortBy=objid) | 2025-01-01 | [DL-DE-BY-2.0](https://www.govdata.de/dl-de/by-2-0) | 2658048 | `205e86d6016f93c7fc9446a9b9e906d3647436d86d64fe0c9e12de6c7424886e` |
| [bkg-vg250-vg250_krs](https://sgx.geodatenzentrum.de/wfs_vg250?service=WFS&version=2.0.0&request=GetFeature&typeNames=vg250%3Avg250_krs&outputFormat=application%2Fjson&srsName=EPSG%3A4326&CQL_FILTER=gf%3D4&sortBy=objid) | 2025-01-01 | [DL-DE-BY-2.0](https://www.govdata.de/dl-de/by-2-0) | 9288008 | `0c301c12f3f6e896775d0a2264b00241d74d1a43350577223f851fee71fdd147` |
| [bkg-vg250-vg250_gem](https://sgx.geodatenzentrum.de/wfs_vg250?service=WFS&version=2.0.0&request=GetFeature&typeNames=vg250%3Avg250_gem&outputFormat=application%2Fjson&srsName=EPSG%3A4326&CQL_FILTER=gf%3D4&sortBy=objid) | 2025-01-01 | [DL-DE-BY-2.0](https://www.govdata.de/dl-de/by-2-0) | 39633224 | `312f044c05430a743fb56caa7761864e9cd71cee0c4de490e901624822f3feff` |
| [geofabrik-HU-261108-admin6](https://download.geofabrik.de/europe/hungary-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 5380004 | `7c10230925d7503ab805531afd3f11814f464654c551a5f7fd0c023ab923c661` |
| [geofabrik-HU-261108-admin7](https://download.geofabrik.de/europe/hungary-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 5380004 | `7c10230925d7503ab805531afd3f11814f464654c551a5f7fd0c023ab923c661` |
| [geofabrik-HU-261108-admin8](https://download.geofabrik.de/europe/hungary-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 5380004 | `7c10230925d7503ab805531afd3f11814f464654c551a5f7fd0c023ab923c661` |
| [geofabrik-HU-261108-admin9](https://download.geofabrik.de/europe/hungary-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 5380004 | `7c10230925d7503ab805531afd3f11814f464654c551a5f7fd0c023ab923c661` |
| [geofabrik-SK-admin4-region](https://download.geofabrik.de/europe/slovakia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 12061021 | `0c90436ff5d7622c192bc2b8f30847a3cca9d5b73e22bdee7b40b186ca71cfcc` |
| [geofabrik-SK-admin5-municipality](https://download.geofabrik.de/europe/slovakia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 12061021 | `0c90436ff5d7622c192bc2b8f30847a3cca9d5b73e22bdee7b40b186ca71cfcc` |
| [geofabrik-SK-admin6-district](https://download.geofabrik.de/europe/slovakia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 12061021 | `0c90436ff5d7622c192bc2b8f30847a3cca9d5b73e22bdee7b40b186ca71cfcc` |
| [geofabrik-SK-admin8-local_admin](https://download.geofabrik.de/europe/slovakia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 12061021 | `0c90436ff5d7622c192bc2b8f30847a3cca9d5b73e22bdee7b40b186ca71cfcc` |
| [geofabrik-SK-admin8-municipality](https://download.geofabrik.de/europe/slovakia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 12061021 | `0c90436ff5d7622c192bc2b8f30847a3cca9d5b73e22bdee7b40b186ca71cfcc` |
| [geofabrik-SK-admin9-local_admin](https://download.geofabrik.de/europe/slovakia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 12061021 | `0c90436ff5d7622c192bc2b8f30847a3cca9d5b73e22bdee7b40b186ca71cfcc` |
| [geofabrik-EE-admin6-region](https://download.geofabrik.de/europe/estonia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 5640870 | `540f2454188d020e8120afa0521117ba185210c9f98f58c806920b58bb79c6af` |
| [geofabrik-EE-admin7-municipality](https://download.geofabrik.de/europe/estonia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 5640870 | `540f2454188d020e8120afa0521117ba185210c9f98f58c806920b58bb79c6af` |
| [geofabrik-AL-admin6-region](https://download.geofabrik.de/europe/albania-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 2272497 | `4e2ee2ecd71b31361aeeb7428d6edc333413abca496f7ece2a25440a310cd86e` |
| [geofabrik-AL-admin7-municipality](https://download.geofabrik.de/europe/albania-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 2272497 | `4e2ee2ecd71b31361aeeb7428d6edc333413abca496f7ece2a25440a310cd86e` |
| [geofabrik-AL-admin8-local_admin](https://download.geofabrik.de/europe/albania-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 2272497 | `4e2ee2ecd71b31361aeeb7428d6edc333413abca496f7ece2a25440a310cd86e` |
| [geofabrik-AL-admin9-local_admin](https://download.geofabrik.de/europe/albania-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 2272497 | `4e2ee2ecd71b31361aeeb7428d6edc333413abca496f7ece2a25440a310cd86e` |
| [geofabrik-MK-admin6-region](https://download.geofabrik.de/europe/macedonia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 752791 | `edc6cd00060c14c546545428700ee48f7ccd53f98fa3673bbe2bfba71ccfb4e5` |
| [geofabrik-MK-admin7-municipality](https://download.geofabrik.de/europe/macedonia-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 752791 | `edc6cd00060c14c546545428700ee48f7ccd53f98fa3673bbe2bfba71ccfb4e5` |
| [geofabrik-MD-admin4-region](https://download.geofabrik.de/europe/moldova-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 2581565 | `9991001b61d08dc60f4d6dbc1724c6e4282064607953a38dd55a17d486d1092e` |
| [geofabrik-MD-admin7-local_admin](https://download.geofabrik.de/europe/moldova-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 2581565 | `9991001b61d08dc60f4d6dbc1724c6e4282064607953a38dd55a17d486d1092e` |
| [geofabrik-MD-admin8-municipality](https://download.geofabrik.de/europe/moldova-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 2581565 | `9991001b61d08dc60f4d6dbc1724c6e4282064607953a38dd55a17d486d1092e` |
| [geofabrik-GG-admin10-local_admin](https://download.geofabrik.de/europe/guernsey-jersey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 120618 | `21fa88f6360d07391d8dfeb42a29318acdfc5aecbf3a98e04e1f69fc295eefea` |
| [geofabrik-GG-admin4-region](https://download.geofabrik.de/europe/guernsey-jersey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 120618 | `21fa88f6360d07391d8dfeb42a29318acdfc5aecbf3a98e04e1f69fc295eefea` |
| [geofabrik-GG-admin8-municipality](https://download.geofabrik.de/europe/guernsey-jersey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 120618 | `21fa88f6360d07391d8dfeb42a29318acdfc5aecbf3a98e04e1f69fc295eefea` |
| [geofabrik-GG-admin9-local_admin](https://download.geofabrik.de/europe/guernsey-jersey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 120618 | `21fa88f6360d07391d8dfeb42a29318acdfc5aecbf3a98e04e1f69fc295eefea` |
| [geofabrik-JE-admin10-local_admin](https://download.geofabrik.de/europe/guernsey-jersey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 137879 | `c21efb0fe47beeb2e8a770c8456356399e6ef9fa121027c925017d2f5a1aefd8` |
| [geofabrik-JE-admin8-municipality](https://download.geofabrik.de/europe/guernsey-jersey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 137879 | `c21efb0fe47beeb2e8a770c8456356399e6ef9fa121027c925017d2f5a1aefd8` |
| [geofabrik-JE-admin9-local_admin](https://download.geofabrik.de/europe/guernsey-jersey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 137879 | `c21efb0fe47beeb2e8a770c8456356399e6ef9fa121027c925017d2f5a1aefd8` |
| [osm-JE-Grouville-20261108](https://api.openstreetmap.org/api/0.6/relation/9238571/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 137879 | `c21efb0fe47beeb2e8a770c8456356399e6ef9fa121027c925017d2f5a1aefd8` |
| [geofabrik-IM-admin8-municipality](https://download.geofabrik.de/europe/isle-of-man-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 101316 | `fe4719df4c63cc49b1f8bb5ab1acc3097aa9a241e0a9dd4026f457c37d1857f2` |
| [geofabrik-FO-admin6-region](https://download.geofabrik.de/europe/faroe-islands-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 962179 | `b386f939d1a53c99f2c7683ab9a4630d6060ec3a173d60b80a3e1d4f6c4a1c82` |
| [geofabrik-FO-admin7-municipality](https://download.geofabrik.de/europe/faroe-islands-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 962179 | `b386f939d1a53c99f2c7683ab9a4630d6060ec3a173d60b80a3e1d4f6c4a1c82` |
| [geofabrik-CZ-admin4-region](https://download.geofabrik.de/europe/czech-republic/zlinsky-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [geofabrik-CZ-admin5-district](https://download.geofabrik.de/europe/czech-republic/zlinsky-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [geofabrik-CZ-admin6-district](https://download.geofabrik.de/europe/czech-republic/zlinsky-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [geofabrik-CZ-admin7-district](https://download.geofabrik.de/europe/czech-republic/zlinsky-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [geofabrik-CZ-admin8-local_admin](https://download.geofabrik.de/europe/czech-republic/olomoucky-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [geofabrik-CZ-admin8-municipality](https://download.geofabrik.de/europe/czech-republic/zlinsky-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [geofabrik-CZ-admin9-local_admin](https://download.geofabrik.de/europe/czech-republic/ustecky-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-436952-20261108](https://api.openstreetmap.org/api/0.6/relation/436952/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439175-20261108](https://api.openstreetmap.org/api/0.6/relation/439175/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439237-20261108](https://api.openstreetmap.org/api/0.6/relation/439237/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439527-20261108](https://api.openstreetmap.org/api/0.6/relation/439527/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439564-20261108](https://api.openstreetmap.org/api/0.6/relation/439564/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439572-20261108](https://api.openstreetmap.org/api/0.6/relation/439572/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439576-20261108](https://api.openstreetmap.org/api/0.6/relation/439576/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439583-20261108](https://api.openstreetmap.org/api/0.6/relation/439583/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439610-20261108](https://api.openstreetmap.org/api/0.6/relation/439610/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-municipality-439623-20261108](https://api.openstreetmap.org/api/0.6/relation/439623/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [osm-CZ-region-442452-20261108](https://api.openstreetmap.org/api/0.6/relation/442452/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 53983672 | `14e62761525deac11b99d3f84054ffdbb2194b649c7185a1a6817ee81a49dcab` |
| [geofabrik-NO-admin4-region](https://download.geofabrik.de/europe/norway/vestlandet-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6450782 | `693ce7a98bead63711c573c5b9aae68afd3223c029d7df7a09b8250bdede54f7` |
| [geofabrik-NO-admin7-municipality](https://download.geofabrik.de/europe/norway/vestlandet-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6450782 | `693ce7a98bead63711c573c5b9aae68afd3223c029d7df7a09b8250bdede54f7` |
| [geofabrik-NO-admin9-local_admin](https://download.geofabrik.de/europe/norway/vestlandet-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6450782 | `693ce7a98bead63711c573c5b9aae68afd3223c029d7df7a09b8250bdede54f7` |
| [osm-NO-municipality-406493-20261108](https://api.openstreetmap.org/api/0.6/relation/406493/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6450782 | `693ce7a98bead63711c573c5b9aae68afd3223c029d7df7a09b8250bdede54f7` |
| [osm-NO-region-406567-20261108](https://api.openstreetmap.org/api/0.6/relation/406567/full.json) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6450782 | `693ce7a98bead63711c573c5b9aae68afd3223c029d7df7a09b8250bdede54f7` |
| [geofabrik-TR-admin4-region](https://download.geofabrik.de/europe/turkey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 30153494 | `71dba0026f521a8440b555927d8faf163c78de189f8a0f0ebe5c4956b1fc68ad` |
| [geofabrik-TR-admin6-district](https://download.geofabrik.de/europe/turkey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 30153494 | `71dba0026f521a8440b555927d8faf163c78de189f8a0f0ebe5c4956b1fc68ad` |
| [geofabrik-TR-admin7-municipality](https://download.geofabrik.de/europe/turkey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 30153494 | `71dba0026f521a8440b555927d8faf163c78de189f8a0f0ebe5c4956b1fc68ad` |
| [geofabrik-TR-admin8-local_admin](https://download.geofabrik.de/europe/turkey-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 30153494 | `71dba0026f521a8440b555927d8faf163c78de189f8a0f0ebe5c4956b1fc68ad` |
| [geofabrik-RU-admin4-region](https://download.geofabrik.de/russia/volga-fed-district-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 36045835 | `287855b2d385b4a8894821b782decfd9ec5615bc254f019120c5a396c558a9ea` |
| [geofabrik-RU-admin5-district](https://download.geofabrik.de/russia/volga-fed-district-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 36045835 | `287855b2d385b4a8894821b782decfd9ec5615bc254f019120c5a396c558a9ea` |
| [geofabrik-RU-admin6-district](https://download.geofabrik.de/russia/volga-fed-district-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 36045835 | `287855b2d385b4a8894821b782decfd9ec5615bc254f019120c5a396c558a9ea` |
| [geofabrik-RU-admin8-municipality](https://download.geofabrik.de/russia/volga-fed-district-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 36045835 | `287855b2d385b4a8894821b782decfd9ec5615bc254f019120c5a396c558a9ea` |
| [geofabrik-RU-admin9-local_admin](https://download.geofabrik.de/russia/volga-fed-district-latest-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 36045835 | `287855b2d385b4a8894821b782decfd9ec5615bc254f019120c5a396c558a9ea` |
| [geofabrik-LB-admin4-region](https://download.geofabrik.de/asia/lebanon-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 914774 | `90f0adfddec49dafa604ca95d0476ac33439c9d47498eae611af9dd2ce5e9e25` |
| [geofabrik-LB-admin5-district](https://download.geofabrik.de/asia/lebanon-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 914774 | `90f0adfddec49dafa604ca95d0476ac33439c9d47498eae611af9dd2ce5e9e25` |
| [geofabrik-LB-admin7-municipality](https://download.geofabrik.de/asia/lebanon-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 914774 | `90f0adfddec49dafa604ca95d0476ac33439c9d47498eae611af9dd2ce5e9e25` |
| [geofabrik-BY-admin4-region](https://download.geofabrik.de/europe/belarus-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 8008990 | `6ab84987de8ef4b75115f04fcc545841e4b5720a0b9512f6419a3d8a14f34e6d` |
| [geofabrik-BY-admin6-district](https://download.geofabrik.de/europe/belarus-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 8008990 | `6ab84987de8ef4b75115f04fcc545841e4b5720a0b9512f6419a3d8a14f34e6d` |
| [geofabrik-BY-admin8-municipality](https://download.geofabrik.de/europe/belarus-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 8008990 | `6ab84987de8ef4b75115f04fcc545841e4b5720a0b9512f6419a3d8a14f34e6d` |
| [geofabrik-IQ-admin4-region](https://download.geofabrik.de/asia/iraq-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1926217 | `f77776e86c2ce037727c54f27f82df4a3d03bf7e541e32339b10a96fda1de11d` |
| [geofabrik-IQ-admin6-district](https://download.geofabrik.de/asia/iraq-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1926217 | `f77776e86c2ce037727c54f27f82df4a3d03bf7e541e32339b10a96fda1de11d` |
| [geofabrik-IQ-admin7-local_admin](https://download.geofabrik.de/asia/iraq-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1926217 | `f77776e86c2ce037727c54f27f82df4a3d03bf7e541e32339b10a96fda1de11d` |
| [geofabrik-SY-admin4-region](https://download.geofabrik.de/asia/syria-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1550027 | `1d3c1f73ea60e6d6701d612bc1ee9a20710720e43b66969e6fb0d80c2658f0fc` |
| [geofabrik-SY-admin5-district](https://download.geofabrik.de/asia/syria-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1550027 | `1d3c1f73ea60e6d6701d612bc1ee9a20710720e43b66969e6fb0d80c2658f0fc` |
| [geofabrik-SY-admin6-local_admin](https://download.geofabrik.de/asia/syria-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1550027 | `1d3c1f73ea60e6d6701d612bc1ee9a20710720e43b66969e6fb0d80c2658f0fc` |
| [geofabrik-TN-admin4-region](https://download.geofabrik.de/africa/tunisia-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 7096574 | `002bb51b00d40739540a98b8572f25e599e0966cfc2b8b57c9368b5f6eb03d65` |
| [geofabrik-TN-admin5-district](https://download.geofabrik.de/africa/tunisia-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 7096574 | `002bb51b00d40739540a98b8572f25e599e0966cfc2b8b57c9368b5f6eb03d65` |
| [geofabrik-TN-admin6-local_admin](https://download.geofabrik.de/africa/tunisia-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 7096574 | `002bb51b00d40739540a98b8572f25e599e0966cfc2b8b57c9368b5f6eb03d65` |
| [geofabrik-KZ-admin4-region](https://download.geofabrik.de/asia/kazakhstan-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6079840 | `1c1320b5d38a28c3a3794fd4db1ec3754e00b799f5b008cd3ff5c3b888938aac` |
| [geofabrik-KZ-admin6-district](https://download.geofabrik.de/asia/kazakhstan-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6079840 | `1c1320b5d38a28c3a3794fd4db1ec3754e00b799f5b008cd3ff5c3b888938aac` |
| [geofabrik-KZ-admin8-municipality](https://download.geofabrik.de/asia/kazakhstan-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6079840 | `1c1320b5d38a28c3a3794fd4db1ec3754e00b799f5b008cd3ff5c3b888938aac` |
| [geofabrik-IL-admin4-region](https://download.geofabrik.de/asia/israel-and-palestine-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1449235 | `31c23c169b7e65823e10bae0c5f2e5061817abba549194a32a41475984764dff` |
| [geofabrik-IL-admin5-district](https://download.geofabrik.de/asia/israel-and-palestine-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1449235 | `31c23c169b7e65823e10bae0c5f2e5061817abba549194a32a41475984764dff` |
| [geofabrik-IL-admin8-municipality](https://download.geofabrik.de/asia/israel-and-palestine-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 1449235 | `31c23c169b7e65823e10bae0c5f2e5061817abba549194a32a41475984764dff` |
| [geofabrik-JO-admin4-region](https://download.geofabrik.de/asia/jordan-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 191735 | `dc2422f96624f84e8d2b822fa2ffbe2c73e262f1f90d067e4658c4625ab6f280` |
| [geofabrik-LY-admin4-region](https://download.geofabrik.de/africa/libya-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 83776 | `1220d00bdc219070b9543bd4c24d66ffb8590f58b23684ff6bfbd2f8fb008500` |
| [geofabrik-AZ-admin8-municipality](https://download.geofabrik.de/asia/azerbaijan-261108-free.shp.zip) | 2026-11-08 | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 11161 | `884b02c20728c5c740a37c3e7dbb228904353080350d6222b1891edcbea5e6a2` |
| [gbOpen-FRA-ADM5](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FRA/ADM5/geoBoundaries-FRA-ADM5_simplified.geojson) | 2020 | [Open Data Commons Attribution License 1.0](https://opendatacommons.org/licenses/by/1-0/) | 58886663 | `35ca1a1c457d3f8911a78f614257c7d623970f6efb8bed3ec62c5c51c7b6468b` |
| [gbOpen-ITA-ADM4](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/ITA/ADM4/geoBoundaries-ITA-ADM4_simplified.geojson) | 2023 | [Creative Commons Attribution 3.0 License](https://creativecommons.org/licenses/by/3.0/) | 18353080 | `3f3d441797c9fb6631ae787ed0f00f84500824dda4ed0ed98d8529cb3cca4bbd` |
| [gbOpen-ESP-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/ESP/ADM3/geoBoundaries-ESP-ADM3_simplified.geojson) | 2018 | [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) | 18613175 | `e5bfa1c3889ea763ca2bb82c7f1e8ff9eff715dcb99ce405293a03de7ac85862` |
| [gbOpen-POL-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/POL/ADM3/geoBoundaries-POL-ADM3_simplified.geojson) | 2017 | [Creative Commons Attribution-ShareAlike 2.0](https://creativecommons.org/licenses/by-sa/2.0/) | 7277983 | `4bc15f849d519bc7e4290221e5f46de29a7a4d1277046502e686a0d70efa1654` |
| [gbOpen-AUT-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/AUT/ADM3/geoBoundaries-AUT-ADM3_simplified.geojson) | 2017 | [Creative Commons Attribution-ShareAlike 2.0](https://creativecommons.org/licenses/by-sa/2.0/) | 6014584 | `02675b87ffca0e43520151e203d49b5c14589339fce25175e5f825f1d53f2604` |
| [gbOpen-CHE-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/CHE/ADM3/geoBoundaries-CHE-ADM3_simplified.geojson) | 2022 | [Federal Office of Topography swisstopo License](https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices) | 3677733 | `6e63fa6ede78d77a0454be0a6d2baa5ee4f7d522ed7ce30f405d747819d307b7` |
| [gbOpen-DNK-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/DNK/ADM2/geoBoundaries-DNK-ADM2_simplified.geojson) | 2018 | [Public Domain](https://creativecommons.org/publicdomain/mark/1.0/) | 380355 | `d67ed4e8b7f1bb613f93edd2bfc7c69e85169aab31e19596115cf648d9b31628` |
| [gbOpen-NLD-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/NLD/ADM2/geoBoundaries-NLD-ADM2_simplified.geojson) | 2022 | [CC0 1.0 Universal (CC0 1.0) Public Domain Dedication](https://creativecommons.org/publicdomain/zero/1.0/) | 861643 | `a973d6452362a29a8b8d364df0a377362e0cf68ce8f7da0298008c77c1c678c7` |
| [gbOpen-SWE-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/SWE/ADM2/geoBoundaries-SWE-ADM2_simplified.geojson) | 2017 | [CC0 1.0 Universal (CC0 1.0) Public Domain Dedication](https://creativecommons.org/publicdomain/zero/1.0/) | 969526 | `da1070d503e08824b28f8dfac98df108f7ba07772da8c0d3a6f5016a5938801a` |
| [gbOpen-GRC-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/GRC/ADM3/geoBoundaries-GRC-ADM3_simplified.geojson) | 2010 | [CC0 1.0 Universal (CC0 1.0) Public Domain Dedication](https://creativecommons.org/publicdomain/zero/1.0/) | 1263212 | `72179d50a8a85aa9fecf996761f905db9e8a59f4eb882f8481f88651692b7e18` |
| [gbOpen-PRT-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/PRT/ADM3/geoBoundaries-PRT-ADM3_simplified.geojson) | 2021 | [CC0 1.0 Universal (CC0 1.0) Public Domain Dedication](https://creativecommons.org/publicdomain/zero/1.0/) | 5741514 | `c7d5c18b17b5cdd23581439d9c2ef0f423b33c19a93ebc1245048c0c2c3f7211` |
| [gbOpen-BGR-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/BGR/ADM2/geoBoundaries-BGR-ADM2_simplified.geojson) | 2019 | [Public Domain](https://creativecommons.org/publicdomain/mark/1.0/) | 763781 | `06274be24b1fc1fb29c61598018ab53aaa95223ab5cf3ca4bfc3860bdaf84fb9` |
| [gbOpen-HRV-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/HRV/ADM2/geoBoundaries-HRV-ADM2_simplified.geojson) | 2021 | [Creative Commons Attribution-ShareAlike 2.0](https://creativecommons.org/licenses/by-sa/2.0/) | 2196969 | `bfcda6087b26678f026c2a1ac5c4fe903bd67ad24a7c9761519f7929b3915d16` |
| [gbOpen-ROU-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/ROU/ADM2/geoBoundaries-ROU-ADM2_simplified.geojson) | 2016 | [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) | 10169381 | `401206108399ef39301b9fff1d5ab3ebd12aaeb072cf336d80197c9b26b538a2` |
| [gbOpen-UKR-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/UKR/ADM3/geoBoundaries-UKR-ADM3_simplified.geojson) | 2021 | [Creative Commons Attribution-ShareAlike 2.0](https://creativecommons.org/licenses/by-sa/2.0/) | 19557967 | `9b543b0d3bee95d6d8faebcb2fbaa49021d38e5aa464f221aae618865f186af5` |
| [gbOpen-ARM-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/ARM/ADM2/geoBoundaries-ARM-ADM2_simplified.geojson) | 2020 | [Creative Commons Attribution 3.0 Intergovernmental Organisations (CC BY 3.0 IGO)](https://creativecommons.org/licenses/by/3.0/igo/) | 207069 | `00a9e367b4a97a39786aa26965e0056e9ac7a829b1c517995c7fc9dc79af4dc8` |
| [gbOpen-GEO-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/GEO/ADM2/geoBoundaries-GEO-ADM2_simplified.geojson) | 2007 | [Public Domain](https://creativecommons.org/publicdomain/mark/1.0/) | 1299394 | `15c6b10e5418bcb5bab0a812bf69e9961b7b2e4c5c8f0f5a224709438af3ded9` |
| [gbOpen-DZA-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/DZA/ADM3/geoBoundaries-DZA-ADM3_simplified.geojson) | 2021 | [Creative Commons Attribution-ShareAlike 2.0](https://creativecommons.org/licenses/by-sa/2.0/) | 3475499 | `55bf7b1305192a190ca71cdf53f4a49c6de20648ca5b77921713a284d6f0bc9b` |
| [gbOpen-IRN-ADM4](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/IRN/ADM4/geoBoundaries-IRN-ADM4_simplified.geojson) | 2021 | [Creative Commons Attribution-ShareAlike 2.0](https://creativecommons.org/licenses/by-sa/2.0/) | 4363325 | `89d50a325cda34b4420b8b10ecbebe585825011a3c5969a3a813ef5ac386185c` |
| [gbOpen-BEL-ADM4](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/BEL/ADM4/geoBoundaries-BEL-ADM4_simplified.geojson) | 2018 | [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) | 1027535 | `dc52206dddfa403b782fb2d9567c9319e3ae85b423f61e963749aeaaab90ace3` |
| [gbOpen-LUX-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/LUX/ADM3/geoBoundaries-LUX-ADM3_simplified.geojson) | 2018 | [Public Domain](https://creativecommons.org/publicdomain/mark/1.0/) | 286245 | `01f2ce11b52ac3f80f88e78be41aaf469ea18cef687eb79609099522f6a1190f` |
| [gbOpen-LTU-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/LTU/ADM2/geoBoundaries-LTU-ADM2_simplified.geojson) | 2017 | [Open Data Commons Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 462674 | `65a2c1aa9531a6a09af906d87ddc812a290ccc0ef32ac81df4a783f5ffa04e6f` |
| [gbOpen-MNE-ADM1](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/MNE/ADM1/geoBoundaries-MNE-ADM1_simplified.geojson) | 2017 | [Open Data Commons Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 72358 | `c9afe5300b402f75cf13b5d65341d849afd631af32b220be3f74c883cab36833` |
| [gbOpen-SRB-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/SRB/ADM2/geoBoundaries-SRB-ADM2_simplified.geojson) | 2017 | [Open Data Commons Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 681679 | `a6b70eb39c0efe525bab5ca28ac3173680718577bd59b166fcd244236e8c8565` |
| [gbOpen-XKX-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/XKX/ADM2/geoBoundaries-XKX-ADM2_simplified.geojson) | 2017 | [Creative Commons Attribution-ShareAlike 2.0](https://creativecommons.org/licenses/by-sa/2.0/) | 187280 | `9da77181ae0ea7ea61fb0361217685a27e3165f7602d5142cd2e3eabf95d9ce5` |
| [gbOpen-LIE-ADM1](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/LIE/ADM1/geoBoundaries-LIE-ADM1_simplified.geojson) | 2017 | [Open Data Commons Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 18157 | `6e951b381a6529bd8fbda4194414f822777ebc8f470caa30eb89c2a8b3576ebc` |
| [gbOpen-SMR-ADM1](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/SMR/ADM1/geoBoundaries-SMR-ADM1_simplified.geojson) | 2017 | [Open Data Commons Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 7921 | `22380e2dda503552dac177bb7f76cf0baee810b3f732c5795f688f82fb23ed33` |
| [gbOpen-SVN-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/SVN/ADM2/geoBoundaries-SVN-ADM2.geojson) | 2017 | [Open Data Commons Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 5188866 | `b5e2bb260cd78a05e16a457d85cc3fce83b9ad7f65cbefc7feae6f4b836a97fe` |
| [gbOpen-BIH-ADM3](https://github.com/wmgeolab/geoBoundaries/raw/f549eab/releaseData/gbOpen/BIH/ADM3/geoBoundaries-BIH-ADM3_simplified.geojson) | 2013 | [Public Domain](https://creativecommons.org/publicdomain/mark/1.0/) | 572032 | `75d25d61ff6f3b5d5ba0ccfeb500653d2b83a83f34c806739e2b6ceb4a41a20f` |
| [gbOpen-CYP-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/CYP/ADM2/geoBoundaries-CYP-ADM2_simplified.geojson) | 2009 | [Creative Commons Attribution-ShareAlike 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/) | 1154366 | `ee42b3310282b318778fa6c1fa5695fcaec88295283645494c925cd2ab626928` |
| [map-tunisia-municipalities-OSM20261016](https://github.com/Alaa-Taieb/map-tunisia/tree/2b704248c6105ceb2d8963ef9cfa052c683d0457) | 2026-10-16T20:21:21Z | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 6840764 | `1423f9731ecb6c70e01341a0b034499d81b0111670d30b014e282703fad41ba8` |
| [geofabrik-AM-261108-qualified](https://download.geofabrik.de/asia/armenia-261108-free.shp.zip) | 2026-11-08T21:21:00Z | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 4411103 | `00b18c15f7618b893f8f4f5003512f95c7f88724bada72544040935fe3ad6a81` |
| [osm-api-AM-Chambarak-20261108](https://api.openstreetmap.org/api/0.6/relation/10853047/34.json) | 2026-11-08T21:21:00Z | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 4411103 | `00b18c15f7618b893f8f4f5003512f95c7f88724bada72544040935fe3ad6a81` |
| [gbOpen-regional-FRA-ADM1](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FRA/ADM1/geoBoundaries-FRA-ADM1_simplified.geojson) | 2022 | [Etalab Open License 2.0](https://github.com/etalab/licence-ouverte/blob/master/LO.md) | 1674230 | `7dc61e5c7e4c81f5fa10d339e6a5bc8428f1346f43f4426d9d165d2e44fc3a7e` |
| [gbOpen-regional-ITA-ADM2](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/ITA/ADM2/geoBoundaries-ITA-ADM2_simplified.geojson) | 2023 | [Creative Commons Attribution 3.0 License](https://creativecommons.org/licenses/by/3.0/) | 1259295 | `a01b6408d7d9061318034f8f4f54b377b99b5f8dcf5a7f84c5fa1e8ee3c86549` |
| [gbOpen-regional-ESP-ADM1](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/ESP/ADM1/geoBoundaries-ESP-ADM1_simplified.geojson) | 2017 | [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) | 974041 | `b61a1bf661b90883763f633f5e9dbc27e7356309e42cbe56b60d2ceab5112f63` |
| [ons-CTRY24-UK-BGC](https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Countries_December_2024_Boundaries_UK_BGC/FeatureServer/0/query?where=1%3D1&outFields=FID%2CCTRY24CD%2CCTRY24NM%2CCTRY24NMW&returnGeometry=true&outSR=4326&orderByFields=CTRY24CD&f=geojson) | 2024-12 | [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) | 12556314 | `21dac6a28850812e7fee919bf8a3ead617314b1853bddce6d30e8c9ac5fe6eb0` |
| [statfi-kunta-2026-1000k](https://geo.stat.fi/geoserver/tilastointialueet/wfs?service=WFS&version=2.0.0&typeNames=tilastointialueet%3Akunta1000k_2026&outputFormat=application%2Fjson&request=GetFeature&srsName=EPSG%3A4326&sortBy=kunta&count=1000) | 2026 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | 2774659 | `33705daedd6eca7775090678ead4de85dc3081c7eb1887288966794324217f6e` |
| [ons-LAD25-UK-BGC](https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Local_Authority_Districts_DEC_2025_Boundaries_UK_BGC/FeatureServer/0/query?where=1%3D1&outFields=FID%2CLAD25CD%2CLAD25NM%2CLAD25NMW&returnGeometry=true&outSR=4326&resultRecordCount=25&orderByFields=FID&f=geojson) | 2025-12 | [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) | 53228442 | `5693a93f9902e4a41ca2fdef81fec4a8d4f3ec5397296ba236ddf1e5cd1f6b6d` |
| [tailte-local-authorities-2019-20m](https://services-eu1.arcgis.com/FH5XCsx8rYXqnjF5/arcgis/rest/services/Administrative_Areas___OSi_National_Statutory_Boundaries___Generalised_20m/FeatureServer/0/query?where=1%3D1&outFields=ESRI_OID%2CGUID%2CCC_ID%2CENGLISH%2CGAEILGE%2CCONTAE&returnGeometry=true&outSR=4326&resultRecordCount=100&orderByFields=ESRI_OID&f=geojson) | 2019 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | 4982711 | `1dbce893ebd285736f20a9be1bbc9ab0c6dc410eeaa465034592bc637e8173c0` |
| [mml-AX-kunta-2025-10k](https://paituli.csc.fi/geoserver/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames=paituli%3Amml_hallinto_2025_10k&outputFormat=application%2Fjson&srsName=EPSG%3A4326&CQL_FILTER=NATCODE+IN+%28%27035%27%2C%27043%27%2C%27060%27%2C%27062%27%2C%27065%27%2C%27076%27%2C%27170%27%2C%27295%27%2C%27318%27%2C%27417%27%2C%27438%27%2C%27478%27%2C%27736%27%2C%27766%27%2C%27771%27%2C%27941%27%29&count=20&sortBy=NATCODE) | 2025-01-01 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | 310978 | `b3adde69b48ea012816b6296a008db1659107477656e2a37afe44ef38ef9f36a` |
| [act-LU-communes-20261105](https://download.data.public.lu/resources/limites-administratives-du-grand-duche-de-luxembourg/20261105-042000/limadmin-shp.zip) | 2026-11-05 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 18646951 | `9db2e4aacf39a806f6352039985d1879c6e27f4b8fea5075d8206e229d166e40` |
| [act-LU-cantons-20261105](https://download.data.public.lu/resources/limites-administratives-du-grand-duche-de-luxembourg/20261105-042000/limadmin-shp.zip) | 2026-11-05 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 7026847 | `e341bce23301e01487a2d2bb1cecafefd6d6532859709724fbb5b5caeb989f3f` |
| [morocco-communes-HCP2024-OSM202609](https://github.com/zkousama/morocco-communes/tree/4ec363333fea43e712820e20f59532bac5df0b07/data/v1) | HCP 2024 / OSM 2026-09-17–19 | [ODbL 1.0 (Geometrie); CC BY 4.0 (HCP-Namen und Kennungen)](https://opendatacommons.org/licenses/odbl/1-0/) | 3727248 | `30600c2dfd74b074ba9affdf35140c77851f8f02396e16873147365f0c061e42` |
| [osm-RU-admin8-20261109T200006Z](https://overpass-api.de/api/interpreter) | 2026-11-09T20:00:06Z | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 14964 | `f2155225323b8522efe6a1540ce318f6c7a47afbed3e0f36443d371a04ff7746` |
| [osm-TR-admin7-20261109T200006Z](https://overpass-api.de/api/interpreter) | 2026-11-09T20:00:06Z | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 14964 | `979decd1e763b18d6cb8efae1dd5aabb63d9f64f1ec79a7547e34b208ba4733e` |
| [osm-TR-admin8-20261109T200006Z](https://overpass-api.de/api/interpreter) | 2026-11-09T20:00:06Z | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | 14964 | `0ec5624cbb1cd78bb659954a3296c8634aa775838d9e70b34b926c121e65024a` |
| [atlas-terminal-authorities](https://github.com/chaotiKKK/kronen-und-kriege/blob/main/data/atlas_terminal_authorities.json) | 2026-11-09 | [Nicht anwendbar: eigene Strukturmetadaten; amtliche Rechtstexte werden nur verlinkt]() | 5335 | `dd1b24db8e9b3ff4c798c2a3149ea2be921c9f1560fd38e103276c12d4fb3c50` |

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
| `data/atlas.json` | 97749149 | `3df29746045fb714146926f48eb1f1ed337e12a2a5c1f82732ae0b96e27178fc` |
| `data/atlas_geometry.bin` | 57424392 | `e5040e6f85521b2ee2a5076b9d7c85a0948e20f768ca5d236820e0ecd5be1540` |

## Landesweise Abdeckung lokaler Verwaltung

Die Prozentwerte messen echte lokale Flächen gegen eine unabhängige Landreferenz im Kartenausschnitt. 95 % ist der Prüfwert für geometrische Abdeckung, kein Nachweis einer lückenlos aktuellen Verwaltungsreform. Quellabweichungen und ungeeignete Nenner bleiben gesperrt. Gemeinden und native Ortsverwaltungen werden fachlich getrennt erhalten; mehr Referenzflächen verändern die 49 Spielgebiete nicht.

| Gebiet | Name | Landabdeckung | Prüfstatus | Unabhängige Landreferenz |
|---|---|---:|---|---|
| AD | Andorra | 100.00 % | Prüfwert erreicht | natural-earth-countries |
| AL | Albanien | 98.58 % | Prüfwert erreicht | natural-earth-countries |
| AM | Armenien | 93.16 % | Quellprüfung offen | natural-earth-countries |
| AT | Österreich | 98.97 % | Prüfwert erreicht | natural-earth-countries |
| AX | Åland | 100.00 % | Prüfwert erreicht | syke-physical-land-AX-MML2025 |
| AZ | Aserbaidschan | 3.45 % | Lücke | natural-earth-countries |
| BA | Bosnien und Herzegowina | 98.14 % | Prüfwert erreicht | natural-earth-countries |
| BE | Belgien | 98.37 % | Prüfwert erreicht | natural-earth-countries |
| BG | Bulgarien | 97.91 % | Prüfwert erreicht | natural-earth-countries |
| BY | Belarus | 98.51 % | Prüfwert erreicht | natural-earth-countries |
| CH | Schweiz | 98.26 % | Prüfwert erreicht | natural-earth-countries |
| CNM | UN-Pufferzone in Zypern | 99.87 % | Quellprüfung offen | natural-earth-countries |
| CY | Republik Zypern | 99.02 % | Quellprüfung offen | natural-earth-countries |
| CYN | Türkische Republik Nordzypern | 98.05 % | Quellprüfung offen | natural-earth-countries |
| CZ | Tschechien | 99.01 % | Prüfwert erreicht | natural-earth-countries |
| DE | Deutschland | 99.31 % | Prüfwert erreicht | natural-earth-countries |
| DK | Dänemark | 97.34 % | Prüfwert erreicht | natural-earth-countries |
| DZ | Algerien | 99.63 % | Prüfwert erreicht | natural-earth-countries |
| EE | Estland | 99.97 % | Prüfwert erreicht | maaruum-physical-land-EE-20261101 |
| ES | Spanien | 99.54 % | Prüfwert erreicht | natural-earth-countries |
| ESB | Dekelia | 95.87 % | Quellprüfung offen | natural-earth-countries |
| FI | Finnland | 99.41 % | Prüfwert erreicht | natural-earth-countries |
| FO | Färöer | 99.73 % | Prüfwert erreicht | us-physical-islands-FO-20261109 |
| FR | Frankreich | 99.61 % | Prüfwert erreicht | natural-earth-countries |
| GB | Vereinigtes Königreich | 98.90 % | Prüfwert erreicht | natural-earth-countries |
| GE | Georgien | 98.81 % | Prüfwert erreicht | natural-earth-countries |
| GG | Guernsey | 97.76 % | Prüfwert erreicht | eea-physical-islands-GG-v3-2017 |
| GI | Gibraltar | entfällt (Strukturklassifikation) | Gebietsweite Verwaltung ohne zusätzliche Kommunalgliederung | natural-earth-countries |
| GR | Griechenland | 97.08 % | Prüfwert erreicht | natural-earth-countries |
| HR | Kroatien | 98.15 % | Prüfwert erreicht | natural-earth-countries |
| HU | Ungarn | 98.98 % | Prüfwert erreicht | natural-earth-countries |
| IE | Irland | 99.14 % | Prüfwert erreicht | natural-earth-countries |
| IL | Israel | 92.75 % | Lücke | natural-earth-countries |
| IM | Isle of Man | 96.51 % | Prüfwert erreicht | natural-earth-countries |
| IQ | Irak | 97.03 % | Prüfwert erreicht | natural-earth-countries |
| IR | Iran | 98.74 % | Quellprüfung offen | natural-earth-countries |
| IT | Italien | 99.34 % | Prüfwert erreicht | natural-earth-countries |
| JE | Jersey | 99.26 % | Prüfwert erreicht | eea-physical-islands-JE-v3-2017 |
| JO | Jordanien | 0.00 % | Lücke | natural-earth-countries |
| KZ | Kasachstan | 77.57 % | Quellprüfung offen | natural-earth-countries |
| LB | Libanon | 61.67 % | Lücke | natural-earth-countries |
| LI | Liechtenstein | 99.59 % | Prüfwert erreicht | swisstopo-land-LI-2026 |
| LT | Litauen | 98.82 % | Prüfwert erreicht | natural-earth-countries |
| LU | Luxemburg | 100.00 % | Prüfwert erreicht | act-national-LU-20261105 |
| LV | Lettland | 98.73 % | Prüfwert erreicht | natural-earth-countries |
| LY | Libyen | 0.00 % | Lücke | natural-earth-countries |
| MA | Marokko | 99.48 % | Quellprüfung offen | natural-earth-countries |
| MC | Monaco | entfällt (Strukturklassifikation) | Gebietsweite Verwaltung ohne zusätzliche Kommunalgliederung | natural-earth-countries |
| MD | Republik Moldau | 98.74 % | Prüfwert erreicht | natural-earth-countries |
| ME | Montenegro | 97.35 % | Prüfwert erreicht | natural-earth-countries |
| MK | Nordmazedonien | 98.66 % | Prüfwert erreicht | natural-earth-countries |
| MT | Malta | 100.00 % | Prüfwert erreicht | natural-earth-countries |
| NL | Niederlande | 99.16 % | Prüfwert erreicht | natural-earth-countries |
| NO | Norwegen | 99.12 % | Prüfwert erreicht | natural-earth-countries |
| PL | Polen | 99.24 % | Prüfwert erreicht | natural-earth-countries |
| PT | Portugal | 99.54 % | Prüfwert erreicht | natural-earth-countries |
| RO | Rumänien | 99.57 % | Prüfwert erreicht | natural-earth-countries |
| RS | Serbien | 98.49 % | Prüfwert erreicht | natural-earth-countries |
| RU | Russland | 95.40 % | Prüfwert erreicht | natural-earth-countries |
| SE | Schweden | 99.34 % | Prüfwert erreicht | natural-earth-countries |
| SI | Slowenien | 97.69 % | Prüfwert erreicht | natural-earth-countries |
| SK | Slowakei | 99.23 % | Prüfwert erreicht | natural-earth-countries |
| SM | San Marino | 99.22 % | Prüfwert erreicht | istat-italy-enclave-SM-2023 |
| SY | Syrien | 99.61 % | Prüfwert erreicht | natural-earth-countries |
| TN | Tunesien | 97.61 % | Prüfwert erreicht | natural-earth-countries |
| TR | Türkei | 55.59 % | Quellprüfung offen | natural-earth-countries |
| UA | Ukraine | 99.40 % | Prüfwert erreicht | natural-earth-countries |
| VA | Vatikanstadt | entfällt (Strukturklassifikation) | Gebietsweite Verwaltung ohne zusätzliche Kommunalgliederung | natural-earth-countries |
| WSB | Akrotiri | 96.97 % | Quellprüfung offen | natural-earth-countries |
| XK | Kosovo | 96.76 % | Prüfwert erreicht | natural-earth-countries |

Noch nicht eingebettete Quellen: atlas_overture_sources.
