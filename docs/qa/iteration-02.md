# Banger Queens · QA-Iteration 2

## 1. Ziel

Die Ortssuche verbindet den realen Atlas mit der Herrschaftssimulation. Beide Ebenen sollen beim Erkunden und Antippen unmittelbar erkennbar bleiben. Die Karte unterscheidet beide Ebenen durch Text und ein eigenes Kartenzeichen.

## 2. Bestandsaufnahme

Build 31 findet den Gemeindetreffer Wiesbaden und zentriert dessen Referenzpunkt. Das betreffende Polygon des Spiels heißt Hamburg und trägt die ID germanien__02. Die Regionsgeometrie bestätigt die Zuordnung. Der Kartenkopf zeigt beide Namen derzeit ohne Rollenbezeichnung. Direkte Kartenklicks bei niedriger Vergrößerung können den alten Auswahlpunkt in der Atlasebene belassen.

Der Assetbestand enthält elf passende Modelle im Projekt. Weitere einschlägige Projekt- und Downloadverzeichnisse auf C, D und E lieferten für die gesuchten Blender-, glTF- und FBX-Dateinamen keine zusätzlichen Kandidaten. Die Kompassmarke entstand aus eigener Blender-Geometrie. Das Spiel zeigt den gerenderten Pin an einer einzigen Position. Das GLB und sein Generator bleiben bearbeitbar.

## 3. Testmatrix

| Ziel | Vorgehen | Erwartung | Abbruchkriterium |
| --- | --- | --- | --- |
| Erster Kartenkontakt | Wiesbaden suchen, Ort und Gemeinde auswählen, Provinzleiste und Pin ansehen. | Die Rollen Atlasort und Spielregion sind verständlich beschriftet. Der Pin zeigt auf die Referenzkoordinate. | Falsches Spielgebiet oder verdeckte Beschriftung. |
| Kartenarbeit und Erschließung | Karte wechseln, zoomen und verschieben. Eine Provinz direkt wählen. Den angezeigten Ort mit den Aktionsmöglichkeiten und nach einem regulären Zug vergleichen. | Kartenansichten und Aktionen bleiben nutzbar. Die alte Ortsmarke wird beim reinen Provinzklick gelöscht. | Verwaister Pin, Sprung in eine fremde Provinz oder Veränderung von Aktionen, Kosten oder Zugzustand. |
| Schneller Einstieg | Eine exakte und eine breite Suche ausführen. Einen Ortsmarker erneut antippen und zwischen verschiedenen Treffern wechseln. | Treffersortierung, Auswahl und Kartenzentrum bleiben korrekt. | Wechselwirkung zwischen Panel, Karte und Marker verhindert Auswahl. |
| Fehlbedienung und Sitzungswechsel | Einen Atlasort außerhalb der Spielwelt wählen, Pause und Spielstand prüfen sowie die Sitzung neu beginnen. | Fremde Referenzorte erben keinen alten Herrscher. Ein neuer Spielstand startet ohne alte Kartenmarke. | Falsche Herrschaft, ungewollter Befehl oder sichtbarer alter Kartenstand. |
| Lesbarkeit und Ressourcen | Karte auf Windows und Android per Touch prüfen. Schrift auf 200 Prozent stellen. Markierung am Rand und in verschiedenen Kartenmodi kontrollieren. | Die Ebene ist im Text erkennbar, und die Karte zeichnet keine Markierung außerhalb ihrer Arbeitsfläche. | Landesgrenze, Ortsname oder Bedienelement werden durch den Pin unlesbar. |
| Regression | Atlasdaten, abgegrenzte Suchtreffer, Monatswirtschaft, Pause, Speichern, Start sowie den gerenderten Kartenschwenk prüfen. | Orte, Geometrie und Simulation bleiben konsistent. Die zusätzliche Markierung beschränkt sich auf die Auswahl. | Fehler beim Start, im Save oder in einer geprüften Standardhandlung. |

## 4. Probespiele

- **Erstspieler** Im gerenderten Windows-Test wurde Wiesbaden aus der echten Suche gewählt. Der Kartenkopf nannte „Atlasort Wiesbaden“ und „Spielregion Hamburg“. Dieselbe Zuordnung war in der Provinzleiste sichtbar.
- **Erfahrener Spieler** Der reguläre Wirtschaftslauf führte ab Startkasse bis Monat 31 und bezahlte Produktion, Forschung und Infrastruktur. Seine 316 Prüfungen bestätigen die vorhandene Wirtschaftslogik. Die Kartenprüfungen deckten den Wechsel der Ansichten und die tatsächliche Grenzdarstellung ab.
- **Schneller Einstieg** Die Suche führte ohne manuelle Kartennavigation nach Lviv und Wiesbaden. Der gewählte Pin war selbst als Ziel nutzbar. In der Übersicht blieb nach direkter Provinzwahl nur die Spielregion ausgewählt.
- **Bug-Hunter** Vier Fehlprüfungen am unveränderten Build-31-Quellstand bestätigten die beiden Textprobleme, den fehlenden Pin und die getrennte Alt-Auswahl. Die Fälle mit Algier, Stadtbeschriftung und Hintergrundtipp prüften auch außerhalb des üblichen Suchpfads.
- **Geringe Ressourcen** Der Android-36-Emulator mit 4 GiB liefert die ursprüngliche Reproduktion mit Build 31. Der Touchlauf mit Build 32 lieferte zusätzlich die Reproduktion für das Antippen des Pins selbst. Build 33 hielt Wiesbaden nach zwei weiteren Berührungen an derselben Stelle ausgewählt. Das direkte Antippen der Spielregion Wien in der Übersicht löschte die Ortsmarkierung.

## 5. Priorisierte Befunde und Vorschläge

| ID | Schwere und MoSCoW | Befund und geplante Änderung | Aufwand · Nutzen · Risiko |
| --- | --- | --- | --- |
| BQ-006 | Medium · Must | Build 31, Android. Wiesbadener Gemeinde antippen. Im Kopf stehen zwei Namen ohne Rollen. Text und eigener Ortsmarker unterscheiden die Ebenen. | Klein · hoch · niedrig |
| BQ-008 | Medium · Must | Build 31, Windows-Quelltest. Nach Atlaswahl in die Übersicht wechseln und ein Spielgebiet antippen. Eine getrennte Atlas-ID kann zurückbleiben. Ortsname und visuelle Auswahl gemeinsam aktualisieren. | Klein · mittel · mittel |
| BQ-009 | Medium · Must | Im Android-Vorabstand 32 die Wiesbadener Gemeinde wählen und den Pin antippen. Der benachbarte Atlasort Sonnenberg kann erscheinen. | Das erste Eingabeereignis entfernte vorübergehend die Trefferfläche des Pins. Ein zweites Ereignis im selben Bild wählte die Fläche darunter. Die Referenz wird in einem Schritt gesetzt. | Klein · hoch · niedrig |
| BQ-010 | Medium · Must | Als WLAN-Gast den Atlasort Wiesbaden wählen und vom Host einen vollständigen Spielstand empfangen. Der Ort verschwand während der Aktualisierung. | Der Gast nimmt für vollständige Übertragungen ein neues Game-Objekt an. Eine solche Übertragung erhält den lokalen Atlasort. Ein neuer Start löscht ihn über die vorhandene Kartenanwahl. | Klein · mittel · niedrig |
| BQ-003 | High · Should | Die unveränderte JSON-Spitze bleibt ein Engpass auf schwächeren Geräten. Eigenständige Messung bei einem gestückelten Atlasformat. | Mittel · hoch · mittel |
| BQ-007 | High · Should | Profilierung beim Schwenken bei vierfacher Vergrößerung. Textlayout, Grenzdarstellung und Kartenbasis getrennt messen. | Mittel · hoch · mittel |

## 6. Umsetzung

AtlasLayer zeigt die aus Blender gerenderte Kompassmarke nur am aktiven Referenzort. Die Spitze liegt an der echten Kartenkoordinate. Die Darstellung reserviert ihre Fläche für die Beschriftungslogik. Der Pin bleibt innerhalb des sichtbaren Ausschnitts, und ein Tipp darauf wählt dieselbe Referenz.

Der Kartenkopf bezeichnet Referenzort und Spielregion. Die Provinzleiste zeigt den Zusammenhang bei aktivem Atlasort. MapView aktualisiert Atlas-ID und Ortsname gemeinsam. Eine direkte Provinzwahl, Armee- oder Baustellenauswahl löscht den Ortsbezug. Wiederholte Zeigerereignisse für dieselbe Position erhalten die Referenz zwischen den Renderbildern. Vollständige WLAN-Spielstände ersetzen die Spielwelt des Gasts und lassen dessen lokale Atlaswahl bestehen. Räume außerhalb der Spielregionen erhalten eine eigene Statuszeile. Die Quellgeometrie umfasst 224 Dreiecke. Blender-Generator, GLB und PNG sind Bestandteil des Projekts.

## 7. Verifikation und Regressionstest

- Der abschließende gerenderte Atlasintegrationslauf bestand 7.319 Prüfungen. Der Kartenlauf des Vorabstands bestand 73. Die Android-Reproduktion BQ-009 wurde als zwei Eingabeereignisse im selben Bild im Windows-Quelltest rot und nach der Korrektur grün nachvollzogen. Der Regressionstest fügt der echten Such- und Auswahlfolge den Pin, dessen Spitze, die Beschriftungsabstände und den direkten Provinzklick hinzu.
- 22.970 Atlasdatenprüfungen bestätigen die unveränderte Referenzgeografie. Die Kartenprobe prüfte 108 Gebiete, 25 Herzogtümer, neun Königreiche, drei Reiche und sechs Ansichtswege.
- 316 Produktions-, 284 Versorgungs-, 91 Flotten-, 58 Provinzereignis-, 50 Produktionsbefehls-, 37 Reichsvorhaben- und 35 Kriegsinteraktionsprüfungen bestanden. 20 Kalender-, 22 Ladephasen-, 445 aktuelle Spielstand-, 2.316 Migrations- und 16 Autoritätsprüfungen bestanden ebenfalls. Die Mehrspielerbefehle wurden auf dem lokalen Rechner nachvollzogen. Der Mehrspielertest mit vier lokalen Teilnehmern bestand nach Ergänzung der Gastansicht 38 Prüfungen. Derselbe gezielte Test hatte zuvor den Verlust der Referenz nach Übernahme eines neuen Weltstands reproduziert.
- Die ausgelieferte Windows-EXE bestand 400 Prüfungen. Der geprüfte Ablauf enthält Logo, Hausdesigner, 18 Kampagnenmonate, Pause und Fortsetzen, Speichern und Laden sowie die getrennte Beschriftung des Atlasorts und der Spielregion. Bei 200 Prozent Schriftgröße bleiben „Atlasort Wiesbaden“ im Kartenkopf und der Bezug in der Provinzleiste sichtbar. Der nachgestellte Hausname im Kartenkopf wird bei wenig Platz abgekürzt. Die vollständige Zeile steht im Tooltip.
- Nach Beenden des Prüflaufs stellte ein neuer EXE-Prozess aus dem gleichen isolierten Profil „Ari Paketprüfung“, Monat 19 und 184 Gold wieder her.
- Der Windows-Renderlauf bestand 29 Prüfungen bei 1600 × 900, intern 1280 × 720, auf der RTX 5070 Laptop GPU. Die Übersicht lag bei 59,4 FPS. Beim Schwenk mit vierfacher Vergrößerung waren es 35,7 FPS und 31,48 ms am 99. Perzentil. Die Messung bestätigt einen weiter offenen Schwenkengpass. Sie erfasst den Standardpfad ohne ausgewählten Referenzort.
- EXE und APK enthalten dieselben 66 Spielskripte und 24 Spieldateien. Die statische Prüfung erfasste 1.236 Dateien und bestätigte Build 33, APK-Signatur und Archivintegrität.
- Der erste Android-Durchlauf endete vor APK-Installation, weil der Emulator noch startete. Eine eigene ADB-Verbindung mit längerer Wartezeit lud einen echten Testspielstand und reproduzierte BQ-009 in Vorabstand 32. Beim ersten Installationsversuch von Build 33 lief die laufende Paketübertragung ins Zeitlimit. Die vollständige Übertragung vor der Installation war erfolgreich.
- Für Build 33 stimmen Prüfsummen des installierten Pakets und der APK in Downloads überein. Der 4-GiB-Android-36-Emulator zeigte den Godot-Startmarker nach rund 86 Sekunden. Nach Wahl des Gemeindetreffers im vorbereiteten Spielstand blieben Kartenkopf und Wiesbadener Pin nach zwei Berührungen erhalten. Die direkte Wahl von Wien entfernte die alte Ortsreferenz. Die Prozessmessung in dieser Sitzung meldete 2.316.674 KiB PSS und 402.181 KiB Swap-PSS. Startzeit und Speicherwerte beschreiben den einzelnen Emulatorlauf.
- Die Belege liegen lokal in **build/verify/qa-iteration-02**.

## 8. Offene Informationen

Physische Poco-Messungen und ein WLAN-Spiel auf zwei Geräten bleiben Teil der späteren Geräteprüfung.

## 9. Nächste Iteration

1. Erbfolge für lange Kampagnen. Ein gezielt hergestellter Zustand ohne Nachkommen und eingetragenen Erben endete beim Tod von Kral trotz sechs Hofpersonen mit Spielende. Dieser reproduzierte Ausgangspunkt dient der Prüfung von Adoption, Nebenlinien und politischer Nachfolge.
2. Spürbare Bildzeitausreißer beim Kartenschwenk nach Kartenbasis, Grenzlinien und Namensschildern untersuchen. Dafür dienen identische Kamerawege und isolierte Renderproben.
3. Atlas-Speicherspitze mit getrennten Metadatenblöcken messen. Kartenbestand und Suchrangfolge dienen als Abnahmekriterien.
4. Paket auf dem Poco und WLAN-Verlauf mit zwei physischen Geräten validieren, sobald die Geräte in einem gemeinsamen Zeitfenster verfügbar sind.
