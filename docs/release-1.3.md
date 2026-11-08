# Release 1.3 — Kronen und Kriege

> Status: **Entwurf, nicht veröffentlicht.** Tag, Push, Upload und Freigabe stehen aus.
> Stand: 2026-11-08
> Quellstand der Builds: Arbeitsbaum auf `8af9c8f` mit uncommittetem Versionssprung auf 1.3. Doku-HEAD: `bbb0f27` auf `main` (ein Commit nicht gepusht); dieser Entwurf ist noch uncommittet.
> Artefakte: `F:\ck3-kronen-kriege.exe` und `F:\ck3-kronen-kriege.apk`
> Vorherige Veröffentlichung: `v1.2` (Commit `89846de4fcdf4c9fef3f11b1c9fbe6041c4a2634`), bleibt unverändert.

## Release-Notes (Entwurf für GitHub)

### Kronen und Kriege 1.3 — Testversion

Bronzezeit-Grand-Strategy für Windows und Android. Diese Testversion bringt das neue Titelbild, einen korrigierten Waffenstillstand und einen reproduzierbaren 30-Minuten-Abnahmelauf. Die Windows-Abnahme ist bestanden; die Android-APK ist gebaut und signiert und auf dem Emulator `emulator-5554` mit Host-GPU sichtbar getestet, aber noch nicht auf realer Hardware geprüft.

**Neu in 1.3**

- **Titel- und Ladebild:** Das Banger-Queens-Cover ersetzt den bisherigen Startbildschirm. Das zweite Logo entfiel, weil die Wortmarke im Bild liegt; die Menüleiste sitzt im dunklen Bereich darunter.
- **Waffenstillstand:** Der Eintrag speichert jetzt das absolute Endjahr statt der Restdauer. Bisher lasen `truce_until()` und die KI das Feld als Kalenderjahr, sodass ein frisch geschlossener Frieden sofort als abgelaufen galt und K7 Angriffe nie sperrte.
- **Automatisierter Abnahmelauf:** `scripts/AcceptanceDriver.gd` und `tools/run_acceptance.ps1` fahren die zwölf Pflichtaktionen, drei Save/Load-Roundtrips und den KI-Beleg ohne Handarbeit; der Lauf schreibt `acceptance-result.json`, Screenshots und Save-Snapshots.
- **Versionsmetadaten:** `1.3.0.0` (Windows), `versionName 1.3` / `versionCode 4` (Android), Versionszeile `v1.3` in Start- und Ladebild.

**Downloads**

- **Windows:** `ck3-kronen-kriege.exe` — x86_64, PCK eingebettet, ohne Installation startbar.
- **Android:** `ck3-kronen-kriege.apk` — Debug-signiert (APK Signature Scheme v2), Installation über `adb install -r` oder direkt auf dem Gerät.
- **Prüfsummen:** `SHA256SUMS.txt`.

**SHA-256**

```
d2cc6508d07c65cb64e786a029736e4c04ad17f800736c6ac2f3c38f0826ec72  ck3-kronen-kriege.exe
3b17118a9ea7d4e307fec735b58cc4b46dcc459d4ca49a4edac30f71037dbbbf  ck3-kronen-kriege.apk
```

`tools/publish_github_release.sh` erzeugt beim Veröffentlichen **eigene, minimale Notizen** (Titel, Quellstand, Downloads, Prüfsummen, Debug-Hinweis) und setzt darin den Quellstand auf den dann aktuellen Commit-Kurzhash. Die Abschnitte „Neu in 1.3“, „Bekannte Einschränkungen“ und die Nachweise oben sind darin **nicht** enthalten und müssen nach dem Publish per `gh release edit v1.3 --notes-file <datei>` nachgezogen oder durch eine Erweiterung des Skripts ergänzt werden. Die Hashes müssen vor dem Upload mit `F:` übereinstimmen.

## Builds

| | Windows | Android |
|---|---|---|
| Datei | `F:\ck3-kronen-kriege.exe` | `F:\ck3-kronen-kriege.apk` |
| Größe | 113.718.904 Bytes | 180.708.021 Bytes |
| SHA-256 | `d2cc6508d07c65cb64e786a029736e4c04ad17f800736c6ac2f3c38f0826ec72` | `3b17118a9ea7d4e307fec735b58cc4b46dcc459d4ca49a4edac30f71037dbbbf` |
| Zeitstempel | `2026-11-08 14:00:57` (CET) | `2026-11-08 14:02:14` (CET) |
| Version | `1.3.0.0` | `versionName 1.3`, `versionCode 4` |
| Signatur | — | APK Signature Scheme v2, ein Signer, Debug-Zertifikat `da3c6296…`; `zipalign -c 4` ok |
| Plattform | x86_64, Fenster oder `F11` | minSdk 24, targetSdk 35, `arm64-v8a`/`armeabi-v7a` |

## Nachweise

- **Windows-Startcheck:** `WINDOWSTART OK`, Fenster `1298x765`, Titel „Kronen und Kriege“, Sichtbarkeit und nichtleerer Render-Frame geprüft, `MAIN_READY version=1.3`, Exit 0, keine Fehlerzeilen. Beleg: `build/verify/exe-1.3.log`.
- **Android-Paketprüfung:** `ANDROID_APK OK`, Paket `org.example.kronen`, Version 1.3/4, minSdk 24, targetSdk 35, beide ABIs, V2-Signatur, `zipalign` ok. Beleg: `build/verify/apk-1.3.log`.
- **30-Minuten-Abnahme Windows, 2026-11-08:** `14:45:16–15:15:17` (30:01), `status=BESTANDEN`; 12/12 Aktionen, 3/3 Roundtrips ohne Save-Diff, KI-Kanten AI2+AI3, 0 Fehlerzeilen. Beleg: `build/verify/manual-build-d2cc-v2/`, Protokoll: [manual-acceptance.md](manual-acceptance.md#windows-lauf-2026-11-08).
- **Automatisierte Tiefentests:** `FullDepthTest` 57 Prüfungen (`build/verify/final-fulldepth-check-1.3.log`, 2026-11-08 15:38), `SystemicDepthTest` 38 Prüfungen (`build/verify/systemicdepth-check-1.3.log`, 2026-11-08 15:52), beide grün.

## Abgleich mit dem Trockenlauf (2026-11-08)

`bash tools/publish_github_release.sh --dry-run` lief zweimal; Ausgaben unter `build/verify/release-dryrun.log` und `build/verify/release-dryrun-dirty.log`.

| Prüfung | Ergebnis |
|---|---|
| Im aktuellen Baum (vier Doku-Dateien geändert) | **Exit 1**: „Arbeitsbaum ist nicht sauber“ — der Entwurf muss vorher committet werden |
| Auf sauberem Snapshot bei `38a4b28` | **Exit 0**, kein Push, kein Upload |
| Repository | `chaotiKKK/kronen-und-kriege` |
| Version / Tag | `1.3` / `v1.3` auf `38a4b28`; Tag existiert noch nicht |
| APK-Prüfung | `ANDROID_APK OK`, V2, ein Signer, `zipalign ok`, versionCode 4/versionName 1.3 |
| Hashes | EXE `d2cc6508…`, APK `3b17118a…` — identisch mit diesem Entwurf und mit `F:` |

**Einzige Abweichung:** Die Skript-Notizen sind kürzer als dieser Entwurf (kein „Neu in 1.3“, keine Einschränkungen, keine Nachweise) und listen die APK vor der EXE. Hashes, Größen und Downloads stimmen überein, sodass nur der kuratierte Text nach dem Publish nachgezogen werden muss.

## Bekannte Einschränkungen

- **Android nicht auf realer Hardware geprüft:** `adb devices` meldet kein reales Gerät. Die APK 1.3 ist auf `emulator-5554` (AVD `fhd36`, Android 16) mit Host-GPU (`-gpu host`, NVIDIA) installiert und rendert dort sichtbar: Ladebildschirm bei 82 % und Hauptmenü, `MAIN_READY version=1.3`, kein FATAL. Ein früherer SwiftShader-Lauf scheiterte an `GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`; das ist ein Emulator-/SwiftShader-Fall, kein realer Hardware-Nachweis. Die reale Sichtprüfung und der Android-30-Minuten-Lauf bleiben offen; der Emulator-Smoke-Test ist bestanden.
- **Debug-Signatur:** Die APK ist mit dem Android-Debug-Zertifikat signiert und nicht für Store-Verteilung gedacht.
- **Spielstände aus 1.2:** Das Feld `truces` enthielt bis 1.2 die Restdauer (z. B. `24`). 1.3 liest es als Kalenderjahr und vergleicht mit dem laufenden Monatsindex; ein aus 1.2 übernommener Waffenstillstand gilt deshalb nach dem Update als abgelaufen. Neu geschlossene Waffenstillstände sind korrekt. Save-Schema bleibt 4.
- **Windows-Build** ist nur x86_64 und wird nicht installiert, sondern direkt gestartet.

## Veröffentlichungs-Checkliste

### 0. Voraussetzungen

- [x] Die Release-Vorbereitung liegt auf `main`; aktueller HEAD ist `bbb0f27`, ein Commit nicht gepusht.
- [x] Arbeitsbaum sauber bis auf diesen Entwurf; `build/` und `.tools/` sind ignoriert.
- [x] Windows-Abnahme, Startcheck, APK-Prüfung und Tiefentests bestanden.
- [ ] **Freigabe des Eigentümers zur Veröffentlichung** — ohne diese Freigabe wird nichts gepusht, getaggt oder hochgeladen.

### 1. Vor dem Push

- [ ] Diesen Entwurf committen, damit der Arbeitsbaum sauber ist — `publish_github_release.sh` bricht bei Änderungen ab.
- [ ] `git status --porcelain` liefert keine Ausgabe.
- [ ] `git log --oneline -8` zeigt ausschließlich die erwarteten Release-Commits.
- [ ] Hashes gegen die Dateien unter `F:` prüfen:
      `sha256sum "F:/ck3-kronen-kriege.exe" "F:/ck3-kronen-kriege.apk"` → `d2cc6508…` / `3b17118a…`
- [ ] `gh auth status` ist angemeldet; Zielrepo ist `chaotiKKK/kronen-und-kriege`.
- [ ] Trockenlauf: `bash tools/publish_github_release.sh --dry-run` — prüft APK-Signatur, zeigt Tag, Notizen und Prüfsummen, ändert nichts.
- [ ] Notizen oben gegen den Trockenlauf abgleichen (Wortlaut, Hashes, keine Android-Behauptung).

### 2. Veröffentlichen (nur nach Freigabe, ein Schritt)

- [ ] `bash tools/publish_github_release.sh`
      Wirkung: `git push origin HEAD:main`, annotierter Tag `v1.3` auf HEAD, `gh release create … --prerelease`, Upload von APK, EXE und `SHA256SUMS.txt`.
- [ ] Skript-Ausgabe prüfen: `Release veröffentlicht` mit URL und beiden Assets.
- [ ] Nur bei Skriptfehler manuell nachziehen (gleiche Reihenfolge: Push, Tag, Release, Assets) — nicht mit abweichenden Hashes.

### 3. Nachkontrolle

- [ ] `gh release view v1.3 --json url,tagName,isPrerelease,assets` zeigt `v1.3`, `isPrerelease: true` und beide Assets mit erwarteter Größe.
- [ ] Assets herunterladen und `sha256sum -c SHA256SUMS.txt` besteht.
- [ ] Release-Seite im Browser öffnen: Titel, Vorab-Kennzeichnung und Notizen sichtbar.
- [ ] `README.md` und `docs/ui-kernel.md` von „nicht veröffentlicht“ auf „veröffentlicht“ umstellen (Folge-Commit, danach erneut sauberer Baum).
- [ ] Release-Notizen prüfen: das Skript veröffentlicht nur die Minimalnotizen; „Neu in 1.3“ und „Bekannte Einschränkungen“ per `gh release edit v1.3 --notes-file <datei>` ergänzen.

### 4. Rücknahme

- [ ] Release auf Entwurf setzen: `gh release edit v1.3 --draft` — Assets und Tag bleiben erhalten.
- [ ] Endgültig entfernen: `gh release delete v1.3 --yes`; Tag nur nach ausdrücklicher Entscheidung zusätzlich `git push --delete origin v1.3` und `git tag -d v1.3`.
- [ ] Ein gelöschtes Release entfernt keine Commits; `main` bleibt gepusht.

### 5. Offen nach der Veröffentlichung

- [ ] Android-Gerät verbinden, APK installieren, Kaltstart und Sichtprüfung.
- [ ] Android-30-Minuten-Lauf nach dem Protokoll; Ergebnis in `docs/manual-acceptance.md` und im Android-Bericht nachtragen.

## Nicht Teil dieses Entwurfs

Kein Tag, kein Push, kein Upload, keine Änderung am bestehenden Release `v1.2`. Dieses Dokument beschreibt den Ablauf nur; ausgeführt wird er ausschließlich nach ausdrücklicher Freigabe.
