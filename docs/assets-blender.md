# Blender-Asset-Pipeline

Ein einziger headless Blender-Lauf erzeugt den kompletten prozeduralen Asset-Satz
des Godot-Ports — ohne Fremdassets, ohne CK3-Material, ohne manuelle Nacharbeit:

| Familie | Anzahl | Format | Inhalt |
|---|---|---|---|
| Karten-Token | 17 | 256×256 RGBA, transparent | 9 Geländetypen, 3 Gebäude, 5 Einheiten |
| Charakterporträts | 12 | 512×512 | Brustbilder vor neutralem Grund |
| Ereignisbilder | 8 | 960×540 | Hofempfang, Hochzeit, Tempelgründung, Gabe, Ernte, Händler, Schlacht, Fieber |

## Erzeugen

```bash
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
  --background --python tools/blender/make_tokens.py
cd .tools && APPDATA="$PWD/appdata" ./godot.exe --headless --path .. --import
```

Der Blender-Lauf rendert alle 37 Bilder und schreibt `assets/asset_manifest.json`;
sein letzter Ausgabesatz ist `ASSETS OK: 17 Token, 12 Porträts, 8 Ereignisse`.
Der Godot-Import ist Pflicht und nach **jedem** Neu-Rendern zu wiederholen, weil
sonst die importierten `.ctex` veralten.

## Gestaltungsregeln

- Token: Subjekt auf einer Scheibe (Ø 2,0), Kamera orthografisch 57°/45°,
  `ortho_scale` 2,55, transparenter Hintergrund. Neue Typen ergänzen, nie umbauen.
- Porträts: 85 mm, Kamera auf 3,05 m, Brustbild mit Rumpf, Schultern, Armen, Kopf,
  Augen mit Lichtpunkt, Brauen, Nase, Mund. Unterschieden werden Geschlecht,
  Alter (Kind: größerer Kopf, kürzerer Rumpf), Stand (Krone, Reif, Helm mit
  Visier, Haube, Schleier, Kopftuch) und Gewandfarbe.
- Ereignisse: 38–40 mm, Blick leicht abwärts; Boden und Rückwand als zwei Flächen,
  Figuren im Vordergrund dunkel und groß, im Hintergrund hell und klein; die Sonne
  steht **vor** der Rückwand, nicht dahinter.
- Farben ausschließlich aus `PALETTE`. Der View-Transform steht auf `Standard`:
  AgX drückte die gemessene Farbspanne auf 3–38, mit `Standard` liegt sie bei 6–64.
  Leinen und Gewänder nutzen bewusst gedeckte Töne, weil reines Weiß ausbrennt.
- Ein Token bzw. Porträt ist eine Funktion aus Primitiven (Scheibe, Quader, Kegel,
  Kugel, Torus). Keine Texturen, keine importierten Meshes.

## Manifest und Prüfskript

`assets/asset_manifest.json` ist die einzige Quelle für Dateiliste, Zielgrößen,
Deckungskorridore und Schlüsselzuordnung:

```json
"families": { "tokens": { "size": [256,256], "coverage": [0.15,0.55], "files": [...] }, ... },
"key_map":  [ { "code": "terrain.forest", "asset": "assets/ui/tokens/terrain_forest.png" }, ... ],
"open":     [],
"existing": [ { "code": "characters.portrait_0", "asset": "assets/portraits/portrait_0.png" }, ... ]
```

```bash
python tools/verify_assets.py            # Exit 0 = alles in Ordnung
python tools/verify_assets.py --verbose  # mit Deckung, Farbzahl und Kontrast je Bild
```

Geprüft wird:

1. **Datei und Format** — existiert, Zielgröße laut Manifest, PNG im Modus RGBA,
   nicht vollständig transparent.
2. **Deckung** — Alpha-Anteil im Korridor der Familie (Token 0,15–0,55; Porträts
   und Ereignisse 0,97–1,0, weil sie einen Grund haben).
3. **Inhalt** — Bounding-Box mindestens 10 % der Fläche, mindestens 24 Farben,
   mittlere Standardabweichung ≥ 6 (fängt flaue oder leere Renders ab).
4. **Schlüsselabgleich** — liest `TERRAIN_TYPES` aus `scripts/Data.gd`,
   die Zweige von `building_cost()` aus `scripts/Game.gd` und die `"id"`-Werte aus
   `Data.gd` `events()`. Jeder gefundene Schlüssel braucht ein Asset aus `key_map`
   oder einen Eintrag in `open` mit Begründung; ein Tippfehler in `open` fällt auf.
5. **Bestand** — die zwölf bestehenden `assets/portraits/portrait_N.png` müssen
   weiterhin vorhanden sein.

Aktueller Stand: 37 Bilddateien, 20 Code-Schlüssel (terrain=9, building=3,
event=8), Exit 0. Die Ereigniszuordnung prüft zusätzlich
`tests/EventArtTest.tscn`: acht Ereignisse, acht eindeutige Dateien, acht
Cache-Treffer, ein leeres Manifest-`open` und der Vektor-Fallback; zuletzt
98 Prüfungen, Exit 0.

## Reproduzierbarkeit und Tor-Nachweis

Der vollständige Lauf nach der Erweiterung; die Leerordner-Probe des
Grundbestands wurde zuvor bestanden:

| Schritt | Ergebnis |
|---|---|
| Ein Aufruf `blender --background --python tools/blender/make_tokens.py` | Exit 0, `ASSETS OK: 17 Token, 12 Porträts, 8 Ereignisse` |
| Zählung danach | 17 / 12 / 8 PNG, Manifest mit denselben Zahlen |
| Erneuter vollständiger Lauf nach der Erweiterung | Exit 0, gleiche Zahlen, keine Reste — jede PNG-Datei steht im Manifest |
| `python tools/verify_assets.py` | Exit 0, 37 Dateien, 20 Code-Schlüssel |
| `godot --headless --import` | Exit 0, 17 / 12 / 8 `.import` |

Das Prüfskript ist als Tor belegt — jede gezielte Verletzung endet mit Exit 1:

| Verletzung | Meldung |
|---|---|
| Token auf 200×200 verkleinert | `200x200 statt 256x256` |
| Porträt-Alpha auf 0 gesetzt | `vollständig transparent` und `Deckung 0.000 außerhalb 0.97–1.00` |
| Ereignisbild als einfarbige Fläche | `nur 1 Farben` und `Kontrast zu flach (stddev 0.0)` |
| `terrain.forest` aus `key_map` entfernt | `Code-Schlüssel ohne Asset und ohne Offen-Liste: terrain.forest` |
| Tippfehler `event.gibtsnicht` in `open` | `Offen-Liste nennt unbekannten Code-Schlüssel: event.gibtsnicht` |

Nach jeder Verletzung wurde die Originaldatei zurückgespielt; der Schlusslauf ist
wieder Exit 0, und es bleiben keine Testreste.

## Zuordnung zum Spielstand

| Asset | Code-Quelle |
|---|---|
| `terrain_*` (9) | `Data.gd` `TERRAIN_TYPES` |
| `building_*` (3) | `Game.gd` `building_cost()` |
| `unit_levy`, `unit_archer`, `unit_knight`, `unit_siege` | `Game.army_composition()`: Armeestärke je 55/25/15 % auf Fußvolk, Bogenschützen, Reiterei, dazu ein Belagerungsgerät je 100 Mann |
| `unit_fleet` | fertiger Token für ein künftiges Seekriegs-System; im Manifest zugeordnet |
| `event_court_reception` | `hoftag` |
| `event_wedding` | `hochzeit` |
| `event_monastery` | `kloster` |
| `event_tithe` | `zehnt` |
| `event_harvest` | `ernte` |
| `event_merchant` | `haendler` |
| `event_battle` | `grenzstreit` |
| `event_fever` | `krankheit` |

Die Offen-Liste im Manifest ist leer. Der Flotten-Token ist als Asset vorhanden
und zugeordnet; ein Seekrieg als Spielsystem ist noch nicht implementiert.
Fußvolk, Bogenschützen, Reiterei und Belagerung sind über
`Game.army_composition()` an die Armeestärke gebunden und erscheinen als
Token-Zeile im Chronik-Abschnitt „Armee & Krieg“.
Jedes der acht Ereignisse löst über `EVENT_ART_KEYS` eine eigene, vorhandene
Bilddatei auf. Fehlt eine Datei oder kommt eine unbekannte Ereignis-ID an,
zeichnet `EventArtFallback.gd` eine texturfreie Burgenlandschaft als
Vektor-Fallback; das Panel bleibt dadurch nie leer.

## Sichtprüfung

Jeder Renderlauf wird über Kontaktbögen geprüft, nicht nur über Zahlen:

```bash
python - <<'PY'   # Bögen unter build/verify/ anlegen
...               # sheet_portraits.png, sheet_events.png, sheet_units.png
PY
```

Dabei gefunden und behoben:

- AgX entsättigte alle Token bis zur Unlesbarkeit → `Standard` + kräftigere Palette.
- Barracks-Fahne hing als loser Klotz neben dem Dach → Pol am First, Fahne daran.
- Porträts hatten Kugelohren an den Schultern und einen Riesensaum am Hals →
  schmaler Rumpf, Schulterblock, angedeutete Arme, schmaler Kragen.
- Helm lag vor dem Gesicht (weiße Kugel statt Kopf) → Helm nach hinten versetzt,
  Visierbügel und Nasenschutz ergänzt.
- Leinen- und Priestergewänder brannten aus → gedeckter `linen`-Ton.
- Ereignis-Sonne stand hinter der Rückwand → Sonne davor, Komposition mit
  Vordergrund-/Hintergrundstaffelung neu aufgebaut.
- Der gebückte Schnitter lag quer im Feld → aufrechte Figur mit Sichel.
- Hochzeit, Tempelgründung, Zehnt und Händler waren zunächst nur Wiederverwendungen
  anderer Szenen → vier eigene Renders; Priester und Wagen wurden nach der
  Fensterprüfung sichtbar in den mittleren Bildbereich gerückt.
- Das Fieber-Ereignis zeigte zunächst das alte Verratsmotiv → eigene
  Krankenstube mit Bett, Heiler, Arzneien und warmem Kerzenlicht gerendert.

## Stand und Offen

Verdrahtet:

- **Karte** (`scripts/MapView.gd`): Gelände-Token markieren die Provinzen im
  Modus „Gelände“; Hauptstädte tragen Gebäude-Token, im Kriegsmodus erscheinen
  Belagerungs-Token. Die Legende nutzt dieselben Token; fehlt eines, greift die
  Vektorform als Rückfall.
- **Provinzseite** (`scripts/Main.gd`): Gelände-Token als Provinzillustration,
  Besitzerwappen, Herrscherporträt, drei Gebäude-Token mit Stufe, Truppen-Token,
  Nachbarliste und die Aktionen Ausbauen, Werben, Angreifen und Herrschaft. Das
  Hofpanel bietet zusätzlich eine Kurzansicht mit Token, Wappen und Aufgebot.
- **Ereignis-Panel** (`scripts/Main.gd`, `ViewModelBuilder.gd`): alle acht
  Ereignisse erhalten ihr eigenes Render über die feste Zuordnung
  `EVENT_ART_KEYS`; beim Öffnen erklingt `open.wav`. Fehlt ein Bild, zeichnet
  `scripts/EventArtFallback.gd` eine Vektorlandschaft statt einer leeren Fläche.
- **Chronik**: Die Armeestärke erscheint als gemischte Token-Zeile aus Fußvolk,
  Bogenschützen, Reiterei und Belagerung.

Offen:

- Keine offenen Assets im Manifest. Der Seekrieg als Spielsystem fehlt weiterhin;
  der Flotten-Token ist dafür bereits vorbereitet.

Nach jeder UI-Änderung ist ein frischer Windows-Lauf mit
`tools/verify_windows_start.ps1` nötig; der Lauf prüft Fenster, Render-Frame,
Exit-Code und Skriptfehler.
