# Iran: belegte Dehestan-Flächen und ausgeschlossene Altquelle

Der getrennte Reader `tools/atlas_iran_sources.py` übernimmt ausschließlich positiv als **دهستان (Dehestan)** bezeichnete örtliche Verwaltungsflächen. Er ersetzt keine allgemeine Städte- oder Gemeindevollzählung. Der Stand ist der **8. November 2026, 21:21 UTC**.

Die [offizielle Geofabrik-Iran-Seite](https://download.geofabrik.de/asia/iran.html) verlinkt den datierten Landesextrakt. Die [Geofabrik-Spezifikation](https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf) beschreibt die administrative Polygonklasse. Die [ursprüngliche OSM-Landestabelle](https://wiki.openstreetmap.org/wiki/Template:Admin_level) unterscheidet Städte und Dehestan von Dörfern und Stadtuntergliederungen. Der Reader verwendet weder eine pauschale Gleichsetzung aller ADM-Nummern noch einen Export gewöhnlicher Siedlungsumrisse.

Im tatsächlichen Adminareas-Datensatz stehen 3.409 Level-7-Records: 2.731 mit explizitem Dehestan-Präfix, 332 mit Shahr-Präfix, ein Shahrak-Record und 345 weitere Namen ohne eindeutigen positiven Typ. Ausschließlich die 2.731 Dehestan sind Kandidaten. Alle anderen Level-7-Flächen sowie die Levels 8–11 bleiben außerhalb dieses Imports. Dass ein OSM-Objekt eine hohe Adminnummer besitzt, belegt allein noch keine sachgerechte Verwaltungsrolle; in den höheren Rohklassen erscheinen beispielsweise auch Parks und Kliniken.

Die Landeszuordnung erfolgt anhand der unveränderten Geometrien von 30 Quellprovinzen. Eine begrenzte ursprüngliche OSM-Metadatenantwort bestätigt für jede Provinz dieselbe Kennung, denselben Namen, `boundary=administrative`, Level 4, einen iranischen ISO-Code und einen Elementstand vor dem Snapshot. Ihre Union dient ausschließlich als territoriale Zulassungsreferenz. Sie erzeugt keine neuen Länderobjekte und ersetzt keinen unabhängigen physischen Landflächennenner.

**2.679 Dehestan** liegen zu mindestens 99,9 % innerhalb dieser positiv belegten Provinzunion und sind zugelassen. **52 weitere typisierte Kandidaten** bleiben mit ihren Originalkennungen und Namen im Audit, weil die territoriale Referenz für ihre Aufnahme nicht ausreicht. Unter anderem fehlt Bushehr als Level-4-Polygon im Rohdatensatz. Es wird weder eine Ersatzprovinz aus Restflächen konstruiert noch dem Archivnamen eine Landeszuordnung entnommen. Die Originalpolygone werden weder repariert noch zugeschnitten. Der Atlas kann sie später an seiner getrennten Landreferenz beschneiden.

Die nachträgliche unabhängige räumliche Prüfung hat für alle 52 ausgeschlossenen Originale **keinen Schnitt mit dem Atlas-Kartenausschnitt `(-12, 33, 52, 72)`** festgestellt. Ihre gesamte Nord-Süd-Ausdehnung reicht von 26,9885614° bis höchstens 30,2949624° N. Die unabhängig gelesene Bushehr-Provinzreferenz endet ebenfalls südlich von 33° N. Diese nationale Quellenpartialität ist deshalb kein nachgewiesener Rollen- oder Scopefehler der tatsächlich dargestellten Dehestan. Der Beleg `audit/IR-qualification-20261110/IR-excluded-bbox-audit.json` hält alle 52 ursprünglichen Kennungen, Namen und Bounds einzeln fest; sein SHA-256 lautet `7317d608a43c8f01ce4f3334f5171b4adf519650e088f017249274a10356cdf1`.

Im geprüften zusammengeführten Atlasstand belegen die qualifizierten örtlichen Flächen **97,597428 %** der unveränderten Referenzlandfläche im Kartenausschnitt. Die verbleibenden **2,402572 % beziehungsweise 8.538,031862 km²** sind noch nicht räumlich in Städte, Referenzdifferenzen und tatsächliche Quelllücken aufgeteilt und werden nicht aus Restflächen ergänzt. Die bbox-spezifische Quellenqualifizierung ist an den exakten Hash der 2.679 bereits geprüften Originale gebunden. Sie entfernt nur deren frühere generelle Quellensperre; sie belegt keine heutige nationale Behördenvollzählung. Die alte gemischte gbOpen-Quelle bleibt vollständig quarantänisiert. Deutsche `coverage_note` und `territorial_scope_note` machen diese Grenzen auch in der Ortssuche sichtbar.

Die Daten bleiben `local_admin`, mit dem tatsächlichen Typ `Dehestan / دهستان`. Sie werden nicht pauschal als selbstverwaltete Gemeinden bezeichnet. Die Quelle liefert hier keinen vollständigen aktuellen Nachweis einzelner Rechtskörperschaften. Die örtlichen Flächen haben stabile ursprüngliche OSM-Kennungen; als importierter Elternknoten dient zunächst `country:IR`. Die bestätigten Provinzidentitäten bleiben separat im Herkunftsaudit, ohne doppelte Provinzobjekte einzufügen.

Die gebündelte Quelle steht unter [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/), mit der Attribution **© OpenStreetMap contributors; Geofabrik GmbH**. Das vollständige ZIP ist 447.069.064 Byte groß. Die tatsächlich übertragenen selektiven HTTP-Ranges für Adminareas und README umfassen nur **15.120.470 Byte**, bei einem vorab begrenzten Budget von 30.000.000 Byte. Starker ETag, `If-Match`, Status 206, `Content-Range`, ZIP-CRC und SHA-256 sind im Rohcache erhalten.

## Reproduzierbare Rohvorbereitung und lokaler Aufbau

Ein frischer Checkout kann die exakt gepinnten öffentlichen Rohdaten getrennt vorbereiten. Der neue Stager benötigt nur Python-Standardbibliothek, den vorhandenen Geofabrik-Range-Reader und `curl.exe` mit normaler TLS-Prüfung:

```powershell
python tools/atlas_iran_stage.py
python tools/atlas_iran_stage.py --check-only
```

`tools/fixtures/iran-stage-20261108.json` hält URL, Archivgröße, starken ETag, die fünf SHP-Komponenten, README, ursprüngliche CRC/SHA-Werte und die 30 überprüften Provinzversionen fest. Der Stager prüft den Archiv-Pin vor dem ersten ZIP-Payload. Er liest ausschließlich die Verwaltungsmitglieder und README, in HTTP-Ranges von höchstens 1 MiB. Das vollständige 447-MB-Archiv wird nicht heruntergeladen. Andere datierte Archive oder ein „latest“-Stand sind keine stillschweigenden Alternativen.

Für Provinzmetadaten verwendet der Stager ausdrücklich die festgelegten Versionspaare `idvversion` der [ursprünglichen OSM-API](https://wiki.openstreetmap.org/wiki/API_v0.6). Er prüft die exakten Namen, iranischen ISO-Kennungen, Versionen, Zeitpunkte, sämtliche Tags und die geordnete ursprüngliche Memberliste über semantische SHA-256-Fingerprints. Der wechselnde API-Backendname im Antwortumschlag ist kein stabiler Dateninhalt; die unveränderte tatsächliche Antwort erhält deshalb zusätzlich ihren eigenen SHA und Receipt. Ein Versionsabruf darf nicht durch aktuelle Metadaten ersetzt werden.

Das Gesamtbudget beträgt 30.000.000 Byte einschließlich Metadaten. Neue Antworten werden vorab im dauerhaften Budgetledger reserviert; fehlgeschlagene oder unterbrochene Versuche behalten vorsorglich die vollständige Reservierung. Diese konservativ belasteten Bytes werden getrennt von tatsächlich gespeicherten Antwortbytes ausgewiesen. Ein Wiederholungsversuch setzt das Budget nicht zurück. Zwischengespeicherte Ranges werden auch auf ihre gesonderten URL-, ETag-, Start-, Ende- und Bytefelder geprüft, nicht nur auf den Bodyhash. Veränderte Daten werden abgewiesen. Vorhandene vollständige Originalcaches und ihre Receipts bleiben beim Replay schreibfrei erhalten; `--check-only` erzeugt keine fehlenden Pfade und startet keinen Transfer.

Ein abgeschlossener öffentlicher Clean-Replay hat **15.375.261 Byte** übertragen: 15.120.470 ZIP-Rangebytes und 254.791 Byte versionierte Provinzmetadaten. Alle ursprünglichen Member-CRCs/SHA-Werte und alle 30 semantischen Metadaten-Fingerprints stimmen mit der Rezeptur überein. Der anschließende `--check-only`-Replay übertrug 0 Byte und ließ sämtliche Dateizeitstempel unverändert. 15 kleine Stager-Regressionstests prüfen unter anderem falsche Pins, veränderte Members, Budgets über Fehlversuche/Wiederaufnahme hinweg, fehlende Receipts nach Prozessabbruch und den Rezeptur-Pin nach normalen LF-/CRLF-Konvertierungen durch Git. Zusammen mit den Provider- und Altquellen-Qualifierprüfungen bestehen 31 gezielte Tests. Diese Ergebnisse sind Quellenprüfungen, keine zusätzliche Spielabnahme.

Bleibt nach einem Prozessabbruch ein vollständig gepinnter Body ohne seinen Receipt zurück, darf nur ein ausdrücklich als abgeleitet bezeichneter Integritätsnachweis ergänzt werden. Bei Metadaten wird die feste Versions-URL dann als Reproduktionsadresse gekennzeichnet; ein ursprünglicher Transportreceipt oder eine frühere HTTP-Antwort wird nicht erfunden. Die Reparatur gilt ausschließlich für unvollständige neue Stages. Ein fertiger Cache oder `--check-only` bleibt strikt schreibfrei.

Der Stager führt keine Geometrieauswertung, Normalisierung oder Manifeständerung aus. Nach erfolgreicher Rohvorbereitung folgt der vorhandene Provider ausdrücklich als separater Schritt; dafür müssen die bereits im Projekt verwendeten Geometrieabhängigkeiten vorhanden sein:

```powershell
python tools/atlas_iran_sources.py
python -m unittest discover -s tools -p test_atlas_iran_sources.py
python -m unittest discover -s tools -p test_atlas_iran_qualification.py
```

`prepare_sources(cache)` liest oder erzeugt den gesonderten unveränderlichen Cache; `iter_boundaries(cache, sources)` prüft Hash, Bytezahl, Typ, Kennungen und Anzahl erneut. Ein erneuter Aufruf mit vorhandenem normalisiertem Cache benötigt keinen Netzwerkzugriff. Ein fehlender oder veränderter öffentlicher Archivstand führt zu einem ausdrücklichen Fehler; die beschädigte alte Quelle wird nicht als Ersatz geladen. `--cache` ist bei beiden CLIs derselbe optionale Wurzelpfad. Bei einer neuen Normalisierung schreibt der Provider sein Quellenmanifest, weshalb dieser zweite Schritt im gemeinsamen Checkout mit dem zentralen Datenbuild koordiniert werden muss.

Die ursprünglichen Rohmitglieder und die datierten Provinzmetadaten liegen unter `.tools/atlas_sources/audit/IR-qualification-20261110/geofabrik/`. Die verifizierte Ausgabe liegt unter `.tools/atlas_sources/iran-dehestan-261108/v1/`. Alle Pfade sind relativ zum Quellcache in `data/atlas_iran_sources.json` verzeichnet.

| Artefakt | Bytes | SHA-256 |
|---|---:|---|
| `boundaries.jsonl.gz`, 2.679 Records | 4.480.172 | `d49610c674f9f9e46fb083988bbfd790359ef591fa45120c173f4d221b2226c8` |
| Herkunfts- und Scope-Audit | im Manifest | `0bdf8761cf151da8618c6f184ac21aa662af74a03233634730afddcabca058b4` |

## Warum die frühere gbOpen-Quelle quarantänisiert bleibt

Die archivierte Quelle [`gbOpen-IRN-ADM4` am Commit 9469f09](https://github.com/wmgeolab/geoBoundaries/tree/9469f09/releaseData/gbOpen/IRN/ADM4) enthält 2.772 Releasefeatures. Das [zugehörige ursprüngliche Producer-ZIP](https://github.com/wmgeolab/geoBoundaries/blob/9469f09/sourceData/gbOpen/IRN_ADM4.zip) enthält tatsächlich 2.815 gültige Shapefile-Records. Die Metadatenzahl ist damit als Inputanzahl belegt. Im Rohsatz finden sich sechs exakt geometrisch doppelte Paare und mehrere überlagerte Stadtflächen. Die geometrischen Gesamtunions von Input und Release besitzen eine IoU von **0,9999999997984395**. Die numerische Differenz ist daher kein Beleg für 43 fehlende Landesgebietsflächen oder 43 fehlende Gemeinden. Eine vollständige Erklärung aller internen Exportentscheidungen wird daraus nicht abgeleitet.

Der Roh-DBF bewahrt jedoch ausschließlich `Level` und `Name`. Ursprüngliche OSM-Kennungen, Boundary-Tags und unterschiedliche native Einzelrollen fehlen. Die Quelle enthält sowohl ausdrückliche Stadtnamen als auch den pauschalen Katalogtyp „Dehestan“. **2.514 Release-Namen enthalten bereits in den Originalbytes literal `?`; 2.513 bestehen nur aus Fragezeichen und Leerzeichen.** Das ist kein durch einen anderen UTF-8-Decoder wiederherstellbarer Zeichensatzfehler. Der separate Namensqualifier erhält den Originalnamen und markiert solche Beschriftungen mit `name_known=false`, ohne einen Ortsnamen zu erfinden.

Nur diese konkrete alte IR-Quelle bleibt deshalb mit unveränderten Geometrien, IDs, Lizenz und ursprünglichen Metadaten im Archiv, ist aber für administrative Darstellung und kommunale Zählung gesperrt. Auch eine pauschale Umetikettierung zu `local_admin` wird für ihre unbekannten Einzelrollen nicht vorgenommen. Die ursprüngliche Lizenzbezeichnung der alten Quelle wird nicht durch die Lizenz des neuen Geofabrik-Datensatzes überschrieben.

Der neue Reader und die gezielten Quelltests wurden lokal geprüft. Der hier angegebene Flächenprüfwert stammt aus dem zentralen zusammengeführten Atlasbuild. Darstellung, Eingaben, Leistung sowie Android-/Windows-Ausgaben werden gesondert zentral geprüft; der Rohstager führt solche Prüfungen nicht aus.
