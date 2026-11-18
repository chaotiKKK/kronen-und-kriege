# Zivile Vorräte · Implementation Plan

**Goal:** Endliche zivile Nahrung/Rationen machen Arbeit, Steuern und Krieg zu zusammenhängenden Siedlungsentscheidungen.

**Architecture:** CivicProvision plant rein; Game bucht genau einmal. CivicProvisionReport validiert den autoritativen Ledger einschließlich gemeinsamem Arbeitsbudget. Save19/LAN und ein kleines eigenes Provinzpanel erhalten dieselben Grenzen.

**Tech Stack:** Godot4.5.1/GDScript, vorhandene Festkommaquanten, ENet, native Windows-/Android-Exporte.

**Spec:** `docs/superpowers/specs/2026-11-18-civil-provisions-design.md`.

Ausführung im vorhandenen Checkout mit nativen Teilagenten und exklusiven Dateigrenzen. Nutzerfreigabe für autonome Entwurfsentscheidungen liegt vor. Root integriert/reviewt; kein erneuter Ausführungsdialog. Planung und Tests sind keine fertige Spielstrecke.

## Gemeinsame Grenzen

- Version1.9.1/Code23/Schema19; alte Pakete und fremde303Änderungen erhalten.
- N=kanonischesweight_u; Food ist kein heutiger Bevölkerungswert und keine umbenannte Soldatenkapazität.
- Anfang3N, Kapazität6N/12N, Rationen75/100/125%, tatsächliche Farmarbeit aus bestehendem2w-Budget; kein neuer voller Arbeitstopf.
- Kein Nahrungsverkehr in dieser lokalen Fassung; keine doppelte Straßenkapazität und keine monatlich zusätzlich gebuchten militärischen Hungerverluste.
- Mengen/Zufriedenheit nur im gemeinsamen Monat, Politik ohne Sofortressourcen; keine automatische Menschenpolitik, keine NPC-Geschenke.
- Neue rohe Felder streng vor Kanonisierung prüfen; Originale/Backups und Legacy-Forschung erhalten.
- Telefon/StandardADB frei; Renderer exklusiv und nur DISPLAY3(1960,40). Headlessprofile getrennt/kurz. Keine ungemessenen FPS-Aussagen.

## 1 · Reine Nahrung und geteilte Arbeit

**Owner:** performance_tooling. **Dateien:** CivicProvision.gd, RegionalProduction.gd(optional available_labor_u), CivicProvisionTest.gd/.tscn, RegionalProductionTest.gd bei Bedarf.

- [ ] Fachlichen Modul-Rotfall sauber ausführen; fehlendes Modul/Methode als kontrollierte Assertion, keine Parserfehler als Rot zählen.
- [ ] Testinitialisierung und neutrale vollständige Bilanz:

```gdscript
var p={"id":"a","owner":0,"economic_share":1.0,"economic_focus":"balanced"}
p.provisioning=Food.initial_state(p)
var r=Food.plan(p,1,1)
check(r.ok and r.ledger.before_u==3000000 and r.ledger.consumed_u==1000000,"Normale tatsächliche Ration")
check(r.ledger.before_u+r.ledger.produced_u-r.ledger.consumed_u-r.ledger.wasted_u==r.ledger.after_u,"Erhaltung")
check(r.ledger.farm_work_u+r.ledger.industry_labor_u<=r.ledger.total_labor_u,"Gemeinsame Arbeit")
```

- [ ] Alle Foki, kleinste/größte Gewichte, drei Rationen, Carry über viele Monate, Blockade/Vorratsende/Erholung, Steuern und Rohfehler rot→grün abdecken.
- [ ] RegionalProduction.plan_local(province,tasks,month,blocked=false,available_labor_u=-1) begrenzt echte Arbeit und Produktion auf denselben übergebenen Rest. Der alte Standardpfad bleibt für das reine Basismodul definiert.
- [ ] Extremwerte und keine Mutation/RNG/Datei-/Gameabhängigkeit; Quellenstopp/Hashes mit echter Rot-/Grünherkunft.

## 2 · Bericht und Save19/Original18

**Owner:** map_render_audit. **Dateien:** CivicProvisionReport.gd, SaveGame.gd, CivicProvisionSaveTest.gd/.tscn, CivicProvisionReportTest.gd/.tscn, echte18Fixture+Provenienz.

- [ ] Vor Änderungen eine neue synthetische echte18-LAN-Datei aus unveränderter veröffentlichter Trade22-EXE erzeugen. Vorhandenen alten17Capturetreiber als Muster verwenden, keine Schema-/Fingerprint-Umschreibung. Eigene lokaleENetports, leeres Arbeitsverzeichnis/kurzes Profil, nur headless; alle Artefakte/Logs/Hashes festhalten.
- [ ] Reports leer/vollständig, Mengen/Owner/Endbestand/Monat/Arbeitsgrenzen und gleichmonatiges Produktionsbudget mit kontrollierten Fehlern rot→grün.
- [ ] Migration ergänzt nur neue provisioning-Felder und leeren Bericht. Beispielerhaltung:

```gdscript
var legacy=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
var upgraded=Save.normalize(legacy)
check(upgraded.schema_version==19,"Neue Schemafassung")
# Vergleich projiziert ausschließlich die neuen Felder weg; alle Originalwerte bleiben gleich.
```

- [ ] Raw19 mit fehlenden oder booleschen/brüchigen/fremden Feldern ablehnen; neue finite Ganzzahlen erst danach normalisieren. Bestehende Backups/Originaldateien niemals editieren.
- [ ] Echter18-Altstand und Legacy6Monate; Quelle stoppen, Root über tatsächliche neue Fixtureidentität informieren.

## 3 · Game, Vorschau und wirtschaftliche Konsequenzen

**Owner:** Root. **Dateien:** Game.gd, Infrastructure.gd, EconomyPlanner.gd nur nach Abgleich, Data.gd(Erntetext), CivicProvisionGameTest.gd/.tscn, CivicProvisionCampaignTest.gd/.tscn.

- [ ] Rotfälle für einmalige Monatsbuchung, zustandsreine Vorschau, verweigerte fremde Politik, unveränderte Wiederholung und Snapshot/Restore.
- [ ] Exakte Game-APIs aus Spec, Initialisierung/Restore und gemeinsamer Tick vor Materialhandel/Regionalwirtschaft integrieren.
- [ ] Aktueller gebuchter Industriebudgetwert für echte Produktion; reine nächste Foodplanung für Vorschauen/Eigenreserve/Handelsbedarf. Kontrollierter Vergleich:

```gdscript
var before=game.snapshot()
var preview=game.provision_preview(id,"generous")
check(Save.diff(before,game.snapshot()).is_empty(),"Vorschau ist rein")
var changed=game.set_province_rations(id,"generous")
# Erst der tatsächliche folgende Monat bucht exakt die unveränderte Vorschau unter denselben Bedingungen.
```

- [ ] Einkommens-/Auffüllungsfolgen, gewichtete Hausrundung, tatsächliche Forschungsboni und alte Fristen. Neuer Schwerpunktvergleich nennt positiven tatsächlichen Materialpotenzialwert.
- [ ] Freie nichtmenschliche Rations-/Erholungspolitik nutzt dieselben APIs und keine heimlichen Bestände. Bestehende eine bezahlte Absicht bleibt erhalten.
- [ ] Ernteabgaben-/Ausrüstungstexte beschreiben vorhandene Gold-/Aufgebotseffekte ehrlich; alte pending-Entscheidungen nicht verändern.
- [ ] Zwei feste Seeds/zwei Häuser sowie ein kleines selbst gestaltetes Haus ohne Debugmittel; gepaarter Rationstausch, echte Blockade und Erholung. Tatsächlich veränderte Bau-/Handelsfristen messen und mit alter Kontrollwelt vergleichen.

## 4 · Autoritative Befehle und Kompatibilität

**Owner:** Root nach Game. **Dateien:** UiKernel.gd, LanProtocol.gd, LanSession.gd, CivicProvisionCommandTest.gd/.tscn, CivicProvisionLanTest.gd/.tscn.

- [ ] province_rations{rations} über autorisierte Auswahl und Haushaltsrolle. Zusätzliche Mengen/Häuser/Provinzspoofs, Wiederholung und falsche Typen ändern weder Welt noch Log.
- [ ] Civic/Report/Gamepolitik im Fingerprint und Cachekey; echte alte18Kennung nur für passende lokale Dateien, nicht für neue Verbindungen.
- [ ] Zwei echte ENet-Menschen: eigene Politik beider Rollen, ein gemeinsamer Hostmonat, gleiche Food-/Gold-/Arbeitszustände und Welt-Hashes. Kein neuer Verbrauch beim Gastrestore/Perspektivwechsel.

## 5 · Kompakter eigener Plan und Orientierung

**Owner:** marker_clarity_audit. **Dateien:** CivicProvisionPanel.gd, ProvinceInspector.gd, CivicProvisionUiTest.gd/.tscn, ProvinceEconomyUiTest.gd ergänzen.

- [ ] Eigener kurzer Vorrats-/Zufriedenheitswert und klappbare Planung; fremd/leer/besitzergewechselt ohne eigene Regler. Gleich gewählte Ration ohne unnötigen Applybutton.
- [ ] Alle APIs/Felder wie Spec; UIFehlerfälle zustandsneutral. TDD-Rot vor Panelcode.
- [ ] Neuer positiver Baustoffvergleich in Schwerpunktvorschau, ehrliches Potenzial und Farmarbeitskosten statt nur negativer Gold-/Mannwerte.
- [ ] Echte Maus-/Touchwege, schnelle Auswahl-/Politik-/Besitzwechsel,6Themes/100/200%, Scrollreichweite/44px; kein synchrones Entfernen des Senders während eines Touchcallbacks.
- [ ] Nur eine lesbare Warn-/Detailprojektion statt neuer globaler Verwaltung. Alte Bilder/Belege erhalten, Renderer erst nach Rootslotfreigabe.

## 6 · Integration, Review und Lieferung

**Owner:** Root, unabhängiger Review durch jeweils anderen Teilagenten.

- [ ] Neue Suiten registrieren; gezielte Altvertragsmigration mit erhaltenen negativen Kontrollen und legitimen neuen Zeit-/Arbeitswerten. Kein Test passt durch künstliche Ressourcen.
- [ ] Vollständige relevante Quellenregression und tatsächliche normale Spielwege; Rendererfehler zählen als Fehler trotz grüner Szenenasserts. Vollrun und gezielte Nachläufe klar trennen.
- [ ] Produktionspaketprüfer um explizites Schema19/Code23 und vollständiges dynamisches Modulinventar erweitern, alte Defaults17/20 erhalten; neue negative Verifierfälle zuerst rot.
- [ ] Vorlage vor Freeze, neueprovisionsEXE/APK ohne Überschreiben, statische vollständige Parität/Signatur, tatsächliche EXE aus leerem Ordner mit unveränderten Treibern.
- [ ] Neue eigene private Emulatorprüfung erst nach expliziter Rootlease; Originaldaten/Settings/Backups sichern und exakt zurückstellen, nur eigene Dienste beenden. Telefon/5037 bleiben frei.
- [ ] Neue Downloadkopien hashgleich, explizite eigene Dateiliste committen/pushen und Remote-SHA prüfen. Fremde303 Änderungen erhalten. Gesamtziel bleibt aktiv, solange weitere originale Anforderungen offen sind.
