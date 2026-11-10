# Gemeinsam im WLAN

Die Fassung 1.7.0 ergänzt eine gemeinsame Partie für zwei bis vier Menschen.
Jeder führt ein eigenes vorhandenes Haus. Ein Gerät berechnet die gemeinsame
Welt, die anderen erhalten dessen bestätigten Zustand. Windows und Android
verwenden dasselbe Protokoll; unterschiedliche Spiel- oder Datenstände werden
bereits beim Verbindungsaufbau mit einer deutschen Erklärung zurückgewiesen.

## Eine Partie eröffnen

1. Auf allen Geräten dieselbe vollständige Fassung starten und mit demselben
   lokalen Netzwerk verbinden.
2. Im Hauptmenü **Gemeinsam im WLAN** wählen.
3. Der Gastgeber trägt Spielername und Partiename ein, wählt sein Haus und
   **Neue Partie hosten**. Die Lobby zeigt seine lokalen IPv4-Adressen an.
4. Gäste wählen **Partien im WLAN suchen** und einen gefundenen Raum. Alternativ
   tragen sie die angezeigte Gastgeber-IP ein und wählen **Über IP beitreten**.
   Der Spielport ist standardmäßig 28741 und muss auf beiden Geräten gleich sein.
5. Jeder Gast wählt ein freies Haus und **Bereit**. Sobald mindestens zwei
   verschiedene Häuser bereit sind, startet der Gastgeber die Partie.

Falls das Netzwerk Geräte voneinander isoliert, ist keine direkte Verbindung
möglich. Die IP-Alternative hilft bei unterdrückter Raumsuche, umgeht aber keine
Netzwerkisolation. Das Spiel richtet keine Portweiterleitung und keine
Windows-Firewallregel ein. Es benötigt keinen Internetserver und keinen Account.

## Gemeinsame Zeit und persönliche Entscheidungen

Die Partie beginnt pausiert. Nur der Gastgeber setzt die gemeinsame
Geschwindigkeit und entscheidet am Kampagnenende über die Sandboxfortsetzung.
Gäste führen ihre eigenen wirtschaftlichen, militärischen und politischen
Befehle aus; Kosten und persönliche Ereignisse gehören zum zugewiesenen Haus.
Ausstehende Entscheidungen eines lebenden Menschenhauses pausieren die Welt
für alle. Ein ausgespieltes Haus kann die übrige Partie beobachten.

Ein Gastbefehl wird erst nach Bestätigung übernommen. Währenddessen bleibt
höchstens ein Befehl offen. Veraltete Ereignisantworten, doppelte Befehle und
Aktionen gegen eine fremde Provinz werden mit dem tatsächlichen Ablehnungsgrund
angezeigt. Kartenmodus, Auswahl, Theme und Textgröße bleiben lokale Ansichten.
Herrschereditor und Wappengenerator sind während einer laufenden WLAN-Partie
gesperrt, weil sie den gemeinsamen Zustand außerhalb der bestätigten Befehle
verändern würden.

## Speichern, Unterbrechung und Fortsetzen

Der Gastgeber speichert die gesamte Partie mit allen persönlichen Hauszuständen
in `user://lan_partie.json`. Dieser Spielstand ist von Einzelspielerdateien
getrennt. Die Option zum jährlichen automatischen Speichern gilt beim
Gastgeber auch für LAN-Partien. Gäste speichern keine eigene abweichende Welt.

Bei einem verlorenen Gast pausiert die Welt. Der Gastgeber kann in der
WLAN-Lobby speichern und **Zur Lobby zurückkehren**. Zum Fortsetzen müssen alle
ursprünglichen Menschenhäuser wieder besetzt und bereit sein. Ein fehlender
Mensch wird nicht automatisch durch die KI ersetzt.

Für eine gespeicherte Partie eröffnet der Gastgeber über
**LAN-Spielstand laden und hosten** eine Wiederaufnahmelobby. Nach dem Verlust
des Gastgebergeräts endet die Verbindung der Gäste mit einer Erklärung; ein
automatischer Hostwechsel gehört nicht zu dieser Fassung.

Die App muss auf den teilnehmenden Geräten geöffnet bleiben. Netzwerk- oder
Appunterbrechungen pausieren beziehungsweise trennen die Verbindung. Eine
verlorene Verbindung oder ausbleibende Befehlsbestätigung endet nach einer
begrenzten Wartezeit mit einem sichtbaren Status.

## Technik und Prüfgrenzen

ENet verwendet UDP 28741; die getrennte lokale Raumsuche verwendet UDP 28740
und Antworten an den tatsächlichen Absender. Die Sitzung besitzt eine private
`SceneMultiplayer`-Instanz mit deaktivierter Objektdekodierung und deaktiviertem
Serverrelay. Nachrichten sind begrenzte JSON-Daten; Spielfunktionen werden
über eine explizite Befehlsliste und serverseitige Hauszuordnung erreicht.

Der Inhaltsfingerprint umfasst die statischen Häuser, Provinzen, Nachbarschaften
und SHA-256-Werte aller drei zentralen Kartendateien. Persönliche Gastprojektionen
enthalten keine fremden privaten Kontexte und keine lokalen Wappen-Dateipfade.

Getrennte Windows-Prozesse auf Loopback und native Godot-Prüfszenen belegen den
Transport. Ein solcher Test allein belegt keine reale Android-WLAN-Verbindung.
Die tatsächlichen Ergebnisse der ausgelieferten Fassung stehen im zugehörigen
Prüfbericht; offene Geräteprüfungen bleiben dort ausdrücklich erkennbar.
