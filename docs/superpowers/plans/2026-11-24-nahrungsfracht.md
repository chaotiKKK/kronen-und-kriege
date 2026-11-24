# Nahrungsfracht und gemeinsamer Straßenraum

**Ziel** Eine finanzierte Landwirtschafts- und Straßenentscheidung kann Arbeit in spezialisierten Nachbarorten freihalten. Die Karte und die Provinzbilanz zeigen tatsächlich abgegangene und eingetroffene Lieferungen.

**Architektur** CivicFreight plant Nahrungsfracht aus Anfangsvorräten über MaterialTransport. MaterialTransport nutzt einen gemeinsamen Kantendurchsatz. Game verrechnet Fracht vor örtlicher Produktion und Ration. CivicProvisionReport bewahrt für den Monat Menge, Besitz und Weg. Beide Berichte werden beim Empfang gemeinsam geprüft.

## Umsetzung und Abnahme

- [x] Mit bestehenden Straßen- und Vorratsregeln eine Quelle, eine örtliche Werkstatt und eine echte Monatsration prüfen. Nahrung muss zum Ziel gelangen, weniger Arbeitskraft binden und denselben Durchsatz wie gleichzeitig beförderte Baustoffe verwenden. In Gegenproben geschlossene, neu begonnene und fremde Kanten sowie Weiterexport prüfen.
- [x] MaterialTransport um bewusste Eingabe des verfügbaren Vorrats pro Frachtart und bereits belegter Kanten erweitern. Die Materialbilanz zeigt weiterhin nur ihre eigene Fracht. Beide Arten buchen ganzzahlige Mengen aus dem jeweiligen Vorrat.
- [x] CivicFreight lässt nur Landwirtschaft mit mindestens vier eigenen Monatsrationen plus aktueller Ration exportieren. Werkstätten und Handel beziehen bis zu einer Monatsration, andere Regionen füllen bei weniger als zwei Monatsrationen auf. Weder Empfänger noch Durchfahrt benötigen ein freies Bauvorhaben.
- [x] CivicProvision plant Farmarbeit, Rationen, Verluste und Zufriedenheit nach der gebuchten Fracht. Vorausschau bleibt ausdrücklich örtlich. Dieselbe alte vollständige Straße steht beiden Frachten zur Verfügung. Neue Straßen wirken ab der folgenden Monatsabrechnung.
- [x] Die zivile Monatsbilanz mit Mengen und Wegen speichern. Bei einem Netzwerkschnappschuss den gemeinsamen Kantendurchsatz prüfen. Bisherige Bilanzen ohne Fracht bleiben lesbar. Routendaten aus früherem Besitz bleiben nachvollziehbar und werden für neue Buchungen nicht wiederverwendet.
- [x] Im vorhandenen Ausbauabschnitt die gebuchten Lebensmittelmengen zeigen. Wirtschaftskarte zeichnet die gebuchten Wege als andersfarbige Kartenbewegung. Bewegungsreduktion lässt lesbare Informationen erhalten.
- [x] Kontrollfälle, alte Spielstände, eine regulär finanzierte echte Lieferkette und bestehende Bau-, Handels- und Feldzugkampagnen prüfen. Android und Windows aus dem gleichen Stand bauen, sobald die Modell- und UI-Prüfungen bestanden sind.
