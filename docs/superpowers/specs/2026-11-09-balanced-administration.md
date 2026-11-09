# Landesübergreifend vergleichbare Verwaltungsebenen

Nutzerkorrektur vom 09.11.2026: Deutschland besitzt bislang eine zusätzliche kommunale Detailebene, die anderen Länder nicht. Gewünscht sind ausdrücklich **echte Verwaltungsebenen überall vergleichbar detailliert**, keine künstlich gleich großen Spielgebiete. Dieser Auftrag erweitert den Atlasplan.

## Bedeutung der Anforderung

- Echte administrative Gliederungen bis zur jeweiligen kommunalen/lokalen Verwaltungsebene über den gesamten vorhandenen Kartenausschnitt erschließen.
- Administrative Ebenennummern und Objektzahlen allein sind kein Maß für Vergleichbarkeit. Natural Earth nennt etwa französische Départements, italienische Provinzen und maltesische Local Councils alle `admin_1`; ihre tatsächlichen Rollen unterscheiden sich.
- Einheitliche Darstellungsrollen `region`, `district`, `municipality` anhand dokumentierter landesspezifischer Verwaltungsrollen zuweisen. Quell-Ebenennummer, amtliche Bezeichnung, Stand und Herkunft zusätzlich erhalten.
- Vorhandene echte kommunale Einheiten kleiner Länder wiederverwenden; nicht durch erfundene feinere Zellen ergänzen. Fehlende Daten sind keine implizite Abdeckung und werden nicht durch Umbenennen von Kreisen zu Gemeinden kaschiert.
- Die bestehenden 49 simulierten Spielgebiete bleiben durch diese kartografische Erweiterung unverändert. Mehr gezeichnete Gemeinden erzeugen kein zusätzliches Gold, Aufgebot oder KI-Handlungen.

## Quellen und Abdeckungsnachweis

- Overture Divisions als möglicher globaler Rahmen: offene ODbL-Geodaten, aber die Dokumentation nennt lückenhafte Abdeckung unterhalb der Kreisebene. Allein daraus folgt kein Vollständigkeitsnachweis.
- Semantisch geprüfte geoBoundaries-gbOpen-Ebenen und amtliche offene Daten ergänzen reale kommunale Flächen. Quelllizenzen einzeln prüfen und erforderliche Attribution/Weitergabebedingungen erhalten.
- Für jedes Land beziehungsweise Gebiet im tatsächlichen Ausschnitt: maßgebliche Verwaltungsebenen, Quellenstand, verarbeitete Einheitenschlüssel, Anteil durch lokale Flächen abgedeckter Landfläche und verbleibende Lücken dokumentieren.
- Abdeckung mit der geometrischen Vereinigung gültiger lokaler Flächen relativ zur Landeslandfläche im Ausschnitt messen; keine Gleichsetzung von Feature-Anzahl mit Prozentabdeckung.
- Tests decken Deutschland und mehrere Nachbarländer ab, erkennen fehlende Ebenen, falsche Rollen und eine weiterhin einseitige Detailabdeckung. Nicht verfügbare tatsächliche Daten bleiben als offen erkennbar.

## Umsetzung

1. Aktuellen Country-/Level-Bestand auditieren; offizielle Quellen und landesspezifische Rollen prüfen.
2. Einen kleinen realen Overture-Pilot extrahieren und die tatsächliche lokale Abdeckung messen; geoBoundaries-/amtliche Kandidaten ergänzen.
3. Importvertrag und Quellenmanifest um Rollen, Datenstände und Abdeckungswerte erweitern. Neue Verwaltungsdaten testgetrieben normalisieren und einbetten; keine Rohdownloads im Git-Baum.
4. Renderer verwendet identische Bildschirm-/Zoomkriterien für dieselbe Verwaltungsrolle in jedem Land. Falls der größere Bestand den bisherigen gemeinsamen Index überlastet, nach LOD getrennte Kandidatenindizes beziehungsweise räumlich abgegrenzte Datenpakete einsetzen.
5. Gleiche Zoomausschnitte mehrerer Länder tatsächlich rendern. Erst nach Prüfung von Geografie, Lesbarkeit, Quellen und Paketinhalt die erweiterte Version veröffentlichen.
