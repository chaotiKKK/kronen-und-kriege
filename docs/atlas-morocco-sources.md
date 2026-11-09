# Marokko: belegte kommunale Verwaltungsgrenzen

Stand der Prüfung: 9. November 2026. Dieser zusätzliche Provider liefert reale
Stadt- und Landgemeinden. Er verändert weder Spielprovinzen noch die Simulation.

## Quelle, Verwaltungsrolle und Kennungen

Die ursprüngliche Datensammlung
[morocco-communes](https://github.com/zkousama/morocco-communes) verbindet den
Gemeindekatalog des Haut-Commissariat au Plan (HCP, RGPH 2024) mit
OpenStreetMap-Verwaltungsrelationen. Der Import ist auf Commit
`4ec363333fea43e712820e20f59532bac5df0b07`, Datensatzversion `1.10.0`, festgelegt.
Die [festgeschriebene Herkunftsdatei](https://github.com/zkousama/morocco-communes/blob/4ec363333fea43e712820e20f59532bac5df0b07/data/v1/sources.json)
enthält die ursprünglichen HCP-Datei-URLs, deren SHA-256-Werte und den
OSM-Abfragezeitraum vom 17. bis 19. September 2026.

Der Datenproduzent bezeichnet die Geometrien ausdrücklich als
`OpenStreetMap admin_level=8 relations, matched to HCP communes on ref:MA:HCP`.
Für jede Geometrie verlangt der Reader einen eindeutigen Join ihres
neunstelligen `code` auf `codeDigits` des HCP-Katalogs. Nur die Katalogtypen
`urban` und `rural` sind zugelassen; Arrondissements, Douars, Kreise und
Provinzen werden nicht zu Gemeinden erklärt. Die Original-Hierarchie bleibt
in `native_parent_codes` erhalten. Die Einheiten heißen im Datensatz
`Commune urbaine` beziehungsweise `Commune rurale`.

IDs bestehen aus `hcp:MA:commune:` und dem unveränderten offiziellen Code mit
Punkten. Die neunstellige Join-Kennung bleibt zusätzlich einschließlich
führender Nullen erhalten. Beispiel Tanger: `01.511.01.0`, `001511010`,
OSM-Relation `2758781`. Französische und arabische Originalnamen werden
bewahrt. Ein numerischer Level `8` beschreibt hier den tatsächlichen
OSM-Quelllevel, keine weltweite Gleichsetzung administrativer Hierarchien.

## Gemessene Datenmenge und bekannte Lücken

| Messung | Ergebnis |
|---|---:|
| HCP-Katalogeinträge | 1.503 |
| Tatsächliche kommunale Grenzgeometrien | 1.502 |
| Stadtgemeinden mit Geometrie | 242 |
| Landgemeinden mit Geometrie | 1.260 |
| Geometrien mit Schnitt zum Atlas-Ausschnitt `−12/33/52/72` | 682 |
| Fehlende Namen unter den importierten Grenzen | 0 |
| Durch `make_valid` reparierte Geometrien | 5 |
| Unveränderte Eingabedateien insgesamt | 3.727.248 Bytes |
| Davon zwölf TopoJSON-Grenzdateien | 1.967.082 Bytes |

Die einzige Gemeinde des Katalogs ohne Grenzgeometrie ist
**Sidi Mohamed Benmansour**, Code `04.281.05.11` / `042810511`, Region
Rabat-Salé-Kénitra (`04`), Provinz Kénitra (`04.281`), Cercle `04.281.05`.
Der Produzent liefert dafür weder Grenzpolygon noch Schwerpunkt, Boundingbox
oder OSM-Relation. Diese fehlenden Werte bleiben `null`. Aus einer Gemeinde
ohne Geometrie wird kein Ersatzpolygon erzeugt.

Der Produzent dokumentiert außerdem eine etwa 88 km² große unzugeordnete
Grenzlücke zwischen Ifrane und Boulemane. Auch diese wird nicht gefüllt.
Das Manifest bewahrt `known_missing_boundaries` und
`blocks_full_coverage_claim=true`. Die Zahl der importierten Gemeinden wird
nicht auf die Katalogzahl hochgesetzt.

Eine unabhängige Messung gegen die vorhandene Natural-Earth-10m-Landmaske,
jeweils innerhalb des Atlas-Ausschnitts, ergab:

| Flächenmessung | Ergebnis |
|---|---:|
| Referenzlandfläche im Ausschnitt | 126.291,1051 km² |
| Davon von tatsächlichen Gemeindepolygonen bedeckt | 125.628,1195 km² |
| Gemessene Bedeckung dieser Referenz | **99,4750 %** |

Das ist eine Messung gegenüber einer unabhängigen generalisierten Karte,
kein Nachweis lückenloser amtlicher Grenzgenauigkeit. Der Gesamtkatalog umfasst
auch Gebiete südlich des Ausschnitts und folgt dort der HCP-Klassifikation
einschließlich Westsahara. Diese südlichen Gebiete liegen außerhalb der
Atlas-Untergrenze von 33° Nord. Weder 1.502 noch 1.503 sind deshalb eine Zahl
der im Atlas sichtbaren Gemeinden.

## Zwei getrennte Lizenzschichten

Die [Geometrie-Lizenz des Originalproduzenten](https://github.com/zkousama/morocco-communes/blob/4ec363333fea43e712820e20f59532bac5df0b07/data/v1/geometry/LICENSE)
ist **ODbL 1.0**. Die Geometrie bleibt OSM-Datenbankinhalt mit der zugehörigen
Attribution und den Weitergabebedingungen der
[Open Database Licence](https://opendatacommons.org/licenses/odbl/1-0/).

Die HCP-Namen und geographischen Kennungen stehen nach den
[Nutzungsbedingungen des HCP](https://www.hcp.ma/Conditions-generales-d-utilisation-Version-1-0_a2194.html)
unter **CC BY 4.0**. Die Bedingungen erlauben auch kommerzielle Weiterverwendung
mit Quellenangabe, Hinweis auf Änderungen und ohne vorgetäuschte Unterstützung
durch das HCP. Diese Lizenz ersetzt die ODbL der OSM-Geometrie nicht.

Das Quellmanifest enthält beide Lizenzschichten, ihre Beleg-URLs und den Credit:

> © OpenStreetMap contributors, ODbL 1.0; Haut-Commissariat au Plan,
> RGPH 2024, CC BY 4.0; assembled by Ousama Ajebbar (morocco-communes).
> Boundaries decoded, projected and clipped for the atlas; no endorsement
> by HCP implied.

## Reader und reproduzierbare Prüfung

`tools/atlas_morocco_sources.py` stellt dieselbe Provider-Schnittstelle wie
die anderen kommunalen Reader bereit:

```python
prepare_sources(cache: Path) -> list[dict]
iter_boundaries(cache: Path, sources: list[dict]) -> Iterator[dict]
```

Die unveränderten Originaldateien und ihre Einzelquittungen liegen ausschließlich
unter `.tools/atlas_sources/morocco/`. Das veröffentlichbare Manifest ist
`data/atlas_morocco_sources.json`. Der Gesamt-SHA-256 beschreibt ausdrücklich
die kanonische geordnete Liste der Eingabequittungen. Jede Originaldatei besitzt
zusätzlich ihren eigenen SHA-256 und ihre genaue Bytezahl. Der Reader prüft
diese Werte vor dem Import erneut. Der Cache lädt atomar und nutzt die
Windows-Zertifikatsprüfung ohne TLS-Ausnahme.

Der TopoJSON-Decoder folgt der
[Originalspezifikation](https://github.com/topojson/topojson-specification):
Delta-Koordinaten mit Scale/Translate, negative Arc-Indizes, gemeinsame
Grenzsegmente, Innenringe und getrennte Inselpolygone bleiben erhalten.
Geometrien und Attribute werden nach Quellregion verarbeitet; die Rohdateien
werden nicht in Git aufgenommen.

```powershell
python -X utf8 -m unittest discover -s tools -p test_atlas_morocco_sources.py
python -X utf8 tools/atlas_morocco_sources.py
```

Acht gezielte Python-Prüfungen sind grün: Koordinatentransformation und
Umkehrung, amtliche ID/Unicode-Namen, falsche Rollen und fehlgeschlagene Joins,
fehlende Grenzen ohne Erfindung, Innenringe, Inseln, eindeutige Fehler bei
ungültigen Arc-Verweisen sowie Abweisung veränderter Rohdateien. Der echte
Providerlauf liest alle 1.502 Einheiten; ein zweiter Lauf erzeugt das Manifest
bytegleich. Manifest-SHA-256:
`9e4564c29b822e58fe3a727e80efccc491bd2e91fdc590307dcdcf4d1ccf7a97`.

Diese Prüfungen belegen den Datenimport. Die Einbindung in den Gesamtatlas und
die Godot-Laufzeit prüft der koordinierende Hauptprozess gesondert.
