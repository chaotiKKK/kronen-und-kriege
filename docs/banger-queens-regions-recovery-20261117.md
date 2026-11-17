# Banger Queens – wiederhergestellter Regionskern

Stand: 17. November 2026. Basis ist der unveränderte GitHub-Quellstand 7e127e4 (1.7.0). Der frühere lokale C:-Branch war nicht mehr erreichbar; die hier dokumentierten Änderungen wurden neu testgetrieben rekonstruiert. Die vom Nutzer genannte Downloads-EXE 1.6.1 ist unverändert.

## Geprüfter Umfang

- 108 eigene Spielregionen über neun Großräume. Der 140.044-Objekt-Atlas bleibt unverändert als eigenständige Referenz erhalten.
- Deterministische Anker, begrenzte Voronoi-Relaxation, echte übernommene Atlasgrenzen, Reparatur abgetrennter Festlandfragmente und getrennte Eltern-/Regionsanteile.
- 100 angepasste Grenzpaare, 5.455,321511 Einheiten tatsächlich gemeinsamer Atlasgrenzen. Vier harte Flächenausnahmen; Inselgruppen und kleine Inseln werden mit Geometriebelegen dokumentiert. Keine generische Ausnahme zum Übergehen eines Festlandfehlers.
- Rechenpräzision 1e-7 Kartenlängeneinheiten, zulässiger numerischer Überlappungsrest 1e-6 Flächeneinheiten; Binärformat float32, little endian. Abdeckung wird gegen die ursprüngliche Rahmenunion geprüft.
- Godot-Runtimekatalog prüft die exakten kanonischen Writerbytes plus Binärdaten. Ein 32-Einheiten-Raumindex bedient Ankertreffer und Rechteckabfragen. Fehlgeschlagene Ladevorgänge leeren den Zustand und liefern deutsche Fehler.
- Adapter zur bisherigen Engine erhält jährliche Grundwirtschaft 762 (davon 740 aus Provinzen) und 24.240 Aufgebot. Hauswerte sind einzeln geprüft. Die echte jährliche Basiswirtschaft und der JSON-Roundtrip einer neuen Regionspartie bestehen.

## Reproduktion

Python 3.14, Shapely 2.1.2, Godot 4.5.1. Die Godot-Binary stammt aus der offiziellen Veröffentlichung: https://github.com/godotengine/godot-builds/releases/tag/4.5.1-stable . Lokale Werkzeuge liegen ausschließlich im ignorierten .tools-Ordner.

```powershell
python -m unittest tools.test_game_regions -v
python tools/build_game_regions.py
.tools\godot_console.exe --headless --path . res://tests/GameRegionCatalogTest.tscn
.tools\godot_console.exe --headless --path . res://tests/GameRegionDataTest.tscn
```

Realer Doppellauf: JSON, Binärgeometrie und Quellenreceipt byteidentisch. Katalogfingerabdruck:

```text
6112a370a9c26d1186059519e26742db7b63a10b4082c41e2fb2623b30f5f629
```

14 Pythonprüfungen grün. Neun gezielte Godot-Suiten mit insgesamt 2.866 Prüfungen grün. Einzelbelege unter build/tests, Produktionsreceipt unter build/verify/game-regions-build.json. Logauswertung verlangt Erfolgsmeldung und lehnt native/script errors ausdrücklich ab; Exitcode 0 allein reicht nicht.

## Verbleibende Arbeiten

Die regulären Menüstarts arbeiten noch mit den 49 bisherigen Provinzen. Vor einer Umschaltung fehlen die vollständige Gewichtung von Rekrutierung/KI/Gebäudewirkungen, Schema-13-Migration einschließlich gemischter Besitzer und Backups, Katalogbindung im WLAN-Protokoll 2 sowie Karten-/UI-Einbindung und Gesamtabnahme. Neue ausführbare Pakete werden erst aus diesem integrierten Stand gebaut.

Die privaten Rohquellcaches wurden nicht wiedergefunden. Die veröffentlichten drei Atlas-/Geografiedatensnapshots sind bytegleich zur Git-Basis und werden vollständig gehasht. Veröffentlichte Herkunftsbelege werden mitgeführt, aber `raw_sources_rehashed=false` ist ausdrücklich gesetzt. Acht Quellenfälle AZ/CNM/IL/KZ/LB/LY/MA/TR und reale Zwei-Geräte-WLAN-Abnahme bleiben offen. Kein Poco-/Emulator-/Windows-Grafiklauf wurde in dieser Fortsetzung durchgeführt.
