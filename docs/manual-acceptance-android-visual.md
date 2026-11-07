# Android-Sichtprüfung des 30-Minuten-Protokolls

> Stand: 2026-11-07
> Gerät: `24117RK2CG`, Android 16, Geräteserie `f030379a`
> App: `org.example.kronen`, `versionName 1.2`, `versionCode 3`
> Build: Commit `89846de4fcdf4c9fef3f11b1c9fbe6041c4a2634` (Tag `v1.2`)
> Anzeige: 3200×1440 im Landscape; Bedienung per ADB-Touch
> **Ergebnis: NICHT BESTANDEN – extern blockiert.** Der frühere 145-px-Trefferzonen-Befund ist als Messartefakt widerlegt. Der Android-Pflichtlauf konnte nicht durchgeführt werden, weil ein externer ADB-Treiber die App wiederholt beendet hat.

## Ergebnis in einem Satz

Die Touch-Zuordnung ist **kein App-Fehler**: Bei stabilem Scrollzustand öffnete ein Tap auf die sichtbare Beschriftung `Herrschaft` genau das Herrschaftsmodal; der frühere Fehlgriff entstand aus einem Screenshot während einer noch laufenden Scrollanimation. Die Android-Abnahme ist dennoch **nicht bestanden**, weil P01–P12, die Kanten-/KI-Belege und die drei Save/Load-Roundtrips vor jedem Beginn extern per `am force-stop` beendet wurden; diese Punkte sind unten als **extern blockiert**, nicht als bestanden, ausgewiesen.

## Abgrenzung

Diese Prüfung ist ein visueller Smoke-Test der wichtigsten Ansichten und Interaktionen. Sie ersetzt weder den vollständigen 30-Minuten-Lauf noch die Pflichtaktionen P01–P12, die Kantenmatrix, die KI-Belege oder die drei Save/Load-Roundtrips aus dem [30-Minuten-Protokoll](manual-acceptance.md). Der 30-Minuten-Lauf wird hier ausdrücklich **nicht** als absolviert bezeichnet.

## Touch-Befund: entschieden

Der gemeldete Versatz von etwa 145 px nach dem Scrollen im Hofpanel ist **widerlegt**. Er war ein Messartefakt aus einem nicht eingefrorenen Scroll-Zwischenzustand, kein Fehler der Trefferzonen.

| Prüfung | Beleg | Beobachtung | Bewertung |
|---|---|---|---|
| Fehlversuch mit altem Zwischenzustand | `build/verify/manual/screens/android-31-scroll-try2.png` | Der Screenshot wurde nur etwa 1 s nach dem Wischen aufgenommen; das Panel bewegte sich noch. Der Tap `(2700,1025)` traf dadurch `Hof halten`, nicht `Herrschaft`. | Artefakt des Messwegs |
| Stabiler Scrollzustand | `build/verify/manual/screens/android-42-scroll-stable-b.png` | Nach dem Scrollen wurde 3 s gewartet; zwei Aufnahmen waren stabil. `Herrschaft` stand sichtbar bei ungefähr `(2750,1300)`. | reproduzierbar |
| Tap auf sichtbare Beschriftung | `build/verify/manual/screens/android-43-rule-at-stable-scroll.png` | Ein Tap auf `(2750,1300)` öffnete korrekt `Herrschaft — Haus Sequana`; es wurde nicht `Hof halten` ausgelöst. | **Touch-Zuordnung korrekt** |
| Scroll mit nicht-interaktiver Startfläche | `build/verify/manual/screens/r6-004-textdrag2.png` | Ein Wisch, der in der Textspalte des Hofpanels begann, scrollte das Panel bis `Herrschaft`; frühere Fehlversuche begannen auf Buttons oder dem Porträt. | **Scroll funktioniert** |

**Entscheidung:** Die 145-px-Abweichung ist **kein App-Fehler**. Die betroffenen Schritte wurden bei stabilem Scrollzustand wiederholt; der Tap auf die sichtbare Beschriftung löste die erwartete Aktion aus. Es gibt keinen Grund für eine Code-Korrektur an der Touch-Zuordnung. Die Lehre für den Messweg: Nach einem Scroll mindestens 3 s warten und erst dann die sichtbare Beschriftung antippen; nicht den Screenshot aus der laufenden Animation verwenden.

## Protokollstatus Android

Die folgende Tabelle nennt für jedes Android-Protokollelement den Status und den konkreten Beleg. `extern blockiert` bedeutet: Die Aktion wurde nicht als bestanden gewertet, weil die App vor bzw. während des Laufs von einem fremden ADB-Treiber beendet wurde. Es handelt sich nicht um ein Anwendungsergebnis.

| Element | Geforderte Aktion | Status | Beleg | Beobachtung |
|---|---|---|---|---|
| P01 | `Marschall` → `Wechseln` | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt; App vor dem ersten Fenster extern beendet. |
| P02 | `Erbfolge` umstellen | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P03 | `Steuersatz` umstellen | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P04 | `Markt` bauen | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P05 | `Kaserne` bauen | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P06 | `Heiraten` | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P07 | `Anspruch schmieden` | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P08 | `Armee aufstellen` | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P09 | `Belagerung vorantreiben` | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P10 | `Frieden schließen` | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P11 | `Geheimnis aufdecken`/`ausnutzen` | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| P12 | `Angreifen` bei Truce prüfen | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Spielschritt ausgeführt. |
| Kanten H1–H5, D5, D7, D8, K2–K4, K6, K7 | mindestens 10 Kanten | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Keine Kantenbelege, da kein Spielschritt abgeschlossen wurde. |
| AI-01 | erste KI-Kante aus Save-Diff | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Keine Saves `ai-start.json`/`ai-end.json` vorhanden. |
| AI-02 | zweite, andere KI-Kante | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Keine Saves vorhanden. |
| Roundtrip 04:30 | Save/Load-Diff | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Lauf, kein Save-Diff. |
| Roundtrip 14:30 | Save/Load-Diff | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Lauf, kein Save-Diff. |
| Roundtrip 24:30 | Save/Load-Diff | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Kein Lauf, kein Save-Diff. |
| 30-Minuten-Lauf | 30:00 Wanduhrzeit | **extern blockiert** | `build/verify/manual/logs/external-driver.log` | Keine stabile, störungsfreie Sitzung erreichbar. |
| **Abschluss** | **Gerät/Datum:** `24117RK2CG`, 2026-11-07 | **DURCHGEFALLEN (extern blockiert)** | `build/verify/manual/logs/external-driver.log` | Kein PASS; die Blockade ist nicht dem Spiel zuzurechnen. |

## Paralleler Fremdtreiber und Isolationsversuch

Der Fremdtreiber auf `com.sylviakart.b3` und das separate `com.sylviakart.b3.touchprobe` wurden zunächst deaktiviert. Zehn Fokusprüfungen zeigten anschließend Kronen im Vordergrund; der Host-Touchprobe-Prozess wurde beendet. Diese erste Isolation war zeitweise erfolgreich.

Danach trat die Störung erneut auf:

- Eine im Host gefundene `bash`-Schleife deaktivierte `org.example.kronen` und rief 900-mal `am force-stop org.example.kronen` auf. Die Prozesskette wurde beendet.
- Die Störung kehrte danach von außerhalb dieser Sitzung zurück. Im entscheidenden Log stehen ab `09:01:13` wiederholt **`am force-stop --user 10 org.example.kronen`** und **`am force-stop --user 0 org.example.kronen`**; die App war zu diesem Zeitpunkt im eigens angelegten Nutzer 10 installiert.
- Auch Nutzer 10 schützte daher nicht: Das Paket wurde dort auf `enabled=3` gesetzt und der Vordergrund fiel auf den Launcher zurück. Der Testnutzer wurde nach der Beweissicherung wieder entfernt.

**Isolationsergebnis:** **nicht gelungen.** Die Fremd-App ließ sich temporär deaktivieren, aber der übergeordnete ADB-Treiber beendete die Kronen-App weiterhin. Eine stabile, störungsfreie 30-Minuten-Sitzung war nicht erreichbar. Das ist die extern begründete Einschränkung des Laufs; sie wird nicht als bestanden gewertet.

Der Gerätezustand wurde anschließend wiederhergestellt: Nutzer 10 entfernt, aktueller Nutzer 0, `org.example.kronen` und die beiden Sylviakart-Pakete wieder aktiviert. Die Fremd-Pakete bleiben nicht dauerhaft deaktiviert.

## Nicht geprüft

- P01–P12 und die geforderten zwölf Entscheidungen; kein Spielschritt wurde abgeschlossen.
- Mindestens 10 Kanten, davon 3 dynastische, 3 Krieg-/Diplomatie- und 2 KI-Kanten.
- Drei Save/Load-Roundtrips mit Save-Diff sowie `ai-start.json`/`ai-end.json`.
- Der vollständige 30-Minuten-Lauf.
- Ein Windows-Lauf; dieser gehört ausdrücklich nicht zu diesem Auftrag.
- Eine Produktbewertung der nicht ausgeführten Pflichtaktionen. Die Status `extern blockiert` sind keine Aussage, dass die Aktionen im Spiel fehlerhaft seien.

## Evidenz

Primärbelege für diese Entscheidung:

- `build/verify/manual/logs/external-driver.log` – 185 Zeilen mit den externen `force-stop`-Aufrufen für Nutzer 0 und Nutzer 10, inklusive `09:01:13` und `09:02:24`.
- `build/verify/manual/screens/android-42-scroll-stable-b.png` – stabiler Scrollzustand mit sichtbarem `Herrschaft`.
- `build/verify/manual/screens/android-43-rule-at-stable-scroll.png` – nach dem Tap geöffnetes `Herrschaft — Haus Sequana`.
- `build/verify/manual/screens/r6-004-textdrag2.png` – reproduzierbarer Scroll aus der Textspalte bis `Herrschaft`.
- `build/verify/manual/screens/android-31-scroll-try2.png` – der alte, während der Scrollanimation aufgenommene Fehlbeleg.

Weitere Ansichtsbelege aus dem Preflight liegen lokal unter `build/verify/manual/screens/`, darunter `android-01-start.png`, `android-05-house-select.png`, `android-06-game-start.png`, `android-16-tree-open.png` und `android-33-rule-probe.png`. `build/` ist von den Exporten ausgeschlossen. Die drei für die Touch-Widerlegung und den externen Blocker zitierten Belege wurden ausnahmsweise mit `git add -f` in den Dokumentations-Commit aufgenommen; die übrigen Rohbelege bleiben lokal.

## Fazit

Die Touch-Frage ist entschieden und belegt: **kein App-Fehler, sondern ein Messartefakt**. Die Android-Abnahme ist dennoch **DURCHGEFALLEN**, weil die App vor dem ersten Protokollschritt und danach wiederholt von einem externen ADB-Treiber beendet wurde. Die nicht ausgeführten Punkte sind als **extern blockiert** dokumentiert; es bleibt kein ungeklärter App-Befund und kein unbegründetes „offen“.

[Zurück zum 30-Minuten-Protokoll](manual-acceptance.md)
