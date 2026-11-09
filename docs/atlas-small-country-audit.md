# Unabhängige Flächenprüfung: Liechtenstein, San Marino, Åland und Luxemburg

Stand der Untersuchung: 9. November 2026. Die niedrigen Abdeckungswerte dieser drei Gebiete entstehen wesentlich durch den Vergleich geometrisch unterschiedlich generalisierter Grenzen. Die Anzahl vorhandener Gemeinden allein erklärt sie nicht. Ein Wechsel von Natural Earth 1:50 Mio. auf 1:10 Mio. behebt die Formfehler kleiner Länder und Inseln nicht zuverlässig.

## Tatsächlich gemessene Geometrien

Alle folgenden Flächen wurden mit derselben flächentreuen sphärischen Projektion berechnet, die der Atlas-Audit verwendet. Absolute Werte unterscheiden sich deshalb geringfügig von amtlichen ellipsoidischen Vermessungsflächen. Flächenanteile sind geometrische Schnittmengenanteile des ausdrücklich genannten unabhängigen Nenners.

| Gebiet | Kommunalquelle, vereinfachte Union | Natural-Earth-10m-Landesfläche | Schnittmenge mit NE | Anteil an NE |
| --- | ---: | ---: | ---: | ---: |
| Liechtenstein | 160,224 km², 11 Gemeinden | 136,877 km² | 122,517 km² | 89,5089 % |
| San Marino | 60,739 km², 9 Castelli | 60,198 km² | 43,395 km² | 72,0872 % |
| Åland | 1.453,558 km², 16 amtliche Gemeinden | 936,780 km² | 818,266 km² | 87,3488 % |

Die unvereinfachten gbOpen-Originale ergeben für Liechtenstein 160,082 km² und für San Marino 61,000 km². Gegen dieselbe NE-Maske erreichen sie nur 89,4037 % beziehungsweise 72,3600 %. Der Wechsel auf diese Originale beseitigt den großen scheinbaren Fehlbestand deshalb nicht. Bei San Marino ist die Gesamtfläche der NE-Maske ungefähr plausibel, ihre Form stimmt aber so wenig überein, dass rund 17 km² der tatsächlichen Referenzfläche außerhalb dieser generalisierten Maske liegen. Ein Clip würde reale Teile verwerfen.

Die amtliche liechtensteinische [Landesstatistik nennt rund 160 km² beziehungsweise im vermessenen Nachweis 160,477 km²](https://www.statistikportal.li/statistikportal/publications/101-statistisches-jahrbuch/2020/01/1/101.2020.01_01_statistisches-jahrbuch-2020.pdf). Die amtliche Tourismusinformation San Marinos nennt [61,19 km² und die Lage zwischen Emilia-Romagna und Marche](https://www.visitsanmarino.com/pub1/VisitSM/contenuto/About-San-Marino/POPOLAZIONE-E-TERRITORIO.html). Diese unabhängigen Zahlen dienen der Plausibilitätsprüfung; sie ersetzen keine geometrische Schnittmengenmessung.

## Liechtenstein: getrennte amtliche Landesgrenze

Der swisstopo-Datensatz [swissBOUNDARIES3D](https://www.swisstopo.admin.ch/en/landscape-models) enthält ausdrücklich die nationalen und administrativen Grenzen sowohl der Schweiz als auch Liechtensteins. Der öffentliche GeoAdmin-Dienst liefert das Landesfeature `LI` aus `ch.swisstopo.swissboundaries3d-land-flaeche.fill`. Die [Produktlegende](https://api3.geo.admin.ch/rest/services/api/MapServer/ch.swisstopo.swissboundaries3d-land-flaeche.fill/legend) nennt den Stand 01.01.2026. Die Auswahl erfolgt anhand dieses exakten Feature- und Layer-Schlüssels.

| Unabhängiger Nenner | Fläche | gbOpen-Originale decken | Vereinfachte gbOpen-Gemeinden decken |
| --- | ---: | ---: | ---: |
| Amtliche swisstopo-Landesgrenze LI | 160,035 km² | 99,9921 % | 99,5901 % |

Damit ist die tatsächliche lokale Flächendeckung für diesen unabhängigen Referenzmaßstab belegt. Die Landesgrenze wurde separat bezogen und wird nicht durch Vereinigung der zu prüfenden liechtensteinischen Gemeinden erzeugt. Für Weitergabe und Bearbeitung gelten die [swisstopo-Nutzungsbedingungen](https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices); der Herkunftshinweis **Federal Office of Topography swisstopo** bleibt im Manifest erhalten.

Die originale GeoAdmin-JSON-Antwort umfasst 58.286 Bytes, SHA-256 `b9e80b16c1a144b02c3d869e4bcd1ba9d21f05d8af74f301f3f896ad8bbbbbb8`.

## San Marino: unabhängige Enklave in den italienischen ISTAT-Flächen

Die bereits festgeschriebenen italienischen ISTAT-Kommunalgrenzen aus `gbOpen-ITA-ADM4` liefern eine unabhängige Außenkontrolle: Italien umschließt San Marino vollständig. Aus 64 italienischen Quellpolygonen im festgelegten Rechteck 12,2–12,7° Ost / 43,7–44,2° Nord wird die Vereinigung gebildet. Die Differenz zum Auswahlrechteck enthält eine geschlossene Enklave um den Punkt 12,45° Ost / 43,94° Nord. Ausschließlich diese Komponente wird übernommen. Eine zum Rechteckrand offene Lücke wird ausdrücklich zurückgewiesen.

Die Methode verwendet **keine der neun zu prüfenden san-marinesischen Gemeinden** und keine aus diesen abgeleitete Landesfläche. Quelle ist der getrennte italienische ISTAT-Datensatz, in der vorhandenen gbOpen-Version datiert 2023. Die [amtliche ISTAT-Beschreibung der Verwaltungsgrenzen](https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici-al-1-gennaio-2018-2/) erläutert die administrativen Ausgangsdaten. Die konkreten verwendeten bytes, der Datenstand und die Lizenz stammen aus den am Commit `9469f09` festgeschriebenen Quelldaten und Metadaten, nicht aus einer nachträglichen Umetikettierung auf den aktuellen ISTAT-Jahrgang.

| Unabhängiger Nenner | Fläche | SM-gbOpen-Originale decken | Vereinfachte SM-gbOpen-Castelli decken |
| --- | ---: | ---: | ---: |
| Geschlossene Enklave der unabhängigen IT-ISTAT-Flächen | 60,878 km² | 99,2234 % | 99,2212 % |

Der kleine Restunterschied bleibt sichtbar: Auch der unabhängige italienische Datensatz ist vereinfacht. Die Übereinstimmung wird gemessen und nicht auf 100 % gesetzt. Der abgeleitete GeoJSON-Grenzverlauf umfasst 3.887 Bytes, SHA-256 `66e979729eea5e183744d2d248501c4b0b999b60b27d3cf7e5696ee3708566bd`. Die Ausgangsdatei wird aus dem vorhandenen Cache wiederverwendet; es erfolgt kein weiterer großer Download.

## Åland: amtliche Schlüssel und unabhängiger Küsten-Nenner nachgewiesen

Der finnische WFS liefert zum Prüfzeitpunkt nur `kunta1000k` und `kunta4500k` samt Jahresständen, keine Variante `kunta100k` oder eine unvereinfachte Gemeindeebene. Der 1:1-Million-Datensatz enthält sämtliche 16 Åland-Gemeindeschlüssel. Die [amtliche Klassifikation Gemeinden 2026](https://stat.fi/en/luokitukset/kunta/kunta_1_20260101) und der [Korrespondenzschlüssel Gemeinden → NUTS](https://stat.fi/fi/luokitukset/corrmaps/kunta_1_20260101%23nuts_2_20260101) weisen diese Gemeinden unabhängig von jeder Geometrie der NUTS-3-Einheit `FI200` zu.

Der offizielle Reader verwendet jetzt genau diesen Schlüssel. `country_assignment_method="official_code"` und `original_source_country="FI"` dokumentieren die Zuordnung. Ganze Gemeinden mit den Schlüsseln `035, 043, 060, 062, 065, 076, 170, 295, 318, 417, 438, 478, 736, 766, 771, 941` erhalten `country="AX"`. Entfernte Inselteile gehen dadurch nicht durch einen Clip auf die ungenauen NE-Inseln verloren.

Die NE-10m-Landfläche von nur 936,780 km² ist für einen unabhängigen Vollständigkeitsnachweis der Åland-Inseln ungeeignet. Eine [2026er Informationsbroschüre der Åland-Standortagentur](https://www.alandliving.ax/sites/default/files/2026-06/24-0465-newcomers-guide_010626.pdf) nennt ungefähr 1.553 km² Land und mehr als 6.700 benannte Inseln; ältere Zahlen unterscheiden sich. Auch die 1.453,558 km² der kommunalen 1:1-Million-Quelle zeigen möglicherweise einen relevanten Generalisierungsverlust. Ein Quotient dieser beiden Flächen wäre noch keine geometrisch gemessene Abdeckung.

Der unabhängige detaillierte Nenner ist inzwischen tatsächlich bezogen und
gemessen. Er kombiniert zwei getrennte amtliche Produkte:

1. **Physische Meeresinseln:** [Ranta10 der finnischen Umweltbehörde SYKE](https://metatieto.ymparisto.fi/geonetwork/srv/api/records/%7BC40D8B4A-DC66-4822-AF27-7B382D89C8ED%7D),
   Maßstab 1:10.000, Layer `syke_rantaviiva:Ranta10_merisaari`. Die Geometrie
   beruht auf der topographischen Datenbank der Landesvermessung aus 2000–2008;
   die aktuell angegebene Paketpflege der Meeresinseln ist 2025. Ein Abrufdatum
   2026 wird nicht als neues Vermessungsjahr ausgegeben.
2. **Gesonderter regionaler Territorialrahmen:** das ursprüngliche
   `SuomenMaakuntajako_2025_10k`-Produkt der Landesvermessung, Region `NATCODE=21`,
   `Ahvenanmaa / Åland`, aus dem [CSC/Paituli-Verzeichnis des Originaljahrgangs](https://boileri.nic.funet.fi/pub/sci/geo/geodata/mml/hallintorajat_10k/2025/).
   Vier SHP-Komponenten umfassen 5.292.852 Bytes. Dieses eigenständige
   Maakunta-Feature wird aus seinem amtlichen Regionalschlüssel ausgewählt,
   **nicht aus der Vereinigung der 16 Zielgemeinden berechnet**. Der
   Meeresflächen einschließende Rahmen von 13.251,595 km² entscheidet lediglich,
   welche physischen Inselteile zu Åland gehören. Er ist niemals selbst der
   Landflächennenner.

Der WFS-Abruf ist auf das nach außen gerundete Rechteck des offiziellen
Regionalfeatures begrenzt. **36.879** tatsächliche Inselteile wurden in **19
geordneten Seiten** zu höchstens 2.000 Features geladen. Für jede Seite werden
`numberMatched`, `numberReturned`, tatsächliche Featurezahl und eindeutige
Quell-IDs kontrolliert. Die früher genannte Pilotzahl 37.058 bezog sich auf
ein etwas größeres gerundetes Testrechteck; der endgültige Datensatz verwendet
ausschließlich das engere abgeleitete Rechteck. Alle Originalseiten bleiben
mit Einzel-SHA-256 und Bytezahl im privaten Cache. Fehlende, gekürzte oder
widersprüchliche WFS-Seiten führen zum Fehler, ohne ersatzweise eine
Gemeindeunion einzusetzen.

Die Inselpolygone werden mit dem amtlichen Regionalrahmen geschnitten und
vereinigt. Dabei waren keine SYKE-Geometrien zu reparieren. Die Quellen
enthalten zusammen 81.155.148 Bytes; der abgeleitete detaillierte GeoJSON-Nenner
umfasst 88.881.304 Bytes. Die Form ist unabhängig von den zu prüfenden
StatFi-`kunta1000k`-Gemeinden.

| Kommunalquelle gegen denselben unabhängigen Küsten-Nenner | Einheiten | Bedeckte Fläche | Gemessener Anteil |
| --- | ---: | ---: | ---: |
| StatFi `kunta1000k_2026` | 16 | 1.411,7053 km² | **89,2905 %** |
| Native MML-Gemeindegrenzen 1:10.000, 2025 | 16 | 1.581,0047 km² | **99,9987 %** |
| Unabhängiger physischer Küsten-Nenner SYKE/MML-Region | — | **1.581,0251 km²** | 100 % Referenz |

Die Generalisierung der 1:1-Million-Quelle verursacht somit einen gemessenen
Detailverlust. Ein echter höher aufgelöster Kommunalstand kann ihn beheben.
Die MML-Gemeindepolygone enthalten dabei reguläres Meeres- und Binnengewässer-
Territorium: Gezählt wird ausschließlich die Schnittmenge mit dem unabhängigen
physischen Küsten-Nenner. **13.251 km² Meeresverwaltung werden nicht als Land
verkauft.** Für die Darstellung müssen diese Original-Verwaltungsgebiete an
der unabhängigen Küstenreferenz beschnitten werden, damit keine kommunalen
Meeresflächen als Inseln gezeichnet werden.

Der Küsten-Nenner kann Binnengewässer im Inselinneren einschließen. Er ist
deshalb eine kartographische Küstenfläche und keine Behauptung einer aktuellen
amtlichen reinen Landfläche ohne Seen. Das erklärt einen Teil des Unterschieds
zu den separat ausgewiesenen 1.555,59 km² Landfläche im MML-Kommunalprodukt;
abweichende Kartenjahre und die sphärische Projektion bleiben weitere Grenzen.
Der Nenner wird zur selben geometrischen Schnittprüfung beider Kandidaten
verwendet, nicht nachträglich auf deren Gesamtfläche skaliert.

Für beide Produkte gelten die Originalbedingungen
[SYKE CC BY 4.0](https://www.syke.fi/en/environmental-data/open-web-services)
und [National Land Survey of Finland CC BY 4.0](https://www.maanmittauslaitos.fi/en/opendata-licence-cc40).
Der Credit nennt **Finnish Environment Institute (Syke)** und **National Land
Survey of Finland / Maanmittauslaitos**, Produkt und Jahr. EPSG:3067 wird mit
`pyproj==3.7.2`, `always_xy=True`, nach Längengrad/Breitengrad transformiert;
`pyshp==2.3.1` liest die amtlichen SHP-Dateien. Der deklarierte dBASE-Sprachtreiber
`0x03` wird als Windows-1252 gelesen, wodurch `Åland` unverändert erhalten bleibt.

Der zusätzliche Kommunalprovider `mml-AX-kunta-2025-10k` in
`tools/atlas_official_sources.py` enthält exakt die 16 belegten Gemeindecodes,
`merge_priority=4` und `requires_physical_land_clip=true`. Es handelt sich um
eine höher priorisierte Alternative zu denselben 16 StatFi-Gemeinden. Beide
Quellversionen bleiben als Provenienz erhalten, dürfen aber im Gesamtatlas
**nicht als 32 unterschiedliche Gemeinden** gezählt werden. Der koordinierende
Merger löst dies über Landesrolle, amtlichen Gemeindecode und Priorität.

## Luxemburg: getrennte aktuelle nationale Grenze statt grober NE-Maske

Die [amtliche ACT-Publikation vom 5. November 2026](https://data.public.lu/en/datasets/limites-administratives-du-grand-duche-de-luxembourg/)
enthält sowohl aktuelle administrative Gemeinden als auch ein **separates
nationales Feature `LIMADM_PAYS`**. Nur dieses genau einmal vorhandene
Länderfeature wird als unabhängiger Nenner eingelesen. Weder die 100 aktuellen
Zielgemeinden noch die 102 älteren gbOpen-Gemeinden definieren den Nenner.
Die abgeschafften Distrikte und das getrennte Kondominium werden nicht als
zusätzliche heutige Landes-/Kommunalfläche importiert.

Die originale PRJ und das Portal deklarieren EPSG:2169. Nach Prüfung aller
Projektionsparameter wird mit LUREF→WGS84-Operation (4), ohne Ballpark-
Transformation, auf Längengrad/Breitengrad umgerechnet. Das Originalarchiv
enthält noch eine historische Datumsbezeichnung; dieser Befund und die
PROJ-Genauigkeitsangabe von 1 Meter bleiben im Manifest nachvollziehbar.

| Kommunalquelle | Unabhängige Referenz | Bedeckte Fläche | Anteil |
|---|---:|---:|---:|
| ACT, 100 aktuelle Gemeinden | 2.584,0457920 km² | 2.584,0457915 km² | **99,99999998 %** |
| gbOpen, 102 ältere Gemeinden | dieselbe ACT-Landesreferenz | 2.567,1090915 km² | **99,34456655 %** |

Der frühere Wert um 94,27 % gegen die NE-Maske war wesentlich eine Folge der
abweichenden Landesform. Der höher priorisierte ACT-Kommunalprovider ersetzt
den historischen gbOpen-Bestand und bewahrt aktuelle, exakt gegen zwei
amtliche Gemeinderegister abgeglichene Namen und Codes. Quelle und nationale
Referenz stehen unter CC0. Die gemeinsame amtliche Datengrundlage erklärt die
sehr hohe Übereinstimmung; die getrennte nationale Ebene verhindert einen
zirkulären Nenner aus der gerade importierten Gemeindeauswahl.

Einzelquittungen, LAU-/ACT-Codeprüfung, Jahrgänge und Wiederverwendung stehen
in [atlas-official-sources.md](atlas-official-sources.md). Die Quellen-ID der
Landreferenz ist `act-national-LU-20261105`.

## Reproduzierbare Landesreferenzen

`tools/atlas_land_references.py` stellt die kleine Schnittstelle bereit:

```python
sources = prepare_sources(cache: Path)
references = load_references(cache, sources)
# {"LI": Polygon, "SM": Polygon, "AX": MultiPolygon, "LU": Polygon,
#  "FO": MultiPolygon, "EE": MultiPolygon, "GG": MultiPolygon, "JE": MultiPolygon}
```

[atlas_land_references.json](../data/atlas_land_references.json) enthält IDs, Herkunfts- und Lizenzhinweise, Abruf- und Metadatenadressen, Quellstände, Dateigrößen und SHA-256-Werte. Für San Marino sind der unabhängige italienische Input, sämtliche verwendeten Feature-IDs, Auswahlrechteck und Seedpunkt ebenfalls festgeschrieben. Originalantworten und abgeleitete Geometrien liegen unter `.tools/atlas_sources/land-references/`; Rohdaten werden nicht ins Git übernommen.

Sechzehn gezielte Tests bestehen nach zuvor beobachteten roten Fällen: die
bisherigen LI-/SM-Fälle und die neuen AX-Prüfungen für unabhängige regionale
Identität, physische Inseln statt Meeresrahmen, Ablehnung von Zielgemeinden als
Nenner, vollständige WFS-Seiten ohne doppelte IDs, explizite Quellkodierung und
Integritätsprüfung sämtlicher AX-Abhängigkeiten. Ein zusätzlicher Fall belegt
die Wiederverwendung der geprüften Ableitung ohne erneute geometrische
Rekonstruktion; veränderte Eingabebytes werden trotzdem zurückgewiesen. Der
reale Quellenabruf und die tatsächliche Ableitung wurden zusätzlich ausgeführt.
Die drei zusätzlichen LU-Fälle sichern ein separates nationales Quellfeature,
vollständige amtliche LAU-Codes und den überprüften Umgang mit der historischen
PRJ-Datumsbezeichnung bei ausdrücklich deklariertem EPSG:2169.

Der vollständige Wiederholungslauf mit erneuter Geometrieableitung erzeugte
beide Quellenmanifeste bytegleich. Diese Referenzberechnung einschließlich
Lesen des detaillierten Ergebnisses und aller amtlichen Quellen dauerte
41,231 Sekunden. Ein versionierter Ableitungs-Cache bewahrt anschließend die
originalen Eingabereceipts und die Ergebnisquittung; Folgeläufe prüfen alle
Hashes und vermeiden die wiederholte Vereinigung von 36.879 Inselteilen.
Zwei anschließende hashgeprüfte Vorbereitungen benötigten zusammen 1,564
Sekunden und lieferten dasselbe Manifest. Stand dieses Nachweises:

- Landreferenzmanifest einschließlich der späteren LU-Ergänzung: 25.404 Bytes,
  SHA-256 `36f488f270d57904a6da40b3cf67f8d44de9b84a76dcb4c922dd9334f147aa1a`.
- Physischer AX-GeoJSON-Nenner: 88.881.304 Bytes, SHA-256
  `bdaa1fcbefa781ca5f1b15a967ae2620dbcda8a5f4a145932d584d7626b690d1`.
- Amtliches Quellenmanifest mit den beiden AX-Quellständen, den 100 aktuellen
  LU-Gemeinden und ihren zwölf aktuellen Kantonen: 81.852 Bytes, SHA-256
  `e2b45c0097b73c674e7ff684727ca3194b25d8f6fed88838c212907cec880332`.

```powershell
python -X utf8 -m unittest discover -s tools -p test_atlas_land_references.py
python -X utf8 tools/atlas_land_references.py
```

Für den erstmaligen Bezug des regionalen SHP-Produkts werden die isolierten
Werkzeugabhängigkeiten reproduzierbar eingerichtet:

```powershell
python -m pip install --only-binary=:all: --target .tools/atlas_land_deps pyproj==3.7.2 pyshp==2.3.1
```

Die Pipeline soll höher aufgelöste, unabhängig belegte Landesreferenzen für den Flächennenner und die Landesdarstellung übernehmen. Kommunale Originalflächen werden nur am eigentlichen Kartenausschnitt beschnitten. Ein pauschaler Clip auf generalisierte NE-Landesmasken würde nach diesem Befund korrekte lokale Flächen löschen und ist dafür ungeeignet.

## Färöer: unabhängige physische Inseln, 9. November 2026

Der bestehende GF-Satz enthält alle 29 Kommunen; der bereits gespeicherte
Namensabgleich gegen die aktuelle amtliche Kommunur-Tabelle ist vollständig.
Seine rohe kommunale Gesamtfläche beträgt 1.390,620235 km². Der bisherige
NE-Nenner misst nur 1.320,582746 km², überschneidet sich aber aufgrund seiner
generalisierten Küsten nur auf 967,177663 km² mit den Kommunalpolygonen.
Die daraus berechneten 73,2387 % beweisen daher keine fehlenden Gemeinden.

Das amtliche [Føroyakort-Diensteverzeichnis](https://www.foroyakort.fo/vevtaenastur)
führt im topografischen Lendiskort physische Inseln und Küstenlinien getrennt
von den Verwaltungsgrenzen. Der originale
[Oyggjar-Layer 15](https://gis.us.fo/arcgis/rest/services/lendiskort/us_lendiskort/MapServer/15)
enthält 34 Insel-/Holm-Features. Er ist der neue unabhängige Landnenner,
keine Union der Zielgemeinden und kein Meeresverwaltungsrahmen.

| Bestehende kommunale Quelle | Physisches Inselland | Bedeckte Landfläche | Anteil |
|---|---:|---:|---:|
| GF, 29 amtlich namensabgeglichene Kommunen | 1.387,673225 km² | 1.383,932835 km² | **99,730456 %** |

Die restlichen 3,740389 km² bleiben eine gemessene Küstendifferenz; es werden
keine Flächen ergänzt oder erfunden. Alle 34 Originalfeatures bleiben in der
Ableitung erhalten, kleine Inseln eingeschlossen. Die Originalantwort enthält
in einigen Namen U+FFFD-Ersatzzeichen; diese werden dokumentiert und nicht
erraten. Namen fließen nicht in die physische Flächenberechnung ein.

Die [amtlichen Nutzungsbedingungen](https://www.foroyakort.fo/um-foeroyakort/terms-and-conditions-in-english)
vom Juni 2019 gestatten weltweite Bearbeitung, kommerzielle Verwendung und
Weitergabe. Sie verlangen Agency-/Dataset-/Abrufangabe und einen verfügbaren
Link auf die Bedingungen, untersagen suggerierte Unterstützung und nautische
Navigation und regeln eine zusätzliche Agency-Nennung auf der Startseite,
falls dort auch andere Quellen genannt werden. Dies ist eine eigene amtliche
Lizenz, kein umbenanntes CC-Modell. Vollständige HTML-Bedingungen wurden mit
gewöhnlichem Browser-User-Agent öffentlich abgerufen und samt Hash gespeichert.

Quelle `us-physical-islands-FO-20261109`, Service-Abrufdatum 2026-11-09;
der Dienst weist keinen festen Release aus. Original-GeoJSON: 13.480.632 Bytes,
SHA-256 `564ce40bea22bab1f4264028a0190823d6deeb84432fdaaf2c8e5642bd0d1533`.
Metadaten, Count-Antwort, Originalfeatures und Lizenz-HTML liegen unverändert
unter `.tools/atlas_sources/audit/fo-physical-2026/`. Abgeleitete physische
Landfläche und alle Abhängigkeiten werden beim Laden hashgeprüft.

Die drei zusätzlichen Tests wurden zunächst rot und danach grün ausgeführt
(19 Landreferenztests insgesamt): vollständige eigenständige Inselgeometrie,
Ablehnung von Kommunal-/Meereslayern, fehlenden Geometrien und doppelten IDs
sowie Hashprüfung aller Ableitungsabhängigkeiten. Der reale Gesamt-Reader
lieferte anschließend alle fünf unabhängigen Referenzen ohne Fehler.

## Estland: amtliche physische Maske mit unabhängigem Landesrahmen

Die 78 aktuellen GF-Kommunen sind bereits vollständig gegen die amtlichen
Namen abgeglichen. Gegen die generalisierte NE-Landesform messen sie trotzdem
nur 93,5774 %. Das sind keine 6,4 % fehlenden Kommunen: Von 2.927,124667 km²
unbedeckter NE-Fläche liegen 1.834,948140 km² allein in den gesonderten
NE-Seepolygonen von Peipus, Pskov und Võrtsjärv. Generisch sämtliche vier
NE-Seepolygone mit Staatsüberlappung abzuziehen ergäbe 97,4982 %. Diese
vereinfachte Diagnose wird jedoch **nicht** als produktiver Nenner verwendet.

Das [amtliche Geoportal](https://geoportaal.maaruum.ee/est/Ruumiandmed/Haldus-ja-asustusjaotus-p119.html)
veröffentlicht eine separate physische „Eesti lõikemask“, laut eigener
Beschreibung anhand der ETAK-Küstenlinien erzeugt. Sie enthält Inseln und
Binnenwasserlöcher. Ihr Rohumriss umfasst auch benachbarte ausländische
Landteile und misst 57.770,876447 km²; deshalb ist sie allein kein estnischer
Landesnenner. Der separate amtliche **Maakonnad**-Datensatz liefert den
nationalen Rahmen mit allen 15 Kreisen, ihren vollständigen EHAK-Codes und
Originalnamen. Erst dessen Schnitt mit der physischen Maske wird verwendet.
Die zu prüfenden 78 kommunalen OSM-Polygone gehen in keinen dieser Schritte ein.

| Kommunalquelle | Unabhängiges physisches Land | Bedeckte Landfläche | Anteil |
|---|---:|---:|---:|
| GF, 78 aktuelle Gemeinden | 43.236,566393 km² | 43.223,848635 km² | **99,970586 %** |

Die verbleibenden 12,717758 km² werden als tatsächliche geometrische
Quellabweichung weiter ausgewiesen. Weder Land noch Gemeinden werden anhand
dieses Ergebnisses aufgefüllt. Der amtliche Kreisrahmen ist bereits mit der
physischen Maske vereinbar; der explizite physische Schnitt lässt seine Fläche
innerhalb der Rechengenauigkeit unverändert. Beide unabhängigen Originale
werden für die Reproduktion und Kontrolle erhalten.

Die Datumsrollen sind unterschiedlich: Kreisexport **2026-11-01**, originale
physische Maskeneigenschaft `eksport=19.11.2025`, Portalabruf 2026-11-09. Der
aktuelle Abruf wird nicht als neu erhobene Küste ausgegeben. Die originale
Kreis-PRJ deklariert EPSG:3301 in historischer ESRI-Schreibweise. Expliziter
Code, Ellipsoid und sämtliche Projektionsparameter werden geprüft; danach
erfolgt die EST97→WGS84-Operation mit 1 Meter deklarierter Genauigkeit, ohne
Ballpark-Transformation. Der originale DBF-Sprachmarker 0x03 wird als cp1252
gelesen, damit beispielsweise Lääne, Põlva und Jõgeva unverändert bleiben.

Die [amtlichen Nutzungsbedingungen der Maatoimingute-Plattform](https://kataster.ee/sites/default/files/documents/2024-03/MTP_andmeteenuste_kasutustingimused.pdf)
erlauben unter Abschnitt 2.5 die kommerzielle Verwendung und Veröffentlichung
unbeschränkter öffentlicher Daten; das Produktportal verlangt Agency- und
Datumsangabe. Portal-HTML und vollständiges Original-PDF werden ebenfalls
mit Hash bewahrt. Die Lizenz wird mit ihrem eigenen Namen geführt.

Quell-ID `maaruum-physical-land-EE-20261101`; originale Archive:

- [Maakonnad SHP](https://s3.pilw.io/rp-kemit-kataster/EHAK/maakond_shp.zip),
  8.233.358 Bytes, SHA-256
  `8c48fabe4e04006641cd82347b12f82561282aa0d10c79df251ed42a08926e46`.
- [Eesti lõikemask JSON](https://s3.pilw.io/rp-kemit-kataster/EHAK/eesti_mask_json.zip),
  10.809.563 Bytes, SHA-256
  `3da4e46c4521b03fa7501c694ae40d723bb2e53d899f8a7da6a85bacab53f9e1`.

Archiv-CRC, Member-SHA, Originalkreisfelder, beide Exportstände und Operation
stehen im Quellenmanifest; private Originale unter
`.tools/atlas_sources/audit/ee-physical-2026/`. Der Ableitungs-Cache prüft alle
Eingabehashes erneut und verhindert eine unnötige erneute Vereinigung großer
Geometrien. Die vier zusätzlichen Tests wurden rot→grün ausgeführt, insgesamt
23 Landreferenztests: unabhängiger vollständiger Kreisrahmen und physisches
Wasserloch, Ablehnung kommunaler/unvollständiger/doppelter Kreisrahmen,
Integrität aller Quelldateien sowie strenge Prüfung der historischen PRJ.

## Guernsey und Jersey: eigenständige physische Inselquelle

Die [Europäische Umweltagentur veröffentlicht einen eigenständigen physischen
Wasser-/Land-Polygonlayer](https://sdi.eea.europa.eu/catalogue/eea-statistical-data/api/records/9faa6ea1-372a-4826-a3c7-fb5b05e31c52):
„EEA coastline for analysis (polygon)“, Version 3, März 2017, Maßstab
1:100.000. Das amtliche Produkt ist unter CC BY 4.0 freigegeben und stammt
aus EUHYDRO-/GSHHG-Küstendaten. Sein Jahr bleibt 2017, unabhängig vom Abruf
am 9. November 2026. Dies ist eine physische Küstenquelle und keine Sammlung
der zu prüfenden Gemeinden.

Im Rechteck −2,8..−1,8 / 48,8..49,9 liefert die getrennte Identitätsabfrage
137 Polygone. Eines ist der europäische Kontinent mit über zehn Millionen
km². Der Geometrieabruf beschränkt sich ausdrücklich auf vollständige
physische Inselpolygone unter 500 km². Er liefert die erwarteten 136 IDs
vollständig, insgesamt 195.092 Bytes. Es werden keine Kontinentalfragmente
erzeugt. Die Mitgliedschaft dieser Inseln wird durch getrennte originale
OSM-Staats-/Bailiwick-Rahmen bestimmt, nicht durch Parishes:

- GG: Relation `270009@69`, ISO3166-1=GG, admin_level=2.
- JE: Relation `367988@53`, ISO3166-1=JE, admin_level=2.

Alle originalen Knoten-/Wege-/Relationsversionen liegen spätestens beim
gemeinsamen Geometriestand 2026-11-08T21:21:00Z. Die Rahmen enthalten
Meeresflächen und werden deshalb nur zur territorialen Zuordnung benutzt.
Jede ausgewählte EEA-Insel liegt **vollständig** im passenden Rahmen;
72 Originalfeatures für GG und 27 für JE. Die Funktion bricht ab, falls
ein Rahmen eine Insel schneiden würde, statt daraus passende Küstenstücke
herzustellen. Kein Gemeindepolygon liefert Landesfläche oder Staatszuordnung.

| Gebiet / tatsächliche lokale Einheiten | Physisches Referenzland | Bedecktes Land | Anteil |
|---|---:|---:|---:|
| GG: zehn Parishes sowie zwei belegte terminale Eigenregierungen | 76,512305 km² | 74,795203 km² | **97,755784 %** |
| JE: zwölf Parishes einschließlich des bereits vorhandenen Grouville-Supplements | 118,962171 km² | 118,087286 km² | **99,264568 %** |

Für GG belegen [das britische Justizministerium](https://www.gov.uk/government/publications/crown-dependencies-jersey-guernsey-and-the-isle-of-man),
[Sarks Regierung](https://sarkgov.co.uk/living-on-sark) und
[Alderneys offizielles Wahl-/Regierungsportal](https://www.alderneyelections.gg/how-government-works/structure/)
die getrennten Jurisdiktionen Guernsey, Sark und Alderney. Sark
`geofabrik:GG:4:1973199` und Alderney `geofabrik:GG:4:1973200` werden daher
nicht in Parishes umbenannt. Ihre tatsächliche Eigenregierung kann als
terminale lokale Rolle erfasst werden. Die Jurisdiktion Guernsey
`geofabrik:GG:4:1711291` wird neben ihren zehn Parishes nicht ein zweites Mal
als Blatt gezählt. Der Vergleich belegt ihre Flächenbeteiligung, nicht eine
neue angebliche Parish-Gliederung auf Sark oder Alderney.

Quellen-IDs `eea-physical-islands-GG-v3-2017` und
`eea-physical-islands-JE-v3-2017`. EEA-Geometrie und originale nationale
OSM-Referenzen sind mit ihren eigenen Lizenzschichten (CC BY 4.0 bzw.
ODbL 1.0), Quellenverweisen und Hashes dokumentiert. Vollständige amtliche
Lizenz-/Rollen-HTML und API-Originalantworten bleiben im privaten Cache
`.tools/atlas_sources/audit/channel-islands-physical-2026/`.

Vier neue Tests wurden rot→grün ausgeführt, insgesamt 27 Landreferenztests:
vollständige physische Inseln statt Ausschnitte, Ablehnung fehlender/doppelter
Geometrieidentitäten und kontinentaler Großpolygone, ursprüngliche ISO-/Level-/
Versionsprüfung mit zeitlich passenden Mitgliedern sowie Integrität sämtlicher
Eingabequellen. Der reale Reader liefert danach alle acht Länderreferenzen.
