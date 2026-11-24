# Frontnachschub über eigene Straßen

**Ziel** Ein gebautes Depot bleibt verwendbar, wenn ein Heer über eine fertig verbundene eigene Grenzregion weiter vorrückt. Die Kriegskarte zeigt die tatsächlich berechnete Route des eigenen Hauses.

**Entwurf** DepotSupply ermittelt vom Depot erreichbare eigene Straßenknoten. Jeder fremde Empfänger mit einem eigenen Heer wird genau einmal über den kürzesten offenen Grenzübergang zugeordnet. Die letzten Provinzen des Wegs sind der Übergang unter eigener Kontrolle und das angrenzende Ziel. Quellenüberschuss, Depotgrenze, eigener Binnenbedarf und stabiler Mengenabgleich werden aus der bestehenden Berechnung übernommen. Die Karte liest die gleiche Bilanz wie der Provinzinspektor.

## Umsetzung und Prüfung

- [x] In DepotSupplyTest den bestehenden direkten Fall um den belegten Weg ergänzen. Eine fertig verbundene eigene Grenzregion liefert, eine unfertige, blockierte oder fremd kontrollierte Straße liefert null. Gleich lange Wege bleiben stabil. Ein fremder Empfänger leitet keine Mengen weiter. Den fachlichen Fehler vor der Änderung reproduzieren.
- [x] In DepotSupply den bisherigen Graphen je Depot um Pfade erweitern. Ziele in Streckenlängen- und Regionsreihenfolge sammeln. Das bestehende Mengenlimit verwenden und pro Lieferzeile `path` ausgeben.
- [x] In ProvinceInspector für ein versorgtes Frontheer Depot und Grenzregion im vorhandenen Versorgungsabschnitt anzeigen. In MapView berechnete Pfade im Kriegsmodus mit mintfarbener Linie darstellen. Die Kartenlegende benennt die Linie. Rendering liest die vorhandene Versorgungskopie aus Main.
- [x] Bestehende lokale Schema-19-WLAN-Dateien mit dem exakten V24-Fingerabdruck und passendem Regionskatalog sichern und weiter öffnen. Alte Netzwerkteilnehmer bleiben über den Regel-Fingerabdruck inkompatibel.
- [x] Die vier unveränderten regulären Testpartien erneut ausführen. Mindestens eine tatsächliche bezahlte Versorgungskette muss fertige Straßen, Depot, vorhandenen Überschuss und geringeren Fehlbedarf nachweisen. Die kontrollierte Vergleichspartie prüft die Wirkung auf den Belagerungsschritt. Die Kartenprüfung erfasst Pfad, Darstellung und Sperre auf falschem Kartenreiter.
