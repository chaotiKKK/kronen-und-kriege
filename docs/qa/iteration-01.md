# Banger Queens · QA-Iteration 1

## 1. Ziel

Atlas und Suche im fertigen Spiel beschleunigen. Die Iteration prüft den Atlas zusammen mit repräsentativen Hauptpfaden der Kampagne. Sie erfasst außerdem die größten Risiken für Spielspaß und weitere Entwicklung. Ausgangspunkt ist Banger Queens 1.9.1, Build 30, Commit 91414ad.

## 2. Bestandsaufnahme

- Die Kampagne beginnt mit einem selbst gestaltbaren Haus. Provinzbesitz, Ausbau, Forschung, Feldheere und Nachfolge laufen in Monatszügen. Die 108 Spielregionen verwenden einen separaten Katalog von der Referenzgeografie. Drei freiwillige Reichsvorhaben verbinden reguläre Aufträge mit sichtbaren Zielen.
- Bau, zivile Versorgung und Krieg teilen endliche Arbeit, Baustoffe und Wege. Die Geld- und Versorgungssysteme liefern bereits konkrete Gründe für unterschiedliche Eröffnungen. Die laufende Partie entscheidet die meisten Ereignisse über einzelne Dialoge. Über mehrere Generationen bleibt der Weiterlauf von einem direkten oder hinterlegten Erben abhängig.
- Der Atlas umfasst 140.044 geografische Gebiete, 23.463 Orte und 175 Flüsse. Die Suche lief synchron mit jeder Texteingabe. Die Palette der Ansichten, ihre Blender-Modelle und reduzierte Bewegung verwenden dieselben Kartenregeln. Bestehende Build- und Prüfroutinen erlauben Proben an der exportierten EXE und einer einzelnen APK.
- Der Start lädt die vollständigen Atlasmetadaten im Kartenaufbau. Im früheren Emulatorlauf mit 4 GiB Gast-RAM dauerte es rund drei Minuten bis zum Titel. Der systemfremde Dialog während jenes Laufs und die ARM-Übersetzung verhindern einen Rückschluss auf das Poco.

## 3. Testmatrix

| Prüfung | Ziel und Vorgehen | Erwartung | Abbruchkriterium |
| --- | --- | --- | --- |
| Erststart und Neue Partie | Exportierte EXE im isolierten Profil vom Logo über Hauptmenü und Hausdesigner in eine Partie führen. Eine Provinz und ein Reichsvorhaben wählen. | Deutsches Menü reagiert, die Partie hat 108 Regionen, die Auswahl erreicht Karte und Provinzleiste. | Prozess beendet sich vor dem Menü oder die Eingabekette kann nicht fortgesetzt werden. |
| Core Loop und Wirtschaft | Mit regulärem Startgeld Ausbau, Forschung und Versorgung über Monatszüge durchführen. Preise, Auftrag, Fertigstellung und Einnahmen aus dem Zustand lesen. | Ertrag, Kosten und Warteschlange reagieren nachvollziehbar. Abhängigkeiten verändern die Karte oder den Bericht. | Inkonsistente Ressourcen, doppelte Vergütung oder ein irreversibel blockierter Fortschritt. |
| Krieg, Einheiten und Flotte | Feldheer formieren, Marsch, Versorgung, Belagerung, Rückzug und Flottenübergang an den vorhandenen regulären Szenarien ausführen. | Legale Befehle berechnen Kosten und Wege. Illegale Ziele ändern den Spielzustand nicht. | Fremde oder ungültige Befehle werden angenommen oder ein Heer verschwindet unerklärt. |
| Schnelles Eingeben und Reinzoomen | Kurze, mehrdeutige, genaue und ungültige Begriffe suchen. Treffergrenzen, Umlaute und Auswahl prüfen. Wiederholt Ansichten wechseln. | Gemessen schneller bei breiten Begriffen. Gleiche Trefferqualität, feste Auflösung von Gleichständen, unveränderte räumliche Auswahl. | Falscher Ort, verschwundene Detailstufe, anhaltend blockierte Eingabe oder Fehler beim Atlasaufbau. |
| Pause, Neustart und Spielstände | Uhr anhalten und wieder starten. Partiestand sichern, Anwendung mit isoliertem Profil erneut starten und den Stand laden. Kaputte und alte Stände an den bestehenden Prüffällen testen. | Datum bleibt im Pausenzustand stabil. Aktuelle und alte gültige Daten werden korrekt geladen, beschädigte Daten abgewiesen. | Verlust des Originalstands, Fortschritt während Pause oder stillschweigend ersetzter Spielstand. |
| Karten-UX und Barrierefreiheit | Echte Renderfenster mit Touch-Ereignissen für Suchtreffer, fünf Ansichten, 200 Prozent Schrift und Karten-Fokusmodus verwenden. | Treffer und wichtige Aktionen sind erreichbar. Moduswechsel behält den geografischen Ort. | Eingabe erreicht falsches Ziel oder eine erforderliche Aktion ragt aus dem Fenster. |
| Performance und geringe Ressourcen | Drei gepaarte Atlasläufe mit gleichen Eingaben erfassen. Vorher-/Nachher-Start, Ladezeit, Speicher und Renderdaten dokumentieren. APK im getrennten Android-Emulator installieren und bedienen. | Suchlatenz sinkt, Datenumfang und Darstellung bleiben vollständig. Das Paket erreicht ein bedienbares Menü und eine Kampagne. | Keine vergleichbare Messung, Abbruch durch Speicher oder fehlender Nachweis einer reagierenden Karte. |
| Mehrspieler und Fortschritt | Zwei ENet-Teilnehmer verwenden gültige und ungültige Befehle, gleichen Zustand ab und laden einen Altstand. Ereigniskatalog und Kampagnenabschluss prüfen. | Legitime Befehle sind bei Host und Gast identisch. Alte Stände behalten Sicherung und Kalender. | Unterschiedliche Ergebnisse oder schreibender Zugriff ohne Autorität. |
| Regression | Atlasdaten, gebaute EXE, APK-Integrität und gespeicherte Modelle gegen den unveränderten Katalog prüfen. | Keine Abweichung der Kartenquellen, Auswahlregeln oder Vertragsformate. | Verlorene Daten, skriptseitiger Fehler oder abweichende Paketinhalte. |

## 4. Probespiele und Testdurchläufe

- **Erstspieler** Der Titel, Hausdesigner und die erste Partie werden aus der fertigen EXE mit sauberen Profildaten bedient. Gemessen werden getrennt Programmstart und erfolgreich erreichte Spielhandlungen.
- **Erfahrener Spieler** Ein deterministischer regulärer Lauf investiert vorhandenes Gold in Forschung, Werkstätten und Markt und verfolgt tatsächliche Lieferungen, Nachschub und mögliche Bauunterbrechung.
- **Speedrunner** Der schnelle Einstieg und das erste erreichbare Vorhaben dienen als Ersatz für einen vollständigen Kampagnenrekord. Echte Monatszüge liefern die Vergleichsdaten für Ausbau, Fruchtwechsel und Feldheer. Zeit bis Kampagnenende wird aus diesem Szenario nicht geschätzt.
- **Bug-Hunter** 40 gleichnamige Einträge mit gegensätzlicher Eingabereihenfolge, unbekannte Orte, ungültige Pfade, Altstände und Mehrspielerbefehle werden gezielt erprobt. Die alte Suche reproduzierte eine unstete Reihenfolge bei sechs und 50 Treffern.
- **Geringe Ressourcen** Im getrennten Android-36-Profil mit 4 GiB RAM startete Build 31 bis zum Titel. Der Test lud einen regulär erspielten Stand. Aus der breiten Suche „a“ wurde Ankara gewählt. Die anschließende Suche nach Wiesbaden zeigte drei getrennte Treffer für Ort, Bezirk und Gemeinde. Die Gemeindeauswahl zentrierte den realen Ort. Es handelt sich um einen Softwaretest mit ARM-Übersetzung.

## 5. Bug- und Optimierungsliste

| ID | Schwere · Priorität | Befund und Reproduktion | Ist / Erwartung und Ursache | Aufwand · Nutzen · Risiko |
| --- | --- | --- | --- | --- |
| BQ-001 | High · Must | Build 30 unter Windows. Auf der Karte einen kurzen häufigen Begriff wie „a“ eingeben. Der isolierte Test ruft dieselbe Produktionssuche mit Limit sechs auf. | Der erste Ausgangsmesswert beträgt 1.880,60 ms. Erwartet wird eine zügig ansprechende Trefferliste. Die Suche sortiert sämtliche Texttreffer, obwohl nur sechs ausgegeben werden. Begrenzte Trefferauswahl. | Klein · hoch · niedrig |
| BQ-002 | Medium · Must | Build 30 auf beiden Plattformen. Gleichnamige gleich bewertete Orte mit unterschiedlichen IDs abfragen. Liste auf sechs und 50 Treffer begrenzen. | Die alte Rangfolge hängt von den Sortierumständen ab. Dieselbe Ranggruppe soll eine reproduzierbare Reihenfolge haben. Stabile Orts-ID als letzter Vergleichsschlüssel. | Klein · mittel · niedrig |
| BQ-003 | High · Should | Vollständigen Atlas in einem frischen Prozess laden und Godot-Speicher während der JSON-Phase protokollieren. Frühere Startprüfung im 4-GiB-Emulator heranziehen. | Beim Ausgangslauf liegen rund 1.399 MiB in der Spitze vor. Aufbau und Kopieren kosten zusätzliche Zeit. Direkte Normalisierung ist klein. Für die Peak-Senkung braucht es einen separat gemessenen, gestückelten Leser. | Klein für CPU, mittel für Datenformat · hoch · mittel |
| BQ-004 | High · Should | In einer langen Partie stirbt der menschliche Herrscher ohne Kandidaten in der aktuellen Nachfolgefunktion. | Der Zustand endet regelgerecht. Für durchgehende Dynastiekampagnen fehlen ergänzende Entscheidungen über Adoption, Nebenlinie und Wahl. | Mittel bis groß · hoch · mittel |
| BQ-005 | Medium · Could | Mehrere Provinzräte in langen Wirtschaftspartien auslösen. | Der Katalog nutzt echte Zustände und kurze Wiederholungssperren. Mehrstufige wirtschaftliche oder politische Folgen fehlen. | Mittel · mittel · mittel |
| BQ-006 | Medium · Should | Auf Android Build 31 nach „Wiesbaden“ suchen und „Gemeinde“ antippen. Der reale Kartenausschnitt springt nach Wiesbaden. In der Provinzleiste steht „Hamburg“. | Der Mittelpunkt gehört laut Spielregionengeometrie zu germanien__02 mit Anzeigename Hamburg. Die Oberfläche sollte die reale Ortsauswahl und das größere spielbare Gebiet eindeutig beschriften. | Klein · mittel · niedrig |
| BQ-007 | High · Should | Den Windows-Kartentest bei vierfachem Zoom und bewegter Kamera ausführen. | Das Fenster erreicht im Schwenk 36,1 FPS mit 38,74 ms am 99. Perzentil. Rund 4.344 Zeichenaufrufe und 1,20 Mio. Primitive geben Anhaltspunkte für die nächste Profilierung. Atlas, Gameplay-Linien und UI müssen dafür einzeln vermessen werden. | Mittel · hoch · mittel |
| QA-001 | Medium · Must | Kalendermigration mit einem absichtlich auf Schema 11 umetikettierten aktuellen Spielstand aufrufen. | Fortschritt der zivilen Vorräte machte die Testeingabe widersprüchlich. Der kalendarische Test muss Felder verwenden, die es beim alten Schema gab. Testdatensatz korrigiert. | Klein · mittel · niedrig |

## 6. Änderungen

Der Atlasleser normalisiert seine gerade eingelesenen Datensätze direkt. Die Akzenttabelle wird wiederverwendet. Die Suche begrenzt ihre sortierte Arbeitsliste auf die angefragte Größe. Namensart, Einwohnerwertung und alphabetische Reihenfolge bleiben erhalten. Bei vollständigem Gleichstand entscheidet die stabile Orts-ID. Der Regressionstest prüft verschiedene Limits und sowohl einen künstlichen Gleichstand als auch echte Orte.

Die priorisierten Spielideen sind in [Vorschläge für den Ausbau](../banger-queens-ausbau.md) beschrieben.

## 7. Verifikation und Regression

Drei gepaarte Windows-Läufe messen dieselben Daten und Abfragen in separaten Godot-Prozessen. Bei der Suche geht pro Lauf der Median von fünf Aufrufen ein. Die Zeit des Atlasaufbaus deckt das Laden und Indexieren ab.

| Messwert | Build 30 | Kandidat |
| --- | ---: | ---: |
| Atlasaufbau | 4977,00 ms | 3616,00 ms |
| Suche „a“ | 1769,15 ms | 101,24 ms |
| Suche „ber“ | 108,04 ms | 74,36 ms |
| Suche „Wiesbaden“ | 80,08 ms | 73,53 ms |
| Godot-Speicherspitze | 1398,80 MiB | 1398,80 MiB |

Die breite Suche benötigt rund 94 Prozent weniger Zeit, der Atlasaufbau rund 27 Prozent weniger. Die ausgewiesene Godot-Speicherspitze bleibt bei circa 1.399 MiB. Die vollständigen 140.044 Gebiete, 23.463 Orte und 175 Flüsse erscheinen in allen sechs Protokollen.

- 22.970 Atlasdatenprüfungen, 7.239 gerenderte Atlasintegrationsprüfungen, 73 gerenderte Kartenprüfungen und 22 Ladephasenprüfungen bestanden. Die Atlasintegration prüfte zwei tatsächliche Touch-Eingaben bei gerendertem Fenster und 200 Prozent Textgröße. Im kopflosen Versuch wich die effektive Fenstergeometrie beim Kartenfokus ab. Das Referenzfenster zeigte die erwartete Flächenvergrößerung.
- Der Windows-Renderlauf bestand 29 Prüfungen bei 1600 × 900 Fenstergröße, 1280 × 720 internem Viewport, OpenGL-Kompatibilitätsrenderer und deaktiviertem VSync. Die Kartenübersicht erreichte 58,5 FPS mit 22,67 ms am 99. Perzentil. Beim Schwenk in vierfacher Vergrößerung waren es 36,1 FPS und 38,74 ms. Die Werte beschreiben diesen Lauf auf der RTX 5070 Laptop GPU.
- Die exportierte Windows-EXE bestand 389 Prüfungen. Dazu zählen Hausdesigner und Start in 108 Regionen, 18 regulär gespielte Monate über das Skript, Pausieren und Fortsetzen, Spielstand laden und unveränderte Atlasressourcen. Der Start in diesem Paketlauf dauerte 17,77 Sekunden einschließlich eingefügter Prüfschritte. Ein Vergleich des Gesamtstarts braucht gepaarte Messungen.
- Die reguläre Produktionsprobe erreichte Monat 31 aus der normalen Kasse und bestand 316 Prüfungen. Dazu kommen 284 Versorgungsprüfungen, 37 Reichsvorhabenprüfungen, 64 Festungsprüfungen, 54 Landheerprüfungen und 91 Flottenprüfungen. Die Ereignissuiten bestanden 263 und 58 Prüfungen.
- 50 Produktions- und ENet-Befehlsprüfungen sowie 16 Autoritätsprüfungen bestanden. 2.316 Altdatenprüfungen, 445 aktuelle Versorgungs-Save-Prüfungen und 20 Kalenderprüfungen decken Migration, ungültige Daten und Jahreswechsel ab.
- Der erste Kalenderlauf scheiterte an einem synthetischen Altstand mit modernen, inzwischen veränderten Nahrungsvorräten. Das reproduzierte die vorgesehene Ablehnung eines widersprüchlichen Inputs. Der korrigierte Test verwendet historische Felder und bestätigt die Migration von Jahr null samt unveränderter Restfrist.
- Die Pakete enthalten dieselben 66 Spielskripte und 24 Spieldateien. Sie tragen die Anzeigeversion 1.9.1. APK-Signatur, ZIP-Ausrichtung und Buildnummer 31 wurden geprüft.
- Ein eigener Prozess mit derselben exportierten EXE und dem isolierten Profil lud „Ari Paketprüfung“ in Monat 19 mit 184 Gold. Der Test verglich die geladenen Werte mit der zuvor geschriebenen Datei.
- Das installierte Android-Paket entsprach der geprüften APK per SHA-256. Der Godot-Startmarker erschien nach etwa 3:08 Minuten. Danach waren Hauptmenü, Spielstand und beide Ortssuchen bedienbar. Die graue Phase vor dem Titel bleibt auf diesem Emulator ein offener Startbefund.

Die Detailprotokolle liegen lokal unter **build/verify/optimization-20261124**.

## 8. Offene Informationen

Physische Poco-Messreihen und ein WLAN-Spiel zwischen zwei Geräten stehen für diese Iteration aus. Framezeiten des x86-Emulators können wegen der ARM-Übersetzung nicht mit dem Poco gleichgesetzt werden.

## 9. Nächste Iteration

1. Erbfolge bei fehlenden direkten Nachkommen abbilden. Adoption, Nebenlinie und Wahl anhand derselben Ansprüche und Legitimität vergleichen.
2. Atlasaufbau und Kartenpan getrennt profilieren. Gestückelte Metadaten gegen die Speicherspitze und isolierte Renderdurchgänge beim vierfachen Schwenk prüfen.
3. Ortsauswahl und Namen größerer Spielregionen in Karte und Provinzleiste eindeutig kennzeichnen. Wiesbaden und die Spielregion Hamburg dienen als Reproduktion.
4. Einen Lagebericht für eigene Regionen am Produktions- oder Versorgungsausfall erproben. Er soll den betroffenen Ort und die nächste mögliche Handlung zeigen.
5. Prüfen, ob eine bezahlte Versorgung über eine geteilte Route in zwei physisch verbundenen Geräten stabil fortgesetzt werden kann.

Für die nächste Bestandsaufnahme ist bereits belegt, dass das Familienrecht derzeit „Ältester zuerst“ und „Jüngster zuerst“ auswertet. Bestehende Kandidatenlisten und das Hofpersonal sind mögliche Grundlagen für ein prüfbares Nachfolgeangebot. Der erste Testfall startet ohne direkte Nachkommen und prüft Anspruch, Zustimmung, Nachfolge sowie einen anschließenden Spielstand-Roundtrip.
