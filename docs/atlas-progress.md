# Banger Queens 1.6.0 – Atlas und Prüfstand

Prüfzeit: 2026-11-10T00:18:40.682400+01:00. Projekt: `C:\Crusader Kings III\mobile-godot`. Geprüfter Kandidat für die Testveröffentlichung 1.6.0.

Der Nutzer verlangt echte vergleichbar detaillierte Verwaltungsebenen über den gesamten vorhandenen Kartenausschnitt. Der Atlas verwendet reale Quellen, einheitliche Bildschirmregeln und eine explizite landesweise Abdeckungsprüfung. Die 49 Simulationsgebiete tragen weiterhin Wirtschaft, Eigentum, Krieg und Speicherstände. Zusätzliche Referenzflächen erzeugen keine zusätzlichen Ressourcen.

## Eingebetteter Bestand

| Darstellungsobjekt | Anzahl |
|---|---:|
| country | 70 |
| district | 4520 |
| local_admin | 17531 |
| municipality | 116652 |
| region | 986 |
| GeoNames-Orte | 23463 |
| Flussgruppen | 175 |

Der Kartenraum reicht von −12 bis 52° Länge und 33 bis 72° Breite. Die Datenstände unterscheiden sich und werden je Quelle genannt. Die Objektzahl ist keine weltweite Behördenvollzählung: Territorialteile können dieselbe ursprüngliche Gemeinde in mehreren Referenzgebieten darstellen. Quellenkennung und originale Einheit bleiben nachvollziehbar.

## Vergleichbare Ebenen und korrigierte Quellen

Deutschland besitzt 16 Länder, 400 Kreise, 10.751 Gemeinden und 198 gemeindefreie Gebiete. Frankreich erhält 13 obere regionale Einheiten einschließlich Corse, Italien 20 Regioni, Spanien 18 im Kartenausschnitt liegende Autonomien/Städte und das Vereinigte Königreich vier Constituent Countries. Die spanischen Provinzidentitäten bleiben als eigene Kreisrolle erhalten; die falsche pauschale NE-Typangabe wird überstimmt. Vorhandene Départements, Provinzen und Gemeinden werden durch den regionalen Rahmen nicht entfernt.

Norwegen enthält 357 amtlich namensabgeglichene Gemeinden einschließlich der gezielt nachgelieferten Røros-Grenze. Tschechien enthält 6.253 Gemeindeobjekte und Prahas zusätzliche Gemeinderolle, zusammen 6.254 zivile Behörden; vier Militärbezirke bleiben gesondert. Luxemburg verwendet 100 amtliche Gemeinden und zwölf Kantone. Armenien verwendet 61 Gemeindeobjekte und Jerewans belegte Gemeinderolle, zusammen 62 rechtlich abgeglichene Identitäten; zwölf Hauptstadtbezirke bleiben getrennt. Zwei Fusionen vom September 2026 werden ausschließlich aus ihren Originalflächen vereinigt. Der ungeeignete alte AM39-Notfallregionssatz ist dokumentiert ausgeschlossen.

Die Türkei erhält genau 30 belegte flächengleiche Metropolrollen auf vorhandenen Provinzgeometrien. Elf aufgehobene frühere Belde bleiben mit Originalgeometrie und Rechtsbeleg im Quellenbestand, tragen aber nicht als heutige Gemeinden zur Darstellung oder Abdeckung bei. Die 974 Kreisrollen werden nicht pauschal zu Gemeinden erklärt. Tunesiens echte boundary=municipality-Ebene liefert 335 im Ausschnitt liegende Quellobjekte; Imada und Nahiya bleiben anders bezeichnete lokale Verwaltung.

136 einzeln belegte OSM-/Geofabrik-Doppelrepräsentationen werden zugunsten des versionierten Originalrecords zusammengeführt. Identität, Quelle, native Ebene, Versionskohärenz und tatsächliche Geometrie werden erneut geprüft. Provenienz und belegte Elternzuordnung bleiben erhalten; die Abdeckungsrechnung verwendet nur die gewählte Geometrie.

Unabhängige physische Referenzen korrigieren die Landnenner von LI, SM, AX, LU, FO, EE, GG und JE. Zielgemeinden bilden keinen dieser Nenner. Sark und Alderney behalten ihre echten Jurisdiction-Regionen mit belegter lokaler Eigenregierung; zusätzliche Gemeinden werden nicht erfunden. Historische zyprische Gemeinde-Referenzteile bleiben auch innerhalb CNM erhalten, ohne eine UN-Kommunalverwaltung zu behaupten. [Küstenaudit](atlas-small-country-audit.md), [Quellen und Verarbeitung](atlas-sources.md).

## Abdeckung und offene Arbeit

Statuszählung: {'complete': 52, 'source_review': 10, 'gap': 5, 'single_jurisdiction': 3}. `complete` bedeutet mindestens 95 % geometrische Abdeckung ohne verbleibende Quellensperre; es ist kein allgemeiner amtlicher Vollzählungs- oder Aktualitätsnachweis. **Die geforderte durchgehend vergleichbare Gesamtabdeckung ist noch nicht vollständig erreicht.**

| Gebiet | Abdeckung | Status |
|---|---:|---|
| AM | 93.16 % | source_review |
| AZ | 3.45 % | gap |
| CNM | 99.87 % | source_review |
| CY | 99.02 % | source_review |
| CYN | 98.05 % | source_review |
| ESB | 95.87 % | source_review |
| IL | 92.75 % | gap |
| IR | 98.74 % | source_review |
| JO | 0.00 % | gap |
| KZ | 77.57 % | source_review |
| LB | 61.67 % | gap |
| LY | 0.00 % | gap |
| MA | 99.48 % | source_review |
| TR | 55.59 % | source_review |
| WSB | 96.97 % | source_review |

MC, VA und GI werden anhand ihrer belegten gebietsweiten Verwaltung gesondert erklärt; fehlende Untergemeinden werden nicht durch erfundene Polygone ersetzt. Weitere Verbesserungen benötigen tatsächlich belegte tiefere Verwaltungsgeometrien und bei manchen Beständen neuere Rollen-/Reformabgleiche.

## Darstellung und geprüfte Bedienung

Regionen erscheinen ab 2×, Kreise ab 6× und Gemeinden/weitere lokale Flächen ab 24× bei mindestens 256 projizierten Boundingbox-Pixel². Zoom reicht bis 64×. Ortsnamen besitzen mindestens 13–14 Canvas-Pixel und bei 200 % mindestens 26–28. Kollisionsprüfung hält Namen auseinander. Unbekannte Quellnamen bleiben echte auswählbare Geometrien und werden nicht erfunden.

Die Grenzebene puffert und clippt echte Linienzüge; nach LOD getrennte räumliche Indizes überspringen verborgene Detailstufen. Komponenten unter 0,75 Bildschirm-Pixeln werden vor der Dekodierung ausgelassen und beim Zoomen wieder verfügbar. Diese Darstellungsregel entfernt keine gespeicherten Originalkomponenten.

Der Tipp auf eine Fläche benutzt die tatsächliche angeklickte Spielgebietsfläche; versetzt gezeichnete Ortsnamen benutzen ihren Ortsanker. In der Nahansicht hat die lokale Verwaltung Vorrang vor einer gröberen überlagernden Region. Orte außerhalb der Simulation behalten keine fremde Herrschaft. Der große Kartenmodus bewahrt den geografischen Mittelpunkt.

Die Quellenanzeige zeigt vollständige Credits, individuelle Lizenzen und konkrete Einschränkungen einschließlich teilweiser Rollenquarantäne. Suchergebnisse und Quellen sind auch bei 200 % scrollbar; die Schließen-Aktion bleibt außerhalb des Rollinhalts erreichbar. Die sechs Lesbarkeitsthemen bleiben erhalten, Walnuss ist der Standard.

## Validierung

Alle **40 Godot-Suiten** bestanden mit **31697 Assertions**. Die aktuelle Python-Sammlung bestand mit **260 Tests ohne ausgelassene Fälle**. Die gerenderten internationalen Vergleiche umfassen DE, FR, IT, PL, HU, CZ, NO, LU, RU, TR, AM, ES und GB auf derselben lokalen Zoomstufe; FR/IT/ES/GB zusätzlich auf 3× regionaler Stufe. Protokolle und Bilder liegen in `build/tests/` und `build/verify/`.

Echter Kameraschwenk, nicht nur Neuzeichnen einer stehenden Karte:

```text
MAPPERF zoom4-pan        zoom=4.00 redraw=yes frames=149 wall=4.024 fps=37.0 p50=26.96ms p95=27.87ms p99=28.90ms low1=34.6 draw_calls=5548 primitives=1363652 pan=yes pan_distance=107.6
```

Gemessen auf dem vorhandenen Windows-Rechner mit RTX 5070 Laptop/OpenGL-Compatibility und echtem 1600×900-Viewport. Diese Messung ist kein Poco-FPS-Nachweis.

Beide Exporte enthalten die aktuellen Atlasdateien bytegleich. Die Android-APK ist v2-signiert und zipaligned, Paket org.example.kronen, versionCode 9/1.6.0, minSdk 24/targetSdk 35, ARM64/v7a. Private Referenzen, Tests, Tools und Keystores sind nicht verpackt. Die Windows-EXE enthält ihre PCK und wurde mit isoliertem Ressourcenpfad und getrenntem Benutzerprofil geprüft: echte Partie starten, mehrere internationale Nahansichten rendern, speichern/wiederladen, Quellen bei 200 % öffnen/schließen; 32 Prüfungen bestanden. Der zusätzliche normale Fensterstart wurde separat geprüft. Kein physischer Android-Gerätelauf wurde für diesen Kandidaten durchgeführt.

Der Windows-Vorbereiter sichert das originale Anwendungsmanifest gegen den bekannten [Godot-4.5-Exportfehler #111316](https://github.com/godotengine/godot/pull/111316). Acht zusätzliche Tests, die bytegleichen Nicht-Ressourcen-Abschnitte, das 613-Byte-Originalmanifest, alle sieben Iconbilder und Version 1.6.0.0 wurden geprüft. Die Ressourcen werden vor dem Einbetten der PCK auf einer privaten Templatekopie vorbereitet; Godots erneute Ressourcenänderung ist im Windows-Preset deaktiviert. Die zuvor beobachtete Common-Controls-Warnung ist im erneuten normalen und isolierten Lauf verschwunden.

## Exportdateien und Reproduktion

| Datei | Bytes | SHA-256 |
|---|---:|---|
| `build/exports/banger-queens.exe` | 317302944 | `b13b8972399fcc53ef9dae3ff81f51e0a4b08397b4d8ecb6e6a505087aa2aa1a` |
| `build/exports/banger-queens.apk` | 269453133 | `053e43e3ca05c08085a928dd7fa0f59d2fe6d637bf5b94a65dbc41b0238428bb` |
| `data/atlas.json` | 97749149 | `3df29746045fb714146926f48eb1f1ed337e12a2a5c1f82732ae0b96e27178fc` |
| `data/atlas_geometry.bin` | 57424392 | `e5040e6f85521b2ee2a5076b9d7c85a0948e20f768ca5d236820e0ecd5be1540` |

Alle Laufzeitdaten liegen in der APK beziehungsweise der eingebetteten Windows-PCK; Spielen benötigt keinen Datenimport oder nachträglichen Download. Source- und Lizenzmanifeste sowie sämtliche Importer sind im Repository. Bytegleiche Datenreproduktion benötigt die dokumentierten hashgleichen Rohcaches; öffentliche APIs können sich ändern. Der Metadatenprüfrahmen wurde für den real erweiterten Bestand von 64 auf 128 MB angehoben, der Binärpool bleibt auf 100 MB begrenzt. Die tatsächlichen Paket- und Datengrößen stehen oben.

```powershell
python tools/build_atlas_data.py
python -m unittest discover -s tools -p "test_atlas*.py"
python -m unittest discover -s tools -p test_prepare_windows_export_template.py
# Godot-Suiten: tools/run_all_tests.sh
# Export: APPDATA auf die vorbereitete lokale Godot-Profilstruktur setzen
python tools/prepare_windows_export_template.py
.tools/godot.exe --headless --path . --editor --export-release "Windows Desktop" build/exports/banger-queens.exe
.tools/godot.exe --headless --path . --editor --export-debug Android build/exports/banger-queens.apk
```

Die Fassung bleibt ein eigenständiges Godot-Spiel. Eine vollständige AAA-Produktion und die vollständig ausmodellierte Geschichte von 2000 v. Chr. bis 2200 n. Chr. werden durch die Atlasarbeit nicht nachgewiesen.
