# Atlas: zusätzliche Quellenprüfung für Libyen und Israel

Prüfstand: 10. November 2026. Diese begrenzte Quellenprüfung erfolgte **nach
dem Einfrieren von Banger Queens 1.6.1**. Sie ergänzt den
[endgültigen Entwicklungs- und Prüfbericht](atlas-progress.md) und den
[Vorher-/Nachher-Bericht zu den 15 ursprünglich offenen Gebieten](atlas-remaining-15-audit.md).

Es wurde keine zusätzliche Verwaltungsgeometrie zugelassen. **Produktdaten,
veröffentlichte Prozentwerte, Release-Tag und Pakete von 1.6.1 bleiben
unverändert. Acht Gebiete sind weiterhin offen.** Auch die 49
Simulationsgebiete wurden nicht geändert. Dieser Nachtrag enthält neue
Quellenbefunde, keine erneute Build-, Geräte- oder Spielabnahme.

Die Untersuchung gilt für das vorhandene Atlasrechteck **−12° bis 52° Länge
und 33° bis 72° Breite**. Das ist insbesondere bei Libyen und Israel nur ein
kleiner Teil des Landes.

## Libyen: drei echte Polygonarchive, aber keine belegten heutigen Baladiyas

Zusätzlich zu den schon bekannten 100 Baladiya-Punkten wurden drei konkrete
HDX-Archive vollständig geprüft. Die Originalmetadaten, SHP-Geometrien,
Feldnamen, Objektzahlen, ursprünglichen ZIP-Prüfsummen und SHA-256-Werte
sind im privaten Audit erhalten.

| Originalquelle | Tatsächlicher Inhalt | Rolle und zeitliche Einordnung |
| --- | --- | --- |
| [COD-AB Libyen](https://data.humdata.org/dataset/cod-ab-lby), Datensatz `fd9fb749-5b68-4942-b5f9-115f20b5c00e`; [Original-SHP-Archiv](https://data.humdata.org/dataset/fd9fb749-5b68-4942-b5f9-115f20b5c00e/resource/82b6ff0a-ae3f-4af7-9eb3-a1f664433503/download/lby_admin_boundaries.shp.zip) | Admin2 enthält **22 Objekte, SHP-Typ 5: POLYGON**. Kein Satz von 100 kommunalen Grenzpolygonen. | Originalmetadaten nennen ausdrücklich 3 Provinzen und 22 Governorates. Grenzen von 2018, Qualitätsprüfung 2024. Baladiya-Grenzen werden nur als damals angekündigte spätere Ergänzung erwähnt. Lizenzmetadaten: CC BY-IGO 3.0. |
| [Admin2-Grenzen, Datensatz `9a733b0e-4f06-4123-84cf-8f44c16a108f`](https://data.humdata.org/dataset/libya-admin-level-2-boundaries); [Original `lby_Admin2_07032017.zip`](https://data.humdata.org/dataset/9a733b0e-4f06-4123-84cf-8f44c16a108f/resource/3007497c-7803-41c4-a584-1aa91325e46d/download/lby_admin2_07032017.zip) | **22 Objekte, SHP-Typ 5: POLYGON**. Das Originalfeld heißt `ADM2_Manti`. | Metadaten beschreiben die ehemalige Mintiqua-Unterteilung. Datenstand November 2016, Archiv von 2017; als archiviert markiert. Lizenz „Other“ mit zusätzlichem Legacy-Verweis, keine pauschale aktuelle Weitergabefreigabe angenommen. |
| [BSC/IOM-Verwaltungsgrenzen, Datensatz `7a8e58e7-6f4e-4236-b7b6-27cddd26da7c`](https://data.humdata.org/dataset/libya-administrative-boundaries-level-0-2); [Original `lby_admbda_adm2_BSC_IOM_20160728.zip`](https://data.humdata.org/dataset/7a8e58e7-6f4e-4236-b7b6-27cddd26da7c/resource/01a4fe56-566e-4c64-ab67-0458399ec621/download/lby_admbda_adm2_bsc_iom_20160728.zip) | **22 Objekte, SHP-Typ 5: POLYGON**, mit Feldern `ADM2_En`, `ADM2_Ar` und `ADM2_ID`. | Ausdrücklich archivierte Grenzen mit dem Hinweis, sie nicht für aktuelle Einsätze zu verwenden. Die Beschreibung von 104 Baladiyas gehört zur separaten Tabellenressource und macht die 22 SHP-Flächen nicht zu 104 Gemeindegebieten. Lizenzmetadaten: CC BY. |

Das COD-AB-Archiv enthält außerdem ein Landespolygon, drei Regionalpolygone,
66 Linien, 26 Verwaltungspunkte und 78 Ortspositionen. Keine dieser
zusätzlichen Punkt- oder Linienlagen bildet die fehlenden kommunalen
Grenzpolygone. Die Adminnummer allein wird nicht als Rollenbeleg verwendet.

### Zuwara und Farwah: der alte Code beweist keine heutige Flächengleichheit

Der Datensatz von 2016 nennt `LY0215` **„An Niquat Al Khums / النقاط الخمس“**.
Der Datensatz von 2017 nennt denselben Code **„Zwara / زوارة“**. Beide
Originalgeometrien sind exakt gleich. Eine neue Namensbezeichnung allein
belegt deshalb keinen Übergang zu einer flächengleichen heutigen
Zuwara-Baladiya.

COD-AB führt ebenfalls „Zwara“ unter `LY0215`. Seine Geometrie ist global
nicht exakt gleich: Gegenüber dem Original von 2016 beträgt die symmetrische
Differenz rund **11,441920 km²**. Im relevanten Atlasland stimmen die Schnitte
jedoch bis auf numerische Rechengenauigkeit überein: **374,119625 km²**,
entsprechend **73,185743 %** des unveränderten libyschen NE-Landanteils im
Rechteck. Es handelt sich hier tatsächlich um Land. Dieser Befund qualifiziert
aber weder das alte übergeordnete Gebiet als heutige Gemeinde noch dessen
gesamten Umfang als aktuelle Zuwara-Zuständigkeit.

**Konkret fehlt** der aktuelle Beleg der zuständigen Behörde für die
Gemeindeidentität und den territorialen Umfang von Zuwara, einschließlich
einer gegebenenfalls einschlägigen Farwah-Zuständigkeit. Dazu gehört eine
positiv zugeordnete aktuelle Grenzgeometrie oder maßgebliche Karte mit
nachgewiesenen Weitergaberechten. Die Flächengleichheit mit dem ehemaligen
Mantika wird nicht angenommen.

### Surman: der scheinbare Treffer liegt im Ausschnitt nur über Meer

Die Original-GF-Relation `15327824` heißt **„ⵚⵔⵎⴰⵏ بلدية صرمان“** und
ist als `admin_level4` erfasst. Geprüft wurde die Originalgeometrie aus dem
[Geofabrik-Libyenarchiv vom 8. November 2026](https://download.geofabrik.de/africa/libya-261108-free.shp.zip).
Ihre Bounds reichen von **12,0859579 / 32,1080974** bis
**12,6288824 / 33,0067061**.

Zwar liegen **1,842204 km²** des Rohpolygons nördlich von 33° und damit im
Atlasrechteck. Sein exakter Schnitt mit dem unveränderten NE-LY-Landanteil
beträgt dort jedoch **0 m²**. Die tatsächliche Landüberlappung des vollständigen
Polygons endet bereits bei **32,815486515° Nord**. Die kleine nördliche Spitze
ist gegenüber dieser Landreferenz ausschließlich Meeresausdehnung. Eine
spätere Rollenpräzisierung dieses Objekts südlich des Ausschnitts würde
deshalb die dargestellte libysche Landabdeckung nicht verbessern.

Die drei HDX-Archive und die fehlenden Einzelmetadaten benötigten zusammen
**752.392 neue Downloadbytes**. Es wurde kein libysches Restpolygon erzeugt
und kein höheres Gebiet zu einer Gemeinde umbenannt.

## Israel: Restflächen lokalisiert, drei amtliche Datenwege geprüft

Version 1.6.1 weist für IL unverändert **92,696891 %** gemessene örtliche
Abdeckung aus. Der kleine nördliche Ausschnitt hat eine Restfläche von rund
95,26 km². Die zusätzliche isolierte Prüfung mit den 235 vorhandenen örtlichen
GF-Einheiten ergibt **95,2553 km²**. Die Abweichung zum bereits zusammengeführten
Prüfwert beträgt ungefähr 216 m²; sie wird nicht als Fortschritt oder Änderung
des veröffentlichten Werts gewertet.

Die lokale Prüfung trennt zwei Fragen:

| Vergleich innerhalb der bisherigen Landreferenz | Restfläche | Bedeutung |
| --- | ---: | --- |
| Außerhalb des bereits früher separat untersuchten detaillierteren Länder-Vergleichsrahmens | **67,0858 km²** | Unterschiede der territorialen Referenzen; daraus folgt keine Auswahl eines neuen Staatsrahmens. |
| Auch innerhalb dieses detaillierteren Vergleichsrahmens | **28,1695 km²** | Konkrete interne Prüfkandidaten; fehlende Quellgeometrie oder gesetzlich nichtkommunales Gebiet noch nicht positiv unterschieden. |

Der diagnostische Vergleichsrahmen wurde nicht in die produktiven Daten
übernommen. Die bisherige nationale Zuordnung und die Rahmen der Nachbarländer
bleiben unverändert. Der Vergleich allein entscheidet nicht, welche
Grenzreferenz rechtlich oder vermessungstechnisch maßgeblich ist.

### Größte konkrete Restkomponenten

Die genannten örtlichen Einheiten sind benachbarte vorhandene Quellenobjekte,
keine aus räumlicher Nähe abgeleiteten Zuständigkeitszuweisungen.

| Lage und benachbarte Quellenobjekte | Fläche | Bounds: West / Süd bis Ost / Nord | Befund |
| --- | ---: | --- | --- |
| Westlich Metula, bei Obergaliläa und Mevo’ot HaHermon | 37,3386 km² | 35,481820 / 33,089483 bis 35,564874 / 33,282130 | Vollständig im Unterschied der Länderreferenzen. |
| Nördlicher Hermon, bei Golan und Majdal Shams | 11,9344 km² | 35,732841 / 33,325535 bis 35,822443 / 33,406722 | Ebenfalls vollständig im Referenzunterschied; kein daraus abgeleiteter militärischer oder nichtkommunaler Status. |
| Hurfeish / Ma’ale Yosef | 10,7510 km² | 35,324183 / 33,000000 bis 35,414823 / 33,036995 | Interne, konkret lokalisierte Prüffläche. |
| Mateh Asher / Ma’ale Yosef | 10,5427 km² | 35,189280 / 33,017997 bis 35,260833 / 33,043810 | Interne Prüffläche; tatsächliche örtliche Zuständigkeit offen. |
| Westlich Fassuta / Ma’alot-Tarshiha | 3,6846 km² | 35,279649 / 33,018828 bis 35,310837 / 33,042620 | Ebenfalls interne Prüffläche. |

Die Aufzählung zeigt die größten Komponenten und ist keine vollständige
Summenliste aller Reststücke. Die amtliche CBS-Kartenlegende kennt zwar Gebiete
ohne kommunale Zuständigkeit beziehungsweise industrielle Lokalräte. Dieser
allgemeine Legendeneintrag belegt jedoch nicht den Status dieser konkreten
Restflächen. Insbesondere wird Hermon nicht allein wegen seiner Lage als
gesetzlich nichtkommunales Grenzland eingestuft.

### Ergebnis der drei begrenzten amtlichen Routen

**1. CBS-GIS-Seite und unmittelbar verlinkte CBS-ArcGIS-Organisation.** Die
[amtliche GIS-Seite](https://www.cbs.gov.il/he/Statistics/Pages/%D7%9E%D7%A2%D7%A8%D7%9B%D7%AA-%D7%9E%D7%99%D7%93%D7%A2-%D7%92%D7%90%D7%95%D7%92%D7%A8%D7%A4%D7%99-%D7%9E%D7%9E%D7%92-GIS%D7%82.aspx)
führt zu konkreten öffentlichen Produkten. Deren tatsächliche Rollen sind:

| CBS-Kandidat | Tatsächlicher Inhalt | Schlussfolgerung |
| --- | --- | --- |
| `census_2022_setl_all_2021` | Laut amtlichem Readme eine Punktlage mit Ortspositionen 2021 und Zensusattributen 2022. | Kein Gemeinde- oder Regionalratspolygon. Das nationale Archiv wurde nicht unnötig geladen. |
| [`SOEC_Rashut_2021`](https://services2.arcgis.com/xMRYm7cNgdR5RN6F/arcgis/rest/services/SOEC_Rashut_2021/FeatureServer) | Einziger Layer: ID 1, **`esriGeometryPoint`**. Sozioökonomische Attribute nach lokaler Behörde, als Punkte veröffentlicht. | Der Behördenname im Thema belegt keine Gebietsgeometrie. |
| [`SOEC_SetlBord_2021_Dissolve`](https://services2.arcgis.com/xMRYm7cNgdR5RN6F/arcgis/rest/services/SOEC_SetlBord_2021_Dissolve/FeatureServer) | Laut Originalbeschreibung Zusammenfassung statistischer Zensusgebiete nach Ortscode. | Analytische Ortsflächen, kein positiver Nachweis gesetzlicher Behördengebiete; keine Polygonübernahme. |
| `Setl_Bord_2008` | Historische Orts-/Zensusgrenzen. | Kein aktueller kommunaler Zuständigkeitsnachweis. |
| [`product_gis.pdf`](https://www.cbs.gov.il/he/subjects/Documents/product_gis.pdf), Eintrag `bord_artzi` auf PDF-Seite 4 | Beschreibt tatsächliche statutarische MOIN-Gebiete einschließlich Regionalräten, führt sie aber als koordiniertes SDE-Verkaufsprodukt. | Kein frei verlinkter aktueller Originalabzug qualifiziert. Ein genauer aktueller Geometrie-Snapshot wurde nicht belegt. |

Die [CBS-Nutzungslizenz, Version 2.1](https://www.cbs.gov.il/he/Pages/%D7%A8%D7%99%D7%A9%D7%99%D7%95%D7%9F-%D7%A9%D7%99%D7%9E%D7%95%D7%A9.aspx)
erlaubt grundsätzlich kommerzielle und nichtkommerzielle Weitergabe und
Bearbeitung mit Zuschreibung und weiteren Bedingungen. Ausgenommene
Dritt-Rechte bleiben bestehen. Eine allgemeine Wiederverwendungserlaubnis
macht statistische Flächen aber nicht zu gesetzlichen Gemeindegrenzen.

**2. Innenministerium, Sammlung der Zuständigkeitsgrenzen.** Die
[amtliche Sammlung](https://www.gov.il/he/departments/dynamiccollectors/boundaries-judgment?skip=0&subject=sub01)
nennt unter anderem Grenzarchive für den Nordbezirk. Der normale öffentliche
Abruf antwortete in dieser Prüfung mit **HTTP 403**. Das ist ein technischer
Abrufbefund dieser Sitzung, kein pauschaler Nachweis einer Anmeldepflicht
oder einer Unzugänglichkeit für andere Nutzer. Es wurde keine Sperre umgangen.
Eine neue Originalgeometrie samt konkretem Stand und Nutzungsbeleg konnte
über diesen Abruf nicht qualifiziert werden.

**3. GovMap, öffentliche API-Dokumentation.** Der normale Abruf der
[API-Seite](https://www.govmap.gov.il/sites/api/) antwortete ebenfalls mit
**HTTP 403**. Auch dies begründet keine allgemeine Behauptung, GovMap verlange
für diese Daten eine Anmeldung. Nach dem technischen Fehler wurde dieser
Weg beendet; es wurden keine Zugangsdaten, alternativen Zugriffstricks oder
ungeprüften Gemeindeersatzflächen verwendet.

**Konkret fehlen** für die internen Galiläa-Restflächen aktuelle Originalgrenzen
mit positiv belegter Gemeinde-/Regionalratsidentität und Weitergaberecht.
Alternativ müsste die zuständige Behörde deren tatsächlichen
nichtkommunalen Status räumlich eindeutig nachweisen. Für die nördlichen
Randdifferenzen fehlt eine konsistent abgestimmte territoriale Referenz,
ohne einseitige Änderungen der Nachbarländerzuordnung.

Die CBS-Prüfung benötigte **1.135.408 neue Curl-Bodybytes**. Die beiden
abgewiesenen Abrufe lieferten keinen gespeicherten Nutzdatenbody. Es gab
keinen zusätzlichen Polygonexport und keine Änderung eines Produktwerts.

## Bedeutung für den nächsten Datenstand

Diese Nachprüfungen schließen konkrete vermeintliche Treffer aus und benennen
die verbleibenden Originalbelege. Sie beweisen nicht, dass weltweit keine
weitere brauchbare Quelle existiert. Ein späterer positiver Fund benötigt
einen gesondert koordinierten Datenstand mit Quellen-, Geometrie- und
Integrationsprüfung; er wird nicht nachträglich in die eingefrorenen
1.6.1-Pakete eingeschoben.

Der [Prüfbericht zu 1.6.1](atlas-progress.md), der
[Gesamtbericht der 15 Fälle](atlas-remaining-15-audit.md) und der vorhandene
[AM/KZ/IL-Referenzvergleich](atlas-AM-KZ-IL-audit.md) bleiben die Bezugspunkte
für die tatsächlich veröffentlichte Fassung. Die Roharchive, Originalmetadaten,
Quittungen und detaillierten Flächenvergleiche dieser zusätzlichen Prüfung
liegen ausschließlich im privaten Auditcache; sie sind keine neu zugelassenen
Laufzeitdaten.
