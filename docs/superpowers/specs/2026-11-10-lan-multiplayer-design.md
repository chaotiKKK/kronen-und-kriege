# Banger Queens: gemeinsames Spiel im WLAN

Stand: 10. November 2026. Der Nutzer beauftragt die autonome Umsetzung; seine bestehende Freigabe sämtlicher routinemäßiger Projektentscheidungen gilt. Dies erweitert die Quellenarbeit um ein eigenes Netzwerksystem. Die Version 1.6.1 bleibt unverändert erhalten.

## Ergebnis und Bedienung

Im deutschen Hauptmenü gibt es „Gemeinsam im WLAN“. Zwei bis vier Geräte spielen dieselbe Welt mit jeweils eigenem vorhandenen europäischen Haus. Der Gastgeber öffnet eine Lobby und zeigt seine lokalen IP-Adressen; Gäste suchen im WLAN oder tragen die IP direkt ein. Die Sitzwahl ist eindeutig, jeder Gast bestätigt Bereitschaft, der Gastgeber startet. Android und Windows verwenden dasselbe Protokoll und dieselben Daten. Kein Konto, Serverdienst, Datenimport oder automatisches Router-Portforwarding wird benötigt.

Der Host entscheidet über Zeit/Pause und Fortsetzung als Sandbox. Bei offenen Ereignissen eines Menschen oder beim Verlust eines Gastes hält der gemeinsame Takt an. Der Verlust des Hosts beendet die Verbindung mit deutscher Erklärung; der zuletzt bestätigte Zustand bleibt sichtbar. Eine Wiederaufnahme erfolgt über einen Host-Spielstand und eine neue Lobby. Der Mehrspielerspielstand ist getrennt von spielstand.json. Gästekopien ersetzen keine Hostdateien.

## Architektur

- Game bleibt die einzige gemeinsame Welt. Häuser, Provinzen, Datum, Forschung, Straßen und Weltverlauf werden genau einmal auf dem Host simuliert.
- Persönliche Zustände (Meinungen, Intrigenfristen, Gefangene, Skandale, Ereignisse und Ereignisinstanz, Hausende, Sieg und persönliche Chronik) sind pro Haus getrennt. KI handelt nicht für die menschlichen Häuser. Ein erbloser Tod eines Menschen beendet keine anderen Häuser.
- UiKernel bleibt die vorhandene ausdrückliche Befehlsliste. LanAuthority bindet Absender an ihren Lobbysitz, prüft typisierte Felder und explizite Provinzauswahl und ruft ausschließlich diesen Router auf. Es gibt keine frei übermittelten Methoden, Callables oder Dateipfade.
- LanSession betreibt eine eigene SceneMultiplayer/ENet-Verbindung mit Roh-JSON-Nachrichten. Die API wird manuell gepollt und gehört nicht zur allgemeinen SceneTree-RPC- oder Spawnverwaltung. Clients akzeptieren Weltzustand ausschließlich vom Host. Zuverlässige Nachrichten, monotone Befehls-/Zustandssequenzen und maximal ein ausstehender UI-Befehl pro Gast verhindern doppelte Ausführung.
- Ein Snapshot enthält die gemeinsame Welt und ausschließlich die eigene persönliche Projektion. Ein gemeinsamer kanonischer Welt-Hash ist unabhängig von der lokalen Hausperspektive. Veraltete Zustände und falsche Hashes werden abgewiesen.
- Vor dem Lobbybeitritt werden Protokollversion, Appversion und eine Inhaltskennung verglichen. Die Inhaltskennung umfasst statische Spieldefinitionen und die unveränderten Laufzeitdateien des Atlas; Atlasdaten selbst werden nicht im Netzwerk übertragen.
- LanDiscovery beantwortet begrenzte UDP-Suchpakete im lokalen Netz. Direkte IP bleibt auch ohne Broadcast möglich. Android erhält die tatsächlichen Netzwerk- und Multicastberechtigungen.
- LanMenu ist eine eigene rollbare Oberfläche mit festen Zurück-/Startaktionen, 200-Prozent-Text und den vorhandenen Lesbarkeitsthemen. Der individuelle Live-Herrschereditor und gerätespezifische Wappengenerator werden während einer LAN-Partie klar gesperrt, damit bestehende direkte Mutationen keine Autorität umgehen. Vorhandene Häuser und Wappen sind spielbar.

## Dateigrenzen und Schnittstellen

Game-Vertrag: configure_human_houses(ids:Array)->bool; select_player_context(index:int)->bool; opinion_value(house,index)/set_opinion_value(house,index,value); scandal_value(house)/set_scandal_value(house,value); pending_event_instance()->int; snapshot_for_player(index:int)->Dictionary; has_pending_human_events()->bool; all_human_houses_over()->bool; is_human_house(index)->bool. Additive Snapshotfelder: lan_human_houses, lan_contexts (Host), lan_projection (Gast) und event_instance. Altes Schema12 und Einzelspieler verhalten sich ohne LAN-Konfiguration wie bisher.

Neue Module: LanProtocol (Schema, Grenzen, kanonischer Hash), LanAuthority (Sitze/Befehle), LanDiscovery (lokale Suche), LanSession (Transport/Lobby/Takt), LanMenu (UI). Main integriert diese Module, ohne Gameplay in das Transportmodul zu duplizieren. Root besitzt Main/Netz/UI/Builder/Versionen; ein Worker besitzt ausschließlich Game/Resolver und deren neue Logiktests. Quellenworker besitzen getrennte neue Provider und Rohcaches.

## Konkrete Abnahme

1. Zwei und anschließend drei getrennte Host-/Gastprozesse tauschen echte ENet-Pakete aus, wählen verschiedene Häuser, starten, führen eigene Befehle aus und vergleichen Welt-Hashes über Monats-/Jahreswechsel.
2. Doppelte/veraltete Befehle, falsche Haus- oder Provinzberechtigungen, ungültige Optionen, falsche Ereignisinstanz, unbekannte Protokolle/Versionen/Daten und übergroße Nachrichten verändern die Hostwelt nicht.
3. Pause bei Gastabbruch, verständlicher Hostverlust, belegte Ports und erneuter Lobbyaufbau sind geprüft. Fehlermeldungen befinden sich im lokalen Sitzungsstatus.
4. Alle persönlichen Zustände und eine Host-Speicherung/-Wiederaufnahme sind getrennt; Gäste können keine Hostdatei laden oder die globale Zeit ändern.
5. Rollbare deutsche Lobby, Touch-Ziele und feste Schließen-/Startaktionen werden bei100% und200% geprüft. Bestehende Einzelspieler-, Karten- und Speicherprüfungen bleiben grün.
6. Neue APK/EXE werden versioniert gebaut, signiert/statisch geprüft und enthalten die vollständigen identischen Spieldaten. Loopback und Desktoptests werden nicht als realer Android-WLAN-Nachweis ausgegeben.

## Parallel laufende Kartenarbeit

Weitere qualifizierte Quellen für AZ/CNM/IL/KZ/LB/LY/MA/TR werden getrennt gesucht. Neue positive Geometrie benötigt aktuelle Identität, tatsächliche Rolle, Originalhashes und nachgewiesene Weitergabe. Ein neuer Import darf die veröffentlichten1.6.1-Pakete nicht verändern. Ersatz vorhandener Einzelobjekte erfordert explizite belegte Feature-IDs. Keine Quellenwarnung wird allein zum Erreichen eines Prozentwerts entfernt.
