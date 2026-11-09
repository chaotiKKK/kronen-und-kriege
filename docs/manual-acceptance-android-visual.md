# Android-Sichtprüfung des 30-Minuten-Protokolls

> Stand: 2026-11-08 (historische Sichtprüfung 2026-11-07)
> Gerät: `24117RK2CG`, Android 16, Geräteserie `f030379a`
> App: `org.example.kronen`, `versionName 1.3`, `versionCode 4` (historische Sichtprüfung auf `versionName 1.2`, `versionCode 3`)
> Build der historischen Sichtprüfung: Commit `89846de4fcdf4c9fef3f11b1c9fbe6041c4a2634` (Tag `v1.2`), APK `8cd6d9b733fc1c62bf63801e4615e0329c62f00f16d2ee440dbe6c409dc8d7d8` (179.750.931 Bytes)
> Aktueller Release-1.3-Build: APK `3b17118a9ea7d4e307fec735b58cc4b46dcc459d4ca49a4edac30f71037dbbbf` (180.708.021 Bytes, `2026-11-08 14:02:14`); am 2026-11-08 auf `emulator-5554` (AVD `fhd36`, Android 16) mit Host-GPU sichtbar geprüft: Ladebildschirm bei 82 % und Hauptmenü, `MAIN_READY version=1.3`, kein FATAL. Der frühere SwiftShader-Lauf scheitert an `GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`; auf realer Hardware nicht installiert.
> Anzeige: 3200×1440 im Landscape; Bedienung per ADB-Touch
> **Ergebnis:** Die historische 1.2-Sichtprüfung vom 2026-11-07 bleibt **NICHT BESTANDEN** (Lauf abgebrochen; „extern blockiert“ widerlegt, Force-Stops aus der lokalen Prozesskette; keine externe ADB-Blockade belegt). Der 1.3-Emulator-Smoke-Test am 2026-11-08 ist auf `emulator-5554` mit Host-GPU **BESTANDEN** (Ladebildschirm + Hauptmenü, kein FATAL); die reale Hardware und der Android-30-Minuten-Lauf bleiben offen.

## Ergebnis in einem Satz

Die Touch-Zuordnung ist **kein App-Fehler**: Bei stabilem Scrollzustand öffnete ein Tap auf die sichtbare Beschriftung `Herrschaft` genau das Herrschaftsmodal; der frühere Fehlgriff entstand aus einem Screenshot während einer noch laufenden Scrollanimation. Die Android-Abnahme ist dennoch **nicht bestanden**, weil der Pflichtlauf nicht abgeschlossen wurde; die frühere Zuschreibung an einen externen Treiber ist zurückgezogen. Der separate 1.3-Emulator-Smoke-Test auf `emulator-5554` mit Host-GPU ist **bestanden** und ersetzt diesen Pflichtlauf nicht.

## Abgrenzung

Diese Prüfung ist ein visueller Smoke-Test der wichtigsten Ansichten und Interaktionen. Sie ersetzt weder den vollständigen 30-Minuten-Lauf noch die Pflichtaktionen P01–P12, die Kantenmatrix, die KI-Belege oder die drei Save/Load-Roundtrips aus dem [30-Minuten-Protokoll](manual-acceptance.md). Der 30-Minuten-Lauf wird hier ausdrücklich **nicht** als absolviert bezeichnet.

## Emulator-Smoke-Test 2026-11-08 — BESTANDEN (Host-GPU)

- **Gerät (erfolgreicher Lauf):** `emulator-5554`, AVD `fhd36`, `sdk_gphone64_x86_64`, Android 16, 1080×2340, Host-GPU (`-gpu host`, NVIDIA RTX 5070 Laptop, OpenGL ES 3.1).
- **Gegencheck:** `emulator-5556`, AVD `fc3d`, Android 14, Host-GPU; ebenfalls Ladebildschirm (100 %) und Hauptmenü.
- **SwiftShader-Vergleich:** Derselbe APK-Stand auf `emulator-5554` mit `-gpu swiftshader_indirect` startet bis `MAIN_READY version=1.3`, kann aber die GLES3-Shader nicht linken; Einzelheiten unten.
- **Build:** APK 1.3/4, SHA-256 `3b17118a9ea7d4e307fec735b58cc4b46dcc459d4ca49a4edac30f71037dbbbf`, 180.708.021 Bytes; Installation und Paketprüfung erfolgreich.
- **Start:** `MAIN_READY version=1.3`; der Prozess blieb am Leben, kein `FATAL`/`AndroidRuntime`-Crash und kein `SceneShaderGLES3`-/`CanvasShaderGLES3`-Linkfehler.
- **Befund (Host-GPU):** Der Ladebildschirm ist bei 82 % sichtbar, danach das Hauptmenü mit `Neues Spiel`, `Spiel laden` und `Beenden`; die App bleibt aktiv. Das ist ein **bestandener Emulator-Smoke-Test**, keine vollständige Android-Abnahme.
- **Befund (SwiftShader):** `SceneShaderGLES3` und `CanvasShaderGLES3` scheitern am Linken: `Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`. Die Screens bleiben leer. Das ist ein bekannter Godot-/SwiftShader-Emulatorfall (Godot-Issue #109550), kein Nachweis für reale Hardware.
- **Bewertung:** **Emulator-Smoke-Test BESTANDEN** auf Host-GPU; **keine vollständige Android-Abnahme**. Der 30-Minuten-Lauf und die reale Hardware bleiben offen.
- **Belege (Erfolg):** `build/verify/android-emulator/target-5554/loading-82pct.png`, `build/verify/android-emulator/target-5554/main-menu.png`, `build/verify/android-emulator/target-5554/launch.log`, `build/verify/android-emulator/target-5554/key-lines.log`; Gegencheck `build/verify/android-emulator/host/screens/30-launch.png` und `.../42-current.png`.
- **Belege (SwiftShader-Vergleich):** `build/verify/android-emulator/logs/clean-launch.log`, `build/verify/android-emulator/screens/current-20s.png`.

## Touch-Befund: entschieden

Der gemeldete Versatz von etwa 145 px nach dem Scrollen im Hofpanel ist **widerlegt**. Er war ein Messartefakt aus einem nicht eingefrorenen Scroll-Zwischenzustand, kein Fehler der Trefferzonen.

| Prüfung | Beleg | Beobachtung | Bewertung |
|---|---|---|---|
| Fehlversuch mit altem Zwischenzustand | `build/verify/manual/screens/android-31-scroll-try2.png` | Der Screenshot wurde nur etwa 1 s nach dem Wischen aufgenommen; das Panel bewegte sich noch. Der Tap `(2700,1025)` traf dadurch `Hof halten`, nicht `Herrschaft`. | Artefakt des Messwegs |
| Stabiler Scrollzustand | `build/verify/manual/screens/android-42-scroll-stable-b.png` | Nach dem Scrollen wurde 3 s gewartet; zwei Aufnahmen waren stabil. `Herrschaft` stand sichtbar bei ungefähr `(2750,1300)`. | reproduzierbar |
| Tap auf sichtbare Beschriftung | `build/verify/manual/screens/android-43-rule-at-stable-scroll.png` | Ein Tap auf `(2750,1300)` öffnete korrekt `Herrschaft — Haus Sequana`; es wurde nicht `Hof halten` ausgelöst. | **Touch-Zuordnung korrekt** |
| Scroll mit nicht-interaktiver Startfläche | `build/verify/manual/screens/r6-004-textdrag2.png` | Ein Wisch, der in der Textspalte des Hofpanels begann, scrollte das Panel bis `Herrschaft`; frühere Fehlversuche begannen auf Buttons oder dem Porträt. | **Scroll funktioniert** |

**Entscheidung:** Die 145-px-Abweichung ist **kein App-Fehler**. Die betroffenen Schritte wurden bei stabilem Scrollzustand wiederholt; der Tap auf die sichtbare Beschriftung löste die erwartete Aktion aus. Es gibt keinen Grund für eine Code-Korrektur an der Touch-Zuordnung. Die Lehre für den Messweg: Nach einem Scroll mindestens 3 s warten und erst dann die sichtbare Beschriftung antippen; nicht den Screenshot aus der laufenden Animation verwenden.

## Force-Stop-Quelle: Korrektur

Die frühere Behauptung eines externen ADB-Treibers ist nicht durch die Belege gedeckt. Die tatsächliche Kette ist im historischen Gerätelog `build/verify/manual-old-113147/logs/force-stop-source.log` dokumentiert:

- Im Gerätelog stehen wiederholt `am force-stop --user 0 org.example.kronen` und `am force-stop --user 10 org.example.kronen` (09:06:46 bis 09:06:54).
- Der Host-Prozessbaum zeigt als Elternprozess von PID 39260 den Codebuff-Orchestrator PID 7356 (`bun.exe`); die Force-Stops liefen aus dieser lokalen Prozesskette.
- Nach dem Beenden von PID 39260 und Kind 22348 um 09:07:57 traten in den folgenden 12 Sekunden **0** weitere Force-Stop-Zeilen auf.
- Die Abfrage des Besitzers von PID 39260 ist unvollständig, weil der Prozess beim zweiten Zugriff bereits beendet war; daraus lässt sich kein externer Verursacher ableiten.

**Konsequenz:** Die Bezeichnung „extern blockiert“ wird gestrichen. Der Android-Lauf ist aus den dokumentierten Gründen **nicht abgeschlossen** und wird als **DURCHGEFALLEN** gewertet. Die Störung ist nicht dem Spiel zuzurechnen; sie ist aber auch nicht als externe Blockade belegt.

## Protokollstatus Android

Die folgende Tabelle nennt für jedes Android-Protokollelement den Status und den konkreten Beleg. `nicht ausgeführt` bedeutet: Der Schritt wurde in diesem Lauf nicht abgeschlossen und wird nicht als bestanden gewertet.

| Element | Geforderte Aktion | Status | Beleg | Beobachtung |
|---|---|---|---|---|
| P01 | `Marschall` → `Wechseln` | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P02 | `Erbfolge` umstellen | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P03 | `Steuersatz` umstellen | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P04 | `Markt` bauen | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P05 | `Kaserne` bauen | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P06 | `Heiraten` | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P07 | `Anspruch schmieden` | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P08 | `Armee aufstellen` | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P09 | `Belagerung vorantreiben` | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P10 | `Frieden schließen` | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P11 | `Geheimnis aufdecken`/`ausnutzen` | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| P12 | `Angreifen` bei Truce prüfen | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger 30-Minuten-Lauf abgeschlossen. |
| Kanten H1–H5, D5, D7, D8, K2–K4, K6, K7 | mindestens 10 Kanten | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Keine gültigen Kantenbelege. |
| AI-01 | erste KI-Kante aus Save-Diff | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Keine gültigen Saves `ai-start.json`/`ai-end.json` aus diesem Lauf. |
| AI-02 | zweite, andere KI-Kante | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein End-Save. |
| Roundtrip 04:30 | Save/Load-Diff | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger Lauf, kein Save-Diff. |
| Roundtrip 14:30 | Save/Load-Diff | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger Lauf, kein Save-Diff. |
| Roundtrip 24:30 | Save/Load-Diff | **nicht ausgeführt** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein gültiger Lauf, kein Save-Diff. |
| 30-Minuten-Lauf | 30:00 Wanduhrzeit | **nicht abgeschlossen** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Keine stabile, vollständige Sitzung. |
| **Abschluss** | **Gerät/Datum:** `24117RK2CG`, 2026-11-07 | **DURCHGEFALLEN** | `build/verify/manual-old-113147/logs/force-stop-source.log` | Kein PASS; keine externe Blockade belegt. |

## Gerätezustand

Der Testnutzer 10 wurde entfernt; aktueller Nutzer ist 0. `org.example.kronen` und die beiden Sylviakart-Pakete wurden wieder aktiviert. Die Fremd-Pakete bleiben nicht dauerhaft deaktiviert. Die frühere externe Zuschreibung wird nicht aufrechterhalten.

## Nicht geprüft

- P01–P12 und die geforderten zwölf Entscheidungen; kein gültiger Android-30-Minuten-Lauf abgeschlossen.
- Mindestens 10 Kanten, davon 3 dynastische, 3 Krieg-/Diplomatie- und 2 KI-Kanten.
- Drei Save/Load-Roundtrips mit Save-Diff sowie `ai-start.json`/`ai-end.json`.
- Der vollständige 30-Minuten-Lauf.
- Der Windows-Lauf ist separat im [30-Minuten-Protokoll](manual-acceptance.md#windows-lauf-2026-11-08) dokumentiert und dort **BESTANDEN**.

## Evidenz

Primärbelege für diese Entscheidung:

- `build/verify/manual-old-113147/logs/force-stop-source.log` – Gerätelog mit den `am force-stop`-Aufrufen, Host-Prozessbaum und 12-Sekunden-Nachlauf ohne weitere Force-Stops.
- `build/verify/manual/screens/android-42-scroll-stable-b.png` – stabiler Scrollzustand mit sichtbarem `Herrschaft`.
- `build/verify/manual/screens/android-43-rule-at-stable-scroll.png` – nach dem Tap geöffnetes `Herrschaft — Haus Sequana`.
- `build/verify/manual/screens/r6-004-textdrag2.png` – reproduzierbarer Scroll aus der Textspalte bis `Herrschaft`.
- `build/verify/manual/screens/android-31-scroll-try2.png` – der alte, während der Scrollanimation aufgenommene Fehlbeleg.

Weitere Ansichtsbelege aus dem Preflight liegen lokal unter `build/verify/manual/screens/`, darunter `android-01-start.png`, `android-05-house-select.png`, `android-06-game-start.png`, `android-16-tree-open.png` und `android-33-rule-probe.png`. `build/` ist von den Exporten ausgeschlossen.

## Fazit

Die Touch-Frage ist entschieden und belegt: **kein App-Fehler, sondern ein Messartefakt**. Die Android-Abnahme ist **DURCHGEFALLEN**, weil der Pflichtlauf nicht abgeschlossen wurde. Der 1.3-Emulator-Smoke-Test auf `emulator-5554` mit Host-GPU ist **bestanden**; die reale Hardware bleibt ungeprüft. Die frühere Behauptung eines externen ADB-Treibers ist zurückgezogen; die dokumentierte Force-Stop-Kette ist lokal. Es bleibt kein ungeklärter App-Befund.

[Zurück zum 30-Minuten-Protokoll](manual-acceptance.md)
