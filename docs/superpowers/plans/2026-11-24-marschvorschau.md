# Marschvorschau im Kriegsreiter

**Ziel** Wer eine Feldarmee am eigenen Grenzübergang führt, kann benachbarte Marschziele vergleichen und sieht, ob die Versorgung nach dem Schritt reicht.

**Architektur** Game baut mit einer Kopie der aktiven Armee dieselbe Versorgungsbilanz wie nach einem echten Marsch auf. Main gibt die abgeleitete Vorschau an Karte und Provinzleiste weiter. AtlasMotion zeichnet einen gerichteten Vorschaupfeil mit einem selbst modellierten Feldwimpel. Befehl und Netzwerkzuständigkeit bleiben beim vorhandenen Marsch.

- [x] In MarchCommandTest eine versorgte und eine unterbrochene Route aus demselben Ausgangszustand vergleichen. Die Vorschau lässt den laufenden Spielstand bytegleich und stimmt nach dem Marsch mit der am Ziel berechneten Bilanz überein.
- [x] Game.march_preview nutzt march_reason, den vorhandenen Versorgungsrechner und das jährliche Verlustbudget. Die Berechnung erfasst andere eigene Verbände im Ziel. Unzulässige Ziele liefern ausschließlich einen Grund.
- [x] Main berechnet die Vorschau für das ausgewählte Ziel im Kriegsreiter. ProvinceInspector zeigt Gelände, Zahl der gedeckten Soldaten, Nachschubanteil und gegebenenfalls Verlust bei unveränderter Lage. Die Karte zeichnet die ausgewählte Nachbarbewegung mit Pfeil und einen davon unterscheidbaren gezeichneten Wimpel. Bewegungsreduktion hält den Wimpel an.
- [x] Eine Testpartie öffnet das Ziel per Touch, legt die Vorschau in der Karte und in der Provinzleiste offen und befiehlt den Marsch mit der vorhandenen Schaltfläche. Nach der Aktion verschwindet die Vorschau. Windows-EXE und Android-APK bauen und gegen denselben Quellstand prüfen.
