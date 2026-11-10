# Zusätzliche Quellen für die offenen Atlasgebiete: AZ, KZ, IL und LY

Stand: 10. November 2026. Zusätzliche Recherche nach dem eingefrorenen Stand 1.6.1. Die neuen Kandidaten bleiben im privaten Audit; keine Produktionsdaten,
Manifeste, Exporte oder veröffentlichten Pakete wurden durch diese Prüfung geändert.
Das ursprüngliche Atlasrechteck −12..52° / 33..72° und die bisherige territoriale
Zuordnung bleiben erhalten. Die 49 Simulationsgebiete werden nicht verändert.

## Konkreter Fortschritt

| Gebiet | Neuer Originalbefund | Ergebnis und nächste fehlende Voraussetzung |
|---|---|---|
| Kasachstan | Weltbank → Forschungsinstitut → öffentlicher WFS: 19 echte ländliche Okrugs in Kurmangazy und 7 in Munaily. Alle 26 aktuellen KATO-Codes und ländlichen Rollen sind amtlich bestätigt. | Stärkster neuer Kandidat: im privaten Vergleich 10.738,1625 km² bislang unbedecktes Atlasland. Die ausdrückliche Weitergabeerlaubnis der Institutsgeometrien fehlt. Grenzstand und zwischenzeitliche Flächenänderungen sind offen, nicht wegen des bloßen Alters pauschal unzulässig. |
| Israel | Öffentliches Originalarchiv des Innenministeriums, einschließlich SHP und zugehörigen Verordnungen. Hurfeish und Mateh Asher tatsächlich geladen und geometrisch verglichen. | Zusätzlicher Restüberlapp nur 0,000288 km² bzw. 0,076489 km². Damit wird keine große Innenlücke geschlossen. Eine ausdrückliche Weitergabelizenz für genau diese Sammlung ist nicht belegt. |
| Aserbaidschan | Amtliches Gemeindedienstportal, aktuelle Statistik-Webkarte, Weltbank GAD/AzRIP, FAO 2024 und ursprüngliche nationale ISCGM-Sammlung geprüft. | Echte Gemeinden sind identifizierbar; kein neuer qualifizierter Gemeindeflächensatz. Benötigt wird ein tatsächlicher kommunaler Geometriedownload mit Weitergaberecht und passendem Identitätsstand. |
| Libyen | Aktuelle Ministeriumsliste, vollständiger GIA-Katalog, UN-Habitat, UN-SALB und FAO 2024 geprüft. Zuwara ist als wirkliche Baladiya positiv belegt. | Keine neue passende Gemeindegeometrie. Die exakte territoriale Zuordnung von Farwah und angrenzendem Atlasland zu heutigen Gemeinden fehlt weiterhin; alte Mantika werden nicht als flächengleiche Baladiya ausgegeben. |

## Kasachstan: nachvollziehbare neue Geometrien

Der offizielle [Weltbankbericht zur nachhaltigen Weidenutzung](https://documents.worldbank.org/curated/en/099524306292239610/text/IDU08851a9550393604e2b08ca00765adc9b8c93.txt)
verweist auf das seit Januar 2021 öffentlich erreichbare
[Institutsportal](https://pastures.kazniizhik.kz/). Dessen eigenes Kartenformular
bezeichnet die Unterteilung als „Сельские округи“ und verwendet den tatsächlichen
WFS-Layer `Pastures2019:adm3pol`. Es wurden keine verdeckten Dienste oder
Zugangssperren umgangen. Der WFS liefert ursprüngliche MultiPolygone,
`kato_te`, native Namen und `type_k`; ein generisches ADM3 wird nicht pauschal
als Gemeinde interpretiert.

Die 26 klein und gezielt geladenen Originale sind gültig und unverändert.
Alle 26 neunstelligen Codes stehen im [aktuellen amtlichen KATO](https://stat.gov.kz/ru/classifiers/statistical/21/),
XLSX vom 4. November 2026. Alle amtlichen Namen tragen weiterhin die ländliche
Okrug-Rolle. Drei echte Umbenennungen sind über denselben Code belegt:
Байдинский → Бөкейхан, Дашинский → Жаңаталап und Ганюшкинский → Құрманғазы.
Es wurden keine Namen anhand räumlicher Nähe geraten.

Der bestehende Geofabrik-Satz mit 911 örtlichen Einheiten bedeckt im unveränderten
Kartenausschnitt 78,685806 %. Ein rein privater Vergleich mit den 26 Originalen
ergibt 84,776039 %, entsprechend 10.738,162497 km² zusätzlichem Land. Das ist
keine neue Produktkennzahl und noch kein zugelassener Importsatz.

Die [BNS-Nachnutzungsregel](https://stat.gov.kz/ru/description/) erlaubt die
Weiterverwendung seiner amtlichen Statistik. Sie wird nicht auf den getrennten
Instituts-WFS ausgedehnt. `AccessConstraints=NONE` im GeoServer und eine öffentliche
Webseite sind ebenfalls kein ausdrücklicher Nachweis der Weitergabe der Polygone.
Die allgemeine Erlaubnis, das Kartenmaterial zur Weidewirtschaft zu benutzen,
klärt das Einbetten in verteilte Spielpakete noch nicht positiv.

`relations=livestocktbl2018` belegt eine Datenbindung, kein exaktes Datum der
Grenzvermessung. Für Atameken/Baskudyk ist eine [wirkliche Grenzänderung von 2018](https://old.adilet.zan.kz/rus/docs/V18M0003648)
bekannt. Aktuelle Identität und aktuelle räumliche Ausdehnung bleiben daher
getrennte Aussagen. Ein datierter informativer Grenzsatz kann grundsätzlich
geeignet sein; es wird nur keine unbelegte 2026er Grenzgenauigkeit behauptet.


Letzter gezielter Primärlizenzweg: Die originalen WMS-Capabilities des konkreten
Institutsdienstes wurden zusätzlich gelesen (`kz-pastures-wms-license-check.xml`,
210.180 Bytes). Der Layer `adm3pol` enthält keine Attribution, Metadaten- oder
Daten-URL und keinen Lizenztext. Die allgemeinen Servicefelder `Fees=NONE` und
`AccessConstraints=NONE` werden nicht als ausdrückliches Weitergaberecht gedeutet.
Damit ist nicht bewiesen, dass eine Weitergabe verboten ist; sie ist für das
Verteilen dieser konkreten Geometrien noch nicht positiv geklärt.

## Israel: Originalquelle statt erneuter Portal-Suche

Das [öffentliche Grenzarchiv des Innenministeriums](https://gvulot-shiput-statutory-moinil.opendata.arcgis.com/)
enthält echte herunterladbare Originalpakete, keine bloßen Ortsmarker.
235 entsprechende Shapefile-Einträge sind in der öffentlichen Gruppe nachweisbar.
Die Lizenz- und Attributionsfelder der konkreten geprüften Einträge sind leer.
Das Schlagwort „Open Data“ ersetzt deshalb noch keinen positiven Rechtenachweis.

Geladen wurden genau zwei passende Originalpakete:

- [Hurfeish](https://www.arcgis.com/sharing/rest/content/items/6d16c57ae2024727a9db0d8d6d716a73/data):
  3.168.641 Bytes, eine gültige PolygonZ-Zeile, Code `0496`, EPSG:2039.
- [Mateh Asher](https://www.arcgis.com/sharing/rest/content/items/674575703b39419ca2fc6506962b9b47/data):
  11.603.289 Bytes, 57 gültige PolygonZ-Teile mit demselben Regionalratscode `04`,
  Ortsausschüssen und allgemeinem Gebiet. Das sind nicht 57 neue Gemeinden.

Datierung: Beide öffentlichen ArcGIS-Einträge wurden am 27. August 2025 angelegt
und zuletzt verändert. Das Hurfeish-SHP heißt im Original
`gv_Hurfeish_25.10.2021_plt.shp`; das Mateh-Asher-SHP
`gv_Mate Asher_2023_plt-(Nahriya).shp`. Diese tatsächlichen Dateibezeichnungen
und Katalogzeitpunkte werden getrennt von einem noch nicht aus dem Gesetzestext
ermittelten Inkrafttretens- oder Vermessungsdatum aufgeführt. Die Dateien wurden
am 10. November 2026 gelesen; daraus wird kein 2026er Grenzstand abgeleitet.

Die unveränderten Originalgeometrien wurden mit abgeschalteter PROJ-Netzwerkfunktion
und ohne geometrische Reparatur nach EPSG:4326 transformiert. Die unbekannte
Transformationsgenauigkeit bleibt ausdrücklich als unbekannt erfasst.
Hurfeish überschneidet den bestehenden Atlasrest um 0,000288158 km²;
Mateh Asher um 0,076489002 km². Keine große örtliche Innenlücke wird damit belegt
geschlossen. Die Originalverordnungen sind im jeweiligen ZIP erhalten.

Die [amtliche Ausschreibung 4/2025](https://www.gov.il/BlobFolder/rfp/tender42025/he/tender_2025_tender42025-appendix.pdf)
erläutert die Paketbestandteile: Verordnung, unterschriebene Karte und digitale
SHP/DWG-Dateien. Sie nennt die digitalen Dateien ausdrücklich nicht selbst
statutarisch. Das ist ein Genauigkeits-/Geltungsvorbehalt, kein pauschaler
Ausschluss einer informativen Referenz. Weitergabe und tatsächlicher Flächengewinn
bleiben die konkreten offenen Punkte.

## Weitere neue, begrenzt ausgeschlossene Routen

### FAO GAUL 2024

Der [FAO-Originalkatalog](https://data.apps.fao.org/catalog/iso/60b23906-f21a-49ef-8424-f3645e70264e)
weist für die neue Ausgabe ausdrücklich CC BY 4.0 aus. Es wurde kein globales
Großarchiv geladen. WFS-Schema, kleiner Attributabzug und ursprüngliche XLSX-
Metadaten zeigen tatsächlich: KZ 219 höhere Bezirks-/Stadtbezirkszeilen,
AZ 75 Zeilen einschließlich Wasser, LY 22 alte Mantika und IL 6 Zeilen mit
„Administrative Unit Not Available“. Die ländlichen Okrugs bzw. heutigen
Baladiyas fehlen in dieser konkreten Sammlung. Die Quellenreferenzen verweisen
für KZ/LY auf bekannte HDX-Vorlagen; die zusätzliche Verpackung erzeugt keine
neue kommunale Ebene.

### Aserbaidschan

Das [amtliche Gemeindedienstportal](https://e-belediyye.gov.az/) zeigt im
Abrufstand 685 Gemeinden: 74 Stadt-, 98 Siedlungs- und 513 Landgemeinden.
Die öffentliche Seite liefert keinen entsprechenden Gemeindeflächendownload.
Private Steuer-/Personendienste wurden nicht abgefragt.

Die [offizielle Statistik-Webkarte](https://azstat.gov.az/webmap/?lang=en)
nennt selbst nur Wirtschaftsregionen sowie Bezirke/Städte und räumt ein,
dass die gegenwärtigen Grenzlinien von ArcGIS stammen; amtliche Grenzen seien
für eine spätere Version vorgesehen. Der [AzRIP-Abschlussbericht](https://documents1.worldbank.org/curated/en/893931586457355703/pdf/Azerbaijan-Second-Rural-Investment-Project.pdf)
beschreibt eine Karte geolokalisierter Projektinvestitionen, keinen vollständigen
Gemeindegrenzsatz.

Ein wirklich anderes Originalarchiv, die [nationale ISCGM-Sammlung in der Universitätsbibliothek](https://geodata-prod.lib.utexas.edu/catalog/stanford-gd062vf8602),
hat zwar 136 Polygonobjekte aus einer Karte von 2009. Die veröffentlichten
Bedingungen erlauben aber keine Weiterverteilung oder kommerzielle Nutzung
ohne vorherige Zustimmung. Die kommunale Rolle dieser Polygone ist außerdem
nicht belegt. Es wurde deshalb kein unnötiges Grenzarchiv geladen.

### Libyen

Die [aktuelle Liste des Ministeriums für Kommunalverwaltung](https://www.lgm.gov.ly/municipalities)
führt Zuwara, Al Jamil, Riqdalin und Zaltan als getrennte Baladiyas.
Damit ist Zuwaras Identität belegt, nicht seine exakte Flächengleichheit mit
LY0215 oder seine vollständige Farwah-Grenze.

Der [amtliche GIA-Open-Data-Katalog](https://opendata.gia.gov.ly/english/)
wurde vollständig über seinen eigenen öffentlich verlinkten CKAN-Endpunkt
mit 166 Datensätzen gelesen. Er enthält 170 XLSX-, 30 CSV-, 21 JSON-,
18 XML- und einen unbenannten Ressourcenverweis. Die einschlägigen
Gemeindeeinträge sind statistische Tabellen; es gibt in diesem Katalogstand
keinen als SHP, GeoJSON, GeoPackage oder KML ausgewiesenen Grenzsatz.
Es wurden nicht alle einzelnen Tabellen als Geodateien heruntergeladen.

[UN-Habitat](https://unhabitat.org/libya) nennt Geodatenbanken für sechs
Stadtprofile (Benghazi, Ubari, Al Kufra, Sabha, Sirte und Janzour), keinen
positiv belegten Zuwara/Farwah-Gemeindeflächensatz. [UN-SALB](https://salb.un.org/en/data/lby)
meldet im sichtbaren Originalindex keine verfügbaren Datensätze; ein technischer
403 beim direkten Abruf wurde nicht umgangen. FAO2024 liefert wieder die
22 Mantika. Die bereits geprüften historischen HDX-Archive wurden nicht erneut
geladen oder zu heutigen Gemeinden umetikettiert.

## Reproduktion und Grenzen

Alle 49 erfolgreichen neuen Antworten sind mit Original-URL, Bytezahl und
SHA-256 erhalten. Insgesamt wurden 21.170.685 Antwortbytes bei einem Budget
von 25.000.000 Bytes gespeichert bzw. vom Transport gemeldet. Ein einzelner
fehlgeschlagener früher Formatter-Abruf bleibt ebenfalls im Transportjournal.

Offline vom Projektordner:

```powershell
python -B -X utf8 .tools/atlas_sources/audit/remaining8-second-pass-20261110/verify_second_pass.py
python -B -X utf8 .tools/atlas_sources/audit/remaining8-second-pass-20261110/il_hurfeish_pilot.py
python -B -X utf8 .tools/atlas_sources/audit/remaining8-second-pass-20261110/il_mateh_asher_pilot.py
```

Die fünf Offline-Prüfungen bestehen: exakte Originalquittungen, KZ-Geometrien
und aktuelle Codes/Rollen, IL-PolygonZ und Elterncodes, FAO-Rohanzahlen und
Downloadbudget. Das ist eine Quellenprüfung, kein Gesamtspiel-, Godot-,
Geräte-, Export- oder Multiplayer-Nachweis. Kein neuer Datensatz wurde für
die Runtime zugelassen; keine Prozentmaske und kein Landesrahmen wurden geändert.

## Originalbelege: URL, tatsächlich gelesene Bytes und SHA-256

Die nachstehende Liste enthält ausschließlich erfolgreich gelesene Originalantworten
dieser Vier-Länder-Prüfung. Ein Download ist kein Eignungs- oder Lizenznachweis.
Die Originaldateien bleiben im privaten Auditcache; insbesondere die KZ- und
IL-Geometrien werden nicht durch diesen Bericht weiterverteilt. Die URLs führen
zu den tatsächlichen öffentlichen Primär- bzw. ursprünglichen Bibliotheksquellen.

<details>
<summary>49 Originalantworten mit Prüfsummen</summary>

| Lokale Belegdatei | Originalquelle | Bytes | SHA-256 |
|---|---|---:|---|
| `az-iscgm-library-metadata.html` | [Original](https://geodata-cdn.lib.utexas.edu/catalog/stanford-gd062vf8602/metadata) | 22.401 | `d4d26be1b1d4ec8db6da7892984a4c38a2f7410c88d2b4fa7a440230615ae5b5` |
| `az-municipal-services.html` | [Original](https://e-belediyye.gov.az/) | 37.084 | `990e0c9af5e4e9f55043bb8da1b74209e16a0cae15f5e444faca9260eb668565` |
| `az-stat-webmap.html` | [Original](https://azstat.gov.az/webmap/) | 107.809 | `c6c2c1cd9d2524f738c3c22e53ffc4e9639252b3db6fed6d4c6ba59d0acf941b` |
| `fao-GAUL2024-catalog.html` | [Original](https://data.apps.fao.org/catalog/iso/60b23906-f21a-49ef-8424-f3645e70264e) | 80.627 | `13be4987d9bde50ff7b95818935674fb169ab202e8372a2a80a4d89f19a5d11d` |
| `fao-GAUL2024-four-country-attributes.json` | [Original](https://data.apps.fao.org/map/gsrv/gsrv1/gaul/ows?service=WFS&version=2.0.0&request=GetFeature&typeNames=gaul%3Ag2024_2023_2&outputFormat=application%2Fjson&propertyName=iso3_code%2Cgaul0_name%2Cgaul1_name%2Cgaul2_name&CQL_FILTER=iso3_code+IN+%28%27LBY%27%2C%27AZE%27%2C%27KAZ%27%2C%27ISR%27%29&count=2000) | 79.785 | `bd10379c41a15e7da987a926c32d66bb2a04e1eb16cb78c7584ccd251f999b83` |
| `fao-GAUL2024-l2-metadata.xlsx` | [Original](https://data.apps.fao.org/catalog/dataset/b0634117-37c0-4125-ad87-89cb9aec4eea/resource/9ee24cae-8126-4d7d-b020-94897395a17e/download/gaul_2024_l2_metadata.xlsx) | 27.479 | `cc270a6f5ae5ebeb05e34e9149dc26a9ec06d3fdfa7c72e7473818109b923457` |
| `fao-GAUL2024-package.json` | [Original](https://data.apps.fao.org/catalog/api/3/action/package_show?id=60b23906-f21a-49ef-8424-f3645e70264e) | 20.161 | `67d493a9081b68f30fa229d30ad5a319ceeddce5cb3878aae63b86c0c9c34606` |
| `fao-GAUL2024-schema.xml` | [Original](https://data.apps.fao.org/map/gsrv/gsrv1/gaul/ows?service=WFS&version=2.0.0&request=DescribeFeatureType&typeNames=gaul:g2024_2023_2) | 2.230 | `57d703c68923f346a812bb8de4c334533407f3943d2b1c54eed568c2a0eb9461` |
| `fao-GAUL2024-wfs.xml` | [Original](https://data.apps.fao.org/map/gsrv/gsrv1/gaul/ows?service=WFS&version=2.0.0&request=GetCapabilities) | 102.327 | `49ff5bcb6b0fe519fddae79b20e3243ea0a082f2304d2be4948bd027cc36aa11` |
| `il-items/069298e81f8e4e6fb96aa59913c113cd.json` | [Original](https://www.arcgis.com/sharing/rest/content/items/069298e81f8e4e6fb96aa59913c113cd?f=pjson) | 1.710 | `fbf9e098ce5533cd8ebe555376dc6fbd3170b74557a34d9c8f0c2aac17443446` |
| `il-items/4d97c52bb29f4c51990ab5b7ac44a0c5.json` | [Original](https://www.arcgis.com/sharing/rest/content/items/4d97c52bb29f4c51990ab5b7ac44a0c5?f=pjson) | 1.807 | `5e2b62cd06e52f34c3127201d552757becbf877e5eba8ac7d0b2bb317d7675ad` |
| `il-items/674575703b39419ca2fc6506962b9b47.json` | [Original](https://www.arcgis.com/sharing/rest/content/items/674575703b39419ca2fc6506962b9b47?f=pjson) | 1.404 | `feb15e54ab3de707ed4407d1136f0ba9af4cc21788d7a67a164cf500bad297a4` |
| `il-items/6d16c57ae2024727a9db0d8d6d716a73.json` | [Original](https://www.arcgis.com/sharing/rest/content/items/6d16c57ae2024727a9db0d8d6d716a73?f=pjson) | 1.422 | `5bba7dbc5ceda81a5524c98884e22304907a7f98b0a0ca87ad477d32eb1d9d24` |
| `il-items/721de02836bd423ea27c2a62058be4ae.json` | [Original](https://www.arcgis.com/sharing/rest/content/items/721de02836bd423ea27c2a62058be4ae?f=pjson) | 1.420 | `f15f9d814c4cd1e9aa3776191358a2a47e3e41556484013fdd01ef336968829d` |
| `il-moin-gis-hub.html` | [Original](https://gisdata-moinil.opendata.arcgis.com/) | 52.738 | `6c56a1d370b4ccb15cafce56a8b0a281bac51919d9ae47200a7127c9efccf7e4` |
| `il-moin-group.json` | [Original](https://www.arcgis.com/sharing/rest/search?f=json&q=group%3Af58872244d044224bfad4dabe4c464d4&num=100) | 112.340 | `35161de9f7ac7c8c4a39cc4c5a83ea0877b47c852d91c5400545f00f3fdd350f` |
| `il-moin-hub.html` | [Original](https://gvulot-shiput-statutory-moinil.opendata.arcgis.com/) | 57.905 | `628301940ced32ff84bb4db9f2c2c0db708ecb60598deaf855d0a4efd0f76e93` |
| `il-moin-org.json` | [Original](https://moinil.maps.arcgis.com/sharing/rest/portals/self?f=pjson) | 15.077 | `bfef9c0b2d31fae6d16c76a5235bda0cd29127c507bc0d8b7cc0150e89e4273b` |
| `il-moin-vector-search.json` | [Original](https://www.arcgis.com/sharing/rest/search?f=json&q=orgid%3AgvSC24scGQBSxl3v+AND+%28type%3A%22Feature+Service%22+OR+title%3A%22%D7%92%D7%9C%D7%99%D7%9C%D7%99%22+OR+title%3A%22muni_vaadim%22+OR+title%3A%22%D7%A8%D7%A6%D7%A3%22%29&num=100) | 16.750 | `01c4089ecfa013a9f765e1cdcb0a7374782b1f287742d2f3112115cb67b58a3b` |
| `il-northern-search.json` | [Original](https://www.arcgis.com/sharing/rest/search?f=json&q=group%3Af58872244d044224bfad4dabe4c464d4+AND+%28title%3A%22%D7%9E%D7%A2%D7%9C%D7%94+%D7%99%D7%95%D7%A1%D7%A3%22+OR+title%3A%22%D7%9E%D7%98%D7%94+%D7%90%D7%A9%D7%A8%22+OR+title%3A%22%D7%97%D7%95%D7%A8%D7%A4%D7%99%D7%A9%22+OR+title%3A%22%D7%A4%D7%A1%D7%95%D7%98%D7%94%22+OR+title%3A%22%D7%9E%D7%A2%D7%9C%D7%95%D7%AA+%D7%AA%D7%A8%D7%A9%D7%99%D7%97%D7%90%22+OR+title%3A%22%D7%92%D7%95%D7%9C%D7%9F%22%29&num=50) | 6.769 | `36e712aa8eab42a65058377320f9515dddfb74fdcfb4c6247a59a66e5c16b7f1` |
| `il-original/hurfeish.zip` | [Original](https://www.arcgis.com/sharing/rest/content/items/6d16c57ae2024727a9db0d8d6d716a73/data) | 3.168.641 | `5150010ec36caaee58d8f8fecfdfefc8dc68bd36351c10bf5139ebe13a5f152e` |
| `il-original/mateh-asher.zip` | [Original](https://www.arcgis.com/sharing/rest/content/items/674575703b39419ca2fc6506962b9b47/data) | 11.603.289 | `298cea7b18cd0da47bc5ce365f63d33ecce52d321343b04af6552d4c94354b44` |
| `kz-BNS-reuse.html` | [Original](https://stat.gov.kz/ru/description/) | 42.146 | `1ef558945e3887252e033413869e8a9044a276d42346cbb081b28ee606e1be9f` |
| `kz-KATO-20261104.xlsx` | [Original](https://stat.gov.kz/upload/iblock/3af/er0488xunb664axbufnw46sagt10aqsm/%D0%9A%D0%90%D0%A2%D0%9E_04.11.2026.xlsx) | 1.003.905 | `20e7db4d65e6cffd6dfbdfb54c9cb1441c603fd2e9a0d4f3b7687a0676f0421d` |
| `kz-all-rural-attributes.json` | [Original](https://pastures.kazniizhik.kz:8443/geoserver/Pastures2019/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=Pastures2019%3Aadm3pol&outputFormat=application%2Fjson&propertyName=name_adm1%2Cname_adm2%2Ckato_te%2Ctype_k%2Cname_adm3%2Cobjectid%2Crelations&maxFeatures=3000) | 722.430 | `0cc8138b9162b1e77516da8bfc6ad69866ed4758792ee094829a7c3732f32adb` |
| `kz-current-KATO-page.html` | [Original](https://stat.gov.kz/ru/classifiers/statistical/21/) | 60.172 | `4c5c49faeeb6813c84c436feeac3e22aa642b43279e38a2f7efd8352bf884082` |
| `kz-kurmangazy-current-official.html` | [Original](https://www.gov.kz/org/atyrau-kurmangazy/documents/details/939692?lang=kk) | 171.053 | `e50f318a68b033eeefbbbdaa7e2b92aeafe6eb19242ab8473a3c61a33f06c651` |
| `kz-kurmangazy-original.geojson` | [Original](https://pastures.kazniizhik.kz:8443/geoserver/Pastures2019/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=Pastures2019%3Aadm3pol&outputFormat=application%2Fjson&CQL_FILTER=name_adm2+ILIKE+%27%25%D0%9A%D1%83%D1%80%D0%BC%D0%B0%D0%BD%D0%B3%D0%B0%D0%B7%25%27&srsName=EPSG%3A4326&maxFeatures=100) | 55.310 | `003ad7ee7062c46d2f71be09ed46286b6280a2aa91b65dc2a2d5c162f4f198a0` |
| `kz-munaily-original.geojson` | [Original](https://pastures.kazniizhik.kz:8443/geoserver/Pastures2019/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=Pastures2019%3Aadm3pol&outputFormat=application%2Fjson&CQL_FILTER=name_adm2+ILIKE+%27%25%D0%9C%D1%83%D0%BD%D0%B0%D0%B9%25%27&srsName=EPSG%3A4326&maxFeatures=100) | 23.963 | `3dffe754e3e87fada19204c23bc95800342058a0f5ac5af4e52cacc2dfc6c77a` |
| `kz-pastures-about.html` | [Original](https://pastures.kazniizhik.kz/Home/About) | 216.589 | `f7cde2623bf8f4fe9709e05cb941911524f8027b193b798b50e314029492bb2c` |
| `kz-pastures-faq.html` | [Original](https://pastures.kazniizhik.kz/Home/FAQ) | 12.332 | `111c8374eafd57d43e10c7ead975cf38e64d1a22874523118e44f6f1dfb8444f` |
| `kz-pastures-instruction.html` | [Original](https://pastures.kazniizhik.kz/Home/Instruction) | 11.669 | `e7f75a277a4ff90f9d0c49c052a74ce0d84a7efda7ad4abab6ead7923d84e2e0` |
| `kz-pastures-land-supply.html` | [Original](https://pastures.kazniizhik.kz/Maps/LandSupply) | 967.883 | `78775329d44e915f15a128df0b39773a786fa84b88512e0e3bd446c2ac4ad318` |
| `kz-pastures-new-domain.html` | [Original](https://www.kazniizhik-pastures.kz/) | 37.614 | `4659413f923824befcb3b1dd56afe91852b7a25a551ea88cb6cd54576ded1929` |
| `kz-pastures-site.js` | [Original](https://pastures.kazniizhik.kz/js/site.js) | 230 | `e2ad63c0585a3da660afc580512aeec7a840ba1d170e0f643d2df1215ab7e88d` |
| `kz-pastures-wfs.xml` | [Original](https://pastures.kazniizhik.kz:8443/geoserver/Pastures2019/ows?service=WFS&version=1.0.0&request=GetCapabilities) | 22.221 | `5984bc8bbbe0fe9dfd25ccc6fa53e3e6fb672b132a6360ca9bcdcd09b05210a3` |
| `kz-pastures-wms-license-check.xml` | [Original](https://pastures.kazniizhik.kz:8443/geoserver/Pastures2019/wms?service=WMS&version=1.3.0&request=GetCapabilities) | 210.180 | `e09a8fdc1946ffe458a4a307e72d78ff1e23ef8943926114be980c8d7c11f01f` |
| `kz-pastures.html` | [Original](https://pastures.kazniizhik.kz/) | 37.614 | `91590ad7019e9847de84e1743d8a9688dd5ba65ca8827db192635e48455bf844` |
| `kz-rural-hits.xml` | [Original](https://pastures.kazniizhik.kz:8443/geoserver/Pastures2019/ows?service=WFS&version=1.1.0&request=GetFeature&typeName=Pastures2019%3Aadm3pol&resultType=hits) | 513 | `1a97771280b2ba92dce456f7a5aa4482f5b5c717ffe86b05c37634d2222fb6fb` |
| `kz-rural-schema.xml` | [Original](https://pastures.kazniizhik.kz:8443/geoserver/Pastures2019/ows?service=WFS&version=1.0.0&request=DescribeFeatureType&typeName=Pastures2019%3Aadm3pol) | 1.796 | `ab1d4e7180c5854c7031b0dab4543e2e8cf2eb5ec163259e363e291abc8ba237` |
| `kz-wb-document-metadata.json` | [Original](https://search.worldbank.org/api/v2/wds?format=json&qterm=099524306292239610) | 17.926 | `c328175a10858ca3aa5aa0e398c13df041960d2ed8ec3fe40cb55b870721b435` |
| `kz-wb-pasture-guide.txt` | [Original](https://documents.worldbank.org/curated/en/099524306292239610/text/IDU08851a9550393604e2b08ca00765adc9b8c93.txt) | 220.044 | `8d8b130714f9055a31abb12e3038f52cc2a8b73dd0b9a59b16079e598b475f09` |
| `kz-western-rural-attributes.json` | [Original](https://pastures.kazniizhik.kz:8443/geoserver/Pastures2019/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=Pastures2019%3Aadm3pol&outputFormat=application%2Fjson&propertyName=name_adm1%2Cname_adm2%2Ckato_te%2Ctype_k%2Cname_adm3%2Cobjectid%2Crelations&CQL_FILTER=name_adm1+ILIKE+%27%25%D0%90%D1%82%D1%8B%D1%80%D0%B0%D1%83%25%27+OR+name_adm1+ILIKE+%27%25%D0%9C%D0%B0%D0%BD%D0%B3%D0%B8%D1%81%D1%82%25%27&maxFeatures=1000) | 20.682 | `82b40f6c5a56d3cc9a715e50cc1667f359f1e5200786dcba05d0fcd3b7e28754` |
| `ly-gia-catalogue.json` | [Original](https://opendata.gia.gov.ly/dashboard/api/3/action/package_search?rows=200) | 942.576 | `58e69b2eacade8d49ebe85728930d7a300a83ceac2946c7e5a00902a451540e4` |
| `ly-gia-open-data.html` | [Original](https://opendata.gia.gov.ly/english/) | 27.985 | `11d9a2c5c38a5c9761159f6bfdd5d28b7601939b36bea2e5185ee0605b61ee5f` |
| `ly-official-municipalities.html` | [Original](https://www.lgm.gov.ly/municipalities) | 407.015 | `641be16e50b451878425c87eec19ad18a32f10603d5e74fa20d86f4721725c25` |
| `ly-unhabitat.html` | [Original](https://unhabitat.org/libya) | 301.826 | `3f72186077e67496a41652400000c981f51e0ec5bc21879b10892ddb4a2ca115` |
| `wb-adm2-layer.json` | [Original](https://services.arcgis.com/iQ1dY19aHwbSDYIF/ArcGIS/rest/services/World_Bank_Global_Administrative_Divisions/FeatureServer/3?f=pjson) | 13.934 | `c1d66071935776d5519739aaaa8736e138ea6d926454bd7db87348211efa9d80` |
| `wb-four-country-attributes.json` | [Original](https://services.arcgis.com/iQ1dY19aHwbSDYIF/ArcGIS/rest/services/World_Bank_Global_Administrative_Divisions/FeatureServer/3/query?where=ISO_A3+IN+%28%27AZE%27%2C%27KAZ%27%2C%27ISR%27%2C%27LBY%27%29&outFields=%2A&returnGeometry=false&f=json) | 99.902 | `627be3557b59a5ea21dc5f7bb69710c11ba26bbd35b68c46ae6317baf69ebe44` |

</details>

## Bezug zum veröffentlichten Atlas

Die [ursprüngliche Prüfung der 15 Gebiete](atlas-remaining-15-audit.md),
der [AM/KZ/IL-Referenzvergleich](atlas-AM-KZ-IL-audit.md) und die
[anschließenden LY-/IL-Negativbefunde](atlas-open-source-followups.md)
bleiben die Ausgangsbelege für 1.6.1. Dieser zusätzliche Bericht beschreibt
konkrete neue Quellenwege und ihre Grenzen. Er setzt keine Kandidaten frei,
verschiebt keine Staatsgrenzen und bescheinigt weder hundertprozentige Flächen-
noch aktuelle Behördenvollzählung. Weitere Integrations- oder Spieltests sind
nicht Bestandteil dieser Quellenprüfung.
