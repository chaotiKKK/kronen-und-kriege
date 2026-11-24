# Örtliche Entscheidungen im Kampagnenlauf

**Ziel** Entscheidungen aus realen Provinzsituationen ändern den folgenden Spielverlauf. Deutscher Anlass, handlungsbezogene Vorschau und ein klares Recht des Hauses bleiben im gewohnten Ereignisfenster sichtbar.

**Architektur** RegionalEvents enthält sechs katalogisierte Szenen und liest Spielzustand. Game bleibt Eigentümer aller Entscheidungen. Der vorhandene persönliche Schlüssel pending speichert bei örtlichem Rat Ereignis-ID und kanonische Provinz-ID. Der Gastgeber interpretiert die Buttons anhand der Ereignisinstanz und seines tatsächlichen Spielzustands.

## Umsetzung

- [x] In RegionalEventsTest echte Provinz, vorhandenen Vorrat und eine angebotene Rationsentscheidung prüfen. Danach Monatsbuchung, Ablehnung beim Besitzwechsel und Spielstandrundlauf belegen. Den fachlichen Rotfall vor Code ausführen.
- [x] RegionalEvents liest Bedarf und Stimmung, Abgaben, feindliche Feldheere, fertig verbundene Marktorte und volle Kornkammern. Nur Szenen mit einer ausführbaren Hauptentscheidung ziehen. Bevorzugte Provinzen bei gleichem Zustand stabil nach ID auswählen. Örtliche Szenen höchstens bei jedem zweiten Ereignis und mit einem gemeinsamen Ziehungswert auslösen.
- [x] Game verwendet beim örtlichen Ereignis ausschließlich echte Rations-, Steuer-, Bau- und Forschungsaktionen. Der zweite Button behält die laufende Politik bei. Vor jeder Annahme Besitz und aktuellen Preis prüfen und nach Erfolg genau einmal schließen. Bekannte, inzwischen verlorene Standorte laden weiter und bieten den Abschluss ohne Aktion an.
- [x] ViewModelBuilder zeigt Ortsname, Anlass sowie tatsächlichen Preis und Inhalt je Button. Die vorhandene zugängliche Ereignisoberfläche und farbige Goldanzeige weiterverwenden.
- [x] Den Regelfingerabdruck um den neuen Katalog ergänzen. Den belegten historischen Build-25-Fingerabdruck nur für lokale WLAN-Dateien mit passendem Regionskatalog akzeptieren und das Original sichern.
- [x] Bezahlte Entscheidungen, unveränderte Alt-Ereignisse, einen Befehlsversuch für ein fremdes Gastgebiet, tatsächlich ausgelöste örtliche Szenen und zugehörige UI prüfen. Den Spielstandtest sowie die normalen Handels-, Bau- und Feldzugproben unverändert erneut ausführen.
