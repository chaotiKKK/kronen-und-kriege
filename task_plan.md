# Vergleichbare echte Verwaltungsebenen – verbleibende 15 Gebiete

Aktueller maßgeblicher Stand: der Gameplay-Meilenstein 1.9.1 ist umgesetzt, als neue Pakete gebaut und unter Windows geprüft; Android-Abnahme wird ergänzt. Das Gesamtziel Spielspaß sowie alte Quellen- und Leistungsgrenzen bleiben offen. Die älteren Statusblöcke bis zum Abschnitt „Aktives Ziel“ dokumentieren frühere Zwischenstände.

## Aktive Fortsetzung am 17. November 2026

Aktueller Auftrag: Restbalance und Migration selbstständig bis zu regulär spielbaren108 Regionen fertigstellen; anschließend EXE/APK bauen und prüfen. Abnahmepfad: alte vollständige Partie→Migration mit unverändertem Eingabestand/Backup→108-Regionen-Partie→Charakter erstellen→Monate spielen→Speichern/Laden; zusätzlich Katalog-/Protokollkonflikte abweisen. Neue Version1.8.0/Androidcode12. Neue Features außerhalb dieses Abnahmepfades werden nicht eingeschoben.

Der Quellstand wurde aus GitHub 7e127e4 unter F:\Crusader Kings III v1.18.3\banger-queens-recovery-20261117 wiederhergestellt. Der frühere C:-Checkout und sein nicht gepushter Branch sind nicht mehr vorhanden. Nutzer nennt F: als Projektort und die EXE 1.6.1 als vorhandenes Paket. Das Paket bleibt erhalten. Die nachfolgenden historischen Atlasabschnitte bleiben als Belege stehen.

Aktueller freigegebener Auftrag: Option 2 vollständig, inline ohne Subagenten. Rund 108 ausgewogene Spielregionen, vollständiger passiver Detailatlas, deutsche Touchoberfläche, keine zusätzlichen Inhaltsimporte. Startwirtschaft 762 und Aufgebot 24.240 erhalten. Schema 13 und WLAN-Protokoll 2 folgen erst mit geprüfter Migration. Version 1.7.0 bleibt Rückfallstand.

1. Quellstand, Plan und Testumgebung wiederherstellen: **Status:** complete.
2. Deterministischen Regionsgenerator und strikte Verträge rekonstruieren, reale Daten doppelt bauen: **Status:** complete (14 Pythonprüfungen; tatsächliche Atlasgrenzen; vier belegte harte Flächenausnahmen; Eingabefreeze der veröffentlichten Datensnapshots, originale Rohcaches nicht vorhanden).
3. Runtimekatalog mit Hashprüfung und Raumindex einbinden: **Status:** complete (441 Godotprüfungen).
4. Wertefluss und Data/Game auf Regionen umstellen: **Status:** in_progress (Adapter, Startwerte, jährliche Basiswirtschaft, gewichtete Werbung/Ausbau/Aufgebotsregeneration und neuer Save-Roundtrip geprüft; KI-/Gebäudewirkungsgewichtung und reguläre Menüaktivierung fehlen).
5. Spielstandmigration Schema 12→13, Backup und WLAN-Protokoll 2: **Status:** pending.
6. Kartenmodi, Suche, Vorschauen, Lesbarkeit und Touch: **Status:** pending.
7. Befehle, sichtbare Infrastruktur, WLAN-Komfort und Spielablauf: **Status:** pending.
8. Regressionen, reproduzierbare Windows-/Android-Pakete und reale Geräteabnahme: **Status:** pending.

Nächste Aktion: KI-/Gebäudegewichtung abschließen und gemischte Schema-12-Besitzer in einer separaten Regionsmigration erhalten; erst nach Atomaritäts-, Integritäts- und Verlustfreiheitsnachweis den regulären Menüstarter umstellen. Kein Telefon ohne erneuten exklusiven Slot.

Stand: 10. November 2026. Fortsetzung des genehmigten Atlasentwurfs; die veröffentlichte Version 1.6.0 bleibt als Rückfallstand erhalten.

## Ziel und Abnahme

Alle im Kartenrechteck vorhandenen Gebiete sollen echte, vergleichbar detaillierte lokale Verwaltung besitzen. Keine erfundenen Flächen, keine Umbenennung höherer Ebenen zur Beschönigung der Abdeckung. Quellenstand, rechtliche Rolle, Lizenz, Herkunft und verbleibende Unsicherheit bleiben sichtbar. Eine geometrische Abdeckung von mindestens 95 % gegen eine unabhängige Landreferenz ersetzt keinen Nachweis der korrekten Verwaltungsrolle.

## Phasen

1. Bestandsaufnahme und Arbeitsteilung: complete.
2. Primärquellen, Rollen und echte fehlende Geometrien: partial / external_sources_required (sieben der 15 Fälle geklärt, acht offen).
3. Getestete Provider, unveränderliche Quellcaches und Integration: complete für alle positiv zugelassenen Quellen; keine unsicheren Kandidaten integriert.
4. Gemeinsamer Atlasbuild, Regressionen, Darstellung und Leistungsprüfung: complete (391 Python-Tests; 41 Godot-Suiten / 31.746 Assertions; 148 isolierte Paketlauf-Prüfungen).
5. Dokumentierter geprüfter Zwischenstand und lokale Pakete: complete. Veröffentlichungsbeleg: GitHub-Release v1.6.1. Das Gesamtziel bleibt wegen acht konkreter Quellen-/Geometrielücken offen.

## Gebiete und Verantwortliche

| Gebiet | Ausgangsstatus / Abdeckung | Bearbeitung |
|---|---|---|
| AM | source_review / 93,16 % | coverage_research: unabhängige Landreferenz und Identitäten |
| AZ | gap / 3,45 % | Root: aktuelle bələdiyyə-Grenzen |
| CNM, CY, CYN, ESB, WSB | source_review / 95,87–99,87 % | atlas_independent_review: datierte Rollen, Reform und Quellzählung |
| IL | gap / 92,75 % | coverage_research: echte Räte und Referenz |
| IR | source_review / 98,74 % | atlas_release_review: aktueller positiver Dehestan-Satz; Altquelle quarantänisiert |
| JO | gap / 0 % | Root: reale Kommunalquelle |
| KZ | source_review / 77,57 % | coverage_research: ländliche/urbane örtliche Verwaltung |
| LB | gap / 61,67 % | atlas_release_review: echte Gemeinden und nichtkommunale Gebiete |
| LY | gap / 0 % | Root: aktuelle Baladiya-Grenzen |
| MA | source_review / 99,48 % | atlas_independent_review: fehlende echte Gemeinde |
| TR | source_review / 55,59 % | atlas_release_review: lokale Gebietsrollen und echte fehlende Flächen |

## Koordination

- Projekt: C:\Crusader Kings III\mobile-godot. F: ist derzeit nicht erreichbar.
- Root besitzt Builder, Integration und diese Planungsdateien. Agenten haben getrennte Providerbereiche.
- Godot, Atlasbuild und Exporte laufen jeweils einzeln und koordiniert. Kein Telefon ohne neue exklusive Übergabe.
- Rohquellen und Auditdownloads bleiben in .tools/atlas_sources; eingebettete Daten werden vollständig mitgeliefert.
- Aktuelle atlas.json ist 97.749.149 Bytes groß. Vor weiterer Veröffentlichung GitHubs 100-MiB-Grenze prüfen und bei Bedarf sauber aufteilen.

## Next Step

Geprüfter Zwischenstand1.7.0 ist veröffentlicht: https://github.com/chaotiKKK/kronen-und-kriege/releases/tag/v1.7.0, getesteter Codecommit71884ddedcb6ac1ebc70717f13e9fc530f682e71. Der LAN-Umfang und die positiv qualifizierte Sakarya-Erweiterung sind umgesetzt. Für das Gesamtziel bleiben die konkret dokumentierten externen Quellen-/Geometriebelege in AZ/CNM/IL/KZ/LB/LY/MA/TR sowie die reale Android-WLAN-Abnahme auf zwei Geräten offen.

## Errors Encountered

| Fehler | Ursache | Umgang |
|---|---|---|
| Überlange Bestandsausgabe abgeschnitten | Vollständige Coverage-Metadaten zusammen ausgegeben | Nur gezielte Schlüssel und kurze Dateiausschnitte lesen |
| rg-Dateiglob unter PowerShell nicht expandiert | Glob als Pfad übergeben | rg mit -g-Dateifilter oder vorheriger Dateiliste verwenden |
| Overpass POST 406; erster GET 429 | Öffentlicher Dienst lehnt generischen Client ab | Ein begrenzter GET mit aussagekräftigem User-Agent; keine Endlosschleife |
| Zwei ArcGIS-Items 403 | Öffentliche Anbieter-Subskriptionen deaktiviert | Andere legale öffentliche Quellen suchen; kein Zugriffsumgehen |
| Minifiziertes atlas.json als ganze ersteZeile ausgegeben | Get-Content -TotalCount begrenzt Zeilen, nichtBytes | Große JSON-Dateien ausschließlich perParser gezielt projizieren |
| JO-CLI UnicodeEncodeError | Windows-Standardkonsole cp1252 | ASCII-sicheres JSON amCLI-Ausgang und UTF-8-Dateien |
| JO-Neucachewiederherstellung .read-Attributfehler | RangeSource-Vertrag hat.fetch | FrischerCache-Regressionstest und gezielteMethodenkorrektur |

## Neue Fortsetzung: acht Quellenfälle und WLAN

Auftrag vom10.November2026: neue belastbare Quellen für die acht offenen Gebiete und echter WLAN-Mehrspielermodus. Architektur/Plan unter docs/superpowers/specs/2026-11-10-lan-multiplayer-design.md und docs/superpowers/plans/2026-11-10-lan-multiplayer.md. Userautonomie gilt. Root besitzt Netz/UI/Main/Integration, Game-Worker isoliert persönliche Zustände; zwei getrennte Quellenworker suchen andere Primärwege. Nur koordinierte einzelne Godot-/Build-/Exportslots.

## Stand 17. November 2026: 108 Regionen und kompakte Oberfläche

Aktiver Checkout: `F:\Crusader Kings III v1.18.3\banger-queens-recovery-20261117`, Branch `codex/balanced-game-regions`. Die ältere C:-Pfadangabe oben ist historisch. Inline ohne Subagenten weitergearbeitet.

1. Regionskatalog und gewichtete Ökonomie: abgeschlossen, Kataloghash `6112a370a9c26d1186059519e26742db7b63a10b4082c41e2fb2623b30f5f629`.
2. Reguläre Menüs, eigener Charakter, Save-Schema 13, bytegleiche Altstand-Sicherungen und lokale WLAN-Dateimigration: abgeschlossen und geprüft.
3. Kompakte Hauptansicht nach Brainstorming/Frontend-Design: abgeschlossen. Größere Touchflächen, sechs Themes und 200-Prozent-Schrift bleiben erhalten.
4. Quellenregression: 54 Godot-Suiten / 35.193 Prüfungen nach dokumentierten gezielten Nachläufen grün, Regionsgenerator 14 Tests grün. Vollständiger alter Python-Quellenaudit wegen fünf fehlender privater Cachebelege und vier übersprungener Cachefälle ausdrücklich offen.
5. Finale EXE und APK 1.8.0 gebaut und statisch geprüft. Exportierte EXE: 368 Runtime-Prüfungen plus 66 Prüfungen mit zwei ENet-Prozessen. Android-Emulator: eigener Charakter und Speichern per Geräteeingabe, Datei mit 108 Regionen und korrektem Schema/Hash bestätigt.

Abnahmegrenzen: physisches Poco und echtes Smartphone-WLAN offen; etwa 11,7 FPS beim 4×-Kartenschwenk im PC-Benchmark; Android-Emulator rund 3 GiB PSS einschließlich Swap. Signaturschlüssel der vorhandenen APK 1.6.1 fehlt; dadurch ist die neue APK kein direktes Update über diese Fassung. Bericht: `docs/releases/1.8.0.md`, endgültige Belege: `build/verify/release-180-final/`.

## Folgeauftrag 1.9.0 – Strategieansichten und gestaltbare WLAN-Häuser

- Fünf getrennte Kartenpolitiken, feste Rechtsgrenzen im Gelände, zusammengefasste Rechtstitelansicht und sofortiger Provinzinspektor umgesetzt.
- Örtliche Bau-/Heeres-/Forschungs-/Vermächtnisansichten; Datei- und Lobbyverwaltung in den Optionen; Weltseite bereinigt.
- 16 Innovationen mit realen Regelwirkungen, 32 kontextabhängige Ereignisse, vier ausgewogene Armeedoktrinen.
- Gemeinsamer Einzelspieler-/WLAN-Hausdesigner, autoritative Heimatreservierung, dynamische Haussitze, Protokoll 3 und getrennte lokale Altdateimigration.
- Stabile Hofverwaltung mit sichtbaren Kosten, Unterhalt, Sperrgründen und Bestätigungen; Fokus und Aktionsinstanzen bleiben beim Refresh erhalten.
- 61/61 Godot-Suiten nach drei belegten Nachläufen, 36.003 Prüfungen. Ursprüngliche Fehlerlogs bleiben erhalten; `build/verify/release-190/regression-reconciled.json` hält die Zusammenführung fest.
- Erstpakete statisch geprüft: 628 PCK-/743 APK-Einträge; EXE 371 Laufzeitprüfungen und zwei getrennte ENet-Prozesse 66 Prüfungen. Separater Funktionsprüfer 49 Prüfungen und sieben Aufnahmen.
- Abschluss: 200%-SpinBox-Schrift rot/grün korrigiert, finale EXE/APK gebaut, 51+371+66 Paketprüfungen und Android-Geräteeingaben mit gespeicherten echten Aktionswerten nachgewiesen. Bericht: docs/releases/1.9.0.md; finale Belege: build/verify/release-190-final2. Downloads und Quellcommit werden abschließend hashgebunden übergeben.

Koordination: drei isolierte Feature-Worker und ein unabhängiger Abschlussprüfer; Root besitzt Integration, Builds und ausschließlich den eigenen Emulator. Poco bleibt unbenutzt. Keine Änderungen am 108-Regionen-Katalog oder der Atlasgeometrie.

## UI-Patch 1.9.1 abgeschlossen

Unteres mittiges Titelmenü, feste weiße Version unten rechts und unverändertes chaotiKKK-Studiologo mit drei Sekunden Intro umgesetzt. Acht gezielte Suiten / 488 Prüfungen; fertige EXE 380 Runtime- und 66 Zwei-Prozess-Netzprüfungen, finale APK/EXE statisch geprüft. APK ohne erneuten Gerätestart; bestehende Hardware-/Performancegrenzen bleiben bestehen. Bericht docs/releases/1.9.1.md und Belege build/verify/release-191. Aktueller Quellstand und Downloadpakete werden abschließend gesichert.

## Aktives Ziel – Spielspaß bleibt offen

Nutzerziel: weniger Leerlauf, bedeutsame Entscheidungen und erkennbare Weltreaktionen, ergänzt um passende Civilization-/Stronghold-Inspiration. Der aktuelle funktionale Meilenstein ist abgeschlossen; eine Gesamtfertigstellung oder AAA-/Flüssigkeitsbewertung wird nicht behauptet.

1. Kontextabhängige Provinzverwaltung und zentrale örtliche Befehle: abgeschlossen; eigene und fremde Verwaltung getrennt, Kriegskarte öffnet passende Befehle.
2. Nutzbare Feldarmeen: abgeschlossen; Auswahl, Anspruch, angrenzender Marsch, Belagerung/Angriffsbeitrag, Monatswache, Erhalt mehrerer Alt-Armeen und Korrektur der 0-Mann-Sackgasse geprüft. Militärische KI monatlich, Käufe/Hof jährlich.
3. Provinzschwerpunkte und endliche Straßenversorgung: abgeschlossen gemäß [Spezifikation](docs/superpowers/specs/2026-11-17-province-economy-and-supply-design.md). Gemeinsame örtliche Deckung und ganzzahlige anteilige Verlustreste, keine Versorgungsverdopplung.
4. Schema 14 und Originalschutz: abgeschlossen; Schwerpunkt/Bindung, bytegleiche lokale und WLAN-Altsicherungen auch vor direktem Überschreiben, strikte aktuelle Netzwerkfingerabdrücke.
5. Quellen-/Windows-Abnahme: abgeschlossen als nachvollziehbare Zusammenführung von 76 Suiten/36.902 Prüfungen; 8.307 unabhängige Regel-/Speicherprüfungen ohne offenen Fund. Fertige EXE: 380 allgemeine, 49 gerenderte Gameplay- und 130 Zwei-Prozess-ENet-Prüfungen erfolgreich.
6. Neue EXE/APK und Downloadkopien: gebaut und statisch geprüft, alte Dateien erhalten. Aktuelle Namen `banger-queens-1.9.1-gameplay.{exe,apk}`. Hashes und Einzelbelege: [Gameplay-Bericht](docs/releases/1.9.1-gameplay.md).
7. Android-Abnahme wird ergänzt. Physisches Poco und echtes Android-WLAN nicht getestet.
8. Weiter offen: längere Spielspaß-/Balancebewertung, Kartenleistung (PC-4×-Pan 10,5 FPS, p95 100,51 ms) und frühere Atlasquellen-/Geometrielücken sowie private Rohcachebelege.

Nächste Aktion: laufende Android-Abnahme mit ihren tatsächlichen Grenzen dokumentieren. Danach am offenen Gesamtziel anhand längerer Partieerfahrung und messbarer Kartenleistung weiterarbeiten; alte Quellenlücken separat verfolgen. Kein physisches Telefon ohne abgestimmten Slot.

- Android-Meilenstein 17.11.: aktuelle APK im eigenen API-36-Emulator tatsächlich aktualisiert, sichtbar gerendert und per Touch bedient. Ari190-Altstand, 108 Regionen, Schwerpunktwechsel 90→45 Gold, Schema14-Speichern und bytegleiches Schema13-Backup geprüft; fremdes Wien nur Krieg/Diplomatie. Zwölf Kontrollen im `build/verify/gameplay-191-final/android-runtime-receipt.json`. Erster SwiftShader-Grafiklauf fehlgeschlagen und erhalten, unveränderte APK mit Host-GPU erfolgreich. Eigener Emulator beendet, kein Poco/echtAndroidWLAN-Nachweis.

## Aktuelle Fortsetzung: Spielabläufe und Kartenleistung (17.11.)

Die vorherige Zielrunde war Fortschritt: getestete Gameplaypakete und GitHubstand geliefert. Das volle Spielspaßziel bleibt aktiv. Der Beschriftungscache wurde als Versuch verworfen: 59 gezielte Prüfungen bestanden, aber im kontrollierten Schwenk nur 87,58→87,38 ms p95. Keine zusätzliche Cachekomplexität in AtlasLayer übernommen.

Aktueller Umfang: Minimap trennt unveränderte Regionsgeometrie vom Kamerarechteck; 37 echte Renderprüfungen grün, kontrollierte Initial-/Pan-/Zoom-Bilder pixelgleich. Neuer endgültiger A/B-Lauf mit festem Walnussthema und identischem Kamerastart läuft; nur WorldMiniMap unterscheidet die Quellmanifeste. Keine fertige Leistungsbehauptung vor Abschluss. Ereignis-/Friedensguards sind integriert; reine peace_reason-Extraktion und abschließende Gesamt-/Paketprüfung stehen noch aus. Marinefeldzug ist bislang Entwurf; Küsten-/Wassergate noch nicht ausgeführt.

- Endgültiger serieller Minimapvergleich beendet:11,5→24,7FPS, p9589,90→41,36ms (−54%); Zeichenaufrufe5598 und Primitive1.659.086 identisch. Alle vier tatsächlichen1600×900-Vergleichsbilder pixelgleich. NurWorldMiniMap differiert zwischen Manifesten. Beleg `build/verify/atlas-cache/minimap-performance/comparison-result.json`; keine60FPS-/Poco-/allgemeineHardwaregarantie. Neue Paketkennung bleibt1.9.1, Androidcode15, Ausgabe soll unter neuemSuffix-gameplay2 erfolgen. Nochkeine v2-Pakete gebaut.

## Aktuelle Nutzerkorrektur: weniger und eindeutigere Provinzbedienung

Die Gameplay2-Pakete sind inzwischen gebaut; 79 Suiten/37.139 Prüfungen und 624 Windows-Paketprüfungen bestanden. Der zugehörige Bericht wird nach den tatsächlichen Paketreceipts aktualisiert, die laufende Androidprüfung gehört genau zu diesem eingefrorenen Vorläufer.

Die neue, begrenzte UI-Änderung verwendet die bestehenden Ansichten und Regeln: ohne Auswahl keine deaktivierten Provinzreiter; eigener Besitz Ausbau/Heer/Wissen, fremder Besitz Krieg/Diplomatie. Strukturell unerreichbare Befehle verschwinden, zeitweilige Sperren bleiben erklärt. Ein hausweiter Forschungsplan ersetzt den zweiten vollständigen Katalog im Inspector; dort bleiben Fortschritt und örtliche Wirkung. Eigene Provinzbereiche sollen nach einem fremden Zwischenbesuch wiederkehren. Kartenaktivierung führt zur selben rechten Provinzansicht.

Nächste Aktion: rote reale Kontextprüfungen, minimale Implementierung, betroffene Regel-/UI-/LAN-Prüfungen und neue, gesondert gekennzeichnete Pakete. Telefon bleibt frei; nur eigener Emulator ist für den Vorläufer belegt. Marine und andere offene Gameplayarbeit werden dadurch nicht als erledigt ausgewiesen.

Aktualisierung: Umsetzung und gezielte Rot-/Grünphase abgeschlossen (37 Render- und 28 Forschungsprüfungen). Der vollständige Lauf ist an 348 eingefrorene Dateien gebunden; aktuell 65/80 Suiten erfolgreich, keine Fehler. Androidcode16 und neue Dateinamen `1.9.1-context` sind vorbereitet. Nächste Aktion: Gesamtregression abschließen, anschließend EXE/APK bauen und deren tatsächliche Laufzeit prüfen.

Endstand vor Androidabschluss: vollständiger Vorlauf 79PASS/1FAIL wegen Cursor-Shutdown; gezielt korrigiert, zehn aktuelle Nachläufe/7.875 Prüfungen grün. Dokumentierter Abgleich80/37.185 erfolgreich, ausdrücklich kein einziger vollständig grüner finaler80er-Lauf. Finalfreeze348 Dateien bb0f29d5… mit exakt MapView/ModernUiTest geändert; getrennt erhaltener alter Freeze b063978f…. Fertige EXE 629 tatsächliche Paketprüfungen, APKcode16 und EXE statisch mit23Daten/Logo/43gleichen kompilierten Skripten geprüft, Downloads hashgleich. Androidupdate15→16 hat den alten Spielstand bytegleich erhalten; geladen und eigeneDreiertabs sowie gemeinsamerPlan perTouch gesehen. Receipt/Bereinigung noch in Arbeit.

Nächste Aktion: letzten Androidbeleg abschließen, Bericht/README/Plan finalisieren und geprüften Quellstand committen/pushen. Danach bleibt das Gesamtziel aktiv; nächster fachlicher Gameplaypunkt ist der belegte Seetransport für Wessex gemäß vorhandenem Marine-/Wasserwegentwurf. Aktuelle echte Schema14-LAN-Dateien aus dem Kontext-Paketlauf für eine spätere Schema15-Migration erhalten.

UI-Abnahme abgeschlossen: Neue Kontext-APK code16 im eigenen Emulator aktualisiert, geladen und in17 begrenzten Protokollpunkten geprüft. Eigene Istanbul mit drei Bereichen, fremde Wien mit Krieg/Diplomatie, gemeinsamer Forschungsplan/Scroll/Schließen und Rückwechsel korrekt; Spielstand nach Installation und Navigation bytegleich, keine Zahlung. App/Emulator/privateADB beendet, Telefon unberührt. Bericht docs/releases/1.9.1-context.md. Letzter Arbeitsschritt dieser UI-Runde: Commit/Push der geprüften Quelle; gesamtes Spielspaßziel bleibt aktiv.

Kontext-Runde abgeschlossen und auf GitHub gesichert: Quellcommit `071f5ae0cdeb39198902549e14c1414799af97e9` auf `codex/balanced-game-regions`; Push und Remote-Referenz stimmen überein. Fertige Downloads heißen `banger-queens-1.9.1-context.exe/.apk`. Generierte Import-/Android-Builddateien wurden nicht in den Quellcommit aufgenommen. Kein weiterer UI-/Pakettest aus dieser Runde ist ausstehend; physisches Poco und echtes Android-WLAN sind weiterhin keine belegte Abnahme.

Nächste Aktion im aktiven Gesamtziel: vorhandenen Marineentwurf und geometrisch belegte London–Brüssel-Küstenroute in einen testgetriebenen Wessex-Transportweg überführen. Die echte Kontext-LAN-Schema14-Datei aus `build/verify/lan-release-1.9.1-20261117-200640-336-b9aba060/` vor einer Schemaänderung als Originalbeleg sichern. Quellen-, Performance- und langfristige Balancegrenzen bleiben eigenständige offene Arbeit.

## Aktuelle Fortsetzung: Marinefeldzug und weitere Kontextbereinigung

Der verifizierte London–Brüssel-Weg, reine Transportvorschau, echte Landung/Abwehr und geteilte Monatswachen sind implementiert; Schema15 erhält Flottenaktionsdaten mit bytegenauen alten Schema14-Belegen. Routen-, Modell-, Save-, Command- und reale UI-Teilstrecken sind gezielt geprüft. Ein regulärer Wessex-Lauf mit120 Startgold und acht aktiven NPCs erreicht Brüssel und erobert es in Monat17; dieser Beleg muss nach der noch ausstehenden KI-Einbindung wiederholt werden.

Aktueller Nutzerwunsch: fremdes Land ohne Bau-/Forschungsverwaltung, kontextbezogene Aktionen und weniger doppelte Bedienung. Der bestehende Kontextstand wird deshalb erneut geprüft und gezielt vereinfacht, während der reine Feldzugsplaner in die tatsächlichen KI-Jahres-/Monatszüge eingebunden wird. Neue Integrationsfälle zuerst rot; danach gesetzliche Renderfolge, vollständiger Regressionlauf und gesonderte APK/EXE. Alte Kontextpakete bleiben erhalten; Smartphone und andere Projekte bleiben unberührt.

Android und Pakete abgeschlossen: Neue APKCode17 und EXE liegen hashgleich als `banger-queens-1.9.1-naval` in Downloads. Tatsächliches Emulatorupdate, Migration/Neustart und zusätzlicher normaler Touch-Wessex-Feldzug bis zur Landung belegt (18Core+14Zusatzpunkte, kein Engineassertion-Zähler). Alter Emulator-Spielstand exakt restauriert; App/Emulator/privateADB beendet, Telefon frei. Alle Runtime-/Testdateien bleiben seit finalemManifest unverändert. Kein einzelner vollständiger finaler89er-Grünlauf behauptet;89/37739 sind nachvollziehbarer Abgleich mit getrennten Nachläufen. Letzter offener Schritt dieser Runde: Commit/Push. Gesamtes Spielspaß-, Balance- und Leistungsziel bleibt aktiv.
