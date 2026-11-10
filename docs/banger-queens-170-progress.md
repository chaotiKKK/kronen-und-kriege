# Banger Queens 1.7.0: WLAN und zusätzliche Verwaltungsflächen

Stand: 10. November 2026. Eigenständige native Godot-Fassung für Windows und
Android. Die vollständige, überall vergleichbare Verwaltungsdetailtiefe bleibt
offen; die acht Fälle AZ, CNM, IL, KZ, LB, LY, MA und TR werden ausdrücklich nicht
als abgeschlossen ausgewiesen. Die bisherigen Pakete von 1.6.1 sind unverändert. Die erste lokale 1.7.0-Kandidatenfassung wurde nach dem abschließenden Game-Review neu gebaut; ihre Dateien und Belege bleiben separat unter `build/verify/release-170-candidate1` erhalten.

## Umgesetzt

Zwei bis vier Menschen können in einer deutschen WLAN-Lobby verschiedene
vorhandene Häuser wählen. Ein Gastgeber führt die gemeinsame Simulation aus.
Gäste erhalten persönliche Ansichten und schicken geprüfte Befehle. Raumsuche,
direkte IP-Verbindung, Bereitschaft, Spielstart, Hostspeicherung und
Wiederaufnahmelobby sind verbunden. Die [WLAN-Anleitung](wlan-mehrspieler.md)
beschreibt die Bedienung und die Unterbrechungsregeln.

Die Welt pausiert bei einer offenen Entscheidung eines lebenden Menschenhauses
oder einem verlorenen Teilnehmer. Der Gastgeber steuert die gemeinsame Zeit.
Gastergebnisse werden erst nach tatsächlicher Bestätigung angezeigt. Fremde
Provinzaktionen, doppelte Befehle und veraltete Ereignisantworten werden
abgewiesen. Ein ausgeschiedener Host kann am Kampagnenende die gemeinsame
Sandbox freigeben. Jahresautosaves gehören ausschließlich dem Host und bleiben
von Einzelspielerdateien getrennt.

Beim Wechsel aus einer LAN-Partie bleiben keine alten Ereigniskarten über der
neuen Einzelspielerpartie stehen. Bei einem Gastverlust öffnet sich die
erreichbare Lobby auch über einem noch offenen Ereignis. Gleichzeitige Abgänge
mehrerer Gäste sind durch eine Prüfung des tatsächlichen ENet-Empfängerzustands
abgesichert. Der ursprüngliche Fehler wurde mit vier getrennten Prozessen
reproduziert; der Testcontroller hat die native Enginefehlermeldung korrekt als
Fehlschlag gewertet. Eine kontrollierte Peer-Reset-Regression bleibt enthalten.

Die abschließende Game-Prüfung ergänzt die frühe Ablehnung ungültiger LAN-Spielerindizes und die persönliche Zuordnung von 14 Meldungspfaden. Forschung, Straßenbau, Geburt und militärische Vorgänge erreichen jetzt auch nicht aktive Menschenhäuser. 126 LAN-Zustandsprüfungen und 2.453 gezielte bestehende Prüfungen bestätigen die Korrektur ohne zusätzliche Welt- oder Kostenberechnung.

## Tatsächlicher Atlaszuwachs

| Bestandteil | Bestand 1.7.0 |
|---|---:|
| Länder-/Gebietsflächen | 70 |
| Regionen | 997 |
| Kreise und Bezirke | 4.521 |
| Kommunale Darstellungsflächen | 114.761 |
| Weitere örtliche Verwaltungsflächen | 19.695 |
| Alle Kartenobjekte | **140.044** |
| GeoNames-Orte / Flussgruppen | 23.463 / 175 |
| JSON / Binärgeometrie | 99.841.251 / 57.514.576 Byte |

Neu sind **662** qualifizierte originale Mahalle-Flächen aus dem
[amtlichen Sakarya-Portal](https://veri.sakarya.bel.tr/dataset/92).
Die [konkrete Lizenz](https://veri.sakarya.bel.tr/license) erlaubt die
Weitergabe und Bearbeitung mit Quellenangabe. Der Provider erhält die
Originalkoordinaten und den Stand 15.05.2024; Darstellungsprojektion und
Vereinfachung folgen dem bestehenden Atlasvertrag.

**189** einzeln belegte Altobjekte wurden ersetzt. **Neun** ungeklärte
Rückfallflächen bleiben vollständig unverändert. Netto entstehen **473**
zusätzliche Objekte. Fünf starke Unterschiede zwischen dem Originalstand 2024
und GF 2026 bleiben dokumentiert; aus der Zulassung folgt keine Behauptung
vermessungsaktueller Grenzen für 2026. Der
[Sakarya-Bericht](atlas-sakarya-sources.md) enthält die Einzelbelege und
ausgeschlossenen Fälle.

Der unabhängige Vergleich gegen Git `4348093` bestätigt: Alle **139.382**
gemeinsamen Features haben unveränderte Metadaten, Rollen, Eltern und
Binärgeometrien. Alle 662 neuen Rendergeometrien wurden aus den Originalen
erneut berechnet und stimmen überein. Es gibt keine doppelten IDs und keine
offenen Eltern. Nur die türkische Flächenprüfung ändert sich, um rund
**42,039216 km²**; alle anderen Länderwerte bleiben unverändert.

Der Atlas umfasst Europa und Nachbargebiete im vorhandenen Rechteck. Die
**49 Simulationsgebiete** tragen weiterhin Wirtschaft, Besitz und Krieg;
zusätzliche Referenzflächen erzeugen keine neuen Ressourcen oder Spielgebiete.

## Acht weiterhin offene Fälle

Die Prozentwerte messen die Union qualifizierter Flächen innerhalb der
unveränderten Landreferenz im Kartenausschnitt. Sie belegen keine vollständige
Landesgliederung und ersetzen keine administrative Rollenprüfung.

| Gebiet | Geometrischer Prüfwert | Konkretes Ergebnis der neuen Suche |
|---|---:|---|
| AZ | 0,000000 % | Amtliche Gemeindeidentitäten gefunden, weiterhin kein qualifizierter kommunaler Polygonexport. Höhere Bezirke bleiben ausgeschlossen. |
| CNM | 99,841186 % | Neuer positiver Einzelbeleg für Pyla; andere Gebietsrollen bleiben ungeklärt. Keine Freigabe der gesamten Pufferzone. |
| IL | 92,696891 % | Originale des Innenministeriums für Hurfeish und Mateh Asher geprüft. Kaum zusätzlicher Lückenschluss; konkrete Weitergabe bleibt unbelegt. |
| KZ | 78,685806 % | 26 echte ländliche Okrug-Polygone mit aktuellen KATO-Identitäten gefunden. Institutsgeometrien bleiben mangels positiver Weitergabe im privaten Audit; datierte Grenzänderungen sind dokumentiert. |
| LB | 61,665802 % | Neue UN-Dienste enthalten Kataster- und Themendaten mit Rechtevorbehalten; kein freigegebener vollständiger Gemeindeflächensatz. |
| LY | 0,000000 % | Aktuelle Baladiya-Rolle bestätigt, aber keine passende aktuelle Fläche. 22 alte Mantika werden nicht zu Gemeinden umbenannt. |
| MA | 99,475034 % | HCP liefert zwei getrennte Originalpolygone. Nutzungsumfang, widersprüchliche CRS-Angabe und Abweichungen vom gesetzlichen Grenzverlauf bleiben ungeklärt. |
| TR | 55,595577 % | Sakarya ist deutlich feiner dargestellt; damit ist der landesweite Ergänzungsbedarf noch nicht gelöst. |

Die Berichte für [AZ/KZ/IL/LY](atlas-remaining8-new-sources-20261110.md)
und [LB/MA/CNM](atlas-remaining8-lb-ma-cnm-20261110.md) nennen Original-URLs,
Dateigrößen, Hashes, tatsächliche Rollen und konkrete verbleibende Hindernisse.
Ein alter Datenstand oder informative statt statutarische Geometrie ist für
sich allein kein pauschaler Ausschlussgrund. Kandidaten werden weder still
importiert noch durch künstliche Restpolygone ergänzt.

## Belegte Prüfung

| Prüfung | Ergebnis |
|---|---|
| Vollständiger Pythonlauf | **427 Tests grün** |
| 47 registrierte Godot-Suiten | **32.043 Prüfungen grün**, aktuelle Einzellogs ausgewertet |
| Vier getrennte Quellprozesse | **142 Prüfungen**, vier eindeutige Peer-/Prozess-IDs, eigene Ausbauten und identischer Welthash |
| Getrennte Transportprozesse | **37 Prüfungen**: Normalfall, falscher Fingerprint, harter Host- und Gastverlust |
| Zwei Prozesse der exportierten EXE | **66 Prüfungen**, produktive Main-Oberfläche und Befehle, echte ACKs und Ablehnung, identischer Welthash |
| Exportierter Atlas, Darstellung, Speichern/Laden | **357 Prüfungen**, isoliertes Profil und leeres Arbeitsverzeichnis |
| Sichtbare exportierte WLAN-Lobby | **4 zusätzliche Prüfungen**, tatsächliche PNGs bei 100 % und 200 %, erreichbares Zurück |
| Windows-PCK / Android-ZIP | Alle 603 PCK-Einträge per MD5 und alle 718 APK-Einträge per CRC geprüft; vollständige Daten zusätzlich per SHA-256 |

Die letzte CourtShot-Prüfung wurde wegen einer geänderten Monitoranordnung
auf dem rechten Bildschirm neu gestartet. Der Abschlussbeleg fasst die
tatsächlichen Einzellogs aller 47 registrierten Suiten zusammen. Nach der
Transportkorrektur wurden die betroffenen Netzprüfungen erneut ausgeführt.
Native `ERROR:`-Zeilen führen jetzt zusätzlich zu Scriptfehlern zum Scheitern
des Sammelrunners.

Wesentliche lokale Belege liegen unter `build/tests/` und `build/verify/`:

- `final-170-python.log` und `final-170-consolidated-summary.json`
- `atlas-170-inputs.json` mit 38 unveränderten Eingaben
- `atlas-170-independent-diff.json`
- `release-170-source-freeze.json`
- `atlas-release-170-final/static-package-receipt.json`
- `atlas-release-170-final/runtime-smoke-receipt.json`
- `lan-four-process-170-20261110-061959-039-aee85e63/summary.json`
- `lan-release-170-20261110-062232-825-c5ed0f04/summary.json`
- `build/tests/lan-network/20261110-062211-909/summary.json`

Die Vier-Prozesse-Quellprüfung verwendet ausdrücklich einen Testfingerprint.
Der Pakettest verwendet die tatsächlich eingebetteten Ressourcen und deren
Fingerprint. Beide sind Windows-Prozesstests. **Reales Android-WLAN zwischen
zwei Geräten ist noch nicht nachgewiesen.** Ein neuer Poco-Gerätelauf,
Android-Softtastatur und längerfristige Mobilgerätebelastung bleiben offen.

## Pakete

Beide Dateien enthalten sämtliche Laufzeitdaten. Die Android-Fassung benötigt
keinen separaten Import und keinen Inhaltsdownload. Es handelt sich um eine
einzelne reguläre APK, nicht um ein ZIP64- oder Erweiterungsdatei-Paket.

| Datei | Byte | SHA-256 |
|---|---:|---|
| `banger-queens-1.7.0.exe` | 320.074.024 | `2758494f59f404a16b9161a437d526b8807deef410cac327dbf87069a72f8d5d` |
| `banger-queens-1.7.0.apk` | 269.896.937 | `fcff14569fdf3ad1049fb815071948a6866c31a69140e3ee35f047c5641d1933` |

APK: Version 1.7.0, Code 11, `org.example.kronen`, ARM64 und ARMv7,
minSdk24/targetSdk35, gültige v2-Signatur, zipaligned. Das Zertifikat stimmt
mit dem bisherigen Schlüssel überein. Die vier tatsächlich eingebetteten
Berechtigungen sind INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE und
CHANGE_WIFI_MULTICAST_STATE. Die Windows-EXE behält das originale vorbereitete
Godot-Manifest und dessen ausführbare Codeabschnitte.

## Reproduzieren

Die lokalen Werkzeuge und SDKs bleiben unter `.tools/`. Positiv qualifizierte
Quellcaches sind unveränderlich und hashgebunden; neue Atlasquellen müssen vor
dem Gesamtbuild gesondert vorbereitet werden. Die Exportwrapper verlangen
einen neuen Ausgabepfad, wenn bereits eine Datei existiert.

```powershell
& C:\Python314\python.exe -m unittest discover -s tools -p 'test_*.py'
& 'C:\Program Files\Git\bin\bash.exe' tools/run_all_tests.sh
& .\tools\run_lan_network_test.ps1
& .\tools\release_validation\run_lan_four_process_smoke.ps1
& 'C:\Program Files\Git\bin\bash.exe' export_windows.sh build/exports/new-test.exe
& 'C:\Program Files\Git\bin\bash.exe' export_android.sh build/exports/new-test.apk
& .\tools\release_validation\run_lan_release_smoke.ps1 -Exe .\build\exports\new-test.exe
```

Sichtbare Prüfungen erhalten die Position des aktuell rechten Bildschirms.
Die Paket-Smoke-Skripte verwenden frische Profile und beenden ausschließlich
an EXE, Helperskript, Laufkennung, Rolle und Startzeit erkannte eigene Prozesse.

## Veröffentlichung

Die [öffentliche Testfassung v1.7.0](https://github.com/chaotiKKK/kronen-und-kriege/releases/tag/v1.7.0) enthält EXE, APK und Prüfsummen. Tag und getesteter Quellstand zeigen auf `71884ddedcb6ac1ebc70717f13e9fc530f682e71`. GitHub bestätigt die Größen und SHA-256-Digests aller drei Assets; Release-ID439980564, draft=false, prerelease=true. Lokaler Beleg: `build/verify/release-170-publication-receipt.json`. Die acht Quellenfälle und reale Android-WLAN-Abnahme bleiben ausdrücklich offen.
