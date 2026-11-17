# Herkunft der echten 1.9.1-Datei mit Schema 13

`lan-191-schema13-original.json` wurde mit dem unveränderten Export `build/exports/banger-queens-1.9.1.exe` erzeugt. Ein externes, fensterloses Diagnoseskript benutzte ausschließlich die in dieser EXE eingebetteten Game-/Data-/LanSession-Ressourcen und deren reguläres `save_host()`.

- Historische EXE SHA256: `6cb5b18232bfa3f4f1f463e74d130458762596538a990fd39ea2f6df715c1a2f`.
- Eingebettete Appversion: `1.9.1`; Save-Schema: `13`; Protokoll: `3`.
- Eingebetteter Inhaltsfingerabdruck: `ca7c50860f0e76f19153a6f985117ac8de7277a0f3559ecdcba692077aebf500`. Diese exportierte Fassung verwendete noch den vorherigen Algorithmus ohne `commands` und ohne Provinzwirtschaft; der identische Wert der 1.9.0-Datei ist deshalb erwartbar.
- Fixture SHA256: `a88ef779bf4eaa2c545ae8bfa18b638117350e7647354632478598ae1402e959`.

Reproduktion mit isoliertem APPDATA und leerem Diagnosepfad: `seed(1910)`, `Game.new(GameRegionData,0)`, `configure_human_houses([0,1])`, Spielerperspektive 1; dort Gold 237, Prestige 31, bekannte Forschung `surveying` und `road_building`, eine Armee `{id:1, province:capital, strength:333, upkeep:2, morale:91}`. Tempo 0. Alte `LanSession` erhält die Welt, `is_host=true` und `phase="playing"`; `save_host()` schreibt unveränderte Metadaten und Fingerabdruck selbst.

Eine zweite unabhängige Erzeugung unter `build/verify/multiplayer-audit-191-20261117/` überprüfte vor dem Speichern EXE-SHA256, Version, Schema und alten Fingerabdruck. Die dabei erzeugte Datei ist bytegleich zur Fixture. Beleg: `build/tests/multiplayer-audit-191-independent.log`; erstes Protokoll: `build/tests/supply-agent-legacy191-original.log`. Es wurde kein aktueller Fingerabdruck mit einer alten Versionsnummer als Migrationsfixture ausgegeben.

Alle Spielinhalte sind synthetische Testdaten. Die Datei liegt unter dem bestehenden Exportausschluss `tests/*` und gehört nicht zum Spielpaket.
