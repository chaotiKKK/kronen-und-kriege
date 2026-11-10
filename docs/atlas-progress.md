# Banger Queens 1.6.1 – Verwaltungsatlas und Prüfbericht

Prüfstand: 2026-11-10T02:26:42.084989+01:00. Projekt: `C:\Crusader Kings III\mobile-godot`. Geprüfte Testfassung für Windows und Android. Die vollständige vergleichbare Abdeckung bleibt bei **acht Gebieten offen**; diese Fassung schließt sieben der zuvor 15 offenen Fälle nach dem begrenzten fachlichen Kriterium.

## Bestand und Aussagegrenzen

| Darstellungsobjekt | Anzahl |
|---|---:|
| Länder-/Gebietsrahmen | 70 |
| Obere Regionalflächen | 997 |
| Kreis-/Bezirksflächen | 4.521 |
| Kommunale Darstellungsflächen | 114.761 |
| Weitere örtliche Verwaltungsflächen | 19.222 |
| GeoNames-Orte | 23463 |
| Flussgruppen | 175 |

Insgesamt 139.571 Kartenobjekte. Das Rechteck reicht von −12° bis 52° Länge und 33° bis 72° Breite: Europa und Nachbargebiete, kein vollständiger Weltatlas. Mehrere territoriale Teile können dieselbe ursprüngliche Verwaltungseinheit darstellen; Kennungen und Herkunft bleiben erhalten. Die 49 Spielgebiete tragen weiterhin Wirtschaft, Besitz, Krieg und Speicherstände. Referenzflächen erzeugen keine zusätzlichen Ressourcen.

`complete` bedeutet mindestens 95 % gemessene örtliche Verwaltungsabdeckung und hinreichend belegte Rollen ohne fortbestehende Quellensperre. Das ist weder eine hundertprozentige Vermessung noch eine nationale Behördenvollzählung. Die Gesamtzählung lautet **59 complete, fünf source_review, drei gap und drei single_jurisdiction**. Die drei strukturellen Sonderfälle MC, VA und GI erhalten keine erfundenen Untergemeinden.

## Was die neue Fassung verbessert

- Armenien: 62 rechtlich abgeglichene kommunale Identitäten bleiben erhalten. Die unabhängige physische Landreferenz zählt tatsächliches Wasser nicht als Land, ohne nationale Zuordnungen zu verschieben. Abdeckung 97,340036 %. [Quellenvergleich](atlas-AM-KZ-IL-audit.md).
- Republik Zypern: Original-DLS-Flächen mit CYSTAT 2026 und Reform 2024 verbunden; 20 aktuelle Gemeinden, 91 Quartiere und 511 territoriale Community-Einheiten fachlich getrennt. CY erreicht 98,991744 %, Akrotiri 96,375101 %. [Zypern und SBA](atlas-cyprus-sources.md).
- Nordzypern: 18 tatsächliche kommunale Identitäten mit Gesetz und ursprünglichen Quellrelationen abgeglichen. Expliziter Schnitt ausschließlich am bestehenden CYN-Rahmen, Abdeckung 95,169134 %. [Identitäten und Grenzen](atlas-north-cyprus-sources.md).
- Dekelia: Zwei belegte Teile von Lysi und Ammochostos additiv als örtliche Verwaltung aufgenommen, ausschließlich innerhalb ESB. Abdeckung 95,597840 %, rund 5,61 km² Rest. Crown-/Militärausnahmen und die fehlende Aussage uneingeschränkter tatsächlicher Machtausübung sind deutsch sichtbar. [Rechts- und Geometriebeleg](atlas-cyprus-sources.md).
- Iran: 1.188 positiv typisierte Dehestan im Ausschnitt. Die alte beschädigte gemischte Quelle bleibt für administrative Darstellung ausgeschlossen. Die 52 zusätzlich ausgeschlossenen Kandidaten und die fehlende Bushehr-Referenz liegen vollständig außerhalb des Rechtecks; die gemessenen 2,40 % Rest bleiben ungeklärt. Abdeckung 97,597428 %. [Qualifizierung und reproduzierbarer Stager](atlas-iran-sources.md).
- Jordanien: Ruwaished bleibt ein `district` mit ausdrücklich belegter terminaler staatlicher örtlicher Zuständigkeit. Die 95,817014 % sind keine Behauptung einer Gemeindegrenze. [Getrennter Rollenbeleg](atlas-jordan-sources.md).
- Falsche Gemeindezuordnungen in Aserbaidschan und Beirut korrigiert. Drei echte kasachische Stadtverwaltungsrollen zusätzlich belegt. Marokkos 44 Rechtspunkte wurden nachvollziehbar rekonstruiert; die problematischen Kandidaten gelangen ausdrücklich nicht in die Runtime. [Marokko-Audit](atlas-morocco-legal-audit.md).

Sinkende Werte bei einzelnen Gebieten sind ein Ergebnis strengerer Rollen- und Quellenkorrekturen. Höhere Verwaltungsebenen, Siedlungspunkte und künstliche Restpolygone wurden nicht benutzt, um örtliche Lücken zu verdecken. Der vollständige [Vorher-/Nachher-Bericht für alle 15 Fälle](atlas-remaining-15-audit.md) nennt je Gebiet die konkrete weitere Quelle.

## Acht verbleibende Fälle

| Gebiet | Gemessene Abdeckung | Konkreter offener Punkt |
|---|---:|---|
| AZ · Aserbaidschan | 0,000000 % | Aktuelle Gemeindegrenzen mit belegten Identitäten und Weitergabe; acht falsche Altzuordnungen ausgeschlossen. |
| CNM · UN-Pufferzone Zypern | 99,841186 % | Territoriale Referenzteile sind vorhanden; tatsächliche lokale Zuständigkeiten sind gesondert zu qualifizieren. |
| IL · Israel | 92,696891 % | Rund 95,26 km² echte Flächen-/Referenzdifferenz im kleinen nördlichen Kartenausschnitt. |
| KZ · Kasachstan | 78,685806 % | Ländliche Okrug-Grenzen fehlen; höhere Bezirksflächen sind kein Ersatz. |
| LB · Libanon | 61,665802 % | Gemeinden, Quartiere, Katasterflächen und nichtkommunale Gebiete brauchen weiterhin konkrete Abgrenzung. |
| LY · Libyen | 0,000000 % | Kein geeigneter aktueller Baladiya-Polygonsatz; gefundene HDX-Objekte sind Punkte. |
| MA · Marokko | 99,475034 % | Sidi Mohamed Benmansour fehlt; die neue Rechtsrekonstruktion bleibt wegen konkreter Geometrieprobleme gesperrt. |
| TR · Türkei | 55,590184 % | Echte lokale Grenzpolygone fehlen; für 30 Osmaniye-Kandidaten fehlen verifizierbare ursprüngliche Nutzungsbedingungen. |

Die Quellenanzeige hält diese Vorbehalte sichtbar. Der amtliche AZ-Katasterweg und die genaue ursprüngliche TR-ULASAV-Ressource wurden zusätzlich begrenzt geprüft; es entstand daraus kein positiv qualifizierter weiterer Import. Der CNM-Rollenhinweis bleibt trotz nachgewiesener ziviler UN-Koordinationsaufgaben bestehen.

## Tests und tatsächliche Paketprüfung

**391 Python-Tests** bestanden ohne ausgelassene Fälle. **Alle 41 Godot-Suiten** bestanden mit **31.746 Assertions**, darunter Daten, Quellenrollen, echte territoriale Eltern, Originalgeometrien, Kartenintegration, Suche, Touch, 200 % Textskalierung und Save-Migration. Die neue achteilige Semantikprüfung verlangt ausdrücklich deutsche nichtkommunale und gebietsbezogene Hinweise.

Der endgültige Atlasbuild bewahrte alle 22 eingefrorenen Eingabereceipts. Es gibt keine doppelten Feature-IDs, offenen oder länderfremden Elternverweise. Die JSON-Datei liegt unter GitHubs 100-MiB-Blobgrenze; keine qualifizierten Daten wurden dafür entfernt.

Die endgültige Windows-EXE wurde aus einem leeren Arbeitsverzeichnis mit getrenntem Benutzer- und Temporärprofil geprüft. **148 Paketlauf-Prüfungen** bestanden: reale Loading-/Main-Szene, neue Partie, internationale und neue Gebietsauswahlen, Quellen bei 200 %, sichtbare Schließen-Aktion sowie Speichern und Wiederladen einer absichtlich veränderten Partie. Der tatsächliche Benutzerpfad blieb im Sandboxprofil. Der erste Diagnoselauf legte einen typstrengen Ganzzahl-/JSON-Gleitkommazahlvergleich im Prüfharness offen; nach isoliert belegter Normalisierung blieb der exakte Rollenbestandsvergleich erhalten und der neue Lauf war vollständig grün. Produktive Daten und Pakete wurden für diesen Fix nicht verändert.

Beide Pakete enthalten alle **19 eingefrorenen JSON-/Binärdateien bytegleich**. Sämtliche 592 PCK-Einträge wurden gegen ihre MD5-Werte geprüft; alle 707 APK-Einträge bestehen CRC-Prüfung. Private Referenzen, Rohcaches, Tools, Tests, Dokumente und Keystores sind nicht eingebettet. Das originale 613-Byte-Windowsmanifest blieb bytegleich; native Ressourcen und Code stimmen mit der vor dem Packen vorbereiteten Vorlage überein.

Die APK ist v2-signiert und zipaligned, Paket `org.example.kronen`, Version 1.6.1 / Code 10, minSdk 24 / targetSdk 35, ARM64 und ARMv7. Der aktualisierte öffentliche APK-Verifier bestätigt dieselben Werte. Zertifikat-SHA256: `da3c6296edd521ad9f67d6d52d1cfe71fa5115e8d7ee0dfbca0a5c2c663802ac`. **Ein physischer Poco-/Android-Gerätelauf dieser Fassung wurde nicht durchgeführt.**

Ein tatsächlicher Kameraschwenk im 1600×900-Viewport auf dem vorhandenen Windows-Rechner mit RTX 5070 Laptop / OpenGL Compatibility:

```text
MAPPERF zoom4-pan        zoom=4.00 redraw=yes frames=147 wall=4.005 fps=36.7 p50=27.12ms p95=28.20ms p99=28.50ms low1=35.1 draw_calls=5548 primitives=1363652 pan=yes pan_distance=107.6
```

36,7 FPS beim Schwenk, 85,4 FPS in der Übersicht ohne Schwenk. Die Messung belegt keine allgemeine Leistungssteigerung gegenüber dem vorherigen Stand und ist keine Poco-FPS-Aussage.

## Dateien und Prüfsummen

| Datei | Bytes | SHA-256 |
|---|---:|---|
| `banger-queens-1.6.1.exe` | 319012192 | `32122fa497e3e5e3fd5311b5342c2cba1130a4039a4a869b07be05e044d848f7` |
| `banger-queens-1.6.1.apk` | 269636854 | `8899c7615bb65d64153d9657ca08d51014f374d9ead0da88ee11aa145a0e471a` |
| `atlas.json` | 99101714 | `9d3e7aa80cf0497d6aea940748a887b84fad78081d8382b2fefb65b395a60cfc` |
| `atlas_geometry.bin` | 57445584 | `42e529cb7495d58029ecb949f38f6d2499568b116b74b14c7e49a6b423b72d83` |

Die Pakete liegen unter `build/exports/`; die Datendateien unter `data/`. `SHA256SUMS-1.6.1.txt` enthält die beiden Paketprüfsummen. Die zuvor veröffentlichte Version 1.6.0 bleibt unter ihren bisherigen Namen unverändert als Rückfallstand erhalten.

Alle Laufzeitdaten sind Bestandteil der APK beziehungsweise der eingebetteten Windows-PCK. Spielen benötigt weder manuellen Import noch Daten-Download. Dies ist das eigenständige Godot-Spiel Banger Queens; es ist keine vollständige native Rekonstruktion der CK3-Engine oder bereits abgeschlossene AAA-/Weltkommunensimulation.

## Reproduktion

Godot 4.5, lokale Exportvorlagen, JDK/Android-SDK und Python mit Shapely müssen wie dokumentiert bereitgestellt sein. Hashgleiche private Rohcaches sind für bytegleiche Datenreproduktion nötig; öffentliche APIs können sich inzwischen verändert haben. Die separaten Provider dokumentieren ihre Wiederherstellungs- und Prüfwege.

```powershell
python -X utf8 tools/build_atlas_data.py
python -X utf8 -m unittest discover -s tools -p 'test_*.py' -v
# Git Bash verwenden; Fensterposition an den rechtesten Monitor anpassen.
$env:GODOT_WINDOW_POSITION='100,60'
bash tools/run_all_tests.sh
python -X utf8 tools/release_validation/atlas_release_validation.py prepare --output build/verify/meine-pruefung
# Versionierte Exportwrapper verweigern bereits vorhandene Ausgabedateien.
bash export_windows.sh
bash export_android.sh
python -X utf8 tools/release_validation/atlas_release_validation.py static --frozen build/verify/meine-pruefung/frozen-data.json --exe build/exports/banger-queens-1.6.1.exe --apk build/exports/banger-queens-1.6.1.apk --output build/verify/meine-pruefung
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release_validation/run_atlas_release_smoke.ps1 -Exe build/exports/banger-queens-1.6.1.exe -Frozen build/verify/meine-pruefung/frozen-data.json
```

Die endgültigen lokalen Belege liegen unter `build/verify/release-1.6.1-final-esb-r2/`, die vollständigen Suiteprotokolle unter `build/tests/`. Atlasbuild-, Python- und Exportprotokolle stehen unter `build/verify/atlas-remaining-final-*` beziehungsweise `build/verify/atlas-161-*`.
