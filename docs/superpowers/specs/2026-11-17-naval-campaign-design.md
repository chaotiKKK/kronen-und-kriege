# Reguläre Küstenfeldzüge und Wessex-Seetransport

Das aktive Spielspaßziel bleibt vollständig bestehen. Diese zusammenhängende Erweiterung behebt den belegten Inselstarter ohne nutzbaren Feldzug und die KI-Sackgasse am ersten unerreichbaren Anspruch. Sie erweitert die vorhandenen Heere, Flotten, Ansprüche und Provinzbefehle. Die vorangegangene Kontextfassung bleibt als funktionsfähiger Export erhalten. Die vollständige 60-FPS-/AAA-/Langzeitbalance-Abnahme ist damit weiterhin nicht erledigt.

## Spielbarer Ablauf und Daten

Wessex beginnt regulär mit 120 Gold. Armee kostet 50, Flotte 60 und Anspruch 40 Gold; Erträge und Verpflichtungen müssen die fehlende Kasse liefern. Keine Ressourceninjektion im regulären Nachweis. Übersetzen kostet kein zusätzliches Gold. Heer, Flotte und Landepunkt werden gemeinsam geprüft. Erfolg bringt Heer und Geleit an die andere Küste, ohne Besitzwechsel oder Belagerungsfortschritt; eine Belagerung benötigt einen späteren Monat. Der umgekehrte Weg zu eigenem Land braucht keinen feindlichen Anspruch und bleibt bei leerer Reisekasse möglich, sofern Geleit, Moral, Kapazität und freie Aktion vorhanden sind.

Die erste zugelassene Route ist die tatsächlich geprüfte Verbindung `britannien__03` (Londonregion) ↔ `gallien__04` (Brüsselregion). Echte Küstenanker und Wasserlinie stammen aus `build/verify/naval-route-proof/route-proof.json`; nicht die Stadtlabel werden verbunden. `NavalRoutes.gd` lädt eine explizite eingebettete Tabelle mit Katalog-/Quellenbindung, validiert IDs und Anker und liefert kopierte Richtungsdaten sowie stabil sortierte Ziele. Ungültige Daten verwerfen den gesamten geladenen Zustand. Es werden keine Landnachbarn, Regionsgrenzen oder Weltatlasgeometrien geändert. Ungeprüfte Seewege werden nicht erfunden. Der Datenreader ist für weitere nachgewiesene Routen vorgesehen; die erste Route ist keine Behauptung einer vollständigen Weltseekarte.

Die Wasserprüfung erfolgt offline gegen die konservative Vereinigung der tatsächlichen Landflächen. Zur Laufzeit wird der zugelassene Graph verwendet, kein unterschiedlich komprimiertes Farbbild. Ein als Routenende verifizierter Port gilt im tatsächlichen Spielkatalog deterministisch als Küste. Alte Datenadapter ohne die betreffenden IDs behalten ihr bisheriges Küstenverhalten.

## Gemeinsame Regeln

`NavalTransport.gd` kapselt die reinen Transportregeln und deren Fingerprintdefinitionen. Kapazität ist 100 Soldaten je vorhandenem Schiff, keine automatische Teilung. Mindestmoral der Flotte ist 20. Die aktive eigene Armee und genau das erste vorhandene eigene Geleit müssen am selben operativen Ort stehen: `army.province == fleet.province == fleet.station`. Das Geleit ist weder mit einer aktiven eigenen Blockade belegt noch durch eine feindliche Blockade am Abfahrts- oder Zielufer gesperrt. Fremde Abfahrtsbrückenköpfe sind zulässig; der Abfahrtsort muss nicht dem Spieler gehören.

Eine fremde Landung benötigt einen aktiven Anspruch, dieselbe zulässige Beziehung wie ein feindlicher Landmarsch und keinen Waffenstillstand. Eigene Landung benötigt dies nicht. Reine Vorschau und abgewiesene Vorbedingungen verändern weder Welt noch Zufallsfolge. Der bestehende einsbasierte Monatsindex bleibt maßgeblich.

Eine ausgeführte Überfahrt setzt `army.last_siege_month` und `fleet.last_naval_month` auf den aktuellen Monat. Damit teilen Transport, Landmarsch, Belagerung und bereiter Heeresbeitrag weiterhin dieselbe Heeresaktion; Flottenblockade und Überfahrt teilen dieselbe Flottenaktion. Ein Wechsel der aktiven Armee umgeht die Geleitwache nicht. Ein tatsächlich ausgeführter Seekampf verbraucht die Aktion auch bei Abwehr. Defensive Reaktionen selbst bekommen keine neue offensive Monatsaktion.

Eine tatsächlich am Ziel stationierte verteidigende Flotte löst genau einen vorhandenen Seekampf aus. `station` ist maßgeblich; `province` ist nur Legacy-Fallback bei fehlender Station. Kein entfernter Geburtshafen darf gleichzeitig verteidigt werden. Nach dem Kampf muss genau das ursprüngliche Geleit überlebt haben und erneut Kapazität/Moral erfüllen. Es darf nicht durch eine andere Legacy-Flotte ersetzt werden. Keine heimliche Truppenlöschung oder automatische Überladung.

Aufgelöste Kämpfe liefern `ok=true` mit `landed=false` beziehungsweise `blockaded=false`, wenn die eigentliche Aktion abgewehrt wurde. Das unterscheidet mutierende Ergebnisse von mutationsfreier Validierungsablehnung und löst auch lokal zuverlässig die Zustandsaktualisierung aus. Die alte Blockade-Niederlagenkonvention `ok=false` wird bewusst angepasst und separat negativ/positiv getestet. Beim Versenken einer von mehreren Legacy-Flotten enden nur die nicht mehr von einer tatsächlich dort stationierten Flotte gedeckten Blockaden.

Erfolgreiche Landung setzt beide Flottenorte und den Heerort auf das Ziel. Eine später endende Blockade springt dadurch höchstens zum aktuellen operativen Stützpunkt zurück. Ungestützte eigene Belagerung am verlassenen Ufer wird beendet; ein anderes dort stehendes eigenes Heer erhält sie. Versorgung bleibt die vorhandene örtliche und begrenzte Straßenversorgung.

## Ansprüche und KI

Eine gemeinsame `claim_reason(target, house=-1)` prüft vorhandenen aktiven Anspruch, fremden Besitz, 40 Gold und Land- oder verifizierte Küstenreichweite. Für den Küstenanspruch muss ein vorhandenes verfügbares Geleit an einem eigenen Routenport stehen; ein Heer ist noch nicht nötig. Der Finanzbefehl verbraucht keine Flottenaktion. Der Landnachbargraph bleibt unverändert.

`has_claim` benutzt die bereits vorhandene aktive Gültigkeit: Ein vorhandenes Ablaufdatum gilt einschließlich dieses Monats, danach nicht mehr. Eine bezahlte Erneuerung ersetzt einen abgelaufenen Eintrag ohne Duplikate. Fehlende historische Frist bleibt gemäß bestehender `claim_active`-Semantik aktiv. Diese Regel gilt konsistent für Land, See und Planung; ein gespeicherter abgelaufener erster Anspruch bindet keine KI-Aktion mehr.

Die KI prüft alle aktiven Ansprüche auf einen ausführbaren deterministischen Weg. Eigene Landschritte und zugelassene Seeetappen dürfen verbunden werden; fremde Zwischenregionen werden nicht durchlaufen. Die Auswahl ist stabil, ein unerreichbarer erster Eintrag verdrängt keinen erreichbaren späteren. Nach Verlusten, Besitzwechsel, Blockade, Frieden und Ablauf wird neu geplant. Insel-NPCs mit einem verifizierten Küstenziel sparen auf die regulären Anschaffungen, statt ihre notwendige Expeditionskasse vorher für beliebige Ausbauten auszugeben. Ein für den Feldzug benötigtes Geleit wird nicht gleichzeitig automatisch blockieren geschickt. NPCs benutzen dieselben bezahlten Modellaktionen.

## UI und Netzwerk

Die vorhandene Militärseite erhält einen kontextuellen Button „Hierher übersetzen“ und eine kurze Vorschau: Abfahrt, benötigte/verfügbare Schiffe, Kapazität, tatsächlicher Sperrgrund und gegnerisches Geleit. Einzig geprüfte direkte Routenziele sind relevant. Anspruchsbutton und Standardauswahl erkennen auch die geprüfte Küstenreichweite. Keine neuen globalen Hauptreiter oder Ressourcen. Die Karte darf die ausgewählte Route dezent und ohne neue Atlas-Triangulation anzeigen.

`UiKernel` routet `transport_army` mit der tatsächlichen Zielauswahl. `LanProtocol.FIELDS` erlaubt dafür keine zusätzlichen Felder. Akteur bleibt ausschließlich der Peer-Sitz, Kampf und Monatsentscheidung bleiben auf dem Host. Route, Kosten, Kapazität und Ergebnis dürfen nicht vom Client behauptet werden. Der Inhaltsfingerprint umfasst Route und gemeinsame Regeldefinitionen. Gemischte Regeln bleiben im Netzwerk unzulässig.

## Speicherung und Abnahme

Schema 15 speichert `last_naval_month`, übernimmt es in beiden festen Flottenrekonstruktionen und validiert Monatswerte als Ganzzahlen im gültigen Bereich. Historische Flotten erhalten `-1`. RegionMigration darf eine aktuelle Migration nicht wieder auf Schema 14 zurücksetzen. Der tatsächliche Laufzeit-Snapshot muss das aktuelle Schema und das benutzte Flottenfeld erhalten; ein nachträglicher Default darf dessen Verlust nicht kaschieren.

Alle belegten lokalen Schema-13-/14-LAN-Pfade bleiben mit bytegleicher Originalkopie erhalten. Der aktuelle Kontext-Fingerprint `49efe0af83dff5e58b98eff1d9e2978a8200f835562ac0202da13b036ac884a6` wird ausschließlich anhand der echten gesicherten Vorgängerdatei zugelassen. Backupfehler dürfen Originaldatei und lebende Partie nicht ersetzen. Aktuelle Netzwerkfingerprints bleiben strikt.

Abnahme umfasst: reine und mutierende Negativfälle; echte Hin-/Rückfahrt; Monatswachen nach Speichern/Laden und Armeewahl; Abwehr und Kapazität nach Kampf; mehrere Legacy-Flotten; bezahlte Wessex-Kampagne mit aktiver NPC-Welt; erreichbare KI-Alternative; echte Host/Gast-Befehle und identische Welt nach Fortsetzung; bestehende Naval-, Army-, Save-, UI- und LAN-Regressionsprüfungen. Erst danach neue getrennte EXE/APK und belegte Paketläufe. Das Telefon bleibt frei; sichtbare Windowsläufe nur auf dem rechten Monitor. Das Gesamtziel wird durch diesen Baustein nicht als vollständig erreicht ausgewiesen.
