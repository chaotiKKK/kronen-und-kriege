# Banger Queens: verbindlicher Ausbauentwurf

Stand: 2026-11-09. Die Abschnitte 1–6 wurden im Gespräch bestätigt. Der Nutzer hat anschließend sämtliche Detailentscheidungen und die autonome Umsetzung freigegeben.

## 1. Produkt und bestehender Arbeitsstand

Das bestehende Godot-Projekt wird unter dem Titel **Banger Queens** weiterentwickelt. Gewählt ist Weg 1: evolutionärer Ausbau der vorhandenen Regeln, UI, Tests und 2,5D-Karte. Windows und Android teilen den Spielkern. Android wird nativ für ARM64 gebaut; alle Laufzeitinhalte sind in einer APK enthalten, ohne manuellen Datenimport. Deutsch ist die einzige angebotene Sprache.

Premium-2,5D bedeutet Relief, hochwertige gerenderte Kartenobjekte, Materialien, Wasser, Wetter, saisonale Varianten, nachvollziehbare Animationen und lesbare Beschriftungen. Die Qualitätsrichtung orientiert sich an modernen Strategiespielen. Gleichwertigkeit mit CK3 ist ein langfristiger gestalterischer Anspruch, kein bereits erreichtes oder durch einen Enginewechsel garantiertes Ergebnis.

Ausgangspunkt am 2026-11-09: `main`, HEAD `193cfc7`, Godot-Kompatibilitätsrenderer, Save-Schema 11, 49 europäische Provinzen. Zahlreiche lokale Änderungen und unversionierte Assets gehören zum übernommenen Stand. Deren bisher dokumentierte Tests gelten nicht automatisch als Nachweis für neue Builds. Sicherung vor Änderungen: `build/checkpoints/20261109-banger-queens-before/`.

## 2. Eine Kampagne über 4200 Jahre

Die reguläre Kampagne enthält Januar 2000 v. Chr. bis Dezember 2200 n. Chr.: 4200 dargestellte Kalenderjahre und 50.400 Monatszustände. Auf Dezember 1 v. Chr. folgt Januar 1 n. Chr. Der nullbasierte Monatsindex ist die gemeinsame Rechenbasis für Fristen, Chronik, Forschung und Epochen. Das Ende stoppt den Zeitlauf und bietet die Fortsetzung als Sandbox an; die Abschlusschronik wird als eigene Ausbaustufe ergänzt.

Standardziel sind rund 60 Stunden tatsächliches Spielen, mit einer Zielspanne von 50–70 Stunden einschließlich üblicher Entscheidungen. Schnell: 25–35; episch: 90–130; Marathon: 150–250 Stunden. Das sind Balancierungsziele, keine bereits gemessenen Laufzeiten. Pause bleibt jederzeit möglich. Beschleunigung darf Entscheidungen nicht auslassen; gebündelte Berechnung muss dieselben relevanten Ergebnisse wie Einzelticks ergeben.

Acht Darstellungs- und Regelpakete bilden Bronzezeit, Antike, Mittelalter, frühe Neuzeit, Industriezeit, Weltkriegs-/Systemzeitalter, Informationszeit und Zukunft ab. Die Namen beschreiben Entwicklungsstände. Regionale Übergänge hängen von Bedingungen ab und sind weder gleichzeitige globale Resets noch eine historische Ereignispflicht.

Alternative Geschichte beginnt mit der ersten Entscheidung. Historische Daten begründen die Ausgangslage, Wissen und Wahrscheinlichkeiten; spätere Reiche, Religionen, Grenzen, Erfindungen und Revolutionen werden nicht erzwungen. Zukunftsinhalte sind ausdrücklich spekulative Entwicklungen aus dem Kampagnenzustand.

## 3. Forschung und sichtbare Technik

Wissensgebiete: Nahrung, Bau/Werkstoffe, Verkehr, Militär, Medizin, Recht/Verwaltung, Handel/Finanzen, Bildung/Kommunikation, Energie/Industrie, Naturwissenschaften, Information/Automatisierung und Institutionen.

Jede Innovation unterscheidet Entdeckung, praktische Erprobung und Verbreitung. Voraussetzungen verbinden Wissen, Infrastruktur, Ressourcen und Institutionen. Höfe, Werkstätten, Schulen, Universitäten, Handel und Migration übertragen Wissen. KI und Spieler nutzen dieselben Regeln. Eine Entdeckung baut kein Reich automatisch um.

Konkrete Projekte verändern die Karte und die Simulation: Pfade/Straßen, Brücken, Kanäle, Häfen, Schienen, Städte, Landwirtschaft, Bergwerke, Industrie, Energie- und Kommunikationsnetze. Ein Netz besitzt reale Endpunkte, Bauzustand, Besitzer und messbare Wirkungen. Schäden und Reparaturen sind sichtbar. Detailstufen bündeln entfernte Objekte, ohne Infrastruktur aus dem Spielzustand zu entfernen.

Erster prüfbarer Forschungs-/Infrastrukturausschnitt: Vermessung und Straßenbau erforschen; eine Verbindung zwischen zwei benachbarten eigenen Provinzen bauen; Baustand und fertige Straße zeichnen; Nutzen für Wirtschaft nachweisen; denselben Zustand speichern und laden. Schienen und spätere Netzarten verwenden später denselben Ansatz, werden in diesem Ausschnitt jedoch nicht als fertig ausgewiesen.

## 4. Figuren, Identität und Nachfolge

Charaktererstellung und bestehende Haus-/Familienfunktionen bleiben bedienbar. Name, Herkunft, Erscheinung, Alter, Fähigkeiten, Wappen und politische Ausgangslage prägen die Figur. Alter, Erfahrungen, Gesundheit, Kleidung und Epochen verändern ihre Darstellung.

Das historische Vermächtnis kann über Blutlinie, Adoption, Nebenlinie, Ehe, Wahl oder politische/institutionelle Nachfolge fortgesetzt werden. Diese Übergänge besitzen belegte Kandidaten und unterscheiden sich in Legitimität, Widerstand, Eigentums- und Bündnisfolgen. Hauptliniensterben allein beendet die Kampagne nicht. Die vollständige Nachfolgeerweiterung ist eine eigene Ausbaustufe; bisherige Nachfolgeregeln dürfen dadurch nicht stillschweigend als vollständig ersetzt gelten.

## 5. Weltmodell

Europa ist der detaillierte spielbare Kern. Außereuropäische Staaten und Gesellschaften bleiben eigenständig handelnde NPCs. Angrenzende Regionen erhalten mittlere, ferne Regionen aggregierte Detailtiefe. Handel, Migration, Wissen, Krankheiten, Religionen, Diplomatie, Krieg und Umwelt koppeln die Räume.

Ein europäisch begonnenes Vermächtnis bleibt bei späteren Verlagerungen fortsetzbar; die Start-/Übernahmeliste bietet europäische Häuser und deren legitime Nachfolger an. Außereuropäischer Besitz und Kontakte sind möglich. Die Weltübersicht zeigt globale Zusammenhänge, Europa die detaillierte Karte. Eine globale, vollständig simulierte NPC-Welt ist Ausbauziel, kein Befund des heutigen Neun-Häuser-Modells.

## 6. Zusammenhängende Systeme

Figuren/Familie, Dynastie, Herrschaft, Gesellschaft, Wirtschaft, Forschung, Diplomatie, Krieg, Umwelt und Intrige verändern einander. Der vorhandene Depth Contract bleibt maßgeblich: Zustandsbesitz, erklärbare Folgen, gemeinsame KI-/Spielerkommandos, persistente Daten und negative Kontrollen.

`Game.gd` bleibt Transaktionsgrenze. `UiKernel.gd` routet Absichten; `ViewModelBuilder.gd` erstellt Anzeigen; `MapView.gd`/`MapBase.gd` projizieren Zustand; `SaveGame.gd` besitzt Migration und Validierung. Neue eng begrenzte Helfer werden nur für benötigte Verantwortung ergänzt. Es erfolgt kein pauschaler Engine-/Renderer-Neubau.

Die akzeptierten Zusatzinhalte umfassen abstrakten Drogenhandel mit Cannabis, weiteren belegten historischen Gütern und später Amphetamin sowie Verführung ausschließlich unter Erwachsenen mit Zustimmung und Abbruch. Verfügbarkeit folgt Forschung und belegtem Kontext; bewusste Abweichungen werden als alternative Geschichte erklärt. Beziehungen werden nicht explizit dargestellt. Handelsregeln behandeln Nachfrage, Recht, Schmuggel, Steuern, Gesundheit und politische Folgen als Spielmechaniken. Die Inhalte werden als eigene, abschaltbare Erweiterungen geplant.

## 7. Bedienung und Darstellung aus den bestehenden Anforderungen

Eine vollständige Partie muss mit Touch möglich sein: Auswahl, Kartenbewegung, Zoom, Scrollen, Texteingabe, Charaktererstellung, Forschung, Bau und Save/Load. Buttons besitzen ausreichend große Trefferflächen. Dialoge bleiben auch bei 200 % Textgröße scrollbar; Bestätigen und Schließen sind erreichbar. Lange Namen, mehrzeilige Eingabe und Android-Tastatur dürfen keine wesentlichen Aktionen verdecken.

Themen für helle, dunkle und hohe Kontraste, Unterschiede zusätzlich zu Farben, lesbare Typografie und eine Option für reduzierte Bewegung gehören zum Ausbau. Moderne Darstellung wird anhand tatsächlicher Ingame-Bilder bewertet. Vorgerenderte Werbung gilt nicht als Kartenverbesserung.

Ladeanzeige: messbarer Ressourcenfortschritt darf Prozentwerte liefern. Ohne Messwert werden Phase und Laufzeit angezeigt. Die bestehende zeitbasierte Prozentanimation in `Loading.gd` muss durch ehrliche Statusanzeige ersetzt werden. Das frühere Fünf-Minuten-Limit ist aufgehoben. Absturzfreiheit, nachvollziehbare Fehler und Speicherbudget bleiben erforderlich.

## 8. Abfolge eigenständig prüfbarer Ausbaustufen

| Stufe | Ergebnis | Abnahme |
|---|---|---|
| BQ-01 | Produktname, beständige Save-Pfade, Kampagnenkalender | Jahreswechsel ohne Jahr null, Fristen/Migration, Endpunkt, Charakterstart und Wiederladen |
| BQ-02 | Forschung und sichtbarer Straßenbau | Forschung benötigt Zeit, Bau braucht Voraussetzungen, Straße wirkt und bleibt nach Neustart sichtbar |
| BQ-03 | Premium-Karte und zugängliche UI | vergleichbare Ingame-Bilder, Touch, 200-%-Text, Themes, reale Frame-/Speichermessung |
| BQ-04 | langfristiges Vermächtnis | Adoption, Nebenlinie, Wahl und politischer Übergang, jeweils mit Save-Roundtrip |
| BQ-05 | Epochen und Wissensverbreitung | Übergänge ohne Zustandsverlust, regionale Unterschiede, 60-Stunden-Balance |
| BQ-06 | globale NPC-Räume und spätere Wirtschaft/Kriegsformen | wirksame gegenseitige Folgen, begrenzte Rechen-/Speicherkosten |
| BQ-07 | zusätzliche Ereignis- und Handelspakete | Regel-, Zustimmungs-, Alters-, Persistenz- und Abschaltprüfungen |
| BQ-08 | vollständige Langzeitabnahme | Kampagnenläufe, Nachfolgen, Epochen, Windows und Poco, vollständiges Wiederladen |

Jede Stufe besitzt einen eigenen Umsetzungsplan. Die Reihenfolge BQ-01 → BQ-02 bildet die jetzt begonnene Strecke. Das Gesamtspiel wird erst als durchspielbar bezeichnet, wenn Nachfolge, Epochen und Inhalte tatsächlich implementiert und getestet sind. Ein Kalenderdurchlauf allein beweist das nicht.

## 9. Verifikation und Auslieferung

Für jede Änderung: passende Logiktests; bestehende Regressionstests; Save-Migration/Roundtrip; tatsächliche Bildprüfung bei Renderer-/UI-Änderungen. Mehrfachstarts und vollständiges Beenden/Wiederladen prüfen veröffentlichte Binärdateien, nicht nur Quellcode. Teststand, Seed, Plattform, Dauer und Fehler werden protokolliert.

Windows-Ziel bleibt zusätzlich das zuvor vereinbarte schwache Systemprofil (8 GB, vier Kerne, integrierte Grafik, 720p/30 FPS). Poco F7 ist das primäre Android-Ziel. Emulatorresultate werden ausdrücklich als solche ausgewiesen und ersetzen keine Gerätemessung. ADB-Zugriff erfolgt nur auf die ausdrücklich identifizierte und freie Geräte-ID; parallele Spielprojekte erhalten eigene Emulator-/App-IDs. Sichtbare Windows-Läufe ausschließlich auf dem rechten Monitor.

Die APK enthält das eigene Spiel. Exportfilter schließen lokale Sicherungen, Referenzen und Tests aus. Paketkennung und Signaturschlüssel bleiben für Update-/Datenkontinuität zunächst erhalten, auch wenn sichtbarer Produktname und Dateinamen wechseln. Ein APK-Export gilt erst nach Installations-/Startprüfung als Geräteerfolg. Reproduzierbare Builds, Hashes und Grenzen stehen im Prüfbericht.

## 10. Erster technischer Schnitt: Kalenderkompatibilität

Ein kleiner `CampaignCalendar.gd` besitzt Datums-/Indexumrechnung. Für laufende Legacy-Aufrufer bleiben `Game.year` und `Game.month` vorerst kompatibel; alle absoluten Fristen verwenden eine gemeinsame Monatsfunktion. Ein Save erhält Kalenderformat und Monatsindex, die gegen Jahr/Monat geprüft werden.

Neue Kampagnen verwenden den Kalender ohne Jahr null. Bereits vorhandene Saves besitzen die alte fortlaufende numerische Jahresrechnung einschließlich Jahr null. Migration erhält die vergangene Dauer: altes Jahr 0 wird Jahr 1 n. Chr., altes Jahr 1 wird Jahr 2 n. Chr. Die sichtbare Korrektur wird in der Migration dokumentiert. Relative Restfristen und Chronikabstände bleiben erhalten. Für bestehende absolute Fristen und Chronikwerte liefert die Kompatibilitätsfunktion `_now()` den neuen nullbasierten Monatsindex plus eins; die gespeicherten Altwerte müssen dadurch nicht verschoben werden.

Ein reiner Kalendertest besucht sämtliche 50.400 Monate und prüft Umkehrbarkeit. Ein echter Spieltest prüft den Jahreswechsel, Wirkungen genau einmal, Fristen und Save-Roundtrip. Er ersetzt keinen vollständigen 4200-Jahre-Spielnachweis.
