# Offene Länder: kommunale Rollen und selektive Geofabrik-Extrakte

Prüfdatum: **9. November 2026**. Diese Recherche ergänzt die bisherigen
kommunalen und amtlichen Provider. Sie nimmt noch keine neue Quelle in den
Gesamtatlas auf und behauptet für keines der zehn Länder vollständige
kommunale Flächendeckung.

## Ergebnis für die Importreihenfolge

**Libanon ist der beste kleine Folgepilot:** echte Gemeindeebene ist OSM-Level
7; im Archiv befinden sich 1.031 Kandidaten. Die vollständigen relevanten
Admin-SHP-Komponenten benötigen zusammen nur 1,35 MB komprimiert. Danach
lohnen sich Belarus und der im Atlas liegende westliche Teil Kasachstans.
Israel/Palästina benötigt vor jeder Rollenvergabe eine territoriale Trennung.

Aserbaidschan hat viel zu wenige Kandidaten für einen vollständigen aktuellen
Gemeindeimport. Tunesiens Gemeinden sind vom üblichen administrativen
Level-Schema getrennt. Libyen enthält im untersuchten Admin-Layer keine
kommunale Ebene. Für Irak und Syrien sind echte örtliche Verwaltungseinheiten
zugänglich, deren Typ **Nahiya / Ortsverwaltung** beibehalten werden muss.
Sie erfüllen dadurch noch keinen Nachweis einer vollständigen Gemeindeebene.

## Rollenmatrix

Die OSM-Zuordnungen beruhen auf der
[länderspezifischen Tabelle des OSM-Projekts](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative#Country_specific_values_of_the_key_admin_level%3D*).
Sie ist eine Tagging-Konvention, kein Gesetz und kein Beleg für die
Vollständigkeit tatsächlicher Daten. Die folgenden nationalen Primärquellen
belegen davon getrennt die Rolle der jeweiligen Einheiten.

| Land | Tatsächliche örtliche Rolle | Geeigneter OSM-Kandidat | Beobachtete Archivdaten | Zulässige Folgerung |
|---|---|---|---|---|
| **BY Belarus** | Primäre Stadt-, Siedlungs- und Dorfräte; `сельсовет / сельсавет` | Level **8**; höhere eigenständige Städte gesondert identifizieren | 1.325 Level-8-Kandidaten; Level 10 zusätzlich 22.395 Siedlungsgrenzen | Level 8 für belegte örtliche Räte prüfen. Siedlungsumrisse auf Level 10 nicht pauschal als eigenständige Gemeinden verwenden. Vollständigkeit der Städte-/Landkombination offen. |
| **AZ Aserbaidschan** | `bələdiyyə`, kommunale Selbstverwaltung | Level **8** | Nur **19** Kandidaten, darunter iranische Pufferobjekte | Keine Vollständigkeit. Aktuell amtlich 685 Gemeinden nach Zusammenlegung 2024/25; nicht mit rund 80 Rayons auf Level 6 ersetzen. |
| **KZ Kasachstan** | `ауылдық округ / сельский округ` sowie selbständige Städte, Siedlungen und Dörfer der örtlichen Selbstverwaltung | Ländliche Bezirke Level **8**; Stadttypen separat | 927 Level-8-Kandidaten, 228 Level 6 | Echte örtliche Verwaltung mit Originaltyp; keine globale Aussage, dass alle Level-8-Grenzen gleichartige Gemeinden seien. Abdeckung des westlichen Atlas-Ausschnitts nach Geometrieimport messen. |
| **TN Tunesien** | `commune / بلدية` kommunal; davon getrennt `délégation`, `imadat` | Gemeinden im untersuchten OSM-Verfahren **`boundary=municipality` ohne admin_level** | Admin-Layer: 266 Level 5, 2.084 Level 6, lediglich 2 Level 8 | 2.084 Sektoren sind keine 2.084 Gemeinden. Kommunalpolygone aus gesonderten Relationen/PBF oder amtlicher Quelle holen. Admin-SHP allein ist dafür unzureichend. |
| **LY Libyen** | `baladiya / بلدية`, kommunale Räte; älteres `shabiya` ist eine andere Ebene | Kein belastbarer kommunaler OSM-Level aus diesem Archiv | 23 Level 4; keine Level 6–10 | Alte Distrikte nicht zu Gemeinden erklären. Separaten aktuellen Baladiya-Datensatz suchen; Geofabrik-Admin-Pilot bringt hier keine lokale Detailabdeckung. |
| **LB Libanon** | `baladiya / بلدية`, Gemeinde | Level **7** | 1.031 Level 7; 67 Level 8 | Level 7 ist der aussichtsreiche Kommunalpilot. Katastergebiete/Quartiere auf Level 8 und Gemeindeverbände separat halten. |
| **IL Israel** | Stadtgemeinde, Ortsrat, Regionalrat | Level **8** | Gemeinsames IL/PS-Archiv: 279 Level 8, dazu Nachbarobjekte | Regionale Räte sind örtliche Behörden trotz ihres Namens. Originaltyp erhalten. Palästinensische Gemeinden und syrische Grenzobjekte nicht allein wegen des Dateinamens Israel zuordnen. |
| **JO Jordanien** | `baladiya`, Gemeinde einschließlich besonderer Hauptstadtregelung | Kommunaler Level im Archiv **nicht belegt** | Nur ein Level 8; 51 Level 5 und 90 Level 6 mit Liwa-/Qadaa-Namen | Die tatsächlich beobachteten Verwaltungslevel weichen von der älteren OSM-Tabellenkonvention ab. Level 5/6 sind kein Kommunalnachweis. Keine Gemeindezuordnung nur aus der Zahl ableiten. |
| **IQ Irak** | `nāḥiya / ناحية`, örtlicher Verwaltungsbezirk; kommunale Baladiya davon unterscheiden | Level **7** als `local_admin` | 404 Level-7-Kandidaten, mit Nachbarpuffer | Lokale Verwaltung ausdrücklich als Nahiya anzeigen. Level 8/9 enthalten untergeordnete Gebiete und Nachbarobjekte; keine generische Gemeindezuordnung. |
| **SY Syrien** | `nāḥiya / ناحية`, Unterbezirk; Städte/Orte und Damaskus-Baladiyat gesondert | Level **6** als `local_admin`; Level 8 nur nach zusätzlichem Rollennachweis | 277 Level 6; 25 Level 8, letztere mit türkischen Mahalle-Beispielen | Nahiya-Grenzen sind echte Verwaltung, keine automatisch belegte kommunale Selbstverwaltung. Kein Landesschluss aus den 25 Level-8-Archivobjekten. |

**Sämtliche Zahlen in der Spalte „Archivdaten“ sind DBF-Zahlen des
Geofabrik-Ausschnitts mit Grenzpuffer. Sie sind keine amtlichen Landeszahlen.**
Aus den Beispielen sind Nachbarländer direkt erkennbar: Das AZ-Archiv enthält
iranische Level-8-Namen, BY enthält lettische/ukrainische/polnische Einheiten,
SY enthält türkische `Mahallesi`. Zuerst Gebiet und Identität auflösen, danach
die für dieses tatsächliche Land belegte Rollenregel anwenden. Ein früherer
Dateiname darf die Länderprüfung nicht ersetzen.

## Nationale Primärquellen und verbleibende Unsicherheit

### Belarus

Das [Gesetz Nr. 108-З vom 4. Januar 2010, Art. 1 und 2, Originaltext bei der ILO](https://natlex.ilo.org/dyn/natlex2/natlex2/files/download/86988/BLR86988.pdf)
unterscheidet regionale, Basis- und primäre Räte. Stadtgemeinden unter
Rayonverwaltung, Siedlungs- und Dorfräte gehören zur primären Ebene.
Selbständige größere Städte können in anderen Ebenen geführt werden.
Die gesetzliche Rollenbezeichnung ist dadurch belegt; ein aktueller vollständiger
Abgleich sämtlicher Räte gegen amtliche IDs steht noch aus. Der Gesetzestext
ist kein frei neu lizenzierter Geometriedatensatz.

### Aserbaidschan

Das [Justizministerium zur Gemeindereform](https://justice.gov.az/az/news/edliyye-nazirliyi-belediyyelerle-bagli-tovsiye-hazirlayib)
bezeichnet die Gemeinden als Organe örtlicher Selbstverwaltung und bestätigt
685 Einheiten nach der Zusammenlegung. Das
[staatliche Gemeindedienstportal](https://e-belediyye.gov.az/)
weist sie als 74 Stadt-, 98 Siedlungs- und 513 Dorfgemeinden aus. Die
unzureichende OSM-Grenzabdeckung wird durch eine höhere Ebene nicht geheilt.

### Kasachstan

Das [Gesetz über örtliche Verwaltung und Selbstverwaltung, Art. 39-1](https://old.adilet.zan.kz/eng/docs/Z010000148_)
nennt unter anderem Stadt, ländlichen Bezirk, Siedlung und selbständiges Dorf
als Gebiete örtlicher Selbstverwaltung. Das
[Verfassungsgesetz über die territorialen Verwaltungseinheiten von 2026](https://old.adilet.zan.kz/eng/docs/Z2600000300)
unterscheidet Gebietskörperschaften und Siedlungskategorien. Damit ist ein
`ауылдық округ` keine erfundene Unterteilung; ein Raster von Level-8-Polygonen
beweist jedoch weder alle kommunalen Stadttypen noch vollständige Landesfläche.

### Tunesien

Die [amtliche regionale Entwicklungsstudie](https://www.cgdr.nat.tn/upload/files/Etudes/Etude/Evaluation_PRD_Rapport%20Phase2%20VFinale.pdf)
beschreibt die vollständige Kommunalisierung durch 350 Gemeinden im Stand der
Reform 2018. Diese Zahl ist ausdrücklich ein datierter Reformbeleg, keine
verifizierte Anzahl des aktuellen OSM-Polygondatensatzes. Die unabhängige
[Originalmethodik des OSM-Datenproduzenten map-tunisia](https://github.com/Alaa-Taieb/map-tunisia/blob/main/docs/methodology.md)
trennt Delegationen/Sektoren von `boundary=municipality` und meldet fehlende
Gemeindegeometrien. Ein etwaiger Import dieses zusätzlichen Produkts muss
dessen Originalgeometrien und Lizenzen gesondert prüfen; der Text allein wird
nicht als Freigabe eines fertigen Atlas-Providers behandelt.

### Libyen

Der [UNDP-Strategierahmen für Libyen 2019–2022](https://www.undp.org/sites/g/files/zskgke326/files/2022-06/UN-Startegic-Framework-for-Libya-2019-2022.pdf)
belegt kommunale Räte unter Gesetz 59/2012. Der von der Weltbank veröffentlichte
[Bericht des Libya Local Government Forum](https://documents1.worldbank.org/curated/en/889311615360771327/pdf/Proceedings-of-the-Libya-Local-Government-Forum.pdf)
beschreibt getrennt Provinzen, Gemeinden und örtliche Einheiten sowie
kommunale Dienstleistungen. Beide Primärberichte begründen die reale
Baladiya-Rolle; sie liefern hier keine geprüfte aktuelle offene Grenzdatei.

### Libanon

Das [Kommunalgesetz, Gesetzesdekret 118/1977, Originaltext der staatlichen DGLAC](https://www.dglac.gov.lb/documents/20124/38882/%D9%85%D8%B1%D8%B3%D9%88%D9%85%20%D8%A7%D8%B4%D8%AA%D8%B1%D8%A7%D8%B9%D9%8A%20%D8%B1%D9%82%D9%85%20118.pdf/124fbe4a-47fb-7bc2-0e99-88ca47c5908b?t=1762384022283)
belegt die Gemeinde als örtliche Verwaltung. Art. 6 trennt ihre
Verwaltungsgrenze ausdrücklich von Einträgen des Katasterregisters. Deshalb
werden Katasterzonen nicht durch Namensähnlichkeit zu Gemeinden erklärt.
Das [Originalgesetz in der Gesetzesdatenbank der Lebanese University](https://legallaw.ul.edu.lb/Law.aspx?lawId=244078)
ist ein zusätzlicher Zugang. Der neue Pilot sollte echte Level-7-Polygone
räumlich zuordnen und ihre Union gegen eine unabhängige Landmaske prüfen.

### Israel

Die [israelische Statistikbehörde CBS, Kapitel Local Authorities](https://www.cbs.gov.il/he/publications/DocLib/isr_in_n/sr_in_n21e.pdf)
belegt die drei lokalen Behördentypen Gemeinden, Ortsräte und Regionalräte.
Alle erfüllen örtliche kommunale Aufgaben; die bloße englische Bezeichnung
`regional council` macht sie nicht zu einer übergeordneten Provinz. Das
gemeinsame Geofabrik-Archiv umfasst ausdrücklich auch Palästina. Quellrolle,
territoriale Darstellung und Herkunft sind getrennt zu dokumentieren.

### Jordanien

Die [staatliche Wahlkommission veröffentlicht Gesetz 16/2026](https://www.iec.jo/node/37691).
Das [Ministerium für örtliche Verwaltung bestätigt dessen Verabschiedung](https://mola.gov.jo/Ar/NewsDetails/%D8%B5%D8%AF%D9%88%D8%B1_%D8%A7%D9%84%D8%A5%D8%B1%D8%A7%D8%AF%D8%A9_%D8%A7%D9%84%D9%85%D9%84%D9%83%D9%8A%D8%A9_%D8%A8%D8%A7%D9%84%D9%85%D8%B5%D8%A7%D8%AF%D9%82%D8%A9_%D8%B9%D9%84%D9%89_%D9%82%D8%A7%D9%86%D9%88%D9%86_%D8%A7%D9%84%D8%A5%D8%AF%D8%A7%D8%B1%D8%A9_%D8%A7%D9%84%D9%85%D8%AD%D9%84%D9%8A%D8%A9_%D9%84%D8%B3%D9%86%D8%A9_2026_%D9%88%D9%8A%D9%86%D9%81%D8%B0_%D8%A8%D8%B9%D8%AF_60_%D9%8A%D9%88%D9%85%D8%A7%D9%8B).
Der rechtliche Bestand von Gemeinden ist damit belegt. Die gegenwärtigen
lokalen OSM-Grenzrelationen wurden nicht vollständig auf amtliche Gemeinde-IDs
abgeglichen. Die einzelne beobachtete Level-8-Einheit `Sweileh` beweist keine
flächendeckende Gemeindeebene.

### Irak

Das [Originaljahrbuch der irakischen Statistikbehörde COSIT, Flächentabelle 1/5](https://www.cosit.gov.iq/documents/AAS2020/1.pdf)
unterscheidet Distrikte und Unterdistrikte/`Nahiya` und führt ihre Flächen auf.
Die Rolle örtlicher Verwaltung ist damit belegt. Die eigene Simulation oder
UI darf den Typ `Nahiya` beziehungsweise „Ortsverwaltung“ verwenden; aus dieser
Quelle folgt keine Gleichsetzung mit einer separat abgegrenzten Baladiya.

### Syrien

Der [OCHA-geführte Humanitarian Atlas](https://www.humanitarianatlas.org/syria/)
führt Unterbezirke als `Admin 3` mit dem nationalen Typ Nahiya. Die vorhandene
gbOpen-Metadatenquelle SYR/ADM3 verweist auf UNCS/UNOCHA und 272 Unterbezirke
im Stand 2017 unter CC BY 3.0 IGO. Das unterscheidet sich vom beobachteten
aktuellen OSM-Extrakt; beide Zahlen werden nicht stillschweigend gleichgesetzt.
Ein aktueller rechtlicher Nachweis, der alle OSM-Level-8-Orte zu kommunalen
Körperschaften erklärt, liegt hier **nicht** vor. Daher sind diese Objekte
bis zur Einzelprüfung keine zugelassenen Gemeindequellen.

## Tatsächlich geprüfte HTTP-Snapshots und Größen

Die Downloadpfade wurden aus dem
[Originalindex von Geofabrik](https://download.geofabrik.de/index-v1.json)
gelesen, nicht geraten. Indexquittung: 3.785.307 Bytes, SHA-256
`9b1d170b09eee255c0e56925788eb367646397c1ba1882f36b4c5c79133691fc`.
Für alle unten genannten datierten Archive antwortete HEAD mit **HTTP 200**,
starkem ETag und **`Accept-Ranges: bytes`**. Die anschließenden selektiven
Range-Abfragen bestätigten HTTP 206, exakte Content-Range, unveränderten ETag,
Bytezahl und SHA-256. Es wurden nur ZIP-Verzeichnisse und DBF-Tabellen gelesen,
keine SHP-Grenzgeometrien und keine vollständigen Archive.

| Land | Archiv | Ganzes ZIP, Bytes | Alle Admin-Komponenten komprimiert, Bytes | Tatsächliche Metadaten-Ranges, Bytes | ETag |
|---|---|---:|---:|---:|---|
| AZ | [azerbaijan-261108](https://download.geofabrik.de/asia/azerbaijan-261108-free.shp.zip) | 98.321.801 | 434.423 | 11.572 | `"5dc4589-65fce9c236a46"` |
| BY | [belarus-261108](https://download.geofabrik.de/europe/belarus-261108-free.shp.zip) | 688.721.837 | 21.663.532 | 288.560 | `"290d0fad-65fce13c194f6"` |
| IQ | [iraq-261108](https://download.geofabrik.de/asia/iraq-261108-free.shp.zip) | 191.781.097 | 3.200.133 | 28.368 | `"b6e58e9-65fce4c7b3597"` |
| IL/PS | [israel-and-palestine-261108](https://download.geofabrik.de/asia/israel-and-palestine-261108-free.shp.zip) | 218.791.122 | 4.098.460 | 16.753 | `"d0a7cd2-65fcf7e8d4b05"` |
| JO | [jordan-261108](https://download.geofabrik.de/asia/jordan-261108-free.shp.zip) | 60.584.695 | 798.788 | 11.934 | `"39c72f7-65fce84d0def6"` |
| KZ | [kazakhstan-261108](https://download.geofabrik.de/asia/kazakhstan-261108-free.shp.zip) | 503.561.525 | 9.804.031 | 32.199 | `"1e03bd35-65fcde97c1ea2"` |
| LB | [lebanon-261108](https://download.geofabrik.de/asia/lebanon-261108-free.shp.zip) | 120.645.738 | 1.345.790 | 25.104 | `"730e86a-65fcd538d61af"` |
| LY | [libya-261108](https://download.geofabrik.de/africa/libya-261108-free.shp.zip) | 181.834.884 | 150.985 | 10.680 | `"ad69484-65fce2647aa31"` |
| SY | [syria-261108](https://download.geofabrik.de/asia/syria-261108-free.shp.zip) | 199.455.339 | 2.700.036 | 16.342 | `"be3726b-65fcf29b7beee"` |
| TN | [tunisia-261108](https://download.geofabrik.de/africa/tunisia-261108-free.shp.zip) | 175.809.439 | 10.357.305 | 37.854 | `"a7aa39f-65fceb4ba5d14"` |

Die unveränderten README-Dateien aller zehn Archive nennen als exakten
**OSM-Datenstand `2026-11-08T21:21:00Z`**. Auch diese kleinen Dateien wurden
selektiv gelesen, ZIP-CRC-geprüft und mit eigenem SHA-256 belegt.
`Last-Modified` ist für alle Archive der 9. November 2026, zwischen 00:48:54
und 03:24:06 UTC. Der Dateisnapshot bleibt `261108`; Dateiname und tatsächlicher
HTTP-Erstellungszeitpunkt werden nicht gleichgesetzt. Exakte Einzelzeiten und
Rohheader stehen im privaten Cache. Die zehn archivbezogenen Metadatenprüfungen
benötigten zunächst **479.366 Bytes**; einschließlich der zusätzlichen
README-Ranges sind es **483.466 Bytes**. Index und HTTP-Header zählen dabei
nicht mit. Die letzte Spalte ist ein ETag, **kein behaupteter SHA-256 des ganzen ZIP**.

Private Prüfdateien:

- `.tools/atlas_sources/audit/remaining-country-geofabrik-head.json`
- `.tools/atlas_sources/audit/remaining-country-geofabrik-inspections.json`
- `.tools/atlas_sources/audit/geofabrik-<Land>-261108/inspection.json`
- Darunter unveränderte Range-Dateien mit Quittungen und Snapshot-Headern.

SHA-256 der zusammengefassten Inspektion:
`6aa7e4c70d0379e94c994d37d801269853b1020469edcb33f3206c74651edf49`.
Der vorhandene `RangeSource` / `RemoteZip` aus
`tools/atlas_geofabrik_sources.py` wurde unverändert wiederverwendet.

## Lizenz und notwendige nächste Prüfschritte

Die Geofabrik-Extrakte sind OSM-Daten unter
[ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/), mit
`© OpenStreetMap contributors`. Die nationale Rechtsquelle erläutert lediglich
die Verwaltungsrolle; ihre Nennung ersetzt keine Geometrie-Lizenz. Die
[Geofabrik-Spezifikation](https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf)
definiert die neue Familie `gis_osm_adminareas_a_free_*.{shp,dbf,shx,prj,cpg}`.
Für einen produktiven Import sind weiterhin nötig:

1. Exakte Admin-Komponenten per Range laden; ETag, Content-Range, ZIP-CRC und
   Datei-SHA-256 prüfen, den ganzen ZIP-Download vermeiden.
2. Original-OSM-ID, `fclass` und zum Level passende `code=1200+N` bewahren;
   doppelte oder aus dem Nachbarpuffer stammende IDs räumlich prüfen.
3. Territoriale Zuordnung und tatsächliche lokale Rolle gemeinsam validieren,
   keine Zuordnung nur aus Dateiname oder gleicher Zahl des admin_level.
4. Die im Ausschnitt vorhandenen lokalen Polygone gegen unabhängige
   Länderlandfläche messen; Namensabdeckung separat berichten.
5. Grenzen unverändert belegen, Lücken ehrlich erhalten und nur nachgewiesene
   Gemeindetypen als `municipality` führen. Andere echte Untergliederungen
   behalten ihren nativen Verwaltungstyp.
