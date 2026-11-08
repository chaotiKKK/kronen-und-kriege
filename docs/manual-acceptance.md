# Manuelle 30-Minuten-Abnahme

> Dokumentversion: 1.3
> Stand: 2026-11-08
> Gültig für: Version 1.3, Builds `F:\ck3-kronen-kriege.exe` und `F:\ck3-kronen-kriege.apk` aus dem Arbeitsbaum auf `8af9c8f` (Versionssprung auf 1.3 uncommittet); nicht das GitHub-Release `89846de4fcdf4c9fef3f11b1c9fbe6041c4a2634`.
> Geltungsbereich: Windows x86_64 und Android (`arm64-v8a`, `armeabi-v7a`)
> **Status: Windows-Lauf am 2026-11-08 gegen den 1.3-Build durchgeführt; Ergebnis BESTANDEN.** P01–P12, alle drei Roundtrips und der KI-Beleg (AI2+AI3) sind belegt; Belege unter `build/verify/manual-build-d2cc-v2/`. Der Lauf am 2026-11-07 auf dem 1.2-Build bleibt als Historie dokumentiert. Der frühere Android-Befund „extern blockiert“ ist widerlegt und im [Android-Bericht](manual-acceptance-android-visual.md) korrigiert. Die Android-APK 1.3 wurde mangels verbundenem Gerät nicht installiert; der Android-Lauf bleibt offen.
> **Windows:** [Laufprotokoll 2026-11-08](#windows-lauf-2026-11-08) — **BESTANDEN** auf dem 1.3-Build (`d2cc6508d07c65cb64e786a029736e4c04ad17f800736c6ac2f3c38f0826ec72`, `113.718.904 Bytes`, `14:00:57`). Älterer Beleg: [Lauf 2026-11-07](#windows-lauf-2026-11-07) auf dem 1.2-Build (`951c65bd4e04f97f8b607ae4bb153b2c2de3fe4a45c1620d32704754eb1a3121`, `113.716.840 Bytes`, `17:08:59`). **Android:** nicht abgeschlossen; die Force-Stops kamen aus einer lokalen Bash-Schleife, nicht aus einem externen ADB-Treiber.

## Zweck

Dieses Protokoll macht die im [Depth Contract](depth-contract.md) und im [Wellenplan](waves.md) verlangte manuelle 30-Minuten-Partie reproduzierbar. Eine beliebige Person soll die Partie ohne Rückfragen durchführen und am Ende objektiv **BESTANDEN** oder **DURCHGEFALLEN** vergeben können.

Die automatisierten Tests bleiben eigenständig. Insbesondere ersetzt dieses Protokoll weder `StoryTest` noch die Matrix-Nachweise aus `SystemicDepthTest` und `FullDepthTest`. Es prüft die Bedienbarkeit und die sichtbaren Wirkungen einer echten Partie über 30 Minuten Wanduhrzeit.

## Vorbedingungen

### Build und Plattform

| Prüfung | Windows | Android |
|---|---|---|
| Artefakt | `F:\ck3-kronen-kriege.exe` | `F:\ck3-kronen-kriege.apk` bzw. installierte App |
| Version | `1.3.0.0` | `versionName 1.3`, `versionCode 4` |
| Build-Commit | Arbeitsbaum auf `8af9c8f` (Versionssprung auf 1.3 uncommittet) | derselbe Arbeitsbaum |
| SHA-256 | `d2cc6508d07c65cb64e786a029736e4c04ad17f800736c6ac2f3c38f0826ec72` | `3b17118a9ea7d4e307fec735b58cc4b46dcc459d4ca49a4edac30f71037dbbbf` |
| Größe | `113.718.904 Bytes` | `180.708.021 Bytes` |
| Zeitstempel | `2026-11-08 14:00:57` (CET) | `2026-11-08 14:02:14` (CET) |
| Paket | — | `org.example.kronen` |
| Start | `F:\ck3-kronen-kriege.exe` | Launcher-Icon oder `org.example.kronen/com.godot.game.GodotApp` |
| Anzeige | Fenster oder `F11` Vollbild | Landscape (`window/handheld/orientation=0`), entsperrter Bildschirm |

Der veröffentlichte Referenzstand auf GitHub ist `git rev-parse v1.2^{}` (Commit `89846de4fcdf4c9fef3f11b1c9fbe6041c4a2634`). Release 1.3 ist lokal gebaut, aber nicht veröffentlicht. Für diesen Lauf zählt ausschließlich der Hash der Dateien unter `F:`.

Erwartet: Windows `d2cc6508d07c65cb64e786a029736e4c04ad17f800736c6ac2f3c38f0826ec72` bei `113.718.904 Bytes` und Zeitstempel `2026-11-08 14:00:57`; Android `3b17118a9ea7d4e307fec735b58cc4b46dcc459d4ca49a4edac30f71037dbbbf` bei `180.708.021 Bytes`. Weicht der Hash oder die SHA-256 der Binärdatei ab, wird **nicht** getestet: Preflight fehlgeschlagen.

### Zeit, Tempo und Ausgangszustand

- **30:00 Minuten Wanduhrzeit**, gemessen mit einer Stoppuhr oder einem Timer. Die Zeit läuft auch während Speichern, Laden, Screenshots und Ereignisdialogen weiter.
- Spieltempo **`x3`**. `x3` ist die Laufgeschwindigkeit; `Pause` ist der Arbeitszustand für jede Entscheidung, jeden Screenshot, jede Save-/Load-Prüfung und jede zeitkritische Kontrolle. Zwischen den Aktionen läuft `x3` nur so lange, wie für die beobachtbare Jahreswirkung nötig. Die 30:00-Uhr läuft durchgehend, auch in `Pause`.
- Ein frisches Spiel über **`Neues Spiel`** beginnen. Nicht `Spiel laden` verwenden und keinen alten Spielstand als Startzustand nehmen.
- Fester Start: **`Haus Sequana`**. Die Zeile im Hausauswahlbildschirm beginnt mit `Haus Sequana` und ist an ihrem Herrscher, ihrer Provinzzahl und ihrem Gold erkennbar. Sequana ist zu Beginn unverheiratet; dadurch ist die dynastische Pflichtaktion `Heiraten` möglich. Kein Eigenes Haus und kein anderes Haus wählen, sonst ist der Lauf nicht vergleichbar.
- Startwerte notieren: Datum, Gold, Prestige, Legitimität, Erbe und Anzahl der Ansprüche/Armeen. Die Startwerte stehen nach dem Start im Hofpanel und im Herrschaftsmodal.

### Evidenzablage

Vor dem Start im Projektordner anlegen:

```powershell
cd "C:\Crusader Kings III\mobile-godot"
New-Item -ItemType Directory -Force build\verify\manual\screens, build\verify\manual\saves, build\verify\manual\logs | Out-Null
```

Alle Belege werden unter `build\verify\manual\` gespeichert. `build/` ist von den Exporten ausgeschlossen. Die Evidenz wird nicht in Git committet.

| Beleg | Windows | Android |
|---|---|---|
| Screenshot | `Win+Shift+S`, danach als `screens\win-<zeit>.png` speichern | Gerät oder `adb`-Screenshot; siehe unten |
| Spiel-Log | Start mit `--log-file`; Datei `logs\windows-session.log` | `adb logcat`; Datei `logs\android-session.log` |
| Save | `%APPDATA%\Godot\app_userdata\Kronen und Kriege\spielstand.json` | app-privat `user://spielstand.json`; Abholung über `run-as` |

Android-Screenshot und -Log:

```powershell
$adb = "C:\Users\HP\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb shell screencap -p /sdcard/ck-manual.png
& $adb pull /sdcard/ck-manual.png "build\verify\manual\screens\android-<zeit>.png"
& $adb logcat -d -v threadtime > "build\verify\manual\logs\android-session.log"
```

Windows-Start mit Log:

```powershell
cd "C:\Crusader Kings III\mobile-godot"
& "F:\ck3-kronen-kriege.exe" --log-file "C:\Crusader Kings III\mobile-godot\build\verify\manual\logs\windows-session.log"
```

### Speicherpfad

Der logische Pfad ist in beiden Builds `user://spielstand.json`.

- **Windows:** `%APPDATA%\Godot\app_userdata\Kronen und Kriege\spielstand.json`
  - Beispiel: `C:\Users\<Name>\AppData\Roaming\Godot\app_userdata\Kronen und Kriege\spielstand.json`
- **Android:** app-privat; bei diesem Debug-Build über ADB lesbar:
  ```powershell
  $adb = "C:\Users\HP\AppData\Local\Android\Sdk\platform-tools\adb.exe"
  & $adb exec-out run-as org.example.kronen cat files/spielstand.json > "build\verify\manual\saves\android-spielstand.json"
  ```
  Wenn `run-as` oder der Pfad `files/spielstand.json` nicht funktioniert, ist der KI-Beleg auf Android nicht führbar; der Lauf gilt dann als **DURCHGEFALLEN**, nicht als „nicht anwendbar“.

### Verbindliche Zählregeln

- **12 echte Entscheidungen:** Jede in der Tabelle P01–P12 genannte Aktion muss ausgeführt werden. Eine Entscheidung liegt nur vor, wenn es mindestens zwei legale Optionen mit unterschiedlichen Folgen gibt; ein reiner Bestätigungsdialog zählt nicht.
- **Mindestens 10 Kanten**, davon mindestens **3 dynastische** und **3 Krieg-/Diplomatie-Kanten**. Die Pflichtaktionen decken 13 Kanten ab; fehlt eine, ist die Mindestabdeckung nicht erreicht.
- **2 KI-Kanten** aus AI2, AI3 oder AI4 werden über den Save-Vergleich belegt. Zwei unterschiedliche Präfixe sind Pflicht.
- **3 Save/Load-Roundtrips** bei 04:30, 14:30 und 24:30. Zusätzlich wird bei 00:30 ein Ausgangs-Save und bei 30:00 das End-Save für den KI-Vergleich erstellt.
- **Screenshots:** mindestens einer am Ende jedes Fünf-Minuten-Fensters. Die Evidenztabelle darf zusätzlich weitere Belege nennen.
- Alle zwölf Pflichtaktionen werden versucht. Ist eine Aktion wegen fehlender Voraussetzungen nicht möglich, wird ein anderes legales Ziel gewählt; bleibt sie unmöglich, wird die Zeile `FAIL` und der Gesamtlauf `DURCHGEFALLEN`.

## Sechs Fünf-Minuten-Fenster

Die Zeitangaben sind Soll-Zeiten. Die Aktion muss innerhalb ihres Fensters abgeschlossen und belegt werden; ein späterer Abschluss zählt nur, wenn die Gesamtzeit 30:00 nicht überschreitet und die Evidenz den tatsächlichen Zeitpunkt nennt.

### 00:00–05:00 — Start und Herrschaft

1. `Neues Spiel` → `Wähle dein Haus` → Zeile `Haus Sequana` wählen (Startgold 130). Die App startet die Partie; die Startmarke `v1.3 · Bronzezeit · 2000 v. Chr.` muss vor dem Start sichtbar gewesen sein. Nach dem Start sofort `Pause`.
2. Provinz `Lugdunum` (Hauptstadt) auf der Karte antippen. Die Hinweiszeile muss `Eigenes Land: ausbauen oder Truppen werben.` oder eine eigene Provinzinfo zeigen.
3. Bei 00:30 `Spiel speichern`; die Datei als `saves\ai-start.json` kopieren (Windows) bzw. per `run-as` abholen (Android). Dies ist die KI-Ausgangsbasis, kein Roundtrip.
4. **P01 (H1):** `Herrschaft` öffnen. Im Abschnitt `Rat` beim Eintrag `Marschall: ...` auf `Wechseln` klicken. Notieren, welcher Marschall aktiv ist. Danach `Schließen`, `x3` für mindestens einen Jahreswechsel (Log `... trainiert ... (+N Truppen)`), dann wieder `Pause`.
5. **P02 (H2):** Im Abschnitt `Gesetz` auf die Schaltfläche `Erbfolge: Ältester` klicken. Danach muss sie `Erbfolge: Jüngster` heißen. Mit `Stammbaum` prüfen: dort steht `Erbfolgegesetz: Jüngster.`; mit `Schließen` zurück.
6. Bei 04:30 **Roundtrip 1:** `Spiel speichern`, die Felder aus der Save-Diff-Liste notieren, `Spielstand laden`; alle Felder müssen unverändert sein. Danach `Pause` halten.

**Plattformhinweis:** Die Schaltflächen sind auf beiden Plattformen identisch. Auf Android werden sie getippt; auf Windows geklickt. `F11` gibt es nur unter Windows.

### 05:00–10:00 — Wirtschaft und Gebäude

1. **P03 (H3):** `Herrschaft` → `Gesetz`. Aktuellen Steuersatz notieren und die Schaltfläche `Steuersatz: <aktuell>/2` einmal drücken. Der Zyklus ist `1/2 → 2/2`, `2/2 → 0/2`, `0/2 → 1/2`; der Wert muss sich ändern. Danach `Schließen`, `x3` bis zur nächsten Jahresabrechnung, dann `Pause`. Ist der Wert bereits durch Faktionsdruck auf `2/2` gestiegen, ist der Wechsel auf `0/2` der Beleg; ein unveränderter Wert ist `FAIL`.
2. **P04 (H4):** Eigene Provinz `Lugdunum` auswählen, `Herrschaft` → `Bauen` → `Markt: Stufe 0/3 · 60 Gold` drücken. Danach muss dort `Markt: Stufe 1/3` stehen und Gold um 60 gesunken sein. Ist der Markt in Lugdunum nicht auf Stufe 0, eine andere eigene Provinz mit Markt Stufe 0 wählen; gibt es keine, `FAIL`. Kein Ersatz durch Kaserne oder Mauern.
3. Screenshot `screens\...-10.png`. Kein Pflicht-Roundtrip in diesem Fenster; `Pause` halten.

### 10:00–15:00 — Krieg vorbereiten und Dynastie

1. **P05 (H5):** Eigene Provinz auswählen, `Herrschaft` → `Bauen` → `Kaserne: Stufe 0/3 · 70 Gold` drücken. Danach `Kaserne: Stufe 1/3` und einen höheren Truppenwert in der Provinzinfo notieren.
2. **P06 (D5):** Vor der Heirat `Gold` prüfen; bei weniger als 30 Gold mit `x3` warten, bis die Kosten bezahlbar sind, dann `Pause`. `Herrschaft` schließen. Auf `Heiraten  (30 Gold)` klicken. Im Picker `Wen heiratest du?` ein freies Ziel mit der höchsten angezeigten Prozentchance wählen. Erwartet: `Gemahl/in: ...` im Hofpanel, `Legitimität` +5 und ein Log-Eintrag mit `Legitimität +5`. Bei Ablehnung die zwölf Spielmonate Abklingzeit mit `x3` abwarten und erneut versuchen; ein Fehlversuch allein ist kein Bestehen.
3. Bei 14:30 **Roundtrip 2:** `Spiel speichern`, Save-Diff-Felder notieren, `Spielstand laden`, Werte vergleichen. Danach `Pause` halten.

Wenn nach dem Markt- und Kasernebau nicht genug Gold für die Heirat vorhanden ist, mit `x3` weiterlaufen, bis die Kosten bezahlbar sind; die Wartezeit zählt zur Fensterzeit. Bei 15:00 ohne Ehe ist P06 `FAIL`.

### 15:00–20:00 — Ansprüche und Armee

1. **P07 (K2):** Vor dem Anspruch mindestens 90 Gold für P07 und P08 sicherstellen; sonst mit `x3` warten, dann `Pause`. Eine **fremde Nachbarprovinz** mit `Meinung` unter 50 auswählen; nach dem Frieden steigt sie um 10 und bleibt unter der D6-Schwelle von 60. Die Hinweiszeile muss `Feindliches Land: angreifen, wenn es an dein Gebiet grenzt.` zeigen. `Herrschaft` öffnen; im Abschnitt `Krieg und Diplomatie` muss die Zeile `Ziel: ...` den Zielherrn nennen. `Anspruch schmieden (40 Gold)` drücken. Erwartet: `Ansprüche` steigt um 1. Danach `Herrschaft` schließen und prüfen, dass `Angreifen  (25 Gold)` für dieses Ziel aktiv ist. Vor dem Anspruch muss die Schaltfläche deaktiviert gewesen sein. Kein Angriff nötig; der K2-Beleg ist die Freischaltung durch den Anspruch.
2. **P08 (K3):** Eigene Provinz auswählen, `Herrschaft` → `Armee aufstellen (50 Gold)`. Erwartet: `Armeen` steigt um 1 und Gold sinkt um 50. Im nächsten Jahreswechsel wird Unterhalt abgezogen; den Goldwert notieren.
3. Screenshot `screens\...-20.png`.

**Zeitkritisch:** Ein Anspruch verfällt nach 240 Spielmonaten. P07–P12 im Arbeitszustand `Pause` abschließen; `x3` zwischen P07 und P12 nur für unvermeidbare Jahreswechsel laufen lassen.

### 20:00–25:00 — Belagerung und Frieden

1. **P09 (K4):** Bei 20:00 `Pause` (falls nicht schon aktiv). Die in P07 beanspruchte fremde Provinz auswählen. `Herrschaft` → `Belagerung vorantreiben`. Erwartet: `Belagerung` steigt über 0 %, die Zeile bleibt bei der Zielprovinz. Den Prozentwert notieren.
2. **P10 (K6):** Dasselbe Ziel ausgewählt lassen. `Frieden schließen (24 Monate)` drücken. Erwartet: In der Zielzeile steht `Waffenstillstand bis <Zahl>` in der Zukunft; die `Meinung` steigt um 10. Ein Frieden ist auch ohne vorherigen Angriff zulässig; der Beleg ist der Waffenstillstand.
3. **P12 (K7), ohne zu entpausieren:** `Herrschaft` schließen, das Friedensziel auswählen und `Angreifen  (25 Gold)` prüfen. Die Schaltfläche muss deaktiviert sein und die Zielzeile den Waffenstillstand zeigen. **Der Waffenstillstand dauert nur 24 Spielmonate; bei x3 sind das etwa 8,4 Sekunden. Deshalb darf zwischen P10 und P12 nicht entpausiert werden.** Ist `Angreifen` aktiv, ist K7 nicht belegt → `FAIL`.
4. Bei 24:30 **Roundtrip 3:** `Spiel speichern`, Save-Diff-Felder notieren, `Spielstand laden`, vergleichen. Danach `Pause` halten.

### 25:00–30:00 — Geheimnis und Abschluss

1. **P11 (D7 + D8):** Eine fremde Provinz eines **anderen** Hauses als in P07/P10 auswählen, dessen Hauptstadt noch keinen Anspruch hat. `Herrschaft` → `Geheimnis aufdecken`, dann `Geheimnis ausnutzen`. Erwartet: `Haltung` des Ziels sinkt um 15 und `Ansprüche` steigt um 1. Ein Log-Eintrag ist für D7/D8 nicht erforderlich. Falls `Ansprüche` nicht steigt, war bereits ein Anspruch auf die Zielhauptstadt vorhanden; anderes Haus wählen und P11 wiederholen. D7 und D8 zählen nur, wenn beide Wirkungen beobachtet wurden.
2. Bei 30:00: `Spiel speichern`; die Datei als `saves\ai-end.json` kopieren. Screenshot `screens\...-30.png`. Danach die App beenden; keine Zeitverlängerung.

## Pflichtaktionen und Kantenzuordnung

| ID | Zeitfenster | Exakte Aktion | Matrixkante | Erwartete beobachtbare Wirkung |
|---|---|---|---|---|
| P01 | 00–05 | `Herrschaft` → `Rat` → `Marschall: ...` → `Wechseln` | **H1** | Beim nächsten Jahreswechsel Log `... trainiert ... (+N Truppen)`; Hauptstadt-Truppen steigen. |
| P02 | 00–05 | `Herrschaft` → `Gesetz` → `Erbfolge: Ältester` drücken | **H2** | Schaltfläche wird `Erbfolge: Jüngster`; `Stammbaum` zeigt `Erbfolgegesetz: Jüngster.` |
| P03 | 05–10 | `Herrschaft` → `Gesetz` → `Steuersatz: <aktuell>/2` drücken | **H3** | Label wechselt im Zyklus `1/2 → 2/2`, `2/2 → 0/2` oder `0/2 → 1/2`; die nächste Jahresabrechnung verändert Gold ohne andere Goldausgabe. |
| P04 | 05–10 | Eigene Provinz → `Herrschaft` → `Bauen` → `Markt: Stufe 0/3 · 60 Gold` | **H4** | `Markt: Stufe 1/3`; Gold −60; im nächsten Jahr Markteinkommen. |
| P05 | 10–15 | Eigene Provinz → `Herrschaft` → `Bauen` → `Kaserne: Stufe 0/3 · 70 Gold` | **H5** | `Kaserne: Stufe 1/3`; Provinz-Truppen steigen. |
| P06 | 10–15 | `Heiraten  (30 Gold)` → Picker `Wen heiratest du?` → freies Ziel | **D5** | `Gemahl/in` gesetzt; `Legitimität` +5; Log `Legitimität +5`. |
| P07 | 15–20 | Fremde Nachbarprovinz → `Herrschaft` → `Anspruch schmieden (40 Gold)` | **K2** | `Ansprüche` +1; `Angreifen  (25 Gold)` wird für das Ziel aktiv. |
| P08 | 15–20 | Eigene Provinz → `Herrschaft` → `Armee aufstellen (50 Gold)` | **K3** | `Armeen` +1; Gold −50; im nächsten Jahr Unterhalt. |
| P09 | 20–25 | Beanspruchte fremde Provinz → `Herrschaft` → `Belagerung vorantreiben` | **K4** | `Belagerung` steigt über 0 %. |
| P10 | 20–25 | Zielprovinz → `Herrschaft` → `Frieden schließen (24 Monate)` | **K6** | `Waffenstillstand bis <Zahl>` in der Zukunft; `Meinung` +10. |
| P11 | 25–30 | Fremde Provinz eines anderen Hauses → `Herrschaft` → `Geheimnis aufdecken` → `Geheimnis ausnutzen` | **D7 + D8** | `Haltung` −15; `Ansprüche` +1; kein Log-Eintrag erforderlich. |
| P12 | 20–25 | Friedensziel auswählen → `Angreifen  (25 Gold)` prüfen | **K7** | `Angreifen` ist bei pausiertem Spiel wegen `Waffenstillstand bis <Zahl>` deaktiviert. |

**Abgedeckte Kanten:** H1, H2, H3, H4, H5, D5, K2, K3, K4, K6, D7, D8, K7 = **13 Kanten**.
**Dynastisch:** D5, D7, D8 = **3**.
**Krieg/Diplomatie:** K2, K3, K4, K6, K7 = **5**.
**Entscheidungen:** P01–P12 = **12**.

## KI-Beleg

Die zwei KI-Kanten werden nicht aus der Spieler-UI abgeleitet, sondern aus den beiden Save-Ständen `saves\ai-start.json` (00:30) und `saves\ai-end.json` (30:00). Das ist zulässig, weil beide Dateien aus demselben Lauf und demselben Spielzustand stammen. Belegt werden **AI2, AI3 und AI4**; **AI1 wird nicht als Pflichtbeleg verwendet**, weil die allgemeine jährliche Truppenverstärkung den Levy-Wert ebenfalls erhöht und die Trainingskante dadurch nicht eindeutig wäre.

Nach dem Lauf im Projektordner ausführen:

```powershell
$before = Get-Content -Raw "build\verify\manual\saves\ai-start.json" | ConvertFrom-Json
$after  = Get-Content -Raw "build\verify\manual\saves\ai-end.json"   | ConvertFrom-Json
$player = [int]$before.player
$hits = @()

for ($i = 0; $i -lt $before.houses.Count; $i++) {
    if ($i -eq $player) { continue }
    $bh = $before.houses[$i]
    $eh = $after.houses[$i]
    if ([int]$bh.laws.tax -ne [int]$eh.laws.tax) {
        $hits += "AI2: Haus $i Steuersatz $($bh.laws.tax) -> $($eh.laws.tax)"
    }
    if ([string]::IsNullOrEmpty([string]$bh.spouse.name) -and
        -not [string]::IsNullOrEmpty([string]$eh.spouse.name)) {
        $hits += "AI3: Haus $i hat geheiratet"
    }
}

for ($j = 0; $j -lt $before.provinces.Count; $j++) {
    $bo = [int]$before.provinces[$j].owner
    $eo = [int]$after.provinces[$j].owner
    if ($bo -ne $eo -and $bo -ne $player -and $eo -ne $player) {
        $hits += "AI4: Provinz $($before.provinces[$j].name) Besitzer $bo -> $eo"
    }
}

$hits | Sort-Object -Unique
$edges = @($hits | ForEach-Object { ($_ -split ':')[0] } | Sort-Object -Unique)
if ($edges.Count -lt 2) {
    Write-Output "KI-BELEG FAIL: nur $($edges.Count) verschiedene KI-Kanten."
    exit 1
}
Write-Output "KI-BELEG OK: $($edges -join ', ')"
```

Mindestens zwei **verschiedene** Präfixe `AI2`, `AI3` oder `AI4` müssen ausgegeben werden. Die konkreten Zeilen und das Skript-Ergebnis werden in der Evidenztabelle unter `AI-01` und `AI-02` eingetragen. `AI1` und `AI5` sind optional und zählen nicht als Pflichtersatz.

## Windows-Lauf 2026-11-08

- **Gerät:** Windows x86_64, Fenster `Kronen und Kriege`, EXE `F:\ck3-kronen-kriege.exe`.
- **Build:** `1.3.0.0`, SHA-256 `d2cc6508d07c65cb64e786a029736e4c04ad17f800736c6ac2f3c38f0826ec72`, `113.718.904 Bytes`, Zeitstempel `2026-11-08 14:00:57` (CET); `MAIN_READY version=1.3`.
- **Start:** `14:45:16` Uhr, **geplantes Ende:** `15:15:16` Uhr, **tatsächliches Ende:** `15:15:17` Uhr (30:01 Wanduhrzeit).
- **Startzustand:** `Haus Sequana`, Hartung 2000 v. Chr., Gold 130, Prestige 6, Legitimität 50, Erbe `Epona`, 0 Ansprüche, 0 Armeen.
- **Ereignisse im Lauf:** `14:46:22` „Schlicht bleiben“ (+5 Prestige); `15:00:18` „Verweigern“ (+35 Gold, −12 Prestige).
- **Ausgangs-Save:** `saves/ai-start.json` um `14:45:47` (00:31).
- **Roundtrip 1:** `14:49:47` (04:31), `saves/roundtrip1-before.json`, Save/Load ohne Diff (Gold 228, Prestige 11, Legitimität 50, Erbfolge `Jüngster`, sechs eigene Provinzen).
- **Roundtrip 2:** `14:59:47` (14:31), `saves/roundtrip2-before.json`, Save/Load ohne Diff.
- **Roundtrip 3:** `15:09:47` (24:31), `saves/roundtrip3-before.json`, Save/Load ohne Diff.
- **Aktionen:** P01–P12 vollständig ausgeführt und **PASS**; Zeiten und beobachtete Wirkung in der Tabelle unten.
- **KI-Beleg:** **AI2** (Haus 3, 5 und 7: Steuersatz 1 → 2) und **AI3** (Haus 5 und Haus 7 haben geheiratet); zwei verschiedene KI-Kanten.
- **Automatisierte Gegenprüfung:** `FullDepthTest` headless am `2026-11-08` um `15:38` gegen genau diesen Stand: `FULLDEPTHTEST OK … 57 Prüfungen`, Exit 0, keine Fehlerzeile. Beleg: `build/verify/final-fulldepth-check-1.3.log`; die K6-Zusicherung `truce_until(1) > _now()` steht in `tests/FullDepthTest.gd:290`.
- **Ende:** `ai-end.json` und die Screenshots um `15:15:17`; der Prozess endete nach `run_end 2026-11-08T15:15:17 status=BESTANDEN`.
- **Befehl:** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_acceptance.ps1 -Exe "F:\ck3-kronen-kriege.exe" -Project "" -Out "C:/Crusader Kings III/mobile-godot/build/verify/manual-build-d2cc-v2"`.
- **Beleg:** `build/verify/manual-build-d2cc-v2/` mit `acceptance-result.json`, `acceptance.log`, `run.out.log`, `run.err.log`, `saves/` und `screens/`.
- **Screenshots:** `screens/win-043-05.png`, `win-043-10.png`, `win-043-15.png`, `win-043-20.png`, `win-043-25.png`, `win-042-3000.png` und `win-042-3000-preview.png` (Endstand).
- **Logs:** `run.out.log` enthält `MAIN_READY version=1.3` und den vollständigen Driver-Lauf; `run.err.log` enthält nur die nicht kritische Windows-Common-Controls-Warnung. Keine `ERROR`-, `SCRIPT ERROR`-, Exception- oder Crash-Zeile.
- **Ergebnis:** **BESTANDEN**.

| ID | Zeit | Aktion | Beobachtete Wirkung | Kante | P/F |
|---|---|---|---|---|---|
| P01 | 14:46:01 | `Herrschaft` → `Rat` → `Marschall` → `Wechseln` | Marschallwechsel; `Hattusa trainiert Lugdunum (+8 Truppen)` | H1 | PASS |
| P02 | 14:46:16 | `Herrschaft` → `Gesetz` → `Erbfolge: Ältester` | Erbfolge `Ältester` → `Jüngster`; Gold 130 unverändert | H2 | PASS |
| P03 | 14:50:16 | `Herrschaft` → `Gesetz` → `Steuersatz` | Steuersatz `1/2` → `2/2`; Gold 228 unverändert | H3 | PASS |
| P04 | 14:50:31 | `Lugdunum` → `Bauen` → `Markt` | `Lugdunum` Markt Stufe 0 → 1; Gold 228 → 168 | H4 | PASS |
| P05 | 14:55:17 | `Lugdunum` → `Bauen` → `Kaserne` | `Lugdunum` Kaserne Stufe 0 → 1; Gold 168 → 98 | H5 | PASS |
| P06 | 14:55:19 | `Heiraten (30 Gold)` → Picker → freies Ziel | Gemahl/in `Gadir`; Legitimität 50 → 55 | D5 | PASS |
| P07 | 15:00:21 | Fremde Nachbarprovinz → `Anspruch schmieden` | `etruria` (Haus Latium): Ansprüche 0 → 1; Gold 220 → 180; `Angreifen` aktiv | K2 | PASS |
| P08 | 15:00:24 | Eigene Provinz → `Armee aufstellen` | Armeen 0 → 1; Gold 180 → 130 | K3 | PASS |
| P09 | 15:05:16 | Zielprovinz → `Belagerung vorantreiben` | `etruria` Belagerung 0 % → 28 % | K4 | PASS |
| P10 | 15:05:18 | Zielprovinz → `Frieden schließen` | Haus Latium: Waffenstillstand bis 49; Meinung 0 → 10 | K6 | PASS |
| P11 | 15:10:16 | Anderes Haus → `Geheimnis aufdecken` → `ausnutzen` | Haus Unetice: Haltung 60 → 45; Ansprüche 1 → 2 | D7, D8 | PASS |
| P12 | 15:05:20 | Friedensziel → `Angreifen` prüfen | `etruria`: `Angreifen` disabled=true; Waffenstillstand bis 49 (jetzt 25) | K7 | PASS |
| AI-01 | 15:15:17 | Save-Diff KI | `AI2: Haus 3 Steuersatz 1 → 2`; `AI2: Haus 5 Steuersatz 1 → 2`; `AI2: Haus 7 Steuersatz 1 → 2` | AI2 | PASS |
| AI-02 | 15:15:17 | Save-Diff KI | `AI3: Haus 5 hat geheiratet`; `AI3: Haus 7 hat geheiratet` | AI3 | PASS |
| T-01 | 15:38 | `FullDepthTest` headless (`res://tests/FullDepthTest.tscn`) | `FULLDEPTHTEST OK: …; 57 Prüfungen`, Exit 0, 0 Fehlerzeilen; K6-Zusicherung `truce_until(1) > _now()` (Zeile 290) | H3–H8, D1–D8, K1–K7, AI2–AI5 | PASS |
| **Abschluss** | **30:00** | **Gerät/Datum:** Windows, 2026-11-08 | 12/12 Aktionen, 3/3 Roundtrips ohne Diff, AI2+AI3 | — | PASS |

## Windows-Lauf 2026-11-07

- **Gerät:** Windows x86_64, Fenster `Kronen und Kriege`, EXE `F:\ck3-kronen-kriege.exe`.
- **Build:** SHA-256 `951c65bd4e04f97f8b607ae4bb153b2c2de3fe4a45c1620d32704754eb1a3121`, `113.716.840 Bytes`, Zeitstempel `2026-11-07 17:08:59` (CET).
- **Start:** `17:24:39` Uhr, **geplantes Ende:** `17:54:39` Uhr, **tatsächliches Ende:** `17:54:40` Uhr (30:01 Wanduhrzeit).
- **Startzustand:** `Haus Sequana`, Hartung 2000 v. Chr., Gold 130, Prestige 6, Legitimität 50, Erbe `Epona`, 0 Ansprüche, 0 Armeen, Erbfolge `Ältester`, Steuersatz `1/2`.
- **Ausgangs-Save:** `saves/ai-start.json` um `17:25:10` (00:31).
- **Roundtrip 1:** `17:29:09` (04:30), `saves/roundtrip1-before.json`, Save/Load ohne Diff.
- **Roundtrip 2:** `17:39:09` (14:30), `saves/roundtrip2-before.json`, Save/Load ohne Diff.
- **Roundtrip 3:** `17:49:09` (24:30), `saves/roundtrip3-before.json`, Save/Load ohne Diff.
- **Aktionen:** P01–P12 vollständig ausgeführt und **PASS**; 13 Matrixkanten, davon 3 dynastisch und 5 Krieg/Diplomatie.
- **KI-Beleg:** **AI2** (Haus 3, 4 und 7: Steuersatz 1 → 2) und **AI3** (Haus 5 und Haus 7 haben geheiratet); zwei verschiedene KI-Kanten.
- **Ende:** `ai-end.json` und die Screenshots um `17:54:40`; der Prozess endete nach `run_end 2026-11-07T17:54:40 status=BESTANDEN`.
- **Befehl:** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_acceptance.ps1 -Exe "F:\ck3-kronen-kriege.exe" -Project "" -Out "C:/Crusader Kings III/mobile-godot/build/verify/manual-build-951c"`. Der leere `-Project`-Parameter verhindert den Editor-`--path`; der Driver startet die EXE direkt.
- **Screenshots:** `screens/win-043-05.png`, `win-043-10.png`, `win-043-15.png`, `win-043-20.png`, `win-043-25.png`, `win-042-3000.png` und `win-042-3000-preview.png` (Endstand).
- **Logs:** `run.out.log` enthält `MAIN_READY version=1.2` und den vollständigen Driver-Lauf; `run.err.log` enthält nur die nicht kritische Windows-Common-Controls-Warnung. Keine `ERROR`-, `SCRIPT ERROR`-, Exception- oder Crash-Zeile.
- **Exit:** Der Prozess beendete sich nach dem regulären `run_end`; die aufrufende Tool-Shell wurde beim Start nach 30 Sekunden abgeschnitten, ohne die bereits laufende EXE zu beenden. Der Lauf selbst wurde bis zum regulären Ende beobachtet.
- **Verhältnis zu 1.3:** Dieser Lauf fand auf `1.2.0.0` statt (`MAIN_READY version=1.2`) und bleibt als Vorgängerbeleg stehen. Der maßgebliche Lauf für 1.3 ist der [Lauf 2026-11-08](#windows-lauf-2026-11-08) auf `1.3.0.0`, der denselben Ablauf mit den 1.3-Metadaten bestanden hat.
- **Ergebnis:** **BESTANDEN**.

## Evidenztabelle Windows-Lauf 2026-11-07

Jede Zeile wird während des Laufs ausgefüllt. `Beleg` nennt den Screenshot, die Logzeile oder die Save-Datei. `P/F` ist `PASS` oder `FAIL`; leere Zellen sind am Ende `FAIL`.

| ID | Zeit | Aktion | Erwartete Wirkung | Beobachtete Wirkung | Kante | P/F | Beleg | Notizen |
|---|---|---|---|---|---|---|---|---|
| P01 | 17:25:24 | `Herrschaft` → `Rat` → `Marschall` → `Wechseln` | Training/Levy steigt | Marschallwechsel; `Cunorix trainiert Lugdunum (+10 Truppen)` | H1 | PASS | `acceptance-result.json`, `acceptance.log` | Trainings-Log im Lauf |
| P02 | 17:25:39 | `Herrschaft` → `Gesetz` → `Erbfolge: Ältester` | Gesetz wird `Jüngster` | Erbfolge `Ältester` → `Jüngster`; Regelzustand im JSON | H2 | PASS | `acceptance-result.json` | vor/nach im Ergebnis |
| P03 | 17:29:40 | `Herrschaft` → `Gesetz` → `Steuersatz` | Steuersatz-Label ändert sich | Steuersatz `1/2` → `2/2` | H3 | PASS | `acceptance-result.json` | Gold 273 unverändert |
| P04 | 17:29:54 | `Lugdunum` → `Bauen` → `Markt` | Stufe 1, Gold −60 | `Lugdunum` Markt Stufe 0 → 1; Gold 273 → 213 | H4 | PASS | `acceptance-result.json` | Markt gebaut |
| P05 | 17:34:39 | `Lugdunum` → `Bauen` → `Kaserne` | Stufe 1, Truppen steigen | `Lugdunum` Kaserne Stufe 0 → 1; Gold 213 → 143 | H5 | PASS | `acceptance-result.json` | Kaserne gebaut |
| P06 | 17:34:42 | `Heiraten (30 Gold)` → Picker → freies Ziel | Gemahl/in, Legitimität +5 | Gemahl/in `Sigrun`; Legitimität 55 | D5 | PASS | `acceptance-result.json` | Startlegitimität 50 |
| P07 | 17:39:39 | Fremde Nachbarprovinz → `Anspruch schmieden` | Anspruch +1; `Angreifen` aktiv | `Etruria` (Haus Latium): Ansprüche 0 → 1; Gold 113 → 73; `Angreifen` aktiv | K2 | PASS | `acceptance-result.json` | Ziel `Etruria` |
| P08 | 17:39:42 | Eigene Provinz → `Armee aufstellen` | Armee +1, Gold −50 | Armeen 0 → 1; Gold 73 → 23 | K3 | PASS | `acceptance-result.json` | — |
| P09 | 17:44:40 | Zielprovinz → `Belagerung vorantreiben` | Belagerung > 0 % | `Etruria` Belagerung 0 % → 27 % | K4 | PASS | `acceptance-result.json` | — |
| P10 | 17:44:41 | Zielprovinz → `Frieden schließen` | Waffenstillstand in der Zukunft | Haus Latium: Waffenstillstand bis 37; Meinung 0 → 10 | K6 | PASS | `acceptance-result.json` | — |
| P11 | 17:49:40 | Anderes Haus → `Geheimnis aufdecken` → `ausnutzen` | Haltung −15, Anspruch +1 | Haus Unetice: Haltung 60 → 45; Ansprüche 1 → 2 | D7, D8 | PASS | `acceptance-result.json` | Zielhaus Unetice |
| P12 | 17:44:43 | Friedensziel → `Angreifen` prüfen | Schaltfläche deaktiviert | `Etruria`: `Angreifen` disabled=true; Waffenstillstand bis 37 (jetzt 13) | K7 | PASS | `acceptance-result.json` | Während Pause geprüft |
| AI-01 | 17:54:40 | Save-Diff KI | eine KI-Kante belegt | `AI2: Haus 3 Steuersatz 1 → 2`; `AI2: Haus 4 Steuersatz 1 → 2`; `AI2: Haus 7 Steuersatz 1 → 2` | AI2 | PASS | `saves/ai-start.json`, `saves/ai-end.json` | — |
| AI-02 | 17:54:40 | Save-Diff KI | zweite, andere KI-Kante belegt | `AI3: Haus 5 hat geheiratet`; `AI3: Haus 7 hat geheiratet` | AI3 | PASS | `saves/ai-start.json`, `saves/ai-end.json` | — |
| **Abschluss** | **30:00** | **Gerät/Datum:** Windows, 2026-11-07 | **Ergebnis:** BESTANDEN | 12/12 Aktionen, 13 Kanten, 3/3 Roundtrips, AI2+AI3 | — | — | `acceptance-result.json`, `screens/win-042-3000.png` | Lauf 17:24:39–17:54:40; regulärer `run_end` |

### Save-Diff-Felder je Roundtrip

Vor `Spiel speichern` und nach `Spielstand laden` müssen diese Werte exakt gleich sein:

- Datum (Tag/Monat/Jahr)
- Gold
- Prestige
- Legitimität
- Erbe und Erbfolgegesetz
- Anzahl der Ansprüche
- Anzahl der Armeen
- Eigene Provinzen (mindestens Name und Besitzer)
- Spieltempo

Der Log-Eintrag `Spielstand geladen.` ist erwartbar und kein Diff. Jede Abweichung bei den aufgeführten Feldern ist ein **Save-Diff** und beendet den Lauf mit `DURCHGEFALLEN`.

## Abbruchregeln

Ein Lauf wird sofort mit **DURCHGEFALLEN** beendet, wenn einer dieser Fälle eintritt:

1. **Crash oder unerwartetes Ende:** Die App stürzt ab, beendet sich ohne Aufforderung oder zeigt einen Godot-/Android-Fehlerdialog. Log und Screenshot sichern.
2. **Leerer Bildschirm:** Über mehr als fünf Sekunden ist außer Hintergrund, Ladebildschirm oder einer leeren Fläche keine bedienbare UI sichtbar. Ein Screenshot als Beleg.
3. **Fehlende UI-Reaktion:** Ein Pflichtknopf reagiert innerhalb von fünf Sekunden nicht, obwohl seine Voraussetzungen erfüllt sind. Kein Doppelklick als „Beleg“; einmal wiederholen, dann `FAIL`.
4. **Save-Diff:** Eines der Save-Diff-Felder unterscheidet sich nach `Spielstand laden` vom Stand vor `Spiel speichern`.
5. **Pflichtaktion unmöglich:** Eine der Aktionen P01–P12 ist nach Ausschöpfung der legalen Alternativen nicht ausführbar, oder die Mindestabdeckung ist um 30:00 nicht erreicht.
6. **KI-Beleg unzureichend:** Der Save-Vergleich liefert weniger als zwei verschiedene KI-Kanten.
7. **Zeitüberschreitung:** Um 30:00 sind nicht alle zwölf Pflichtaktionen, drei Roundtrips und der KI-Beleg abgeschlossen. Es wird nicht überzogen.
8. **Falscher Build:** Version, Commit, SHA-256, Paket oder Pflicht-UI stimmen nicht mit den Vorbedingungen überein.

Nach einem Abbruch werden die Evidenzdateien **nicht überschrieben**. Der Lauf wird als `DURCHGEFALLEN` dokumentiert; ein neuer Lauf ist ein neuer Datensatz.

## Abschlussregel

**BESTANDEN** gilt nur, wenn:

- alle zwölf Pflichtaktionen P01–P12 mit `PASS` belegt sind,
- mindestens 10 Kanten dokumentiert sind, darunter mindestens 3 dynastische und 3 Krieg-/Diplomatie-Kanten,
- mindestens zwei verschiedene KI-Kanten aus AI2–AI4 belegt sind,
- alle drei Save/Load-Roundtrips ohne Save-Diff bestanden sind,
- kein Abbruchgrund eingetreten ist,
- die Evidenztabelle Gerät, Datum, Uhrzeit und Ergebnis nennt.

Andernfalls lautet das Ergebnis **DURCHGEFALLEN**. Dieses Dokument selbst ist kein Nachweis, dass der Lauf durchgeführt wurde; ohne ausgefüllte Tabelle bleibt der Status offen.

## Bezeichnungsabgleich mit dem Spielcode

Die im Protokoll verwendeten Bezeichnungen wurden gegen die Quellen geprüft:

- Startmenü und Hausauswahl: `Neues Spiel`, `Spiel laden`, `Beenden`, `Wähle dein Haus`, `Eigenes Haus gründen`, `Herrschaft beginnen` aus `scripts/Main.gd`.
- Hofpanel: `Stammbaum`, `Ausbauen  (50 Gold)`, `Truppen werben  (30 Gold)`, `Angreifen  (25 Gold)`, `Familie & Intrigen`, `Heiraten  (30 Gold)`, `Beilager halten`, `Verführen  (20 Gold)`, `Ermorden  (60 Gold)`, `Entführen  (45 Gold)`, `Lösegeld fordern  (+80 Gold)`, `Gefangene/n heiraten`, `Hof halten  (40 Gold)`, `Herrschaft`, `Spiel speichern`, `Spielstand laden` aus `scripts/Main.gd`.
- Geschwindigkeit: `Pause`, `x1`, `x2`, `x3` aus `scripts/Main.gd`.
- Herrschaftsmodal: `Herrschaft — <Haus>`, `Schließen`, `Rat`, `Wechseln`, `Gesetz`, `Erbfolge: Ältester`/`Erbfolge: Jüngster`, `Steuersatz: 1/2`, `Krieg und Diplomatie`, `Anspruch schmieden (40 Gold)`, `Armee aufstellen (50 Gold)`, `Belagerung vorantreiben`, `Frieden schließen (24 Monate)`, `Geheimnis aufdecken`, `Geheimnis ausnutzen`, `Bauen`, `Markt: Stufe 0/3 · 60 Gold`, `Kaserne: Stufe 0/3 · 70 Gold`, `Mauern: Stufe 0/3 · 80 Gold` aus `scripts/Main.gd` und `scripts/ViewModelBuilder.gd`.
- Stammbaum: `Stammbaum — <Haus>`, `Schließen`, `Erbfolge`, `Erbfolgegesetz: Jüngster.` aus `scripts/Main.gd` und `scripts/ViewModelBuilder.gd`.
- Zustandsanzeigen: `Waffenstillstand bis`, `Haltung`, `Truppen`, `Belagerung`, `Ansprüche`, `Armeen`, `Gemahl/in` aus `scripts/ViewModelBuilder.gd`.
- Speichern/Laden: `user://spielstand.json`, Log `Spielstand gespeichert.`/`Spielstand geladen.` aus `scripts/Main.gd`.

## Quellen

- [Wellenplan](waves.md)
- [Depth Contract](depth-contract.md)
- [Interaktionsmatrix](interaction-matrix.md)
- [Save-Schema](save-schema.md)
- [README mit Installations- und Starthinweisen](../README.md)
