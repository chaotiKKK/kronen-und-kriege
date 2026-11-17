# Herkunft von `lan-190-original.json`

Die Datei wurde mit der tatsächlichen exportierten `banger-queens-1.9.0.exe` erzeugt, nicht mit dem aktuellen Spielkern und keinem nachträglich eingesetzten aktuellen Fingerabdruck.

- Alte EXE: SHA256 `66b91e7b3c665656df0c89d528d2a564caa71b3dca12c7f282a01d73a95a3013`.
- Passender Quellstand: `93170eb`, `LanSession._content_fingerprint()` enthält `schema`, `protocol`, `houses`, `provinces`, `adjacency`, `events`, `innovations`, drei eingebettete Datei-SHA256 und `regions`. `Protocol.FIELDS` war noch nicht enthalten.
- Historischer Fingerabdruck: `ca7c50860f0e76f19153a6f985117ac8de7277a0f3559ecdcba692077aebf500`.
- Unveränderte Datei: SHA256 `ff009fbd3bbbd94ea2c239b3fc4a06478dbf06eb6dee33ec74322cd5ea4822ba`.

Rezept des externen Diagnoseskripts, ausgeführt über `alte.exe --headless --path <leerer Diagnoseordner> --script <Diagnoseskript>` mit isoliertem APPDATA:

1. `seed(1900)`; `Game.new(GameRegionData, 0)` aus den eingebetteten Ressourcen der alten EXE.
2. `HouseDesign.defaults(data)`, Hausname `Haus Vorher`, Doktrin `infantry`, `_custom_start(profile)`.
3. Zweiter Entwurf mit Heimat `data.provinces()[1].id`, Hausname `Haus Fortsetzung`, Doktrin `cavalry`, erneut `_custom_start(profile)`.
4. `configure_human_houses([9,10])`; `select_player_context(9)`; Gold 321, Prestige 77, bekannte Forschung `["surveying"]`, Tempo 0.
5. Alte `LanSession.new()` mit `is_host=true`, `phase="playing"`, `game=world`; reguläres `save_host(output_path)` schreibt die Datei und den alten Fingerabdruck selbst.

Das Diagnoseprotokoll lag bei der Erstellung unter `build/tests/designer-legacy190-original.log`. Alle Namen und Spielinhalte sind synthetische Testdaten. Die Datei ist eine Testfixture und wird wegen des Exportfilters `tests/*` nicht mit dem Spiel ausgeliefert.
