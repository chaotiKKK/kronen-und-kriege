# Blender-Asset-Pipeline

Ein einziger headless Blender-Lauf erzeugt den kompletten prozeduralen Asset-Satz
des Godot-Ports — ohne Fremdassets, ohne CK3-Material, ohne manuelle Nacharbeit:

| Familie | Anzahl | Format | Inhalt |
|---|---|---|---|
| Karten-Token | 17 | 256×256 RGBA, transparent | 9 Geländetypen, 3 Gebäude, 5 Einheiten |
| Charakterporträts | 12 | 512×512 | Brustbilder vor neutralem Grund |
| Ereignisbilder | 4 | 960×540 | Hofempfang, Schlacht, Ernte, Verrat |

## Erzeugen

```bash
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
  --background --python tools/blender/make_tokens.py
cd .tools && APPDATA="$PWD/appdata" ./godot.exe --headless --path .. --import
```

Der Blender-Lauf rendert alle 33 Bilder und schreibt `assets/asset_manifest.json`;
sein letzter Ausgabesatz ist `ASSETS OK: 17 Token, 12 Porträts, 4 Ereignisse`.
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
"open":     [ { "code": "unit.fleet", "reason": "Seekrieg existiert im Code nicht; ..." } ],
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

Aktueller Stand: 33 Bilddateien, 20 Code-Schlüssel (terrain=9, building=3,
event=8), Exit 0.

## Reproduzierbarkeit und Tor-Nachweis

Geprüft aus vollständig geleerten Zielordnern (PNG **und** `.import` gelöscht,
Manifest entfernt):

| Schritt | Ergebnis |
|---|---|
| Ein Aufruf `blender --background --python tools/blender/make_tokens.py` | Exit 0, `ASSETS OK: 17 Token, 12 Porträts, 4 Ereignisse` |
| Zählung danach | 17 / 12 / 4 PNG, Manifest mit denselben Zahlen |
| Zweiter Aufruf direkt danach | Exit 0, gleiche Zahlen, keine Reste — jede PNG-Datei steht im Manifest |
| `python tools/verify_assets.py` | Exit 0, 33 Dateien, 20 Code-Schlüssel |
| `godot --headless --import` | Exit 0, 17 / 12 / 4 `.import` |

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
| `unit_levy`, `unit_archer`, `unit_knight`, `unit_siege` | `Game.army_composition()`: Armeest�rke je 55/25/15 % auf Fu�volk, Bogensch�tzen, Reiterei, dazu ein Belagerungsger�t je 100 Mann |
| `event_court_reception` | `hoftag` |
| `event_harvest` | `ernte` |
| `event_battle` | `grenzstreit` |

Bewusst offen (im Manifest mit Begr�ndung): `unit.fleet` � Seekrieg existiert im
Code nicht; der Token liegt als Vorleistung bereit. Fu�volk, Bogensch�tzen,
Reiterei und Belagerung sind �ber `Game.army_composition()` an die Armeest�rke
gebunden und erscheinen als Token-Zeile im Chronik-Abschnitt �Armee & Krieg�.
Ebenso `event.zehnt`, `event.hochzeit`, `event.krankheit`, `event.kloster` und `event.haendler`: der
erste Satz deckt vier Szenen ab, die übrigen Ereignisse nutzen später eine
Fallback-Illustration.

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

## Stand und Offen

Verdrahtet:

- **Gelände-Token als Kartenlegende** (`scripts/MapView.gd`): im Kartenmodus
  „Gelände" zeigt die Legende die neun Token als Icon neben dem Geländenamen;
  fehlt ein Token, greift der Farbbalken als Rückfall.
- **Gebäude-Token in der Provinzseite** (`scripts/Main.gd`, `ViewModelBuilder.gd`):
  Markt, Kaserne und Mauern erscheinen mit Token, Name und Stufe über den
  Ausbauknöpfen des Bau-Abschnitts.

Offen:

- Einheiten-Token, Porträts und Ereignisbilder sind noch nicht angebunden
  (Truppenliste, Charakteransicht, Ereignis-Panel).
- Jede UI-Änderung verschiebt die Screenshots der 30-Minuten-Abnahme; nach dieser
  Verdrahtung ist ein frischer Windows-Lauf nötig.
