# Provinzschwerpunkte und Versorgungslinien

Das erweiterte Nutzerziel nennt Stronghold und/oder Civilization als Anregungen für mehr Spielspaß. Wir verbinden örtliche Spezialisierung mit einer endlichen Straßenversorgung. Das ist ein eigenständiges Banger-Queens-System: Der militärische Nutzen einer Kornkammer hängt vom Standort des Heeres, fertigen Straßen und der Kontrolle des Verkehrswegs ab. Einkommen und Versorgung konkurrieren um dieselbe Provinz.

Inspiration: Das [offizielle Civilization-VI-Handbuch](https://steamcdn-a.akamaihd.net/steam/apps/289070/manuals/CIV_VI_25TH_ONLINE_MANUAL_ENG.pdf) beschreibt spezialisierte Stadtbezirke und unterschiedliche Erträge. Das [Stronghold-Crusader-Handbuch](https://steamcdn-a.akamaihd.net/steam/apps/40970/manuals/Stronghold_Crusader_HD_Manual_-_English.pdf) verbindet Ernährung und Abgaben mit der wirtschaftlichen Führung. Unsere Regeln und Werte sind eigene Entwurfsentscheidungen; wir übernehmen keine Assets oder Texte dieser Spiele.

## Regeln

Provinzen haben genau einen Schwerpunkt: `balanced` (Ausgewogen, bisherige Werte), `agriculture` (Kornkammer: −15 % regionaler Grund-/Marktertrag, +50 % örtliche Versorgung) oder `trade` (Handelsort: +15 % regionaler Grund-/Marktertrag, −20 % örtliche Versorgung). Die Landwirtschaft senkt auch den Marktertrag, damit keine versteckte Ausnahme das Abwägen entwertet. Herrscher-, Straßen- und sonstige Hauseinnahmen bleiben unabhängig.

Ein tatsächlicher Wechsel kostet `max(1, round(20 * economic_share))` Gold. Er ist danach zwölf Monate gebunden. Erster Wechsel alter und neuer ausgewogener Provinzen ist sofort möglich; dieselbe Auswahl wird kostenfrei abgewiesen. Eine Eroberung erhält Schwerpunkt und Bindungsdatum. Der neue Besitzer kann die bestehende Infrastruktur nutzen, aber nicht sofort alle Nachteile abschütteln.

Alle eigenen Feldarmeen am selben Ort teilen eine einzige örtliche Versorgungskapazität. Geländebasis und bestehende Forschungsmultiplikatoren gelten weiterhin. Eine Kornkammer darf nur ihren zusätzlichen Landwirtschaftsbonus exportieren: `min(bonus, max(0, local_capacity - own_demand))`. Grundversorgung wird nicht beliebig vervielfacht.

Nur fertige Straßen mit zwei eigenen Endpunkten ohne feindliche Belagerung (`siege > 0`, fremder gültiger `siege_owner`) bilden ein Transportnetz. Fremder Zwischenbesitz oder feindliche Belagerung unterbrechen die Verbindung sofort in der abgeleiteten Bilanz. Fremde Provinzen bleiben für stationierte eigene Heere lokal nutzbar wie bisher, erhalten aber keinen eigenen Straßentransportbonus.

Je zusammenhängendem Netz wird der verfügbare Export genau einmal auf tatsächliche Defizite verteilt. Die Zuteilung ist proportional; Rundungsreste gehen nach größtem Rest und stabiler Provinz-ID. Quellenverbrauch bleibt begrenzt und deterministisch. Die bestehenden jährlichen Versorgungsverluste treffen ausschließlich den ungedeckten gemeinsamen Bedarf; bei mehreren Heeren werden sie anteilig nach Stärke mit stabilen IDs verteilt. Die UI bezeichnet diesen Wirtschaftstermin ausdrücklich als jährlich. Keine neuen Nahrungsbestände oder frei erzeugten Ressourcen.

## Grenzen und Schnittstellen

Ein reines Modul `SupplyNetwork.gd` erhält Provinzen, Straßen, die eigenen Armeen, Hausindex sowie vorberechnete lokale Kapazitäten und Landwirtschaftsboni. `calculate(...) -> Dictionary` liefert `regions`, `roads` und `networks`. Regionseinträge enthalten `demand`, `local_capacity`, `export_available`, `export`, `import`, `shortfall`; Straßen enthalten `active` und einen lesbaren Sperrgrund. Die Berechnung verändert keine Eingaben und ist bei anderer Eingabereihenfolge identisch.

`Game` besitzt weiterhin Änderungen: `province_focus_choices(id, hi=-1)`, `province_focus_reason(id, focus, hi=-1)`, `set_province_focus(id, focus, hi=-1)`, `province_economy_preview(id, focus="", hi=-1)`, `supply_report(hi=-1)`. Vorschauen liefern tatsächliche aktuelle/alternative Jahreserträge, Kosten, Bindungsrest und örtliche Versorgung. `army_supply_capacity` bleibt eine lokale Abfrage; die Verlustanwendung nutzt die gemeinsame Bilanz.

Save-Schema 14 speichert `economic_focus` und `focus_changed_month` explizit im Provinzsnapshot. Die Migration ergänzt `balanced` und `-1`, verändert keine alten Erträge, Gebäude, gewichteten Gebäudeeffekte oder Straßen. Aktuelle Dateien müssen bekannte Schwerpunkt-IDs und ganzzahlige Zeitpunkte innerhalb der Kampagnenzeit enthalten. Für Schemawechsel regionaler Dateien wird das unveränderte Original vor Überschreiben gesichert. Der LAN-Host berechnet Kosten und Folgen; der Client übermittelt nur die gewählte Provinz und Schwerpunkt-ID. Definitionen und Befehlsliste fließen in den Fingerabdruck ein. Historische lokale Dateien werden eng migriert; gemischte Netzwerkstände bleiben abgewiesen.

## Bedienung und Abnahme

Die vorhandene Ausbau-Seite erhält einen kompakten Schwerpunktwähler mit konkretem Vorher-/Nachher-Ertrag, Versorgung, Wechselkosten und Bindungsgrund. Die Militärseite zeigt Bedarf, örtliche Deckung, Import und Fehlbedarf. Fremde Provinzen bleiben ohne eigene Verwaltungsaktionen. Wirtschaftskarte: kleines Schwerpunktsymbol und nachvollziehbare nutzbare/unterbrochene Straßen; keine neue Hauptnavigation.

Abnahme: Startkasse ohne Cheats; legaler Schwerpunktwechsel mit realer Ausgabe; zwölfmonatige Sperre inklusive Save-/LAN-Roundtrip; Forschung und drei Monate Straßenbau; Kornkammer versorgt ein unterversorgtes Heerlager; mehrere Heere verdoppeln keine Kapazität; Zwischenbesitz/Belagerung kappt den Import; Verteilung erzeugt keine Versorgung; alte ausgewogene Ökonomie unverändert. Eigene Desktop-/Emulatortests, kein Poco. Anschließend neue getrennte EXE/APK-Arbeitsstände, Paketprüfung und dokumentierte Grenzen.
