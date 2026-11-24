# Reichsvorhaben für die Spieleröffnung

**Ziel** Eine Partie bietet aus der ersten Spielminute verschiedene Aufbaurichtungen mit konkreten Orten, überprüfbarem Fortschritt und einmaligen Belohnungen.

**Architektur** Reichsvorhaben bilden einen begrenzten Abschnitt des Hauszustands. Game entscheidet über Annahme, Abbruch und Auszahlung. Die Regeln lesen die vorhandene Provinzwirtschaft, Baustellen, Karte und Armee. Chronik und Karte stellen denselben ausgewählten Ort dar. LAN validiert die Befehle samt laufender Kennung.

- [x] Eine reguläre Partie prüft, dass ein Reichsvorhaben aus den Startmöglichkeiten gewählt werden kann, vorzeitig kein Gold gibt und nach tatsächlich ausgeführten Spielaktionen genau einmal ausgezahlt wird.
- [x] Straßenbund verlangt eine bei Annahme fehlende eigene Verbindung. Kornkammer verlangt landwirtschaftlichen Schwerpunkt, Fruchtwechsel und Vorrat für vier Normalrationen. Grenzwacht verlangt am gewählten Grenzort eine zusätzliche Mauerstufe und ein eigenes kampffähiges Feldheer. Verlust eines Zielorts blockiert die Auszahlung. Ein freiwilliger Abbruch lässt eine neu gewählte Aufgabe beginnen.
- [x] Speichern, laden, fremde Ziele, abgelaufene Kennungen, erobertes Land und alte WLAN-Dateien prüfen.
- [x] Chronik zeigt die drei Angebote beziehungsweise den aktiven Auftrag. Die Karte kennzeichnet dessen Ort und bietet einen direkten Sprung. Windows und Android aus demselben Stand bauen und prüfen.
