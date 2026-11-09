# Amtliche lokale Verwaltungsflächen: Finnland, Vereinigtes Königreich und Irland

Diese Ergänzung des Atlasquellenlesers verwendet echte lokale Verwaltungsflächen. Sie ändert weder die Simulation noch die vorhandenen Spielgebiete. Die Zuordnung `municipality` bezeichnet eine gemeinsame Darstellungsrolle; die tatsächlichen Verwaltungssysteme werden mit `native_level`, `unit_type`, Stand und Herkunft zusätzlich erhalten. Eine frei erfundene Entsprechung zu einer numerischen ADM-Ebene wird vermieden: `admin_level` ist bei diesen Produkten `null`.

| Gebiet | Amtliches Produkt | Native Ebene | Stand | Vollständigkeit der Antwort |
| --- | --- | --- | --- | --- |
| Finnland einschließlich Åland | Statistics Finland `kunta1000k_2026` | `kunta`, Kunta / kommun | 2026 | Gegen `numberMatched`, `totalFeatures` und `numberReturned` geprüft |
| Vereinigtes Königreich | ONS Local Authority Districts (December 2025) Boundaries UK BGC | `LAD`; tatsächlicher Typ zusätzlich je GSS-Schlüssel | Dezember 2025 | Gegen unabhängigen ArcGIS-Count-Request und Transferlimit geprüft |
| Irland | Tailte Éireann Administrative Areas 2019, Generalised 20m | `Local authority`; County council / City council / City and county council | 2019 | Vollständige 31er-Antwort gegen unabhängigen ArcGIS-Count-Request geprüft |

Die gemessenen Objektzahlen, Dateigrößen und SHA-256-Werte stehen in [atlas_official_sources.json](../data/atlas_official_sources.json). Eine vollständige Antwort des Anbieters beweist noch keine vollständige Landeslandfläche im tatsächlichen Kartenausschnitt. Diese zweite Prüfung erfolgt durch die geometrische Vereinigung der importierten Flächen im Atlas-Merger. Weder Objektzahlen noch die nominale Maßstabsangabe werden als Flächenprozente ausgegeben.

## Finnland

[Statistics Finland beschreibt die kommunalbasierten Gebietseinheiten](https://stat.fi/en/services/statistical-data-services/geographic-data/statistical-areas/municipality-based-statistical-units) und verlinkt seinen nationalen WFS. Die Produktseite nennt noch Datenjahre bis 2025; das tatsächlich geprüfte WFS-Produktschema und die Feature-Eigenschaft `vuosi` belegen jedoch ausdrücklich das angebotene Produktjahr 2026. Der Leser akzeptiert ausschließlich dieses Jahr und den kommunalen Typ `kunta1000k_2026`. Regionen, Wahlbezirke oder andere ebenfalls über den Dienst verfügbare Gebietstypen werden nicht als Gemeinden importiert.

Die geometrische Quelle ist die Variante 1:1.000.000, im nationalen Dienst detaillierter als die ebenfalls angebotene Variante 1:4.500.000. Die Koordinaten werden ausdrücklich als EPSG:4326 angefordert. Gemeindeschlüssel bleiben Zeichenketten mit führenden Nullen; `005` erhält etwa die stabile Atlas-ID `statfi:kunta:2026:005`. Die finnische Namensform bleibt mit Unicode erhalten, zusätzlich werden die angebotenen schwedischen und sonstigen Namen gespeichert. Es werden keine Ortsnamen übersetzt oder erfunden.

Die vollständige finnische Quelle umfasst Åland. Deshalb enthält das Manifest `scope_countries: ["FI", "AX"]`. Die Gebietszuteilung erfolgt jetzt anhand des [amtlichen 2026er Korrespondenzschlüssels zwischen Gemeinden und NUTS](https://stat.fi/fi/luokitukset/corrmaps/kunta_1_20260101%23nuts_2_20260101), nicht anhand einer generalisierten Inselmaske oder eines Schwerpunkts. Alle 308 Gemeindeschlüssel werden mit der vollständigen amtlichen Tabelle verbunden; die 16 Gemeinden der NUTS-3-Einheit `FI200` erhalten `country="AX"`, die übrigen 292 `country="FI"`. `country_assignment_method="official_code"` und `original_source_country="FI"` dokumentieren die Zuordnung. Ganze Originalpolygone bleiben erhalten.

Die amtlichen Åland-Schlüssel für 2026 sind `035, 043, 060, 062, 065, 076, 170, 295, 318, 417, 438, 478, 736, 766, 771, 941`. Die 924 Zeilen des Korrespondenzschlüssels enthalten für jede Gemeinde die drei NUTS-Hierarchiestufen; nur die belegte dritte Stufe steuert die Gebietszuteilung. Der Reader prüft Klassifikationsjahr, widerspruchsfreie Schlüssel, Übereinstimmung mit sämtlichen WFS-Gemeinden und die freigegebene Åland-Mitgliedschaft. Die vollständige JSON-Quelle wird mit Dateihash im Cache erhalten und im Manifest als eigenständiger Herkunftsbeleg unter derselben CC-BY-4.0-Lizenz aufgeführt.

Die amtlichen [Nutzungsbedingungen von Statistics Finland](https://stat.fi/en/about-us/get-to-know-statistics-finland/legislation/terms-of-use) erlauben Bearbeitung, Weitergabe und kommerzielle Nutzung nach [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Erforderlicher Herkunftshinweis: **Source: Statistics Finland**. Die Lizenz und der Herkunftshinweis bleiben im Quellenmanifest erhalten.

## Vereinigtes Königreich

Verwendet wird der öffentliche [ONS-Feature-Service für LAD Dezember 2025 UK BGC](https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Local_Authority_Districts_DEC_2025_Boundaries_UK_BGC/FeatureServer). Das [ONS-Portalprodukt](https://geoportal.statistics.gov.uk/datasets/ons::local-authority-districts-december-2025-boundaries-uk-bgc/about) ist über die ArcGIS-Item-ID `54b2a8f849f743aea669488cab415c8f` identifiziert. Vor der Aufnahme prüft der Leser die Item-ID, den Eigentümer `ONSGeography_data` und den vollständigen Produkttitel. Produktbeschreibung, Service-Metadaten und Zählantwort werden mit eigenen Hashbelegen gecacht und im Manifest dokumentiert.

Die Produktmetadaten beschreiben BGC als 20 Meter generalisierte, an der Küstenlinie beschnittene Grenzen. Der Stand ist Dezember 2025 und wird nicht auf das aktuelle Kalenderjahr umetikettiert. Ein anfänglicher Abruf sämtlicher Geometrien in einer Antwort wurde vom Anbieter mit Verbindungsabbruch beendet. Ein diagnostischer Abruf von 25 Originalflächen gelang dagegen in etwa elf Sekunden. Der Leser lädt deshalb nach `FID` sortierte Seiten zu je 25 Features, bewahrt die unveränderten Seiten samt Transferlimit-Hinweisen und prüft deren Gesamtzahl sowie eindeutige Schlüssel vor dem Zusammenfügen. Keine Geometrie wird zur Umgehung des Abbruchs erfunden oder auf eine andere Gebietsebene ersetzt. Die Quelle beschreibt tatsächliche lokale Gebietskörperschaften beziehungsweise Local Authority Districts. Ihre Rollen bleiben abhängig vom amtlichen GSS-Schlüssel erhalten:

| Schlüsselpräfix | Tatsächlicher Quelltyp |
| --- | --- |
| `E06` | Unitary authority |
| `E07` | Non-metropolitan district |
| `E08` | Metropolitan district |
| `E09` | London borough |
| `S12` | Council area |
| `W06` | Principal area |
| `N09` | Local government district |

Der Sonderfall `E09000001` bleibt ausdrücklich **City of London**. Die [Greater London Authority unterscheidet 32 London Boroughs und die City of London](https://www.london.gov.uk/who-we-are/how-we-work-london); die gemeinsame GSS-Präfixfamilie wird deshalb nicht zum Anlass, der City einen falschen Verwaltungstyp zu geben. Die [britische Regierung erläutert die unterschiedlichen lokalen Behördenstrukturen](https://www.gov.uk/guidance/local-government-structure-and-elections).

Die gemeinsame Darstellungsrolle bedeutet nicht, dass britische Behörden flächenmäßig so klein wie französische Gemeinden wären. Englische Parish-Grenzen werden hier nicht zusätzlich darübergelegt; höhere Counties mit `E10` werden ausdrücklich zurückgewiesen. Schlüssel und Namen bleiben original erhalten, etwa `ons:LAD25:E06000001` für Hartlepool.

Die [ONS-Lizenzseite](https://www.ons.gov.uk/methodology/geography/licences) ordnet digitale Grenzprodukte ausdrücklich der [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) zu. Für diese Produktklasse verlangt sie den ONS-Herkunftshinweis und einen OS-Copyrightvermerk; beide stehen im Manifest. Dort separat beschriebene Einschränkungen nordirischer Postleitzahlprodukte werden nicht auf dieses Grenzprodukt übertragen. Der Jahresvermerk entspricht dem Quellprodukt 2025.

## Irland

Irlands [amtliche CSO-Geografiebeschreibung](https://www.cso.ie/en/releasesandpublications/ep/p-cpini/irelandandnorthernireland-ajointcensuspublication2021-2022/backgroundnotes/) bestätigt die 31 tatsächlichen County-/City-Local-Authorities. Sie entsprechen nicht den 26 traditionellen Counties und nicht den 166 Wahlgebieten. Der konkrete eingebettete [Tailte-Snapshot](https://www.arcgis.com/home/item.html?id=7f508baddb9644d8ac3c3921df39303a) ist auf 2019 datiert und als 20-Meter-Generalisation bezeichnet. Der Reader prüft Originaleigentümer, exakten Titel, Service-Item-ID, Lizenztext, alle 31 Geometrien und eindeutige native GUIDs. Die drei tatsächlichen Behördentypen bleiben erhalten.

Die [ursprünglichen ArcGIS-Item-Metadaten von Tailte Éireann](https://www.arcgis.com/sharing/rest/content/items/7f508baddb9644d8ac3c3921df39303a?f=pjson) nennen ausdrücklich CC BY 4.0 und © Tailte Éireann; dieser Beleg bleibt im Manifest erhalten. Ein fehlendes Lizenzfeld in einer nachgelagerten Portalkopie wird dadurch nicht als Lizenz angenommen. Neuere 2026er Daten enthalten zunächst 9.161 einzelne Polygonteile und benötigen vor Verwendung einen getrennt geprüften Zusammenschluss anhand amtlicher Behördenkennungen zu 31 Körperschaften. Diese Teile werden nicht als 9.161 Gemeinden gezählt und nicht stillschweigend unter den 2019er Datenstand gemischt.

## Importvertrag und reproduzierbare Prüfung

`tools/atlas_official_sources.py` stellt dieselbe kleine Schnittstelle wie der separate gbOpen-Leser bereit:

```python
sources = prepare_sources(cache: Path)  # Liste geprüfter Quellenbelege
for boundary in iter_boundaries(cache, sources):
    # Shapely-Polygon in Längengrad/Breitengrad; keine Spielsimulation
    ...
```

Jede Grenze enthält Land, stabile ID, ursprünglichen Namen, Namensbeleg, Geometrie, Elternland, Quellen-ID, native Ebene, tatsächlichen Einheitstyp und Quelljahr. Die Vorbereitung validiert sämtliche Geometrien und verwirft falsche Gebietstypen, fehlende Flächen, abweichende Jahre, doppelte Schlüssel und unvollständige API-Antworten. Notwendige geometrische Gültigkeitsreparaturen werden gezählt. Nicht vorhandene Namen bleiben ausdrücklich als unbekannt erkennbar; die vorhandenen Flächen gehen dadurch nicht verloren.

Rohdaten, JSON-Metadaten und SHA-256-Receipts liegen ausschließlich unter `.tools/atlas_sources/official/`. Der Download nutzt Windows-Zertifikatsvertrauen ohne TLS-Umgehung. JSON wird zunächst in eine temporäre Datei geschrieben und geprüft; erst danach wird die Datei atomar in den Cache aufgenommen. Bereits gecachte Daten werden vor Wiederverwendung vollständig auf Dateigröße und SHA-256 geprüft. Die Produkt-URLs sind nach Datenjahr adressiert, aber keine unveränderlichen Publikationsarchive; die reproduzierbare lokale Version wird deshalb zusätzlich durch die konkreten Dateihashes fixiert.

Aus dem Projektverzeichnis lassen sich Quellenbelege und Normalisierung erneut prüfen:

```powershell
python -X utf8 -m unittest discover -s tools -p test_atlas_official_sources.py
python -X utf8 tools/atlas_official_sources.py
```

Die Tests wurden vor dem Leser angelegt und zunächst mit sieben fehlgeschlagenen Fällen ausgeführt. Vor der Ergänzung des Seitenabrufs wurden zwei weitere Fälle rot geprüft; ein zusätzlicher roter Test sichert den Sonderfall City of London. Drei weitere rote Fälle sichern den amtlichen Åland-Code, die Klassifikationsverknüpfung und ein unzulässiges Bezugsjahr. Die drei irischen Testfälle wurden ebenfalls vorher rot geprüft und sichern GUID/Unicode, die tatsächlichen Council-Typen sowie die Zurückweisung eines bloßen traditionellen Countynamens. Nach Umsetzung bestanden alle 16 Fälle. Der reale vollständige Anbieterabruf ist ein eigener Prüfpfad neben diesen kontrollierten Fällen.

Der reale Anbieterabruf ergab 308 finnische Gemeinden (292 FI, 16 AX) und 361 britische lokale Behörden. Alle 669 Datensätze besitzen belegte Namen; keiner benötigte eine geometrische Gültigkeitsreparatur. Die finnische GeoJSON-Datei umfasst 2.774.659 Bytes. Das aus allen belegten britischen Seiten deterministisch zusammengesetzte GeoJSON umfasst 53.228.442 Bytes. Der zweite vollständige Cachelauf lieferte ein bytegleiches Quellenmanifest. Der amtliche 2026er Korrespondenzschlüssel umfasst 1.596.614 Bytes und hat SHA-256 `64bc784267bd6dbf53b206c893bc39f8096688ef33114347c0b5be4e47634c2d`.

Zusätzlich wurden die 31 irischen Local Authorities vollständig geladen und normalisiert; die GeoJSON-Quelle umfasst 4.982.711 Bytes. Eine notwendige geometrische Gültigkeitsreparatur ist im Quellenmanifest gezählt. Der amtliche Grundbestand beschreibt damit 700 lokale Einheiten (292 FI, 16 AX, 361 GB, 31 IE); die nachstehende höher aufgelöste AX-Alternative ersetzt denselben 16er-Bestand. Belgien, Litauen und Luxemburg werden im separaten gbOpen-Leser erschlossen; andere fehlende Länder werden nicht durch beliebige höchste ADM-Ebenen ersetzt.

## Ergänzung: höher aufgelöste Åland-Gemeinden

Am 9. November 2026 wurde der echte MML-Jahrgang 2025 im Maßstab 1:10.000
als zusätzliche Quelle `mml-AX-kunta-2025-10k` aufgenommen. Die
[Originalproduktbeschreibung](https://boileri.nic.funet.fi/pub/sci/geo/geodata/mml/hallintorajat_10k/2025/tietotuoteseloste_kuntajako_2025_10k.pdf)
belegt native Gemeindegrenzen auf Katastergrundlage und weist ausdrücklich
darauf hin, dass diese auch Wasserflächen enthalten. Der öffentliche
CSC/Paituli-WFS liefert mit amtlicher `NATCODE`-Auswahl genau die 16 Åland-
Gemeinden in einer vollständigen Antwort: 310.978 Bytes, SHA-256
`b3adde69b48ea012816b6296a008db1659107477656e2a37afe44ef38ef9f36a`.
Es werden keine 16 Ersatzregionen erfunden.

Die offizielle Gemeinde→NUTS-Zuordnung belegt dieselben 16 Codes als Åland;
das Geometriejahr bleibt ausdrücklich **2025**. IDs lauten
`mml:kunta:2025:<NATCODE>`, `municipality_code` enthält unveränderte führende
Nullen. Schwedische und finnische Namen bleiben erhalten, der schwedische Name
wird bevorzugt. Lizenz ist
[Maanmittauslaitos / National Land Survey of Finland CC BY 4.0](https://www.maanmittauslaitos.fi/en/opendata-licence-cc40),
mit Produkt- und Jahresangabe im Credit; CSC/Paituli wird als Bereitsteller
genannt.

`merge_priority=4` kennzeichnet eine höher aufgelöste **Alternative** zu den
16 StatFi-Gemeinden. `requires_physical_land_clip=true`,
`geometry_includes_marine_area=true` und
`land_reference_source_id="syke-physical-land-AX-MML2025"` verhindern eine
semantische Verwechslung zwischen Verwaltungsgebiet und physischem Land. Die
Originalpolygone bleiben im Reader erhalten; der Atlas-Merger muss sie zur
Darstellung an der gesonderten unabhängigen Küstenmaske beschneiden.

Der unabhängige Nenner stammt aus SYKE-Inselgeometrien und dem **separaten
amtlichen Regionalprodukt** MML-Maakunta 21. Die zu prüfenden Gemeinden bilden
diesen Nenner nicht. Dagegen deckt die alte StatFi-1:1-Million-Quelle
89,2905 % und der MML10k-Kommunalstand 99,9987 % der Küstenfläche. Methode,
Originalquittungen, Binnenwasser-Unterschiede und Grenzen stehen in
[atlas-small-country-audit.md](atlas-small-country-audit.md).

Damit enthält der Rohreader jetzt 716 Quellzeilen: FI 292, GB 361, IE 31 und
AX 16 + 16 alternative Quellversionen. **Nach Prioritätsauflösung müssen es
weiter genau 16 Åland-Gemeinden sein**, keine 32. Diese dokumentierte
Quellenüberlagerung ist kein vergrößerter Bestand kommunaler Körperschaften.
Die beiden neuen gezielten Fälle erhöhen die Python-Suite auf 18 grüne Tests:
amtliche Kennung/Name/Priorität mit ehrlichem Meeresterritorium und Ablehnung
falscher Landeskennungen beziehungsweise fehlender Geometrien.

## Luxemburg: aktueller amtlicher Kommunalstand und getrennter Landesumriss

Die [ACT-Publikation auf dem staatlichen Open-Data-Portal](https://data.public.lu/en/datasets/limites-administratives-du-grand-duche-de-luxembourg/)
liefert das ursprüngliche SHP-Paket vom **5. November 2026** unter **CC0 1.0**.
Produzent ist die Administration du cadastre et de la topographie. Das
festgelegte Archiv umfasst **9.909.017 Bytes** und enthält mehrere getrennte
Verwaltungsebenen. Für den Kommunalprovider wird ausschließlich
`LIMADM_COMMUNES` verwendet: **100** echte administrative Gemeinden, mit
vollständigen UTF-8-Namen und vierstelligen `LAU2`-Kennungen. Die generalisierte
Alternative und die Katastergemeinden werden nicht zusätzlich importiert.

Die [amtliche LAU-/Gemeindeliste vom 9. Juli 2024](https://download.data.public.lu/resources/limites-administratives-du-grand-duche-de-luxembourg/20240709-164127/commune-canton-district-circonscription-arrondissements.csv)
enthält dieselben 100 Code-/Namenspaare. Jede importierte Geometrie stimmt
eins zu eins und ohne erfundene Namensaliase damit überein. Das zusätzliche
[ACT-Gemeinde-/Katasterabschnittsregister vom 21. Oktober 2025](https://download.data.public.lu/resources/limites-administratives-du-grand-duche-de-luxembourg/20251021-085328/liste-communes-sections.csv)
belegt genau dieselben 100 Gemeinden und liefert ihre ursprünglichen
dreistelligen ACT-Kennungen. Beide Register bleiben mit Datum und Einzelhash
im Quellenbeleg erhalten. Sie werden nicht als neue 2026er Register ausgegeben.

Der Source-Schlüssel lautet `act-LU-communes-20261105`; Einheiten erhalten
`act:LU:commune:<LAU2>`, etwa `act:LU:commune:0303` für Hesperange. Führende
Nullen bleiben erhalten. `municipality_code` enthält LAU2,
`native_commune_code` die zusätzliche ACT-Kennung. `merge_priority=4`
kennzeichnet diesen aktuellen Stand als Ersatz der 102 älteren gbOpen-Einheiten;
beide Stände dürfen nicht als zusätzliche Gemeinden zusammengezählt werden.

Die Quelldatei enthält weiterhin historische `DISTRICT`-Attribute. Das Portal
erklärt ausdrücklich die Abschaffung der Distrikte durch das Gesetz vom
2. September 2015. Der Reader erzeugt daraus **keine aktuellen Regionsfeatures
und keine Gemeinde-Eltern**. Stattdessen werden die zwölf heutigen Kantone
aus ihrem separaten amtlichen Layer mit ihren Originalkennungen eingelesen;
die 100 Gemeinden erhalten den jeweils belegten Kanton als Elternfeature.

### Koordinaten und gemessene Flächen

Portal und Original-PRJ deklarieren **EPSG:2169 / Luxembourg TM**. Die PRJ
benutzt allerdings den alten Datumsnamen `Luxembourg_1930`, den PROJ nur mit
geringem Aliasvertrauen erkennt. Der Reader prüft die ausdrückliche
EPSG-Deklaration, Transverse-Mercator-Verfahren, International-1924-Ellipsoid
und sämtliche Projektionsparameter. Danach verwendet er das amtlich
deklarierte EPSG:2169 mit `allow_ballpark=False` und `only_best=True`.
Die tatsächlich verwendete Operation ist **LUREF to WGS 84 (4)**; PROJ nennt
**1 Meter** Transformationsgenauigkeit. Ein bloßer Nullversatz auf Basis eines
unerkannten alten Datumsnamens wird nicht akzeptiert.

Der gesonderte nationale Layer **`LIMADM_PAYS` enthält genau ein Länderfeature**.
Der Landreferenzreader verwendet ausschließlich dieses Originalfeature als
unabhängigen Nenner, nicht die Vereinigung der Zielgemeinden. Die amtliche
gemeinsame Datengrundlage erklärt ihre hohe Übereinstimmung; der getrennte
Layer verhindert, dass eine fehlende importierte Gemeinde aus dem Nenner
verschwinden würde. Source-ID ist `act-national-LU-20261105`.

| Vergleich gegen das getrennte ACT-Länderfeature | Einheiten | Bedeckte Referenzfläche | Anteil |
|---|---:|---:|---:|
| Aktuelle originale ACT-Gemeinden | 100 | 2.584,0457915 km² | **99,99999998 %** |
| Älterer gbOpen-Gemeindestand | 102 | 2.567,1090915 km² | **99,34456655 %** |
| Unabhängiges ACT-Länderfeature | — | **2.584,0457920 km²** | Referenz |

Damit erklärt sich der frühere Wert von etwa 94,27 % wesentlich durch die
abweichende grobe Natural-Earth-Landesmaske. Die aktuelle Quelle verbessert
zusätzlich Jahrgang, Namen, Gemeindekennungen und Geometriegenauigkeit.
Die Flächen werden wie die übrigen Atlas-Audits sphärisch flächentreu gemessen;
sie sind keine Behauptung derselben numerischen Fläche wie in einer amtlichen
ellipsoidischen Vermessung. Keine der 100 Kommunalgeometrien musste repariert
werden. Das Kondominium bleibt ein eigener, hier nicht importierter Quelllayer.

Alle Originale bleiben ausschließlich im privaten Cache. ZIP-Leser prüfen
Original-CRC und die Eindeutigkeit jeder ausgewählten SHP-Komponente. Das
Manifest enthält zusätzlich Archiv-/Metadatenhashes, komponentenweise
SHA-256-Werte, PRJ-Herkunft und die amtlichen Registerquittungen. Aufbereitete
Gemeinden: **18.646.951 Bytes**, SHA-256
`9db2e4aacf39a806f6352039985d1879c6e27f4b8fea5075d8206e229d166e40`.
Getrennte Landesreferenz: **1.349.004 Bytes**, SHA-256
`a8d8afcd3c85d154105568e17e946dc656429822449c04bfce738ccad16bf0aa`.

Die neue kommunale Prüfung sichert LAU-Code, Namen, Priorität und die Trennung
historischer Distrikte; drei Landreferenzfälle sichern den unabhängigen
nationalen Layer, die offizielle Code-Liste und die strikte CRS-Behandlung.
Zusätzliche Hierarchietests sichern den aktuellen Kantonstyp, den eindeutigen
Code-/Namensjoin und die verknüpften Gemeinde-Eltern. Die Suiten umfassen jetzt
**22 amtliche Quellen- und 16 Landreferenztests**. Der
zusätzliche Rohbestand von 100 aktuellen LU-Einheiten wird vor dem Einbau in
die Runtime vom koordinierenden Merger priorisiert; dieser Reader verändert
weder Spielprovinzen noch Simulation.

### Zwölf aktuelle Kantone und belegte Elternbeziehungen

Die zusätzliche Quelle **`act-LU-cantons-20261105`** verwendet ausschließlich
den Original-Layer `LIMADM_CANTONS` desselben datierten ACT-Archivs. Er enthält
genau zwölf Features mit `CANTON`, dem historischen Zusatzattribut `DISTRICT`
und dem **tatsächlichen zweistelligen Originalcode `LAU1`**. Dieser Code wird
nicht aus einer Namensnummerierung erfunden. Seine Originalfeldbezeichnung
wird erhalten; damit wird keine Fortgeltung des früheren zweistufigen
Eurostat-LAU-Schemas behauptet.

Die IDs lauten `act:LU:canton:01` bis `act:LU:canton:12`. Die Darstellungsrolle
ist `district`, der tatsächliche Quelltyp heißt **Canton**; `admin_level` bleibt
`null`. Die Quellenpriorität ist 4, Stand und Lizenz bleiben 5. November 2026
beziehungsweise CC0. Eltern-ID der Kantone ist `country:LU`. Die abgeschafften
Distrikte Diekirch/Grevenmacher/Luxembourg werden daraus nicht rekonstruiert.

Jede Gemeinde wird über ihren ursprünglichen `CANTON`-Namen eindeutig mit
`LIMADM_CANTONS.CANTON` verbunden. Zusätzlich müssen die ersten beiden Zeichen
ihres ursprünglichen LAU2-Codes mit dem **wirklich vorhandenen LAU1-Code** des
Zielkantons übereinstimmen. Fehlende, mehrdeutige und widersprüchliche Joins
werden zurückgewiesen. Der reale Datensatz erfüllt den Join für alle
**100 von 100 Gemeinden**; alle Eltern-IDs sind unter den zwölf Quellfeatures
vorhanden. Beispiel Hesperange: LAU2 `0303` → ursprünglicher Kanton Luxembourg,
LAU1 `03` → `parent_id="act:LU:canton:03"`.

| Original-LAU1 | Kanton | Zugeordnete Gemeinden |
|---|---|---:|
| 01 | Capellen | 9 |
| 02 | Esch-sur-Alzette | 14 |
| 03 | Luxembourg | 11 |
| 04 | Mersch | 10 |
| 05 | Clervaux | 5 |
| 06 | Diekirch | 10 |
| 07 | Redange | 9 |
| 08 | Wiltz | 7 |
| 09 | Vianden | 3 |
| 10 | Echternach | 7 |
| 11 | Grevenmacher | 8 |
| 12 | Remich | 7 |

Auch der tatsächliche räumliche Gegencheck besteht: Jede Gemeindefläche liegt
innerhalb ihres verknüpften aktuellen Kantons. Der kleinste gemessene Anteil
beträgt `0.9999999999999942`; die Abweichung zu 1 liegt im numerischen
Gleitkommabereich. Keine Kantonsgeometrie musste repariert werden.

Der LU-Teil des Rohreaders enthält jetzt **100 Gemeinden und 12 Kantone**.
Diese 112 Verwaltungsfeatures sind keine 112 Gemeinden. Der Original-Kantons-
GeoJSON nach überprüfter Projektion umfasst 7.026.847 Bytes, SHA-256
`e341bce23301e01487a2d2bb1cecafefd6d6532859709724fbb5b5caeb989f3f`.
Sämtliche Originalkomponenten, CRCs und Quellhashes bleiben separat im
Quellenmanifest erhalten. Das aktualisierte amtliche Manifest umfasst
81.852 Bytes, SHA-256
`e2b45c0097b73c674e7ff684727ca3194b25d8f6fed88838c212907cec880332`.
