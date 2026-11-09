# Gleichmäßige kommunale Atlasabdeckung: Quellenprüfung

Stand: 09.11.2026. Recherche, keine Änderung der Spieldaten oder Laufzeit. Der Nutzer hat ausdrücklich echte vergleichbare Verwaltungsebenen in allen Ländern gewählt. Gleich große künstliche Spielzellen oder das Ausblenden deutscher Daten ersetzen diese Anforderung nicht.

## Tatsächlicher Ausgangszustand

`data/atlas.json` enthält 69 Länder-/Gebietskennungen. Nur Deutschland hat die ausdrücklich als `district`/`municipality` gespeicherten 400 Kreise und 10.949 Gemeinden. Alle anderen Länder enthalten bisher ausschließlich `country` und `region`. Das ist tatsächlich eine einseitige zusätzliche Detailebene.

Die Bedeutung von Natural-Earth-`region` ist außerdem uneinheitlich: Frankreich hat 96 Départements, Italien 110 Provinzobjekte, Spanien 50 Provinzen und Großbritannien 232 gemischte Verwaltungseinheiten. In Malta entsprechen 68 Einheiten bereits Local Councils, in Liechtenstein elf Einheiten Gemeinden, in Andorra sieben Einheiten Parishes. Die Laufzeitkategorie allein beweist daher weder eine einheitliche Verwaltungsebene noch fehlende echte Kommunalgeometrie. Die Einheiten müssen pro Land nach ihrer tatsächlichen Verwaltungsrolle normalisiert werden.

## Primäre Datenwege

**Overture Divisions** ist ein guter normalisierter globaler Rahmen. Der Anbieter bestätigt globale Abdeckung für country, region und county; unterhalb von county bezeichnet er die Abdeckung ausdrücklich als lückenhaft. `locality` ist nicht zwingend eine selbst verwaltete Gemeinde, `localadmin` bezeichnet lokale Verwaltung. Deshalb darf eine Anzahl von Overture-Ortschaften nicht als flächendeckende Gemeindeabdeckung ausgegeben werden. `division_area` enthält `division_id`, `country`, `region`, `subtype`, `admin_level`, `is_land` und `is_territorial`. Für eine landbezogene Abdeckungsprüfung sind Landgeometrien erforderlich; Land- und Territorialvarianten derselben Division dürfen nicht doppelt gezählt werden. Das gesamte Divisions-Theme wird unter ODbL angeboten. [Offizieller Divisions-Guide](https://docs.overturemaps.org/guides/divisions/), [DivisionArea-Schema](https://docs.overturemaps.org/schema/reference/divisions/division_area/), [Lizenzangaben](https://docs.overturemaps.org/attribution/#divisions).

**geoBoundaries gbOpen** bietet bereits viele echte Gemeindeebenen als direkt verfügbare, auch kommerziell nutzbare Quellen, aber nicht jede tiefste ADM-Ebene ist eine Gemeinde. `boundaryCanonical`, Quellbehörde, Bezugsjahr und `boundaryLicense` müssen ausgewertet werden. Der zentrale Metadatenabruf wurde vollständig unter `.tools/atlas_sources/coverage-metadata.json` gecacht. Die allgemeine CC-BY-Beschreibung ersetzt nicht die individuellen Quelllizenzen. [Offizielle API](https://www.geoboundaries.org/api.html), [vollständige Metadaten](https://www.geoboundaries.org/api/current/gbOpen/ALL/ALL/).

**Geofabrik** stellt seit April 2026 administrative Flächen auch in kostenlosen GeoPackage-/Shapefile-Extrakten bereit. Die freien Flächen besitzen jedoch keine bereits aufgelöste Elternhierarchie und sind nicht an Küsten beschnitten. Die aufbereiteten Versionen mit diesen Zusatzleistungen sind weiterhin kommerzielle Produkte. Ein kompletter Europa-Rohdatensatz ist ungefähr 33 GB groß; das ist kein zweckmäßiger erster Download für diesen Atlas. [Offizielle Ankündigung](https://blog.geofabrik.de/index.php/2026/04/), [Europa-Downloadübersicht](https://download.geofabrik.de/europe.html).

**GISCO NUTS/LAU** wird für diese Pipeline nicht als uneingeschränkt kommerziell nutzbar angenommen. Die offizielle Downloadregel verlangt für kommerzielle Verwendung zusätzliche Lizenzklärung. **OSM-Boundaries.com** verlangt Download-Credits. **GADM** ist ebenfalls keine pauschal frei kommerziell einbettbare Ausweichquelle. [GISCO-Bedingungen](https://ec.europa.eu/eurostat/en/web/gisco/geodata/statistical-units), [OSM-Boundaries-Dokumentation](https://osm-boundaries.com/about/documentation).

## Konkrete kommunale Kandidaten

Die Zahlen sind Metadaten des genannten historischen Bezugsstands, keine Behauptung aktueller amtlicher Gemeindezahlen oder bereits gemessener flächenhafter Vollständigkeit. Direkt verfügbare vereinfachte GeoJSON-Dateien wurden nur mit HTTP-HEAD geprüft, nicht heruntergeladen. Ihre URLs sind über die API für den festgeschriebenen Commit `9469f09` erreichbar.

| Land | Geeignete Ebene / Rolle | Einheiten / Jahr | Lizenz laut gbOpen | Vereinfachtes GeoJSON / Prüfung |
|---|---|---:|---|---|
| Deutschland | bestehendes BKG VG250 Gemeinden | 10.949 / 2025 | DL-DE-BY-2.0 | eingebettet; Flächenunion noch separat messen |
| Frankreich | ADM5, kommunale Einheiten einschließlich kommunaler Arrondissements | 35.010 / 2020 | ODC Attribution 1.0 | 58.886.663 Bytes; verschachtelte Stadtteil-/Gemeindeobjekte auf Rollen/Doppelzählung prüfen |
| Italien | ADM4, Comuni aus ISTAT | 7.901 / 2023 | CC BY 3.0 | 18.353.080 Bytes; Quelle ISTAT |
| Spanien | ADM3, Municipios | 8.205 / 2018 | CC BY 4.0 | 18.613.175 Bytes |
| Polen | ADM3, Gminas | 2.480 / 2017 | CC BY-SA 2.0 | 7.277.983 Bytes; aktuelle Gebietsreform nicht behaupten |
| Österreich | ADM3, Gemeinden | 2.097 / 2017 | CC BY-SA 2.0 | 6.014.584 Bytes; ADM4 mit 7.850 Einheiten nicht als weitere Gemeinden behandeln |
| Schweiz | ADM3, Municipality | 2.286 / 2022 | swisstopo-Nutzungsbedingungen | 3.677.733 Bytes; Lizenztext vor Übernahme belegen |
| Dänemark | ADM2, Kommune | 98 / 2018 | Public Domain | API-Metadaten geprüft |
| Niederlande | ADM2, Municipality | 344 / 2022 | CC0 | API-Metadaten geprüft |
| Schweden | ADM2, Municipality | 290 / 2017 | CC0 | ADM3 hat 2.652 Einheiten, ist keine zusätzliche Gemeindeebene |
| Griechenland | ADM3, Municipality | 326 / 2010 | CC0 | API-Metadaten geprüft; historischer Reformstand |
| Portugal | ADM3, Freguesias | 2.905 / 2021 | CC0 | unterhalb Municipios; Rolle ausdrücklich beibehalten |
| Bulgarien | ADM2, Municipality | 265 / 2019 | je Datensatz prüfen | kanonische Rolle in Metadaten belegt |
| Kroatien | ADM2, Municipalities and Towns | 560 / 2021 | je Datensatz prüfen | kanonische Rolle in Metadaten belegt |
| Rumänien | ADM2, Municipalities | 3.235 / 2016 | je Datensatz prüfen | kanonische Rolle in Metadaten belegt |
| Georgien | ADM2, Municipality | 68 / 2007 | Public Domain | sehr alter Stand, Konfliktgebiete/Perspektiven prüfen |
| Armenien | ADM2, Municipal Communities | 39 / 2020 | CC BY 3.0 IGO | Gemeindezusammenschlüsse/Flächenvollständigkeit prüfen |
| Algerien | ADM3, Communes | 1.540 / 2021 | CC BY-SA 2.0 | auf tatsächlichen Kartenausschnitt clippen |
| Iran | ADM4, Dehestan | 2.815 / 2021 | CC BY-SA 2.0 | ländliche Verwaltung, nicht automatisch urbane Vollabdeckung |
| Ukraine | ADM3, Village Councils | 10.375 / 2021 | CC BY-SA 2.0 | nicht mit reformierten Hromadas gleichsetzen |

Wichtige Gegenkontrollen: gbOpen meldet für Finnland ADM3 313 Einheiten mit Bezugsjahr 2017; Statistics Finland nennt für 2017 aber 311 Gemeinden. Für Norwegen meldet gbOpen 431 Einheiten für 2013, SSB nennt 428. Diese Abweichungen benötigen eine fachliche Klärung vor einer Vollständigkeitsbehauptung. Großbritannien bietet in gbOpen als tiefste Ebene nur 216 Counties/Unitary Authorities; Russland 2.328 Raions und Türkei 999 Districts. Diese drei Datensätze ersetzen keine echte kommunale Ebene. [Statistics Finland 2017](https://stat.fi/fi/luokitukset/kunta/kunta_1_20170101), [SSB-Verwaltungsgliederung](https://www.ssb.no/befolkning/regioner/statistikk/regionale-inndelingar), [ISTAT-Grenzen](https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici-al-1-gennaio-2018-2/).

## Abdeckungsprüfung statt bloßer Objektzählung

Für jedes Land ist eine landbezogene Zielmenge `Landgeometrie ∩ Kartenausschnitt` festzulegen. Dann wird die Vereinigung ausschließlich fachlich bestätigter kommunaler Einheiten auf diese Zielmenge beschnitten. Der Flächenanteil `Union kommunaler Landflächen / Ziel-Landfläche` ist in einer gemeinsamen flächentreuen Projektion zu messen. Zusätzlich müssen Überlappungsquote, Lückenpolygone, Bezugsjahre, gültige Elternbeziehungen und ungeklärte Verwaltungsrollen ausgegeben werden.

Ein Ziel von mindestens 95 % muss **pro Land im Ausschnitt** überprüft werden. Eine europaweite Durchschnittszahl kann große unbedeckte Flächen eines einzelnen Landes verbergen. Küstensaum-/Maßstabsabweichungen sind getrennt von echten fehlenden Gemeinden zu erfassen. Kleine Gebietskennungen und nur angeschnittene Länder benötigen dieselbe Prüfung, keine künstlich aufgefüllten Zellen.

Die geographische Zahl oder Fläche von Kommunen darf wirtschaftliche und militärische Werte der 49 vorhandenen Spielgebiete nicht implizit vervielfachen. Unabhängige Simulationseinheiten und heutige Referenzverwaltung sind getrennte Verträge. Natürlicherweise unterschiedlich große echte Gemeinden sind kein Fehler, solange dieselben Darstellungs- und Spielregeln gelten.

## Vollständige Bestandsmatrix der 69 Gebietskennungen

Die Spalte „Landesfläche im Ausschnitt“ misst nur, wie viel der Natural-Earth-Landeslandfläche innerhalb Länge −12..52 / Breite 33..72 liegt. Sie ist **keine kommunale Abdeckungsquote**. Berechnung: sphärisch flächentreue Zylinderprojektion mit Radius 6.371 km auf vorhandenen Natural-Earth-Polygonen; Werte sind gerundete Planungsgrößen. Für zusätzliche kleine Gebietskennungen ohne separaten Admin0-Datensatz wird kein Wert erfunden. Keine Aussage zur staatlichen Anerkennung folgt aus der technischen Länderkennung.

`Runtime-Kommunen` zählt ausschließlich bestehende `kind=municipality`-Objekte. Die oben genannten semantischen Natural-Earth-Ausnahmen können trotz Null bereits kommunale Geometrie darstellen. „Höchste gbOpen-Ebene“ ist nur ein Rechercheweg und ausdrücklich kein Nachweis kommunaler Gleichwertigkeit.

| ID | Datensatzname | Landesfläche im Ausschnitt | Runtime-Kommunen | Höchste gbOpen-Ebene / kanonische Rolle / Anzahl / Jahr |
|---|---|---:|---:|---|
| AD | Andorra | 100,0 % | 0 | ADM1 / Parish / 7 / 2007 |
| AL | Albanien | 100,0 % | 0 | ADM3 / Unknown / 373 / 2013 |
| AM | Armenien | 100,0 % | 0 | ADM2 / Municipal Communities / 39 / 2020 |
| AT | Österreich | 100,0 % | 0 | ADM4 / Unknown / 7850 / 2017 |
| AX | Åland | 100,0 % | 0 | kein eigener Eintrag |
| AZ | Aserbaidschan | 100,0 % | 0 | ADM2 / Unknown / 79 / 2020 |
| BA | Bosnien und Herzegowina | 100,0 % | 0 | ADM3 / gbOpen / 142 / 2013 |
| BE | Belgien | 100,0 % | 0 | ADM4 / Unknown / 589 / 2018 |
| BG | Bulgarien | 100,0 % | 0 | ADM2 / Municipality / 265 / 2019 |
| BY | Belarus | 100,0 % | 0 | ADM2 / Raion / 118 / 2005 |
| CH | Schweiz | 100,0 % | 0 | ADM3 / Municipality / 2286 / 2022 |
| CY | Republik Zypern | 100,0 % | 0 | ADM2 / Unknown / 612 / 2009 |
| CYN | Türkische Republik Nordzypern | nicht separat belegt | 0 | kein eigener Eintrag |
| CZ | Tschechien | 100,0 % | 0 | ADM4 / Unknown / 13090 / 2017 |
| DE | Deutschland | 100,0 % | 10949 | ADM3 / Independent City or District / 428 / 2021 |
| DK | Dänemark | 100,0 % | 0 | ADM2 / Kommune / 98 / 2018 |
| DZ | Algerien | 15,1 % | 0 | ADM3 / Communes / 1540 / 2021 |
| EE | Estland | 100,0 % | 0 | ADM3 / Villages / 4797 / 2020 |
| ES | Spanien | 98,6 % | 0 | ADM3 / Municipios / 8205 / 2018 |
| ESB | Dekelia | nicht separat belegt | 0 | kein eigener Eintrag |
| FI | Finnland | 100,0 % | 0 | ADM3 / Unknown / 313 / 2017 |
| FO | Färöer | 100,0 % | 0 | ADM0 / Faroe Islands / 1 / 2021 |
| FR | Frankreich | 85,9 % | 0 | ADM5 / kommunale Einheiten und Arrondissements / 35010 / 2020 |
| GB | Vereinigtes Königreich | 100,0 % | 0 | ADM3 / Counties and Unitary Authorities / 216 / 2020 |
| GE | Georgien | 100,0 % | 0 | ADM2 / Municipality / 68 / 2007 |
| GG | Guernsey | 100,0 % | 0 | ADM0 / Guernsey / 1 / 2021 |
| GI | Gibraltar | nicht separat belegt | 0 | kein eigener Eintrag |
| GR | Griechenland | 100,0 % | 0 | ADM3 / Municipality / 326 / 2010 |
| HR | Kroatien | 100,0 % | 0 | ADM2 / Municipalities and Towns / 560 / 2021 |
| HU | Ungarn | 100,0 % | 0 | ADM3 / Unknown / 3357 / 2017 |
| IE | Irland | 100,0 % | 0 | ADM2 / Local Electoral Areas / 166 / 2015 |
| IL | Israel | 6,1 % | 0 | ADM2 / Subdistrict / 15 / 2021 |
| IM | Isle of Man | 100,0 % | 0 | ADM0 / The Isle of Man / 1 / 2021 |
| IQ | Irak | 46,8 % | 0 | ADM2 / Districts / 101 / 2021 |
| IR | Iran | 21,9 % | 0 | ADM4 / Dehestan / 2815 / 2021 |
| IT | Italien | 100,0 % | 0 | ADM4 / Unknown / 7901 / 2023 |
| JE | Jersey | 100,0 % | 0 | kein eigener Eintrag |
| JO | Jordanien | 1,8 % | 0 | ADM2 / Nahias / 52 / 2006 |
| KZ | Kasachstan | 6,5 % | 0 | ADM2 / District / 174 / 2017 |
| LB | Libanon | 100,0 % | 0 | ADM2 / Districts / 26 / 2021 |
| LI | Liechtenstein | 100,0 % | 0 | ADM1 / Unknown / 11 / 2017 |
| LT | Litauen | 100,0 % | 0 | ADM3 / Unknown / 544 / 2017 |
| LU | Luxemburg | 100,0 % | 0 | ADM3 / Unknown / 102 / 2018 |
| LV | Lettland | 100,0 % | 0 | ADM2 / pilsētās un pagastos / 589 / 2021 |
| LY | Libyen | unter 0,05 % | 0 | ADM1 / Districts / 22 / 2021 |
| MA | Marokko | 21,8 % | 0 | ADM2 / Unknown / 75 / 2017 |
| MC | Monaco | 100,0 % | 0 | ADM2 / Unknown / 9 / 2017 |
| MD | Republik Moldau | 100,0 % | 0 | ADM1 / Districts / 37 / 2020 |
| ME | Montenegro | 100,0 % | 0 | ADM1 / Unknown / 23 / 2017 |
| MK | Nordmazedonien | 100,0 % | 0 | ADM2 / Opštini / 84 / 2016 |
| MT | Malta | 100,0 % | 0 | ADM1 / Local Council / 68 / 2022 |
| NL | Niederlande | 99,3 % | 0 | ADM2 / Municipality / 344 / 2022 |
| NO | Norwegen | 84,0 % | 0 | ADM2 / Unknown / 431 / 2013 |
| PL | Polen | 100,0 % | 0 | ADM3 / Gminas / 2480 / 2017 |
| PT | Portugal | 96,8 % | 0 | ADM3 / Freguesias / 2905 / 2021 |
| RO | Rumänien | 100,0 % | 0 | ADM2 / Municipalities / 3235 / 2016 |
| RS | Serbien | 100,0 % | 0 | ADM2 / Unknown / 145 / 2017 |
| RU | Russland | 17,6 % | 0 | ADM2 / Raion / 2328 / 2017 |
| SE | Schweden | 100,0 % | 0 | ADM3 / Unknown / 2652 / 2018 |
| SI | Slowenien | 100,0 % | 0 | ADM2 / Unknown / 213 / 2017 |
| SK | Slowakei | 100,0 % | 0 | ADM4 / Unknown / 3695 / 2017 |
| SM | San Marino | 100,0 % | 0 | ADM1 / Unknown / 9 / 2017 |
| SY | Syrien | 94,7 % | 0 | ADM3 / sub-district / 272 / 2017 |
| TN | Tunesien | 70,7 % | 0 | ADM3 / Unknown / 2083 / 2017 |
| TR | Türkei | 100,0 % | 0 | ADM2 / Districts / 999 / 2021 |
| UA | Ukraine | 100,0 % | 0 | ADM3 / Village Councils / 10375 / 2021 |
| VA | Vatikanstadt | 100,0 % | 0 | ADM0 / Vatican City / 1 / 2017 |
| WSB | Akrotiri | nicht separat belegt | 0 | kein eigener Eintrag |
| XK | Kosovo | 100,0 % | 0 | ADM2 / Municipality / 38 / 2017 |

## Noch nicht nachgewiesen

Es wurde kein neuer kommunaler Datensatz importiert und keine 95-%-Kommunalflächenquote gemessen. Overture-Pilotabfragen werden parallel durch einen anderen Agenten ausgeführt; sie werden durch diese Recherche nicht vorweggenommen. Die lückenhafte Unterkreisabdeckung von Overture und die historisch uneinheitlichen gbOpen-Bestände verlangen eine Quelle-für-Quelle-Prüfung statt einer pauschalen globalen Vollständigkeitsbehauptung.
