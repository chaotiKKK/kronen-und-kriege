# Armenien: rechtlich geprüfte kommunale Rollen, OSM-Stand 8. November 2026

Prüfdatum: 9. November 2026. Dieser Provider ergänzt echte Referenzgeografie;
er ändert keine der 49 Simulationskennungen. Die nachgewiesenen **62 aktuellen
kommunalen Identitäten** sind ein Rechts-/Identitätsabgleich, keine amtliche
Bestätigung sämtlicher Grenzkoordinaten und kein Nachweis vollständiger
Landflächenabdeckung.

## Eingelesene tatsächliche Rollen

| Bestandteil | Tatsächlicher Nachweis | Darstellung |
|---|---|---|
| 61 Gemeinden außerhalb Jerewans | Erste Gemeindespalte der zehn lebenden Tabellen in Anhang 2 des konsolidierten Gesetzes | `municipality`, nativer Typ `Համայնք / Community` |
| Jerewan | Hauptstadt-/Gemeindeidentität, Artikel 6.1 und amtliche Stadtverwaltung | Eine `region` mit zusätzlicher, flächengleicher Rolle `local_government_role=municipality` |
| 12 Verwaltungsbezirke Jerewans | Zwölf Einträge der amtlichen Stadtverwaltung; Original-OSM-IDs und Tags | `local_admin`, keine zwölf zusätzlichen Gemeinden |

Der Reader prüft tatsächliche Namen und Kennungen. Eine OSM-Ebenennummer allein
vergibt keine Gemeinderolle. Beispielsweise liegen sowohl Gyumri als auch die
Jerewaner Bezirke auf Level 5, haben aber unterschiedliche belegte Funktionen.
Level-6-Stadtpolygone aus dem Nachbarpuffer werden nicht zu Gemeinden umbenannt.

Maßgeblicher aktueller Rechtsbestand ist das
[konsolidierte Verwaltungsgliederungsgesetz, ARLIS 231073](https://www.arlis.am/hy/acts/231073).
Die zehn Gemeindetabellen enthalten 61 Namensidentitäten außerhalb Jerewans.
Die Siedlungsspalte und historische Anhänge mit alten Grenzbeschreibungen
werden nicht als aktuelle Gemeindeliste verwendet. Das
[MTAI-Gemeindeverzeichnis](https://www.mtad.am/pages/armenian-communities)
bestätigt native Namen, führt aber noch frühere Teilgemeinden auf; daraus
wird keine aktuelle Landeszahl abgeleitet. Die belegte Schreibvariante
`Նոր Հաճն` / `Նոր Հաճըն` wird ausdrücklich zugeordnet.

Die [amtliche Stadtverwaltung nennt die zwölf Bezirke](https://www.yerevan.am/en/administrative-districts/).
Ihre ursprünglichen OSM-IDs bleiben getrennt erhalten. Jerewans OSM-Relation
`364087` besitzt `ISO3166-2=AM-ER`, ebenso die alte Natural-Earth-Referenz
`region:ARM-1675`. Ausschließlich dieses nachgewiesene Stadtobjekt wird mit
`replaces_reference_features` als gezielter Ersatz angemeldet. Die zehn
übrigen Marz-Regionen werden dadurch nicht verworfen. Die Umsetzung dieser
gezielten Ersetzung im Hauptmerger ist eine separate Integrationsaufgabe.

## Enaktierte Fusionen und tatsächliche Geometrie

[Gesetz ՀՕ-454-Ն, ARLIS 231060](https://www.arlis.am/hy/acts/231060)
wurde am 15. September 2026 beschlossen, am 17. September unterzeichnet und
am 18. September veröffentlicht. Artikel 9 und der amtliche Status nennen
**19. September 2026** als Inkrafttreten. Die Grenzfusion gilt deshalb bereits;
spätere Termine für die Neuwahl von Organen sind davon getrennt.

| Aktuelle Gemeinde | Unveränderte originale OSM-Polygonteile | Verarbeitung |
|---|---|---|
| Արարատ / Ararat | `10852605` Ararat und `10852606` Vedi | Geometrische Union genau dieser beiden echten Komponenten |
| Վանաձոր / Vanadzor | `17128406` Vanadzor und `11816845` Pambak | Geometrische Union genau dieser beiden echten Komponenten |

Beide Paare überlappen im verwendeten Snapshot nicht. Es werden keine Lücken
aufgefüllt und keine Rechtecke, Voronoi-Zellen oder neuen Verwaltungsgrenzen
erfunden. `source_part_ids`, Versionen, Zeitstempel, Gesetzes-URL und Datum
belegen jede Ableitung. `geometry_modified_by_importer=true` kennzeichnet
ausschließlich diese beiden rechtlich begründeten Vereinigungen. Alle anderen
Quellpolygone bleiben unverändert; ungültige Geometrie ist ein Fehler und wird
nicht still repariert.

Die im kostenlosen Geofabrik-SHP fehlende Gemeinde **Ճամբարակ / Chambarak**
wurde über ihre tatsächliche OSM-Relation
[`10853047`, Version 34](https://api.openstreetmap.org/api/0.6/relation/10853047/34.json)
ergänzt. Der [vollständige Originalabruf](https://api.openstreetmap.org/api/0.6/relation/10853047/full.json)
enthält 600.596 Bytes und 3.311 Elemente; SHA-256
`53d4ba1a523722b13a60c18e5bb4796e8a48b6fed7b3472ff04fd7916c225915`.
Das jüngste Relation-/Way-/Node-Element stammt vom 6. November 2026 und liegt
damit vor dem gemeinsamen Snapshot. Tatsächliche Memberwege und Knoten bilden
das Polygon; fehlende Member oder jüngere Versionen werden zurückgewiesen.

## Originalquellen, Lizenz und Integrität

Die Gemeinde- und Bezirksgeometrien stammen aus dem datierten
[Geofabrik-Archiv Armenien 261108](https://download.geofabrik.de/asia/armenia-261108-free.shp.zip).
Das originale README nennt **2026-11-08T21:21:00Z** und
[ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
Attribution: **© OpenStreetMap contributors; Geofabrik GmbH**. Der direkte
Chambarak-Abruf trägt dieselbe OSM-Datenlizenz und eine getrennte Quellenkennung.
Die rechtlichen Rollenbelege ersetzen diese Geometrielizenz nicht.

`PINNED_INPUTS` im öffentlichen Provider benennt zwölf Originaldateien mit
exakten Bytes, SHA-256 und öffentlichen URLs: fünf SHP-Komponenten, README,
zwei Rechtsbelege, Stadtverzeichnis, zwei Metadatenantworten und Chambarak.
Zusammen sind es 4.411.103 Originalbytes. Ein vorhandener Rohstage wird nur
nach Hashprüfung gelesen/kopiert. Falls er fehlt, liest der Reproducer aus dem
ZIP ausschließlich die erforderlichen Mitglieder über geprüfte HTTP-Ranges;
ZIP-CRC und gepinnte Memberhashes werden kontrolliert. Ein vollständiger
Archivdownload ist nicht erforderlich.

Aktuelle OSM-API-Endpunkte sind veränderlich. Ein später abweichender Abruf
wird nicht still als derselbe Snapshot akzeptiert: Der Reproducer verlangt
die dokumentierten Originalbytes und Mitgliedsstände. Für einen exakt gleichen
Neuaufbau den hashgleichen Cache erhalten. Keine TLS-Prüfung wird ausgeschaltet.

Die vollständigen Gesetzestexte bleiben ausschließlich im ignorierten
Buildcache. Die Runtime-Quellenmetadaten enthalten Links, Daten und Hashes
sowie die faktischen Identitätsbezüge; sie enthalten keine vollständigen
Rechtsdokumente.

## Abdeckung und Prüfstand

Alle 62 aktuellen gesetzlichen Identitäten sind auf die tatsächlichen
Quellobjekte beziehungsweise die beiden gesetzlich belegten Unionen abgebildet.
Der geometrische Prüfwert gegen die unabhängige Natural-Earth-Länderreferenz
beträgt dennoch nur **93,162904 %**: 27.534,198 von 29.554,894 km² des
verwendeten Nenners. Referenz-/Küsten-/Binnengewässerabweichungen dürfen nicht
durch erfundene Gemeindegeometrie verdeckt werden. Beide Quellen behalten
`blocks_full_coverage_claim=true`; der Hauptbuild misst die aktuelle Abdeckung
erneut. Dies ist ein ehrlicher partieller Flächennachweis.

13 gezielte Python-Tests wurden zunächst rot und anschließend grün ausgeführt.
Sie prüfen Gemeindespalte statt Siedlungsspalte, positive Rollen, Land-/Level-
Widersprüche, unbekannte Einheiten, echte Fusionsunionen und Löcher, fehlende
Fusionskomponenten, API-Member/Snapshot, Cachemanipulation und den gezielten
Jerewan-Ersatz. Der echte Offline-Reader lieferte 74 Objekte ohne erlaubten
Netzwerkprozess. Alle 74 bestanden außerdem den tatsächlichen
`feature_record`-Import im RAM. Die zwölf Bezirke liegen geometrisch innerhalb
Jerewans; der kleinste Enthaltungsanteil betrug 99,99999999999991 %.
Die daraus projizierten Grenzpfade umfassten 62.208 Bytes. Ein Godot-, Paket-
oder Gerätelauf wurde mit diesem Provider nicht vorgenommen.

```powershell
python -B -m unittest discover -s tools -p test_atlas_armenia_sources.py -v
python -B tools/atlas_armenia_sources.py --cache .tools/atlas_sources
```

`prepare_sources(cache)` bereitet nur diesen Provider und sein Manifest vor.
`iter_boundaries(cache, sources)` prüft alle Originaldateien offline und liefert
Shapely-Polygone samt Rollen/Provenienz. Der Hauptmerger wird separat integriert.

Der alte gbOpen-ARM-ADM2-Satz mit 39 Flächen ist kein Ersatz für diese Gemeinden:
Die [archivierten HDX-Produzentenmetadaten](https://data.wu.ac.at/schema/data_humdata_org/MzdiODk1NTUtZWYzZS00YjI2LWExYmEtMDcwMzE4MDE2ODUz)
erklären seine zweite Ebene ausdrücklich als nichtamtliche, teilweise von
Behörden verwendete Ebene des damaligen Katastrophenschutzministeriums.
Dies ist ein archivierter Metadatenexport, kein heute erfolgreich neu geladener
HDX-Primärabruf. Die alte Geometrie kann unverändert im Rohcache erhalten bleiben;
sie begründet keine aktuelle kommunale Rolle oder Abdeckung.
