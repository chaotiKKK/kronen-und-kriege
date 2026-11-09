# Banger Queens 1.5.2 – Entwicklungs- und Prüfbericht

Stand: 2026-11-09. Hauptprojekt: `C:\Crusader Kings III\mobile-godot`.

## Aktueller Quellstand: sechs Material- und Lesbarkeitsthemen

Neue oder fehlende Themeneinstellungen starten mit **Holz · Walnuss**. Bestehende gespeicherte Themen behalten ihre Bedeutung; der Stil ist in den Optionen unter „Lesbarkeitsthema“ wählbar. Die Schriftgrößen 100, 125, 150 und 200 % bleiben verfügbar.

| Einstellungs-ID | Thema |
|---|---|
| `0` | Dunkler Atlas — bestehende ID |
| `1` | Hoher Kontrast — bestehende ID |
| `2` | Heller Atlas — bestehende ID |
| `3` | Holz · Walnuss (Standard) |
| `4` | Holz · Helle Eiche |
| `5` | Pergament |

Die Holzoberflächen verwenden eine eigene, prozedural erzeugte und gemeinsam wiederverwendete Maserung. [Poliigon](https://www.poliigon.com/) dient als Materialreferenz; es wurden keine Poliigon-Materialdateien heruntergeladen oder eingebunden. Die Maserung liegt hinter den Inhalten, ignoriert Maus-/Touch-Eingaben und vergrößert die Bedienelemente nicht.

Der Stilwechsel erhält die semantischen Hausfarbfelder sowie grüne Pluswerte, rote Minuswerte und gelbe neutrale Angaben. Einfügecursor und Platzhalter erhalten passende Kontraste; der Tastaturfokus hat eine transparente Fläche und eine mindestens zwei Pixel breite Kontur. Deaktivierte Aktionen bleiben unterscheidbar. Die Temposchalter werden nicht zusätzlich durch eine Gesamtmodulation abgedunkelt. Bereits geöffnete Ereignisse aktualisieren beim Stilwechsel auch ihre Textkonturen; die Ereignisfläche bleibt bei 10 % Deckkraft.

## Prüfstand dieser Änderung

Der abschließende Sammellauf besteht mit **38 von 38 Suiten und 3.722 Prüfungen**: 27 Suiten headless, elf mit Fenster. Es gibt keine übersprungenen oder ausstehenden Fälle; FAIL-Meldungen und Skriptfehler wurden im Sammellauf nicht festgestellt. `MaterialThemeTest` besteht im Fensterlauf mit **219 Prüfungen**. Er prüft unter anderem die sechs Stilwechsel, Kontrastwerte, Hausfarben, Cursor und Platzhalter, Fokus, deaktivierte Aktionen, Zeitsteuerung, nicht blockierende Maserung sowie Ereignisfarben und Textkonturen. Ein früherer fokussierter Headless-Lauf bestand mit 215 Prüfungen; die vier zusätzlichen Fälle des Fensterlaufs prüfen die Screenshot-Ausgabe.

Die Exporte 1.5.2 wurden erstellt und separat geprüft. Die Windows-EXE startet sichtbar auf dem rechten Monitor, erreicht `MAIN_READY version=1.5.2`, liefert einen nichtleeren Render-Frame und schließt mit Exit 0. Die Android-APK besteht Signatur-v2-, ZIP-Ausrichtungs- und Metadatenprüfung: `org.example.kronen`, Versionscode 8, ARM64 und ARMv7, minSdk 24, targetSdk 35. Ein Spieltest dieser APK auf dem Poco steht aus.

| Export 1.5.2 | Bytes | SHA-256 |
|---|---:|---|
| `F:\banger-queens.apk` | 204.862.841 | `9ee52449ab15ea5ea1d4cc0e12da6a40b70638691e8fbfe3682ce3002a94f072` |
| `F:\banger-queens.exe` | 142.853.392 | `377335ad7ac6560076a7fe878de41e57f43bbf7fe0eb7624c29701090fdf0a69` |

Das Android-Zertifikat bleibt das bisherige Debug-Zertifikat (SHA-256 `da3c6296edd521ad9f67d6d52d1cfe71fa5115e8d7ee0dfbca0a5c2c663802ac`). Die APK enthält die eigenen Spieldaten; Wine, Box64 und manuelle Datenimporte gehören nicht zu diesem Projekt.

Die folgenden Abschnitte bewahren den **historischen Bericht zu 1.5.1**. Dessen Größen, Hashes und manuellen Abnahmen gehören ausschließlich zu den damaligen Exporten. Die wiederverwendeten Dateipfade unter `F:` kennzeichnen allein keine Version und sind kein Beleg dafür, dass spätere Dateien dieselben Hashes besitzen.

---

# Vorgänger 1.5.1 – historischer Entwicklungs- und Prüfbericht

Stand: 2026-11-09. Hauptprojekt: `C:\Crusader Kings III\mobile-godot`.

## Ergebnis dieser Ausbaustufe

Die vorhandene Godot-Fassung wurde übernommen und als **Banger Queens** weiterentwickelt. Bestehende lokale Hof-, Glaubens-, Dynastie-, Karten-, Blender- und Testarbeiten wurden bewahrt. Der Zustand vor den Änderungen liegt lokal unter `build/checkpoints/20261109-banger-queens-before/`; `.gdignore` verhindert dessen Import als Spielinhalt. Unreal bleibt nach ausdrücklicher Nutzerentscheidung ein separates nachfolgendes Projekt.

### Oberfläche

- Neues Hauptmenü mit eigenständiger Typografie, deutlichem Spieleinstieg und Kampagnenband.
- Schieferblau, Kupfer und Seegrün statt der bisherigen durchgehend braunen Pergamentoberfläche.
- Getrennte Kopfzeilen für Identität/Datum und Wirtschaft/Zeitsteuerung.
- Kartenmodi und Werkzeuge besitzen reservierte Layoutbereiche. Die frühere Überlappung unter dem Seitenpanel ist durch einen Regressionstest abgedeckt; bei Bedarf ist die Navigation horizontal scrollbar.
- Das Seitenpanel hat vier exklusive Bereiche: Übersicht, Politik, Familie und Welt. Das Herrscherprofil bleibt kompakt; die vollständigen Provinzdetails sind über die Provinzseite erreichbar.
- Drei gespeicherte Lesbarkeitsthemen: dunkler Atlas, hoher Kontrast und heller Atlas.
- Schriftgröße 100, 125, 150 oder 200 %. Dialoginhalte werden durch Rollbereiche begrenzt. Die Optionen mit 200-%-Text wurden tatsächlich gerendert und visuell geprüft.
- Ereignisse wie „Gute Ernte“ zeigen Aktion und sämtliche Folgen im selben Button. Pluswerte sind grün, Minuswerte rot, neutrale Angaben gelb/amber; die Farbtöne passen sich den drei Themen an. Die Panel-Fläche hat 10 % Deckkraft, einen dünnen Rand und einen dezenten Schatten; die Abdunklung der Spielansicht bleibt auf 16 % reduziert. Ein kleineres, abgerundetes Bild bleibt über Titel und Beschreibung sichtbar. Der vollständige Button löst die bestehende Entscheidung aus, auch bei einem Klick direkt auf die Wertzeile. Zugängliche Aktionsnamen enthalten alle Werte. Textgröße und Themen können gewechselt werden; ein Regressionstest prüft, dass die Buttons nach dem Zurückschalten von 200 % nicht überlappen.
- Die Wortmarke und das rote Banner im Hintergrundmotiv des Hauptmenüs sind vollständig vom breiteren, deckenden Menübereich überlagert.

Die Gestaltung folgt dem Skill `frontend-design`: klare Informationshierarchie, eine auf das Spiel abgestimmte Palette und überprüfte Ingame-Bilder. Es handelt sich um native Godot-Bedienelemente.

### Regeln und Persistenz

- Durchgehender Kalender Januar 2000 v. Chr. bis Dezember 2200 n. Chr.; 50.400 Monatszustände ohne Jahr null. Der Grenzmonat stoppt die normale Zeitsteuerung; Sandbox-Fortsetzung wird gespeichert.
- Save-Schema 12. Alte numerische Kalender mit Jahr null werden nach vergangener Dauer migriert. Altfristen behalten über die einsbasierte Kompatibilitätsuhr ihre Bedeutung.
- Erste Forschung: Vermessung (20 Gold, sechs Monate), danach Straßenbau (40 Gold, zwölf Monate).
- Straßen zwischen benachbarten eigenen Provinzen kosten 30 Gold und benötigen drei Monate. Besitzverlust pausiert den Bau. Die Karte unterscheidet Baustelle und fertige Verbindung.
- Eine fertige Verbindung bringt dem gemeinsamen Besitzer jährlich zwei Gold. Geteilte Besitzverhältnisse erzeugen diesen Bonus nicht. Kosten und Wirkungen benutzen den vorhandenen Resolver.
- Forschung und Straßen überleben JSON-Speichern/Laden. Ungültige/doppelte Verbindungen, fehlende Voraussetzungen und widersprüchliche Kalenderdaten werden geprüft.
- Der Ladebildschirm zeigt Status und Laufzeit ohne erfundene Prozentwerte und hält die geladene Szene bis zum Wechsel im Speicher.

## Prüfungen

Godot: `4.5.stable.official.876b29033`.

Der abschließende Sammellauf für Version 1.5.1 meldet **37 von 37 Suiten grün, 3.503 Prüfungen**. Bericht: `build/tests/run_all_summary.tsv`; Einzelprotokolle: `build/tests/*.log`. Neu hinzugekommen sind `CampaignTest`, `InfrastructureTest`, `InfrastructureUiTest`, `LoadingStatusTest`, `ModernUiTest` und `EventChoiceTest`. Die neuen Fälle wurden zunächst gegen den jeweils fehlenden Funktionsstand ausgeführt und anschließend auf Grün gebracht. Die letzte Korrektur erweitert die Abdeckung um Vorzeichenfarben, neutrale Farbe, Themenwechsel, zugängliche Namen, zehn Prozent Deckkraft, Kontur/Schatten und überlappungsfreie Buttonflächen nach Textgrößenwechsel.

Bestehende Prüfungen für Charaktererstellung, individuelle Häuser, drei Hauspartien, Touch-Eingaben, Dynastie, Hof, Religion, Seekrieg, KI-Kanten, Ereignisbilder, Save-Migration und 120 Spielmonate bestehen weiterhin. Die neue Layoutprüfung verwendet Fenstergrößen 1280×720, 1024×768 und 1920×1080. Fensterläufe wurden auf dem rechten Monitor ausgeführt.

Die exportierte Windows-Fassung wurde außerdem außerhalb der Tests gestartet und per echter Bedienung geprüft. Im ersten 1.4-Build wurden Ari/Haus Neu erstellt, Vermessung erforscht, bis Dezember 1999 v. Chr. gespielt, vollständig beendet und derselbe Stand nach Neustart geladen. Version 1.5 lädt diesen Stand mit Herrscher, Forschung und offenem Ereignis im modernisierten UI. Das dient als zusätzliche Binärprüfung; es ist kein 4200-Jahre-Lauf.

Auch der endgültige Export mit transparentem Ereignisfenster wurde gestartet (`build/verify/bq-windows-final.log`, `MAIN_READY version=1.5`). Der Klick direkt auf die Wertzeile „+45 Gold“ im Verkaufsbutton schließt das Ernteereignis korrekt und setzt die Partie fort. Anschließend wurde die Testanwendung regulär beendet. Sämtliche manuellen Partien verwendeten ein separates lokales Testprofil.

Nachkorrektur 1.5.1: Der aktuelle Export startet mit `MAIN_READY version=1.5.1` (`build/verify/bq-windows-1.5.1.log`). Die Logoabdeckung im Hauptmenü sowie das neue, schwach hinterlegte Ereignisfenster mit farbigen Werten wurden im exportierten Programm beobachtet. Ein Klick direkt auf „+60 Gold / −10 Prestige“ bei „Mitgift fordern“ schließt das Ereignis; die tatsächlich angezeigten Werte wechseln von 241 auf 301 Gold und von 24 auf 14 Prestige. Danach wurde die Anwendung regulär beendet.

Screenshots:

- `build/verify/bq-modern-menu.png`
- `build/verify/bq-modern-game.png`
- `build/verify/bq-modern-light.png`
- `build/verify/bq-modern-200.png`
- `build/verify/bq-event-compact.png`

Die Windows-Startprotokolle enthalten eine bereits bekannte Warnung zur Initialisierung nativer Windows-Common-Controls. Die Godot-Oberfläche startet; Skript-/Shaderfehler wurden in der Abnahme nicht festgestellt. Dies ist keine Behauptung vollständig warnungsfreier Engine-Protokolle.

## Dateien des Vorgängers 1.5.1

| Eigenschaft | Windows | Android |
|---|---|---|
| Datei | `F:\banger-queens.exe` | `F:\banger-queens.apk` |
| Bytes | 142.848.056 | 204.857.604 |
| Version | 1.5.1.0 | versionName 1.5.1, versionCode 7 |
| SHA-256 | `f15ef31ed1da49b169b0c84b9db678d39ee8d6adb19c7ca192ceea9d72e54061` | `5a124282e2860d150e6397ced56ea5022728f8a182fb3f020a9a9f2ab62c552a` |

Die APK ist debug-signiert. APK Signature Scheme v2 und `zipalign` sind gültig. Paketkennung bleibt `org.example.kronen`, damit bestehende Installationen mit derselben Signatur aktualisierbar bleiben. Das Zertifikat bleibt unverändert: SHA-256 `da3c6296edd521ad9f67d6d52d1cfe71fa5115e8d7ee0dfbca0a5c2c663802ac`. minSdk 24, targetSdk 35; native Bibliotheken für ARM64 und ARMv7. Alle eigenen Laufzeitdaten sind in einer APK enthalten. Die geprüften 678 Archiveinträge enthalten den neuen Ereignisbildshader sowie die neuen Spielmodule; keine Wine-/Box64-Einträge und keine Sicherungs-/Testszenen.

Für Windows bleibt der bisherige Speicherort unter `Godot/app_userdata/Kronen und Kriege` erhalten. Der Produktname allein verschiebt die Spielstände dadurch nicht in ein neues Verzeichnis.

## Reproduzieren

Im Projektverzeichnis, mit vorhandenen lokalen Godot-Templates, SDK und Debug-Keystore:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' tools/run_all_tests.sh
$env:APPDATA = Join-Path (Get-Location) '.tools\appdata'
& .\.tools\godot.exe --headless --path . --export-debug 'Windows Desktop' 'F:/banger-queens.exe'
& .\.tools\godot.exe --headless --path . --export-debug 'Android' 'F:/banger-queens.apk'
& 'C:\Program Files\Git\bin\bash.exe' tools/verify_android_apk.sh 'F:/banger-queens.apk'
```

Exports nacheinander ausführen, da sie denselben Godot-Import-/Exportcache benutzen. Die Prüfposition ist auf den aktuellen rechten Monitor gesetzt und lässt sich mit `GODOT_WINDOW_POSITION` anpassen. Private Keystores und lokale SDKs sind nicht Teil des Quellrepositories.

## Grenzen und nächste fachliche Ausbaustufen

Die **aktuelle APK wurde nicht auf dem Poco installiert oder gespielt**. Touch-Tests am Windows-Viewport und eine APK-Signaturprüfung ersetzen diesen Nachweis nicht. Auch das frühere Low-End-Windows-Zielprofil wurde mit dieser Version nicht auf einem entsprechend schwachen Gerät gemessen. Die vorhandenen Karten-Benchmarks beschreiben den hiesigen PC mit RTX 5070 Laptop GPU.

Der Kalender umfasst die gewünschten 4200 Jahre. Vollständige Epocheninhalte, dynamische Institutionen/Nachfolge, sämtliche Forschungsgebiete, Wissensverbreitung, Schienennetze, eine globale NPC-Simulation und die auf etwa 60 Stunden ausbalancierte Gesamtkampagne sind weitere Ausbaustufen. Die aktuelle Partie bleibt inhaltlich auf dem bisherigen Bronzezeit-Grundspiel plus den hier beschriebenen Erweiterungen aufgebaut. Ein Kalender-Roundtrip ist kein Beleg für eine vollständig durchspielbare 4200-Jahre-Kampagne. Eine AAA-Grafikparität oder vollständige Barrierefreiheit wird durch diese Tests ebenfalls nicht behauptet.

Der weitergehende Entwurf steht in `docs/superpowers/specs/2026-11-09-banger-queens-design.md`; die ersten Schritte und die UI-Überarbeitung sind unter `docs/superpowers/plans/` dokumentiert.
