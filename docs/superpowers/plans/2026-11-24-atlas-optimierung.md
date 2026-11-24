# Atlasaufbau und Ortssuche optimieren

**Ziel** Das Eingeben breiter Suchbegriffe bremst die Karte weniger. Der Atlas benötigt beim Aufbau weniger Arbeit und dieselben geografischen Daten bleiben nutzbar.

**Architektur** Der bestehende Atlasleser verarbeitet seine frisch geparsten Datensätze direkt. Die Ortssuche hält nur die Treffer, die innerhalb der angeforderten Trefferzahl liegen. Exakte Namen kommen vor Namensanfängen, danach folgen Namensbestandteile. Einwohnerwertung und alphabetische Sortierung bleiben maßgeblich. Bei weiterem Gleichstand entscheidet die stabile Orts-ID.

**Ausführung** Die Schritte werden nacheinander in diesem Arbeits-Checkout ausgeführt. Das Ausgangsverhalten und die Kandidatenmessung nutzen den gleichen Godot-4.5.1-Test auf derselben Maschine. Datenumfang, Grenzen, Maßstabsverhalten, Quellen und Ladeangaben werden über die vorhandenen Atlasprüfungen kontrolliert.

- [x] In tests/AtlasDataTest.gd eine Testmenge mit identischen Namen, verschiedenen Wertungen, exakten und weiteren Treffern prüfen. Dieselbe Reihenfolge muss für Treffergrenzen 1, 6 und 50 gelten. Der vorhandene Sortierer soll den Gleichstandstest verfehlen.
- [x] In scripts/AtlasData.gd die Trefferliste anhand von Kategorie, Wertung, Name und ID begrenzen. Beim Einlesen die privaten Dictionary-Datensätze direkt normalisieren und die Ersetzungstabelle der Namensnormalisierung einmal anlegen.
- [x] Die vollständige Atlasprüfung, Atlasintegration und den Logo-/Ladephasen-Test ausführen. Die Änderung an der Trefferreihenfolge bei völlig gleichen Namen anhand des Testfalls dokumentieren.
- [x] Ladezeit, Laufzeitspeicher und Suchlatenz vor und nach der Änderung mit identischem Testlauf messen. Erst nach bestätigter Verbesserung erneut Windows und Android exportieren.
