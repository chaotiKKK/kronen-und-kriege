# Geofabrik-Verwaltungsquellen und belegte Ergänzungen

Die [kostenlose Geofabrik-Adminareas-Ebene](https://blog.geofabrik.de/index.php/2026/04/) liefert formale administrative Grenzpolygone. Die [Formatspezifikation](https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf) erklärt fclass/code und die fehlende native Elternhierarchie. Pro Archiv werden ausschließlich ZIP-Verzeichnis, Adminareas-Mitglieder und README über geprüfte HTTP206-Ranges gelesen; starke ETag/If-Match, Content-Range, Bytezahl, ZIP-CRC32 und SHA-256 bleiben im Manifest erhalten.

| Land | Originale Ebene | Darstellungsrolle | tatsächlicher Einheitstyp | Einheiten |
|---|---:|---|---|---:|
| HU | 6 | region | Vármegye/főváros | 20 |
| HU | 7 | district | Járás | 174 |
| HU | 8 | municipality | Település | 3155 |
| HU | 9 | local_admin | Kerület | 23 |
| SK | 4 | region | Kraj | 8 |
| SK | 5 | municipality | Mesto | 2 |
| SK | 6 | district | Okres | 79 |
| SK | 8 | local_admin | Vojenský obvod | 3 |
| SK | 8 | municipality | Obec/mesto | 2885 |
| SK | 9 | local_admin | Mestská časť | 39 |
| EE | 6 | region | Maakond | 15 |
| EE | 7 | municipality | Vald/linn | 78 |
| AL | 6 | region | Qark | 12 |
| AL | 7 | municipality | Bashkia | 61 |
| AL | 8 | local_admin | Njësia administrative | 371 |
| AL | 9 | local_admin | Lagje | 21 |
| MK | 6 | region | Град Скопје (aggregated city) | 1 |
| MK | 7 | municipality | Општина | 80 |
| MD | 4 | region | Raion/autonomous area/municipiu II | 37 |
| MD | 7 | local_admin | Sector | 5 |
| MD | 8 | municipality | Oraș/comună/sat | 982 |
| GG | 10 | local_admin | Canton | 4 |
| GG | 4 | region | Jurisdiction | 3 |
| GG | 8 | municipality | Parish | 10 |
| GG | 9 | local_admin | Parish subdivision | 2 |
| JE | 10 | local_admin | Canton | 2 |
| JE | 8 | municipality | Parish | 11 |
| JE | 9 | local_admin | Vingtaine/Cueillette | 54 |
| JE | 8 | municipality | Parish | 1 |
| IM | 8 | municipality | Local Authority | 21 |
| FO | 6 | region | Sýsla | 6 |
| FO | 7 | municipality | Kommuna | 29 |
| CZ | 4 | region | Kraj | 13 |
| CZ | 5 | district | Obvod hlavního města; Okres | 84 |
| CZ | 6 | district | Správní obvod ORP | 224 |
| CZ | 7 | district | Správní obvod POÚ | 383 |
| CZ | 8 | local_admin | Vojenský újezd | 4 |
| CZ | 8 | municipality | Obec | 6243 |
| CZ | 9 | local_admin | Městská část | 142 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 8 | municipality | Obec | 1 |
| CZ | 4 | region | Kraj | 1 |
| NO | 4 | region | Fylke | 14 |
| NO | 7 | municipality | Kommune | 356 |
| NO | 9 | local_admin | Bydel | 53 |
| NO | 7 | municipality | Kommune | 1 |
| NO | 4 | region | Fylke | 1 |
| TR | 4 | region | İl | 81 |
| TR | 6 | district | İlçe | 974 |
| TR | 7 | municipality | Belde | 85 |
| TR | 8 | local_admin | Mahalle/Köy | 13823 |
| RU | 4 | region | Субъект РФ | 54 |
| RU | 5 | district | Административный округ | 31 |
| RU | 6 | district | Муниципальный район/городской округ | 1296 |
| RU | 8 | municipality | Муниципальное образование | 6696 |
| RU | 9 | local_admin | Административный район | 198 |
| LB | 4 | region | Mouhafazah | 9 |
| LB | 5 | district | Qadaa | 25 |
| LB | 7 | municipality | Baladiya | 1031 |
| BY | 4 | region | Voblast | 7 |
| BY | 6 | district | Raion | 128 |
| BY | 8 | municipality | Selsovet / local council | 1287 |
| IQ | 4 | region | Muhafazah | 19 |
| IQ | 6 | district | Qadaa | 139 |
| IQ | 7 | local_admin | Nahiya | 401 |
| SY | 4 | region | Muhafazah | 14 |
| SY | 5 | district | Mantiqa | 67 |
| SY | 6 | local_admin | Nahiya | 275 |
| TN | 4 | region | Gouvernorat | 24 |
| TN | 5 | district | Delegation | 266 |
| TN | 6 | local_admin | Imada / sector | 2084 |
| KZ | 4 | region | Oblys | 20 |
| KZ | 6 | district | Audan | 228 |
| KZ | 8 | municipality | Rural okrug | 908 |
| IL | 4 | region | Mehoz | 6 |
| IL | 5 | district | Nafa | 15 |
| IL | 8 | municipality | Local Authority (city/local/regional council) | 235 |
| JO | 4 | region | Muhafazah | 12 |
| LY | 4 | region | Shabiya | 23 |
| AZ | 8 | municipality | Belediyye | 8 |

## Nationale Rollen und Prüfgrenzen

Eine Gemeinderolle folgt ausschließlich aus einer positiv belegten Landesdefinition. SK-Militärgebiete sind mit tatsächlichen historischen OSM-Tags als local_admin getrennt; Bratislava/Košice sind mit ihren Stadt-Tags auf5 Gemeinden. AL7 sind die61 Bashki, AL8 ihre Unterverwaltungen. MK7 umfasst80 Gemeinden, Skopje6 bleibt das übergeordnete Aggregat. EE7 hat aktuell78 Gemeinden: Jõhvi und Toila fusionierten nach2025; die offiziellen78 Namen stimmen mit dem Datenbestand überein. Tallinn und Kohtla-Järve auf8 bleiben Siedlungseinheiten und werden nicht nochmals als Gemeinden eingefügt. Ausschließlich dieser vollständig positiv namen-/ID-abgeglichene EE-Gemeindesatz erhält replacement_scope=country. Dadurch bleiben keine veralteten Natural-Earth-Gemeindereste zusätzlich bestehen; konkret war region:EST-2352 (Kreis Saare) betroffen. Amtliche Identitätsvollständigkeit und separat gemessene Landflächenabdeckung bleiben verschiedene Belege.

IM verwendet die amtlichen21 heutigen Local Authorities. Garff ist die belegte Union Laxey/Lonan/Maughold (2016), Arbory and Rushen die belegte Union der beiden alten Parish Districts (2020). Alle Quellteile/IDs und Rechtsbelege bleiben erhalten; benachbarte eigenständige Authorities werden nicht einbezogen. FO7 ist durch einen eindeutigen amtlichen Namen-/ID-Abgleich aller29 Kommunen belegt.

GG8 erfasst die10 Hauptinsel-Parishes; Alderney/Sark sind eigene Jurisdiktionen. [Sarks eigene Regierung](https://sarkgov.co.uk/living-on-sark) und die [amtliche Alderney-Regierungsbeschreibung](https://www.alderneyelections.gg/how-government-works/structure/) belegen Chief Pleas beziehungsweise States of Alderney als tatsächliche territoriale Eigenregierungen; [GOV.UK](https://www.gov.uk/government/publications/crown-dependencies-jersey-guernsey-and-the-isle-of-man) bestätigt die drei getrennten Jurisdiktionen im Bailiwick. Genau die vorhandenen Regionen Sark1973199 und Alderney1973200 tragen deshalb zusätzlich local_admin mit Primärbeleg. Sie bleiben region/Jurisdiction und werden weder umbenannt noch geometrisch dupliziert oder als weitere Gemeinden/Parishes ausgegeben. Guernsey1711291 erhält keine zusätzliche Leafrolle neben seinen10Parishes. Die unabhängige physische Landflächenprüfung bleibt offen. JE erhält seine12.Parish Grouville aus einer separat attribuierten, Snapshot-geprüften OSM-API-Geometrie, da sie im Geofabrik-Extrakt fehlt. Das nationale JE-Polygon ist ebenfalls eine ausdrücklich belegte API-Referenz ausschließlich für territoriale Zuordnung.

CZ verwendet sämtliche14 geprüften Regionalextrakte, NO sämtliche5 kontinentalen Regionalextrakte; regionale Puffer werden anhand gemeinsamer, durch native ISO-Tags belegter Territorialreferenzen zugeordnet und danach über stabile Quellkennung dedupliziert. Die fehlenden dargestellten Regionen Ústecký kraj und Trøndelag kommen aus separat attribuierten vollständigen OSM-API-Geometrien. Ihre tatsächlichen admin4-/ISO-Tags und sämtliche Memberstände wurden gegen den08.11.2026,21:21UTC geprüft. Diese Darstellung erzeugt keine Länderobjekte und verwendet die Referenzen nicht als Landflächennenner. CZ enthält6243 Geofabrik-Gemeinden plus10 durch amtliche CISOB-/Okres-Codes belegte direkte OSM-Gemeindegrenzen und4 gesonderte Militärgebiete. Die10 fehlten tatsächlich in sämtlichen14 rohen Regional-DBFs; ihre echten Originalgeometrien ersetzen keine erfundenen Zellen. Praha trägt auf seiner bestehenden Kraj-Geometrie zusätzlich die amtlich belegte Gemeinderolle; ein zweites Geometrieobjekt entsteht nicht. Die10 Praha-Obvod-Flächen haben ihre tatsächliche native Bezirksrolle statt des pauschalen Okres-Namens. NO enthält356 Geofabrik-Gemeinden plus die separat attribuierte Originalgrenze der fehlenden Gemeinde Røros (SSB-Code5025). Die vollständige amtliche SSB2026-Namens-/Codeprüfung belegt357 wirkliche Gemeinden und einen gesonderten Unbekannt-Code9999, der nicht als Gemeinde importiert wird. Oslo ist bereits als echte eigene Level7-Gemeinde vorhanden und wird nicht über die zusätzliche Fylke-Geometrie nochmals kommunal gezählt. Diese realen Quellanzahlen ersetzen keine unabhängige amtliche Behördenvollzählung; kein fehlender Eintrag wird erfunden. Der Bestand umfasst danach6253 explizite Gemeindeobjekte plus die zusätzliche Praha-Gemeinderolle. Der amtliche zivile Namensbestand umfasst6254 Behörden, wobei vier Militärgebiete gesondert bleiben.

RU wurde aus allen5 bereitliegenden europäischen Föderalextrakten zusammengeführt und auf den tatsächlichen Atlasrahmen begrenzt; die [originale russische OSM-Produzentenkonvention](https://wiki.openstreetmap.org/wiki/RU:Tag:boundary=administrative#Административные_уровни_(admin_level)_в_Российской_Федерации) benennt6 ausdrücklich als kommunale Rajons sowie kommunale/städtische Okrugs,8 als kommunale Siedlungen und9 als subkommunale Einheiten. Deshalb behält6 seine gröbere district-Darstellung und trägt zusätzlich die belegte native municipality-Rolle auf derselben Originalgeometrie. Diese Produzentenkonvention ersetzt weder eine aktuelle nationale Behördenvollzählung noch die einzelne amtliche Kataster-/Rechtsgrenzenabnahme. TR aus dem vollständigen Landesextrakt. Mahalle/Köy bleiben local_admin, Belde bleiben municipality. Genau30 bestehende TR4-Provinzen tragen zusätzlich ihre aktuelle TBB-Metropolgemeinderolle: [6360Art.6](https://cdn.tbmm.gov.tr/KKBSPublicFile/D24/Y3/T1/KanunMetni/6fd1dca0-c56a-40ef-bc98-fb463d9ac578.html) fasst5216Art.5 mit ausdrücklich flächengleicher Metropol-/Provinzgrenze neu. Die [aktuelle TBB-Liste](https://www.tbb.gov.tr/tr/buyuksehir-belediyeleri) liefert genau30 Behörden; jede wurde eindeutig mit dem Originalnamen, der administrativen Provinzkennung und dem nativen TR-ISO-Code vor dem Geofabrik-Snapshot abgeglichen. Keine neue Geometrie entsteht, kindregion/İl bleiben erhalten. Die anderen51 Provinzen und974 Kreisgemeinderollen bleiben ungeprüft und werden nicht pauschal kommunal markiert; 11 der85 ursprünglichen Belde-Quellpolygone liegen vollständig in den bestätigten Metropolprovinzen Kayseri, Ankara oder Tekirdağ. 6360Art.1(3) hebt dort die eigenständige frühere Belde-Rechtspersönlichkeit auf. Genau diese11 Datensätze bleiben mit unveränderter municipality/Belde-Originalrolle und Geometrie im Quellcache, sind jedoch administrativ quarantänisiert und werden nicht als heutige Gemeinden dargestellt oder gezählt. Die konkrete Metropolzuordnung, Gesetz, Primär-URL, Datum und ID bleiben erhalten; der Reader gibt weiterhin alle85 ursprünglichen Belde-Records aus. flächengleiche größere Metropolregierungen stellen keine vollständig rekonstruierte feinere Mahalle-/Köy-Ebene her. 136 tatsächliche direkte OSM-/Geofabrik-Doppelrepräsentationen sind nach Kennung, Land, Ebene, Originalnamen und Polygon-IoU>0,999 belegt. Der Reader liefert einen geprüften verified_source_alias samt Zielversion und Audit-/Cachehash; erst der Hauptmerger entscheidet nach erneuter Geometrieprüfung über die Zusammenführung. Es gibt keine allgemeine Gleichsetzung nur nach common osm_id.

Die zusätzlichen Länder behalten ihre tatsächlich belegten Rollen: LB7 Baladiya, BY8 örtliche Räte, KZ8 Rural Okrug, IL8 kommunale Local Authorities; IQ7 und SY6 Nahiya sowie TN6 Imada sind örtliche Verwaltung, ausdrücklich keine pauschalen selbstverwalteten Gemeinden. Libanesische Katastergebiete auf8 und tunesische Gemeinde-Kandidaten auf8 werden nicht automatisch zugelassen. AZ hat lediglich8 tatsächliche Gemeindequellflächen gegenüber685 amtlichen Gemeinden und bleibt partiell. JO enthält nur12 Gouvernorate, LY nur23 Shabiya-Flächen: für beide ist damit keine örtliche Gemeindeebene hergestellt. TR hat zwei relevante leere admin8-Quellpolygone, KZ ein leeres admin8-Polygon. Sie werden mit Originalkennung, Eigenschaften und ungeklärter Landeszuordnung dokumentiert; keine Ersatzgeometrien entstehen, und die betroffenen Quellen blockieren eine vollständige Abdeckungsbehauptung. Source counts beziehen sich auf den tatsächlichen Quellbestand vor dem im Hauptimport angewandten sichtbaren Atlas-Ausschnitt.

Country-Zuordnung erfolgt vor der Rollenvergabe: Ein Archivpuffer allein belegt kein Land. Bestätigte nationale ISO-Grenzpolygone dienen nur zur territorialen Zuordnung, niemals als neues Landobjekt oder als Landflächennenner. Der unabhängige Natural-Earth-Landbeleg und seine Abweichungen bleiben separat erhalten. Eltern werden bei eindeutiger geometrischer Enthaltung als inferred-area-containment markiert; die Quelle liefert keine native Rechts-/Enginehierarchie.

HU-Normalizer3 bleibt bytegleich erhalten. Seine ursprünglichen Cachepfade und die zusätzliche v3-Sicherung werden von den späteren Sammlungen nicht überschrieben. Die späteren Länder verwenden eigene versionierte Cachedateien. Tatsächliche Extraktanzahlen sind keine pauschale Vollständigkeitsbehauptung: Lücken, Überlappungen, Rollen und Landesreferenzqualität werden im Hauptimport anhand unabhängiger Landmasken geprüft.

Datenlizenz: [ODbL1.0](https://opendatacommons.org/licenses/odbl/1-0/), © OpenStreetMap contributors; Geofabrik GmbH. Direkte API-Ergänzungen tragen ihre eigene Herkunft. Natural Earth ist Public Domain. Unveränderte OSM-Elementversionen können wegen wechselnder API-Generator-Header andere Rohantwortbytes haben; maßgeblich sind jeweils die tatsächlich gespeicherten vollständigen Rohantwort- und Geometriehashes.

## Rollenbelege

SK: [Quelle1](https://wiki.openstreetmap.org/wiki/Mechanical_Edits/Fjana/reorganization_of_boundaries_in_Slovakia).
EE: [Quelle1](https://wiki.openstreetmap.org/wiki/User:Apo_lemus/admin_level%3D%2A_Estonia_specific_values), [Quelle2](https://fin.ee/riik-ja-omavalitsused-planeeringud/kohalikud-omavalitsused/asustusjaotus), [Quelle3](https://agri.ee/regionaalareng-uhistransport/kohalikud-omavalitsused).
AL: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://www.instat.gov.al/media/11124/regional-statistical-yearbook-2022_04.pdf).
MK: [Quelle1](https://wiki.openstreetmap.org/wiki/Mk:WikiProject_Macedonia/Administrative_Boundaries), [Quelle2](https://www.stat.gov.mk/oblastopsto_en.aspx?id=1).
MD: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://gov.md/en/node/10566).
GG: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://valeparish.gg/douzaine/about-us/).
JE: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://www.gov.je/LifeEvents/MovingToJersey/SettlingIn/Pages/ParishLife.aspx).
IM: [Quelle1](https://www.gov.im/categories/home-and-neighbourhood/local-authorities/local-authority-contacts/), [Quelle2](https://www.gov.im/categories/home-and-neighbourhood/local-authorities/local-authority-contacts/garff/), [Quelle3](https://legislation.gov.im/cms/images/LEGISLATION/SUBORDINATE/2019/2019-0498/2019-0498_3.pdf).
FO: [Quelle1](https://gis.us.fo/arcgis/rest/services/fyrisitingarlig_kort/us_kommunur/MapServer/0), [Quelle2](https://www.foroyakort.fo/vevtaenastur).
CZ: [Quelle1](https://wiki.openstreetmap.org/wiki/Creation_of_administrative_districts_in_Czechia), [Quelle2](https://csu.gov.cz/territorial-units-methodology).
NO: [Quelle1](https://wiki.openstreetmap.org/wiki/Norway/Administrative_grenser), [Quelle2](https://lovdata.no/dokument/NLE/lov/2018-06-22-83/%C2%A73-2).
RU: [Quelle1](https://wiki.openstreetmap.org/wiki/RU%3ATag%3Aboundary%3Dadministrative), [Quelle2](https://wiki.openstreetmap.org/wiki/RU%3AKey%3Aadmin_level).
TR: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level).
LB: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://legallaw.ul.edu.lb/Law.aspx?lawId=244078).
BY: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://natlex.ilo.org/dyn/natlex2/natlex2/files/download/86988/BLR86988.pdf).
IQ: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://www.cosit.gov.iq/documents/AAS2020/1.pdf).
SY: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://www.humanitarianatlas.org/syria/).
TN: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://www.cgdr.nat.tn/upload/files/Etudes/Etude/Evaluation_PRD_Rapport%20Phase2%20VFinale.pdf).
KZ: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://old.adilet.zan.kz/eng/docs/Z010000148_).
IL: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://www.cbs.gov.il/he/publications/DocLib/isr_in_n/sr_in_n21e.pdf).
JO: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://www.iec.jo/node/37691).
LY: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://www.undp.org/sites/g/files/zskgke326/files/2022-06/UN-Startegic-Framework-for-Libya-2019-2022.pdf).
AZ: [Quelle1](https://wiki.openstreetmap.org/wiki/Template:Admin_level), [Quelle2](https://justice.gov.az/az/news/edliyye-nazirliyi-belediyyelerle-bagli-tovsiye-hazirlayib).

## Ausdrücklich erhaltene Grenzen

- TR: Exactly30 current TBB metropolitan governments match native admin4 province ISO/name identities and are legally coextensive under6360Art6/5216Art5. Exactly11 original obsolete metropolitan Belde claims are quarantined at row level under6360Art1(3), preserving all85 source records and geometry. Other51 provinces and974 district roles remain unpromoted; fine local-layer completeness is separate
- AZ: Only8 municipal source polygons; official685-count proves the local source is partial; coarser administrative level conventions conflict and remain unqualified
- JO: Only the12 governorates admitted; local municipality/subdistrict source roles are not yet independently qualified
- LY: Only23 source Shabiya polygons; no actual municipal layer is present
- municipal_vs_local: Iraqi/Syrian Nahiya and Tunisian Imada are native local_admin, not municipal self-government
- coverage: All source counts describe actual extracted records; independent visible land coverage and official identity completeness are separate audits

```powershell
python tools/atlas_geofabrik_collections.py --cache .tools/atlas_sources
python -m unittest discover -s tools -p test_atlas_geofabrik_*.py
```
