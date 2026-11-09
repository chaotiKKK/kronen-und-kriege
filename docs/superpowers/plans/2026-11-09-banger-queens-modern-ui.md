# Banger Queens: moderne Oberfläche

Autonome Umsetzung vom Nutzer ausdrücklich freigegeben. Godot-Fassung abschließen; Unreal bleibt ein separates späteres Projekt.

Ziel: reservierte Navigation statt überlappender Kartenplaketten; getrennte Seitenbereiche; ruhige dunkle Oberflächen; neues Hauptmenü mit eindeutigem Spieleinstieg; bestehende Regeln und Spielstände bleiben bedienbar.

Gestaltung: Atlantik `#101E2B`, Schiefer `#1A3042`, helle Schrift `#EDF3F5`, zweitrangige Schrift `#AFBFCA`, Kupfer `#D4A875`, Seegrün `#78C6BD`. Die Karte und die Herrscher stehen im Vordergrund. Die Darstellung nutzt vorhandene eigene Motive; Typografie trennt kräftige Titel, normale Lesetexte und kompakte Daten. Die durchgehende Kampagnenzeit bildet ein charakteristisches Band im neuen Hauptmenü.

1. `ModernUiTest` zeigt die tatsächliche Navigationsüberlappung und zu kleine Ziele am alten Layout.
2. `ModernInterface.gd` richtet vorhandene Bedienelemente neu ein: zweizeilige Kopfzeile, separate scrollbare Kartenmodi, reservierte Karteninformationen, exklusive Seitenbereiche, kompaktes Herrscherprofil und neues Hauptmenü.
3. `Main.gd` verwendet gemeinsame moderne StyleBoxen für bestehende und dynamisch erzeugte Fenster/Buttons/Felder. Regeln werden nicht in das Layoutmodul verschoben.
4. Test bei 1280×720, 1024×768 und 1920×1080; echte Bilder von Menü/Hauptansicht prüfen. Bestehende Touch-, UI- und Save-Suiten erneut ausführen.
5. Nur nach grünen Prüfungen Windows und Android erneut exportieren, APK verifizieren und Prüfbericht aktualisieren.

Ergänzung nach Nutzerwunsch: Ereignisfenster zeigen jede Aktion samt allen Werten innerhalb desselben Buttons. Die große Panel-Fläche ist transparent, die Abdunklung geringer und das Bild als kleines, weich abgerundetes Motiv dargestellt. `EventChoiceTest` prüft Werte, Klickwirkung, Transparenz und vollständig sichtbare Entscheidungen bei normaler Textgröße. Größere Texte behalten die Dialog-Rollbereiche.

Lesbarkeit: Drei gespeicherte Themen (dunkler Atlas, hoher Kontrast, heller Atlas) und Textgröße 100/125/150/200 %. `ModernUiTest` deckt Themewechsel, Textvergrößerung, Dialoghöhen und drei Fenstergrößen ab. Der Textmaßstab betrifft die Schrift; die Kartenfläche und ihre Trefferkoordinaten behalten ihre vorhandene Umrechnung.

Nachkorrektur 1.5.1: Werte innerhalb der Buttons bleiben je nach Vorzeichen grün/rot, neutrale Angaben gelb/amber. Die Ereigniskarte erhält 10 % Deckkraft, einen dünnen Rand und Schatten. Die Rich-Text-Unterelemente reichen Eingaben an denselben Button weiter; der vollständige zugängliche Name wird über `accessibility_name` angeboten und vom Abnahmetreiber berücksichtigt. Themen- und Textgrößenwechsel prüfen zusätzlich Farberhalt und überschneidungsfreie Buttonflächen. Der Menübereich überdeckt das alte Hintergrundlogo/Banner vollständig deckend.
