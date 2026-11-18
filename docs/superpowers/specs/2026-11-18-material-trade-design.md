# Baustoffhandel zwischen Häusern

Basis: Commit65a51b9. Das vollständige Spielspaß-/Stronghold-/Civ-Ziel bleibt aktiv. Der Nutzer hat autonome Entscheidungen und Umsetzung freigegeben. Die vorige Runde war belegter Fortschritt; neue Regeln werden nicht als schon ausgeliefert behandelt.

## Zweck und Entscheidung

Werkstattüberschüsse erhalten einen friedlichen Absatzmarkt. Ein Haus entscheidet zwischen Gold durch Verkauf und eigener zukünftiger Entwicklung; ein Käufer zwischen schnellerer Baustoffversorgung und Aufbau einer eigenen Produktionsquelle. Forschung, örtliche Baustellen und das vorhandene eigene Straßennetz bleiben wirksam. Drei geprüfte Alternativen waren Lieferverträge, Forschungsimpulse und Feldzugsaufträge. Handel ist zuerst gewählt, weil damit ein neuer ziviler Wirtschaftszweig entsteht. Forschungsimpulse, weiterführende Forschung, Reichsziele und echtes Nahrungssystem sind weiterhin offene Teile des Gesamtziels.

Baustoffe werden nicht als Nahrung umbenannt. Moderne Atlasbevölkerung bleibt reine Kartografie. Es gibt keine neue globale Verwaltungsseite. Fremde Provinzen bleiben ohne eigene Bau-/Forschungsverwaltung.

## Vertrag und Preise

Zwei verschiedene Häuser handeln ausschließlich über zwei direkt landbenachbarte, gegenwärtig von den Vertragsparteien kontrollierte Regionen. Keine See-/Fernroute wird vorgetäuscht. Ausgangsregion `from` gehört dem Verkäufer, Zielregion `to` dem Käufer. Eroberung oder eine tatsächlich feindliche militärische Stellung unterbricht die Beziehung; ein bloßer Anspruch allein ist noch kein Handelskrieg.

Die feste Chargenmenge ist `max(1, RegionalProduction.edge_weight_u(source,target))`. Der ganzzahlige Preis ist `max(1, ceil(2*lot_u/UNIT))` Gold je vollständiger Charge. Preis und Menge werden bei Angebot festgehalten und gegen diese unveränderte Formel validiert. Kleinere Regionen erhalten kleinere Chargen. Auftragsbeginn erzeugt weder Gold noch Material und zieht auch keine Vorauszahlung ab.

Ein Vertrag erlaubt höchstens drei vollständige Chargen, höchstens eine je Monatswechsel. Angebotsmonat C, Ablaufmonat C+6 einschließlich: erste Lieferung frühestens nach dem Annahmemonat, letzte spätestens im Ablaufmonat. Ohne vollständige Menge, Lagerraum oder Bezahlung gibt es in diesem Monat keine Teilbuchung. Nach drei Lieferungen oder Ablauf endet der Vertrag. Beide Parteien können zukünftige Lieferungen jederzeit beenden; bereits bezahlte Ware wird nicht zurückgebucht. Keine Schulden oder Rückerstattungsfiktion.

Maximal zwei aktive Verträge je Haus; höchstens ein offenes selbst vorgeschlagenes Angebot je Haus und ein Vertrag für dieselbe gerichtete Regionsbeziehung. Weltweit höchstens64 gespeicherte Verträge. Diese Grenze schützt auch konkurrierende LAN-Befehle. Offene Angebote verbrauchen keinen aktiven Platz des Empfängers. Annahme prüft alle Grenzen erneut.

Der Vorschlagende ist eine Vertragspartei; die andere Partei nimmt an. Gegen NPCs wird die Zustimmung nur bei einer aktuell lieferbaren ersten Charge, finanzierbarem Käufer und realem Baustoffbedarf des NPC-Käufers erteilt. NPCs behalten mindestens ihre vorhandene militärische/Marine-Geldreserve. Menschen dürfen eigene Mittel bewusst einsetzen. NPCs schließen automatisch ausschließlich untereinander Verträge; menschliche Güter oder Kassen werden niemals automatisch verplant.

## Monatsphase und Erhaltung

Die Handelsphase liegt nach der vorhandenen Jahresabrechnung und vor der örtlichen Produktions-/Arbeitsphase. Es werden ausschließlich schon vorhandene Bestände betrachtet. Neu angenommene Verträge liefern im Annahmemonat nicht. Eingetroffene Ware kann in der folgenden Arbeitsphase dieses Monats eingesetzt werden; sie wird nicht nochmals innerhalb derselben Handelsplanung weiterverkauft.

Jede Quelle schützt `2*weight_u` Reserve plus den bestehenden gemeinsam berechneten Bedarf ihres nächsten Arbeitsmonats. Zusätzlich wird ein unverändernder eigener Transportplan aus den bisherigen Straßen und Beständen berechnet; dessen vorgesehene ausgehende Eigenlieferungen werden ebenfalls vor Fremdhandel reserviert. Erst der verbleibende Überschuss ist handelbar. Die danach unveränderte örtliche Produktion und eigene Transportphase benutzen die tatsächlich verbleibenden Bestände.

`MaterialTrade.plan` ist rein. Alle Verträge werden anhand ursprünglicher Bestände, Anfangsgelder, freier Lagerplätze, Blockaden und Parteienlage geplant. Geld aus Verkäufen und eingetroffene Ware dürfen weitere Käufe beziehungsweise Verkäufe erst im nächsten Monat finanzieren. Geteilte Anfangsbudgets verhindern Überbuchung. Gleichberechtigte Verträge rotieren deterministisch nach Monat und sortierter ID. Vollständige Übergabe und Bezahlung sind atomar:

`source_stock -= lot_u; target_stock += lot_u; buyer_gold -= lot_gold; seller_gold += lot_gold`.

Neben Regions-IDs unterstützt die ausschließlich für Handel übergebene Blockademap den Schlüssel `trade:<id>` mit konkretem Grund. Damit pausiert ein NPC-Vertrag bei entfallener aktueller Baustellennachfrage, ohne einen anderen Vertrag desselben Hauses zu sperren. Historisch korrekte abgelaufene oder inzwischen anders besessene Verträge bleiben roh validierbar. Die reine Planung entfernt sie ohne Buchung; eine erfolgreiche Annahme bereinigt solche Altverträge vor der neuen Aktivierung. Abgewiesene Annahmen bleiben vollständig unverändert.

Jede Übertragung erhält Quelle, Ziel, Vertrag, Menge und Preis als Beleg. Über alle Parteien bleiben Gold und Material exakt erhalten; keine negativen Bestände, keine Lagerüberschreitung. Eigene Produktionsledger starten nach dieser ausdrücklich vorgelagerten Handelsphase. Handels- und Produktionsphasen dürfen nicht als eine einzige unbelegte Ledgergleichung ausgegeben werden.

## Exakter Speichervertrag

Schema18 ergänzt globale Felder `material_trades: Array` und `trade_serial: int`. Alte Schema17-Stände erhalten ausschließlich `[]` und0; kein Auftrag, Geld, Material oder nachträglicher Fortschritt entsteht. Historische Forschung, Produktion, Straßen, Spielerkontexte und Originalbackups bleiben erhalten.

Jeder Vertrag besitzt genau diese Felder:

```
{id, seller, buyer, from, to, proposer, lot_u, lot_gold,
 created_month, expires_month, accepted_month, last_delivery_month,
 delivered_lots, status}
```

`status` ist `offered` oder `active`; `accepted_month=-1`, `last_delivery_month=-1`, `delivered_lots=0` bei Angebot. Aktiv gilt `created_month <= accepted_month <= now`; Lieferungen nur bei `last_delivery_month > accepted_month` und spätestens `min(now,expires_month)`. `delivered_lots` liegt0..2 in gespeicherten aktiven Verträgen; die dritte Lieferung entfernt den Vertrag. Keine Lieferung hat Datum vor Erstellung. IDs sind eindeutig1..trade_serial, Serial0..1e9; Hausindizes gültig und verschieden; Proposer ist eine der beiden Parteien. Regionen existieren, sind verschieden und landbenachbart. Ursprüngliche Parteien bleiben gespeichert; ein inzwischen geänderter Besitzer darf keine Lieferung auslösen. Veraltete Besitzzuordnung wird bei Prüfung/Ausführung geschlossen, nicht in fremden Besitz umgedeutet.

Strikte rohe Validierung vor Normalisierung: keine Booleschen Zahlen, NaN, Bruchteile, unbekannte Felder/Status, Duplikate, gefälschte Preise/Mengen oder zukünftige Zeitwerte. Endliche ganze JSON-Zahlen dürfen anschließend kanonisch in Integer überführt werden. Gegenwärtige eigene Güter werden beim Restore nicht zur Bestätigung eines ungültigen Vertrags verändert.

## Modulgrenzen und APIs

`scripts/MaterialTrade.gd` besitzt reine Regeln:

- `quote(source: Dictionary, target: Dictionary) -> Dictionary` liefert `{lot_u,lot_gold}`.
- `validate(contracts: Variant, serial: Variant, provinces: Array, houses: Array, adjacency: Dictionary, now: int) -> Array` liefert Fehler, ohne Änderung.
- `plan(provinces: Array, contracts: Array, offers: Dictionary, funds: Dictionary, month_index: int, blocked: Dictionary, hostile_pairs: Dictionary, adjacency: Dictionary) -> Dictionary` liefert `{stock_deltas,gold_deltas,deliveries,contracts,statuses}`. `contracts` enthält die neuen verbleibenden Vertragskopien; `statuses` ordnet IDs deutschen Gründen zu. Parteischlüssel für Feindschaft sind `minHouse|maxHouse`. Fundsschlüssel sind Hausindizes als Strings; Angebotsmengen Regions-IDs als Strings.

Game besitzt allein die Mutation und integriert:

- `material_trade_preview(from_id: String,to_id: String,house_index: int=-1) -> Dictionary` mit Preis/Menge, aktiven Regeln, Gegenpartei und Grund.
- `offer_material_trade(from_id: String,to_id: String,house_index: int=-1) -> Dictionary`.
- `accept_material_trade(id: int,house_index: int=-1) -> Dictionary`.
- `cancel_material_trade(id: int,house_index: int=-1) -> Dictionary`.
- `material_trade_options(region_id: String,house_index: int=-1) -> Array` für vorhandene relevante Vorschläge, Verträge und neue Grenzoptionen.
- `_tick_material_trade()` vor der Produktionsphase; `_run_ai_trade()` nach der Produktion, nur für NPC-Parteien.

Neue UiKernel-Absichten `material_trade_offer {from,to}`, `material_trade_accept {trade}`, `material_trade_cancel {trade}`. Haus, Preis, Menge, Laufzeit und Geldstände kommen ausschließlich vom Hostmodell. Abgewiesene oder wiederholte Absichten verändern weder Spielwelt noch Logbuch. Ein alter Provinzcallback darf keine fremde Verwaltung oder ein neues unbestätigtes Handelsziel auslösen.

`SaveGame` besitzt Migration, rohe Validierung und kanonische Zahlen. `LanSession/LanProtocol` nehmen Regeln und erlaubte Befehle in den Fingerprint auf, übertragen den autoritativen Vertragszustand und erhalten die echte frühere Schema17-LAN-Datei. Alte Fingerprints bleiben ausschließlich für nachgewiesene historische Dateien zulässig, nicht für neue Verbindungen.

## Oberfläche und NPCs

Ein kleines `MaterialTradePanel` wird in den bestehenden Provinzinspektor eingebettet. Es erscheint nur bei wirklichen Grenzoptionen oder vorhandenen Verträgen. Preis, vollständige Chargenmenge, Richtung, Laufzeit, Lieferstand und aktueller Sperrgrund werden einmal gezeigt. Bestätigen/Annehmen/Beenden verwenden dieselben Begriffe. Human-Human-Angebote benötigen sichtbar die Gegenbestätigung. Keine eigene Forschungs-/Bauseite in Fremdland.

NPC-Käufe verlangen einen echten Projektfehlbedarf mindestens einer Charge, ausreichend verfügbares Geld nach Militärreserve und erreichbare Verkäuferüberschüsse. Der rein lesende Kandidatenvergleich verwendet dieselbe Vorschau und Regeln wie der Mensch, stabile Reihenfolge bei Gleichstand und höchstens ein neues Angebot je NPC und Monat. Ohne Nachfrage oder beiderseitigen Nutzen entsteht kein Vertrag.

## Belege und Auslieferung

TDD: volle/fehlende Lieferung, Reserven, drei konkurrierende Verträge, Raum-/Goldgrenzen, Rotation, keine Weiterverkaufs-/Neufinanzierungsschleife, Ablauf/Annahmezeiten, Blockade/Feindschaft/Besitzwechsel, extreme/rohe ungültige Eingaben. Danach reale Game-Befehle, negative unveränderte Snapshots/Logs, strikte Migration17→18 und echte LAN-Akteurgrenzen.

Normalkampagne ohne Debugmittel: Werkstattschwerpunkt mit vorhandener Staatskasse, tatsächlich erzeugter Überschuss, NPC-Baustelle/Nachfrage, Vertragsabschluss, erste bezahlte Lieferung, reales Gold des Verkäufers und Material des Käufers sowie spätere Verwendung/Fertigstellung. Gegenprobe ohne Vertrag bewahrt Material/Geld und baut anders schnell. NPCs handeln untereinander nach identischen Grenzen. Mehrere Start-Häuser einschließlich kleinem/custom Haus prüfen.

Abschluss umfasst relevante Regression, reproduzierbare neue Pakete mit Version1.9.1/Code22/Schema18 und neuem Suffix `trade`, vollständige eingebettete Ressourcen, Signatur/Byteparität sowie tatsächliche EXE-/Touchprüfung. Frühere Pakete werden nicht überschrieben. Das Telefon und Standard-ADB bleiben frei; sichtbare Windows nur auf DISPLAY3(1960,40). Kein unbewiesener FPS-/Poco-/Android-WLAN-Nachweis. Der Gesamtauftrag bleibt bis zu wesentlich umfassenderer Spielspaß-/4200-Jahre-/Balanceabnahme offen.
