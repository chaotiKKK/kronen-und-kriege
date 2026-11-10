# WLAN-Mehrspieler Implementation Plan

> Execution: vorhandene Kollaborationsagenten mit getrennten Dateibesitzern; Root kontrolliert jeden Godot-/Build-/Exportslot. Die autonome Projektfreigabe gilt; keine zusätzliche Genehmigungsrunde.

**Goal:** Eine echte gemeinsame Banger-Queens-Partie für zwei bis vier Windows-/Android-Geräte im selben WLAN.
**Architecture:** Ein autoritativer Host, persönliche Hauskontexte, vorhandener UiKernel als Befehlsliste, private ENet-Rohpakete und vollständige bestätigte Zustandsprojektionen.
**Tech Stack:** Godot4.5, GDScript, ENet/SceneMultiplayer, PacketPeerUDP, vorhandenes Schema12 und kanonischer Save-Serializer.
**Spec:** docs/superpowers/specs/2026-11-10-lan-multiplayer-design.md

## Globale Grenzen

- Zwei bis vier Menschen mit eindeutig zugewiesenen vorhandenen europäischen Häusern; zusätzliche Häuser bleiben KI.
- Der Host simuliert Welt/Datum genau einmal und steuert Geschwindigkeit. Persönliche Ereignisse und Hauszustände bleiben getrennt.
- Vollständige Offline-APK, Deutsch und vorhandene Themen; Zielversion1.7.0 mit neuem Android-Versionscode11.
- Version1.6.1, ihre signierten Pakete und der Release-Tag bleiben unverändert.
- Keine beliebigen Remote-Methoden, Netzwerkobjektdeserialisierung oder entfernten Dateipfade.
- Alle tatsächlichen Geräte-/Netzwerkgrenzen im Ergebnis ausweisen; kein fremdes Smartphone oder Emulator ohne koordinierte Übergabe.

### Task1: Persönliche Hauszustände und Ticklogik

Files: scripts/Game.gd, scripts/SystemicResolver.gd; tests/LanGameStateTest.gd/.tscn.
- [x] RED: neue Szene fordert zwei menschliche Häuser, getrennte Intrigen/Ereignisse und genau einmalige Jahreswirtschaft; auf unverändertem Game fehlt der Vertrag.
- [x] GREEN: den vollständig im Spec genannten Game-Vertrag implementieren, Resolver nach effect.house routen, KI-Mensch-Ausschluss und erbloses Hausende korrekt behandeln.
- [x] Test: `.tools/godot.exe --headless --path . res://tests/LanGameStateTest.tscn`; gezielte vorhandene UiKernel-, SaveMigration- und SystemicDepth-Prüfungen.
- [x] Prüfen: vollständiger Snapshot/Restore und entfernte persönliche Gastprojektion, keine Änderung des Einzelspieler-Schemas ohne LAN.

### Task2: Typisiertes Protokoll und autoritative Befehle

Files: scripts/LanProtocol.gd, scripts/LanAuthority.gd; tests/LanProtocolTest.gd/.tscn und LanAuthorityTest.gd/.tscn.
Interfaces: LanProtocol.validate_command(command:Dictionary)->Dictionary, world_hash(state:Dictionary)->String; LanAuthority.new(game,peer_houses:Dictionary), execute(peer:int,sequence:int,command:Dictionary)->Dictionary, snapshot_for_peer(peer:int)->Dictionary.
- [x] RED: unbekannte Befehle, falsche Typen, fremde Hausvorgabe, doppelte Sequenz und falsche Ereignisinstanz werden abgewiesen; unveränderte autoritative Welt wird verglichen.
- [x] GREEN: explizite UiKernel-Allowlist mit pro Befehl erlaubten Feldern und Maximalgrößen, hostseitige Sitzzuordnung und eigener temporärer Kernel.
- [x] Test: neue Szenen einzeln ausführen, danach genau einmalige Kosten/Ergebnisbestätigung und Perspektiv-unabhängige Welt-Hashes prüfen.

### Task3: Transport, Lobby und Suche

Files: scripts/LanSession.gd, scripts/LanDiscovery.gd; tests/LanTransportTest.gd/.tscn und tools/run_lan_network_test.ps1.
Interfaces: host(room_name,player_name,house,port), join(address,player_name,port), choose_house(house), set_ready(value), start_match(), submit(command), close_session(reason), save_host(path), load_host_lobby(path). Signale lobby_changed, game_started, game_updated, status_changed, command_finished.
- [x] RED: getrennte Prozesse können noch keine ENet-Lobby eröffnen, verschiedene Sitze wählen und Datenkennung abgleichen.
- [x] GREEN: zuverlässige Roh-JSON-Nachrichten, Absenderprüfung, Hash-/Versionshandshake, Zustandssequenzen, Zeit und Abbruchregeln implementieren.
- [x] Test: zwei Prozesse auf einem ausschließlich dieser Prüfung gehörenden Loopbackport; dann dritter Prozess, volle/doppelte Sitze, schlechte Kennung und Wiederaufbau. Getrennte Benutzerverzeichnisse verwenden.
- [x] GREEN: UDP-Suche auf eigener Banger-Queens-Kennung; direkte IP unabhängig von gefundenen Broadcast-Antworten.

### Task4: Deutsche WLAN-Oberfläche und Integration

Files: scripts/LanMenu.gd, scripts/Main.gd, export_presets.cfg; tests/LanUiTest.gd/.tscn.
- [x] RED: Hauptmenü enthält noch keinen WLAN-Einstieg, Lobby-, Sitz-, Ready- und IP-Flow.
- [x] GREEN: rollbares LAN-Menü mit festen Aktionen; Main._dispatch an Session, Main._process bei Gästen ohne Simulation und beim Host über Session. Save-/Load-Grenzen und direkte Customizer-/Banner-Mutationen schützen.
- [x] Test: echte Hauptszene, Lobby öffnen, Fehler verständlich anzeigen,200%Text, Schließen/Zurück erreichbar, Einzelspieler weiterhin startbar. Android INTERNET/Netzwerk/Multicastberechtigungen im tatsächlichen APK prüfen.

### Task5: Quellenintegration, Gesamtprüfung und Pakete

Files: nur positiv qualifizierte neue Atlasprovider/-manifeste, tools/atlas_administration.py bei belegtem Einzelfeatureersatz; source-/release-Dokumente.
- [x] Konkrete neue Primärquellen mit Lizenz/Rollen/Identität/Originalgeometrie einlesen; keine positive Abdeckung bei fehlenden Belegen behaupten.
- [x] Bei Datenänderung: reproduzierbaren Atlasbuild einzeln ausführen, Inputs einfrieren, Integrität und Quellenrollen prüfen.
- [x] Alle Python- und registrierten Godot-Suiten durchführen; neue LAN-Suiten im Runner registrieren.
- [x] Versionierte1.7.0-EXE/APK bauen; alle eingebetteten Daten, natives Windowsmanifest, Androidsignatur und Berechtigungen prüfen.
- [x] Echte isolierte Paket-/Netzwerkabnahme; Ergebnisse und verbleibende Quellen-/Gerätelücken dokumentieren und autorisierten Quell-/Paketstand sichern.

Abschluss: genehmigter LAN-Umfang und positiv qualifizierte Sakarya-Integration umgesetzt. Vollständige vergleichbare Verwaltung über alle acht Gebiete bleibt extern blockiert; keine Quarantäne aufgehoben. Reale Android-WLAN-Abnahme bleibt ausdrücklich offen; siehe docs/banger-queens-170-progress.md.
