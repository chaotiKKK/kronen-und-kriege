# Baustoffhandel · Umsetzungsplan

**Goal:** Ein spielbarer, tatsächlich bezahlter ziviler Grenzhandel nutzt reale Werkstattüberschüsse für fremde Baustellen.

**Architecture:** Reine Vertrags-/Buchungsregeln liegen in MaterialTrade; Game besitzt alle Mutationen. SaveGame sichert Schema18, LAN ausschließlich Hostabsichten. Ein Panel im vorhandenen Provinzinspektor zeigt relevante Fälle.

**Tech Stack:** Godot4.5.1, GDScript, vorhandene Integer-Materialquanten, ENet, native Windows-/Android-Exporte.

**Spec:** `docs/superpowers/specs/2026-11-18-material-trade-design.md`.

Ausführung im bestehenden Checkout mit nativen Subagenten, exklusiven Dateigrenzen und testgetriebenen Teilaufgaben. Root integriert und veröffentlicht. Die autonome Freigabe des Nutzers gilt; es wird keine erneute Entwurfsfreigabe verlangt.

## Gemeinsame Grenzen

- Drei vollständige Chargen, höchstens eine pro Monat, Ablauf C+6 einschließlich.
- Zwei aktive Verträge je Haus, ein eigenes offenes Angebot, höchstens64 weltweit.
- Keine kostenlose oder teilweise Übergabe, keine gleichen-Monat-Weiterleitung/-Finanzierung.
- Eigenreserve, eigener nächster Baustellenbedarf und vorausgeplante Eigenlieferungen gehen vor.
- Schema18, Version1.9.1/Android22, aktuelle Altstände exakt erhalten.
- Kein Telefon/Standard-ADB; GUI nur rechter DISPLAY3, Root besitzt allein Renderer/Emulatorslot.
- Vor jedem Teil zuerst aussagekräftigen Rotfall ausführen; danach Grün und unabhängiger Review.

## 1 · Reine Verträge und Buchung

**Dateien:** `scripts/MaterialTrade.gd`, `tests/MaterialTradeTest.gd/.tscn`.

**Schnittstellen:** Exakte drei Modulmethoden und Vertragsfelder aus Spec. Aufrufer übergeben vorhandene Überschüsse und Geldbudgets; Modul liest weder Game noch Uhrzeit/RNG/UI und ändert keine Eingabe.

- [x] Test: Ein aktiver Vertrag, Quelle3UNIT, Ziel0, Angebot1UNIT, Käufer4Gold, Charge1UNIT/2Gold, Monat nach Annahme ergibt genau1UNIT/2Gold atomare Deltas unddelivered_lots1.
- [x] Rot bestätigen; fehlende Teilmenge, Geld oder Raum muss vollständig unverändert bleiben.
- [x] Implementieren; mehrere Verträge teilen ursprüngliche Angebote, Lagerraum und Geld. Verkäufereinnahmen sind nicht neues Käuferbudget.
- [x] Drei Lieferungen entfernen Vertrag; Angebot/Annahmemonat liefert nicht; Ablauf entfernt ohne Buchung; blockierte/feindliche/fremd gewordene Enden liefern nicht.
- [x] Rohvalidierung gegen gefälschte Preise/Mengen, doppelteIDs, zukünftige Daten, Bool/NaN/Fraction und fremde Felder.
- [x] Tests ausführen und Ergebnis/Quellstopp melden; Root registriert Suite zentral.

## 2 · Spielstand18

**Dateien:** `scripts/SaveGame.gd`, `tests/MaterialTradeSaveTest.gd/.tscn`.

**Consumes:** MaterialTrade.validate; Root ergänzt Game-State gleichzeitig.

- [x] Vorherige gültige17-Welt sichern. Test verlangt neue leere Felder ohne Änderung alter Werte und verwirft fehlende/ungültige18-Felder.
- [x] Rot bestätigen, CURRENT_VERSION18 und trade_fields vor jeder Normalisierung integrieren. Integer erst nach bestandenem Rohvertrag kanonisieren.
- [x] Array-/Serialgrenzen, Preisformel, Datums-/Haus-/Regionsbindung, Roundtrip eines aktiven und offenen Vertrags prüfen.
- [x] 17erOriginal, bestehende Schema16-Forschungsmarker und Backupfamilie unverändert prüfen. Keine Migration erzeugt Güter oder Vertrag.
- [x] Quellstopp und Ergebnis melden; Root registriert Suite und aktualisiert nur nachgewiesene alte Schema-Erwartungen.

## 3 · Game-Integration und zivile Normalkampagne

**Dateien:** `scripts/Game.gd`, `tests/MaterialTradeGameTest.gd/.tscn`, `tests/MaterialTradeCampaignTest.gd/.tscn`.

**Produces:** Alle sechs öffentlichen APIs und beide Monatsmethoden aus Spec; `material_trades`, `trade_serial` in Snapshot/Restore.

- [x] Rotfall für tatsächliches Angebot, Gegenbestätigung, Doppelaufruf ohne Log-/Zustandsänderung und autorisierten Abbruch.
- [x] Vorschau bleibt rein; Zustimmung, Limits und Eigentümer bei Mutation erneut prüfen. NPC-Bedingungen und gemeinsame Reserve nutzen.
- [x] Handelsüberschüsse aus Originalvorrat minus Eigenreserve/Arbeitsbedarf und hypothetischem eigenen Transportplan bestimmen.
- [x] `_tick_material_trade` vor Arbeit verbucht nur Deltas des reinen Plans. Alle betroffenen Menschen erhalten tatsächliche Ergebnisse im vorhandenen Log.
- [x] NPC-Nachfrage aus bestehenden Projekten; Kandidaten aus direkt benachbarten NPC-Quellen. Keine automatische Verplanung menschlicher Güter.
- [x] Regelmäßiger bezahlter Kampagnenweg plus Kontrollwelt ohne Vertrag. Geld-/Materialerhaltung vor und nach jeder Phase; echte spätere Verwendung und kein Debugguthaben.

## 4 · Hostabsichten und Kompatibilität

**Dateien:** `scripts/UiKernel.gd`, `scripts/LanProtocol.gd`, `scripts/LanSession.gd`, `tests/MaterialTradeCommandTest.gd/.tscn`, `tests/MaterialTradeLanTest.gd/.tscn`.

- [x] Rotfall: Gast darf nur Angebot eigener Partei, Gegenannahme und eigenen Abbruch senden; keine Preise/Mengen/Häuser im Befehl.
- [x] Drei Befehle in Whitelist, Typ-/Längengrenzen, Game-Dispatch, Fingerprint sowie Cacheidentität integrieren.
- [x] Echter ENet-Austausch mit zwei Menschen: Angebot bleibt offen bis Gegenseite annimmt, dann echte Lieferung nur durch Hostmonat. Gast darf keine fremde Annahme erzwingen.
- [x] Echte bisherige Schema17-LAN-Datei/fingerprint bytegenau erhalten und in18 migrieren; neue Verbindungen verlangen neuen vollständigen Fingerprint.
- [x] Autoritativer State enthält Verträge/Serial. Restore und negative Rollenbefehle bleiben side-effect-frei.

## 5 · Kompaktes Panel, Prüfung und Lieferung

**Dateien:** `scripts/MaterialTradePanel.gd`, `scripts/ProvinceInspector.gd`, `tests/MaterialTradeUiTest.gd/.tscn`, Runner, Verifier, Exportkonfiguration und Releasebericht.

- [x] Rotfall für relevante eigene/fremde Grenzprovinz, tatsächliche Vorschläge/Annahme/Abbruch und verschwundenen Leerbereich.
- [x] Panel nutzt nur Game-Vorschau/Absichten, keine Direktmutation. Ausreichende Touchflächen, Textumbruch und100/200-Prozent-Scrollreichweite.
- [x] Keine Bau-/Forschungsverwaltung in Fremdland, keine versteckten alten Handelsziele nach Auswahl-/Besitzerwechsel.
- [x] Alle neuen Szenen registrieren; kritische alte Forschungs-/Schema-/Sofortannahmen ehrlich migrieren. Vollständiger relevanter Regressionlauf, unabhängiger Review, reine Inputvergleiche.
- [x] Vorlage vor Freeze vorbereiten, Schema18/Code22 explizit prüfen, alle neuen Module aus vollständigem Inventar zulassen und echte APK/EXE bauen.
- [x] Tatsächliche neue APK im eigenen dedizierten Emulator auf Load/Save, Touchsuche, fremden Kontext und Lesbarkeit prüfen; anschließend Originalprofil vollständig restaurieren und nur die eigene Session beenden.
- [x] Tatsächliche neue EXE aus leerem Ordner mit unveränderten Treibern prüfen, statische APK-/EXE-Parität und Signatur, Downloadkopien hashgleich, Quellcommit/Push.

Offene Teilschritte sind keine Gesamterfüllung des Spielspaßziels. Weitere Forschung, Reichsziele, Ereignisfolgen, Langzeitbalance und messbare Leistung behalten ihren ursprünglichen Umfang.

## Abnahmestand 18.11.2026

Reine Regeln201, Game85, Save448, Commands103/echtesENet100 und Normalkampagne268 sind belegt. Die erweiterte NPC-Matrix umfasst1411 Prüfungen mit868 bezahlten Aufträgen,32 vollständigen Ketten und7 Frontlieferungen; die ursprünglichen Nullfront-Läufe bleiben erhalten. Die Quellenmatrix46572/123 ist aus122 unveränderten V2-Suiten und dem gezielt korrigierten1751-Originaltest zusammengeführt, kein einzelner vollständig grüner Sammellauf.

Ein später im nativen Android-Touchlauf entdeckter Lebensdauerfehler der Suchtreffer ist separat rot/grün geschlossen: identischer7395-Treiber, zwei echte Touchfolgen, zuerst zwei native Fehler, danach null. Danach sind sechs gezielte UI-Suiten mit824 Prüfungen sauber. Dieser neue Runtime-Diff wird ausdrücklich nicht als bytegleicher Teil der alten123-Suiten-Matrix ausgegeben. Die endgültigen Pakete trade-delivery sind aus frozen-delivery2 gebaut und statisch gegengeprüft; drei tatsächliche EXE-Suiten bestehen8127 Prüfungen mit47 Bildern. Nach der zentralen Palettenkorrektur bestehen573+608=1181 gezielte Quell-UI-Prüfungen. Android-Lieferprüfung, vollständiger Originalrestore und eigener Stop sind belegt; Downloadkopien sind hashgleich. Root schließt den geprüften Quellcommit/Push ab und hält die tatsächliche Remote-SHA im abschließenden Lieferbeleg fest.

Weitere normale Handelskampagnen mit kleinen selbst gestalteten Häusern bleiben eine zusätzliche Balanceprobe des umfassenden Ziels; die zwei normalen Handelswelten ersetzen diesen Nachweis nicht.
