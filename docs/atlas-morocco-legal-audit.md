# Marokko: fehlende Gemeinde konkret untersucht, Rekonstruktion gesperrt

Prüfstand: 10. November 2026. Die bestehende produktive MA-Quelle und ihre offene Quellenprüfung bleiben unverändert.

Die fehlende Kommune **Sidi Mohamed Benmansour, HCP-Code 042810511**, ist im amtlichen RGPH2024-Katalog eindeutig von **Ben Mansour, 042810503**, getrennt. Ein gleichnamiger OSM-Ortspunkt ist kein Grenzpolygon und belegt keine Flächengleichheit. Die vorhandene Ben-Mansour-Geometrie darf deshalb nicht als zusätzliches Sidi-Polygon dupliziert werden.

Ein neuer Primärbeleg liegt als gesicherte Kopie des tatsächlichen **Bulletin Officiel 6964 vom 25. Februar 2021** vor: Entscheidungen 1635.20 und 1636.20 vom 23. Juni 2020, Druckseiten 1450–1453. Der Originaldruck wurde über den öffentlich verlinkten Download auf [der Rechtsbibliotheksseite](https://www.elkanounia.com/2021/03/B.O.6964.html) gelesen. Die versuchten amtlichen SGG-Pfade antworteten nicht und sind nicht als verifizierte Downloadadressen ausgegeben. Eine amtlich bestätigte Byteidentität wird nicht behauptet.

Beide Tabellen wurden visuell gegengelesen. Die 44 Punkte und sämtliche 88 sechsstelligen Koordinatenwerte stimmen zusätzlich mit dem tatsächlichen PDF-Text überein. Die [ANCFCC](https://www.ancfcc.gov.ma/ReseauGeodesiquePlanimetrique) belegt das nationale Merchich-/Lambert-System. EPSG 26191 für diese konkreten Tabellen bleibt eine begründete Inferenz: unabhängige RP4201- und Fekroun-Anschlüsse passen auf wenige Meter; die festgehaltene Transformation hat eine angegebene Genauigkeit von 7 m.

Der gesonderte Helper rekonstruiert die gedruckten Polygonzüge einschließlich der ausdrücklich verlangten Fluss-, Straßen- und Küstenverläufe aus zehn ursprünglichen OSM-Wegen mit 603 Knoten. Es gibt keine künstliche Restfläche, stillschweigend gerade Flussverbindung oder verschobene Originalknoten. Die veröffentlichbare faktische Quelldatei enthält Koordinaten, IDs, feste Versionen und Zeitstempel, jedoch keine OSM-Nutzernamen, UIDs oder Changesets. Original-PDF und -XML bleiben im privaten Auditcache.

Die vollständige Rekonstruktion zeigt konkrete Hindernisse:

| Prüfung | Ergebnis |
|---|---|
| Gemeinsamer Straßenabschnitt | Nur Sidi schreibt die RP4201-Achse ausdrücklich vor; Bens Text führt dieselben Endpunkte ohne diese Ausnahme. Maximaler geometrischer Unterschied 174,655 m, lokale Unterschiedsfläche 195.738,178 m². |
| Ben-Mansour-Küstenanschluss | Unveränderter Kandidat hat eine Selbstüberschneidung bei Lambert 406541,696529 / 450442,403999. |
| Sidi-Küstenanschluss | Unveränderter Kandidat hat eine Selbstüberschneidung bei Lambert 397703,539200 / 432986,111747. |
| Gedruckte Punkte gegenüber heutiger physischer Achse | Sebou etwa 63–109 m, Atlantikküste etwa 16–39 m Anschlussabweichung. |

Die Kandidaten werden **nicht in die Spielgeometrie übernommen**. `iter_eligible_boundaries()` liefert absichtlich null Grenzen. Der Audit behauptet keine sichere globale Überlappungsfreiheit aus ungültigen Polygonen. Für eine belastbare Zulassung wird die maßgebliche kartografische Anlage beziehungsweise eine autoritative Auflösung des gemeinsamen Straßenverlaufs und der Küstenanschlüsse benötigt.

Reproduktion ohne Netzwerk aus der öffentlichen faktischen Quelldatei:

```powershell
python tools/atlas_morocco_legal_boundaries.py
python -m unittest discover -s tools -p test_atlas_morocco_legal_boundaries.py
```

Elf Prüfungen bestanden nach beobachtetem Rot→Grün. Daten- und Lizenzkette stehen vollständig in `data/atlas_morocco_legal_source.json`; der Helper validiert deren kanonischen Hash vor jeder Ableitung. Diese Arbeitsstufe verbessert den nachprüfbaren Quellenstand, schließt die produktive MA-Lücke aber ausdrücklich noch nicht.
