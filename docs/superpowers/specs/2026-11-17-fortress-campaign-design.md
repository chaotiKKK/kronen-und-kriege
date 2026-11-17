# Festungsfeldzug, Entsatz und Feldlager

Basis: veröffentlichter Stand `9cb94c8`. Vorherige Zielrunde war belegter Fortschritt; das gesamte Spielspaß-/Stronghold-/Civ-Ziel bleibt aktiv. Der Nutzer hat selbstständige Entscheidungen und Umsetzung freigegeben. Die bestehende Provinzbedienung bleibt kompakt, deutsch und nach Besitz getrennt.

## Belegtes Problem und gewählter Ablauf

Mauern und Versorgung ändern derzeit keinen Belagerungsschritt; ein einzelner Soldat kann Brüssel in fünf Aktionen einnehmen. Der zusätzliche nationale Aufgebotsangriff umgeht Anmarsch und verbrauchte Heeresaktionen. Verteidiger können eine besetzte eigene Provinz nicht entsetzen, beschädigte Feldheere nicht ergänzen. Verlassene Belagerungen können Straßenversorgung dauerhaft unterbrechen. Analyse: `build/verify/fortress-design/FINDINGS.md` und zugehörige kontrollierte Beobachtung.

Gewählt ist eine gemeinsame Schleife: vorbereiten/auffüllen → tatsächlich marschieren oder übersetzen → Festung belagern oder riskant stürmen → gegnerischen Entsatz berücksichtigen → bei Bedarf über einen echten Weg zurückziehen und erholen. Nur Prozentwerte langsamer zu machen würde den nationalen Angriffspfad attraktiver lassen. Neue Warenketten und neue Truppentypen werden als eigenständige spätere Ausbauten geführt; sie ersetzen diese Kriegsschleife nicht.

## Gemeinsame Regeln

- Alle aktiven Heeresbefehle verwenden das vorhandene `last_siege_month`: Marsch, Überfahrt, Belagerung, Sturm, Entsatz und Auffüllen. Auswahl und Vorschau sind rein. Ungültige Aktionen ändern weder Welt noch RNG oder Log.
- Ein aufgelöster Kampf ist `ok=true, won=<bool>`, auch bei Niederlage: Verluste/Gold/Monatswache müssen auf Host und Gast ankommen. Ungültige Voraussetzungen bleiben `ok=false`. Meldungen informieren beteiligte menschliche Häuser genau einmal.
- Keine neue gespeicherte Ressource oder Armeesollstärke. Schema15 bleibt bestehen. Neue Regeln und Befehle gehen vollständig in den Inhaltsfingerprint. Alter tatsächlicher Code17-Schema15-LAN-Stand erhält einen eng belegten lokalen Backup-/Ladepfad; alte Netzwerkpeers bleiben abgewiesen.
- Einheiten an einem Ort sind echte Einträge mit Haus/ID/Standort. Verteidigende Feldheere zählen nur bei tatsächlicher Stationierung im Ziel. Keine nationalen Aufgebotssummen und keine grobe Reichsnachbarschaft ersetzen ein Feldheer.
- Jährliche Versorgung und Unterhaltskosten bleiben jährliche Werte. Kein versehentliches zwölffaches Abbuchen; Versorgung wirkt zusätzlich rein abgeleitet auf die Belagerung.

## Belagerung

`SiegeRules.preview(game,target,hi)` und `game.siege_preview(target,hi)` liefern dieselbe Entscheidung, die `advance_siege` ausführt.

- Fremder Besitzer, aktiver Anspruch, zulässige Beziehung/Waffenstillstand und bereite lebende ausgewählte Armee am Ziel oder echten direkten Nachbarn.
- Ein tatsächlich vorhandenes verteidigendes Feldheer verhindert den Festungsschritt; es muss zunächst militärisch besiegt werden. Ein anderer unterstützter Belagerer blockiert Fortschrittsübernahme. Neue Besitzer beginnen bei0, falls ein ungestützter Altzustand bereinigt wird.
- Effektive Soldaten = `floor(strength*morale/100)`; Festungsbonus = gespeicherte `defense` + Gelände + tatsächliche Verteidigungsforschung des Besitzers. Mauerboni werden nicht doppelt addiert, weil Bauen `defense` bereits erhöht.
- Mindestdruck = `max(1,ceil(garrison*0.35*max(0.5,1+fort_bonus/100)))`. Ein darunterliegendes Heer erhält keinen Fortschritt und einen ausführbaren Hinweis auf Verstärkung/Erholung.
- Grundschritt = `20+floor(effective_strength/60)+floor(martial/4)`. Festungsfaktor = `max(0.5,1+fort_bonus/100)`.
- Versorgung am tatsächlichen Heeresort aus dem gemeinsamen Mehrarmeenbericht: `coverage=(demand-shortfall)/demand`, begrenzt auf0.25..1. Keine erfundenen Straßenimporte ins fremde Land. Eine benachbarte erste Belagerung bewertet den bisherigen Ausgangsstandort; nach dem tatsächlichen Einrücken gilt beim nächsten Befehl der neue Standort.
- Aktive eigene Blockade multipliziert den Grundschritt mit1.15. Schritt = `max(1,floor(base/fort_factor*coverage*blockade_factor)+doctrine_siege_bonus+research_siege_bonus)`. Die vorhandenen angezeigten +8/+1-Boni bleiben tatsächliche zusätzliche Punkte; kein Bonus umgeht den Mindestdruck.
- Vorschau enthält gültigen Sperrgrund, aktuellen/nächsten Fortschritt, Schritt, ungefähr verbleibende Aktionen bei unveränderter Lage, Mindest-/Iststärke, Garnison/verteidigende Verbände, Festungsfaktoren, tatsächlichen gemeinsamen Versorgungsfehlbedarf und nächsten jährlichen Verlusttermin. Kein Zufall in der Vorschau.
- Landabmarsch, Überfahrt, Aufreibung, erzwungener Rückzug und Frieden beenden ungestützte eigene Belagerungen; ein anderes tatsächlich dort stehendes kampffähiges Heer erhält sie. Kein anderer Angreifer übernimmt Altprozente.

## Feldkampf: Sturm und Entsatz

`FieldBattleRules.assault_preview(game,target,hi)` / `relief_preview` sind reine Vorschauen. `game.attack(target,hi=-1)` bleibt der vorhandene Sturm-Befehl; `game.relieve(target,hi=-1)` ist der neue Entsatzbefehl.

Sturm braucht eine tatsächlich bereite ausgewählte Armee im Ziel oder am echten direkten Nachbarn, aktiven Anspruch,25Gold und gültige Diplomatie. Die reine Reichweitenabfrage hängt nur von tatsächlichem Heeresort und direkter Nachbarschaft ab. Keine nationale Ersatzkraft nach Marsch/Landung/verbrauchter Aktion.

Angriffskraft = effektive ausgewählte Soldaten × `(1+martial/20)` × Kriegsvermächtnis × Angriffsdoktrin × Angriffsforschung. Verteidigung ist die bisherige örtliche Garnisonsformel plus tatsächlich stationierte gegnerische Feldheere, mit deren Moral, Herrscher, Verteidigungsdoktrin/Forschung. Eigene Blockade behält ihren bestehenden Sturmfaktor1.25. Fortschritt macht keinen nationalen Fernangriff möglich.

Entsatz braucht eigenen Besitz und tatsächliche fremde kampffähige Verbände am Ort. Vorzugsgegner ist der echte `siege_owner`, sonst deterministisch stärkster zulässiger Angreifer (Haus-ID als Gleichstand). Waffenstillstand/gute Beziehung verhindern grundlosen Kampf. Ausgewähltes eigenes Heer muss bereit am Ort/echten Nachbarn stehen. Kosten0Gold. Eigene Angriffskraft erhält zusätzlich25% der örtlichen Garnisonsverteidigung als Ausfallunterstützung; feindliche Feldheere stehen außerhalb der Festung und erhalten deren Mauerbonus nicht. Keine neue Garnisonsressource.

Es wird ein normaler Angriffsrollfaktor aus0.85..1.15 verwendet; die bestehende `attack_roll_override`-Diagnose bleibt verwendbar. Vorschauwahrscheinlichkeit entspricht dieser Formel exakt und kann0 oder100Prozent sein. Abgewehrter One-Man-Angriff schädigt keine große Garnison pauschal um15%.

- Angreifer gewinnt: eigene Verluste10%, gegnerische Feldheergruppe40%, übrige Verlierer treten tatsächlich zurück oder werden bei fehlendem Ausweg zerstreut/aufgegeben. Gewinner behalten mindestens einen Soldaten.
- Angreifer verliert: eigene Verluste20%, gegnerische Feldheergruppe10%. Gewinnergruppe behält mindestens einen Soldaten. Moral der überlebenden Verlierer sinkt20, mindestens10; Gewinner erhalten bis+5. Alle Verluste werden gruppenweise integer/proportional verteilt, nicht durch Fragmentierung vervielfacht.
- Verlorener Sturm reduziert Garnison höchstens15%, proportional zur eigenen Angriffskraft gegenüber Gesamtverteidigung; schwache Restheere verursachen entsprechend geringe/keine Verluste. Siegreicher Sturm verwendet einmalig die bisherige60%-Restgarnison/Entwicklungsfolge und+15Prestige. Kein doppelter Eroberungsschaden.
- Erfolgreicher Entsatz bewegt das ausgewählte Heer ins eigene Ziel, beendet nur die nicht mehr unterstützte feindliche Belagerung und verändert keinen Besitz. Eine Niederlage überträgt ebenfalls keinen Besitz.
- Echter Rückzug: zuerst freier direkt benachbarter eigener Ort; sonst tatsächlich am Kampfplatz stationierte ausreichende Flotte und zugelassener Seeweg zu eigenem Hafen. Eigene Blockade darf dafür beendet werden. Kein Fernversetzen zur Hauptstadt. Alle betroffenen Verbände/Schiffe werden am selben aktuellen Monat markiert. Ohne echten Ausweg werden verbliebene Verlierer aus der Welt entfernt und ausdrücklich als zerstreut/aufgegeben gemeldet. Unbeteiligte Verbände/Blockaden bleiben erhalten.

## Feldlager und Erholung

`ArmyRecovery.preview(game,location,hi)` / `game.army_recovery_preview` beschreiben `game.recover_army(location,hi)`.

- Nur ausgewähltes lebendes Heer am eigenen Standort, freie Monatsaktion, keine feindliche Belagerung/Blockade oder fremde kampffähige Verbände vor Ort. Moral0 darf sich hier erholen.
- Abgeleitete örtliche Heereskapazität = `max(100,round((region_capacity.maximum/2)*legacy_war_multiplier))+vassal_levy_bonus`. Keine neue gespeicherte Obergrenze; bestehende größere Verbände werden nicht abgeschnitten.
- Bis100 neue Soldaten je Aktion, begrenzt durch fehlende Kapazität und tatsächliches örtliches Aufgebot über50Reserve. Übernommene Soldaten werden genau vom Provinzaufgebot abgezogen. Kein kostenloses Doppelzählen.
- Kosten `5+ceil(new_soldiers/10)` Gold, Moral bis+20/max100. Reine Moralpflege kostet5. Bei fehlenden tatsächlichen Soldaten kann Moralpflege weiterhin zulässig sein, sofern Moral fehlt; bei vollem Zustand keine Bezahlung/Mutation.
- Vorschau zeigt Preis, Vorher/Nachher, Abzug örtliches Aufgebot, verbleibende Reserve und tatsächlichen neuen Jahresunterhalt. Stärkegewinne verwenden dieselbe bestehende Basisunterhaltsformel wie Aufstellung (mindestens1, floor(strength/250)); Doktrin wird im Hausgesamtwert berücksichtigt.
- Eine demoralisiert lebende Armee darf ausschließlich in eigenes Nachbarland beziehungsweise mit realem Geleit zum eigenen Hafen zurückweichen; feindliche Befehle bleiben gesperrt. Kein allgemeiner Moral-Bypass.

## KI und Oberfläche

Die KI benutzt dieselben öffentlichen Aktionen. Vorrang: aussichtsreicher tatsächlicher Entsatz (mindestens35% Vorschauchance), eigener Landweg zur bedrohten Front, notwendige Erholung (Moral<60 oder Stärke<60% örtlicher Kapazität), laufender Feldzug. Bei verteidigenden Feldheeren/stärkerer Festung: Sturm ab55% Chance oder echter Rückzug zu Erholung; kein nutzloses Restheer-Monatsklicken. Jährliche Käufe berücksichtigen benötigte militärische Mittel vor optionaler Hofausstattung. Keine menschlichen LAN-Sitze automatisieren.

Vorhandenes Militärpanel: eine gemeinsame Festungs-/Kampfvorschau bei den tatsächlichen Aktionen. Fremd: Belagerung/Sturm, eigener bedrohte Ort: Entsetzen, eigener freier Standort mit Bedarf: Auffüllen/Ordnen. Keine neue Hauptnavigation, kein zweiter Zahlenkatalog. Karte verwendet vorhandenen Belagerungsmarker mit tatsächlichem Fortschrittsbogen und Besiegerfarbe. Deutsch, hoher Kontrast,44pxTouch,100/200%-Text und Scrollbarkeit bleiben erhalten.

## Verifikation und Lieferung

Reine Tests mit unabhängig abgeleiteten Literalwerten und unverändertem RNG/Snapshot; echte Game-Einstiegspunkte zuerst rot. Lebenszyklus-/Mehrarmeen-/Monats-/Preis-/Migrations-/Netzwerkfälle sind verpflichtend. Bestehende Tests schützen teils bewusst den alten Aufgebots-Bypass; diese Erwartungen werden nach beobachtetem Rot anhand der neuen Regeln geändert, keine Sonderpfade für alte Testwelten.

Normale108er-Partien mit aktiven NPCs: Festung verzögert, Entsatz bewegt reale Verbände, Rückzug/Erholung bezahlt, anschließender Feldzug spielbar. Kontrollierte Geld-/Stärkefälle bleiben von regulärer Budgetabnahme getrennt. Veränderte Regeln bleiben in einer eigenen `1.9.1-campaign`-EXE/APK/Androidcode18; vorherige Pakete erhalten. Eigener Emulator5604/ADB5039 mit USB-Filter, niemals Telefon/Standard5037. Sichtbare Windows nur DISPLAY3(1960,40). Gesamtziel bleibt aktiv, bis umfassendere Spielspaß-/Balance-/Leistungsabnahme belegt ist.
