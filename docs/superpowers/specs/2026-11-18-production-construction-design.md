# Banger Queens · Produktion, Bauvorhaben und Frontversorgung

Stand: 18. November 2026, Ausgangspunkt `9588de14ecebd2119a64fbb0c0413f7b8b7b9454`. Die letzte UI-Lieferung ist abgeschlossen. Dieser Architekturabschnitt wird innerhalb der ausdrücklich übertragenen autonomen Entscheidungsbefugnis umgesetzt. Er erfüllt einen weiteren Teil des umfassenden Spielspaßziels; die Gesamtanforderungen des Banger-Queens-Entwurfs bleiben bestehen.

## Entscheidung und Spielgewinn

Eine zusammenhängende Strecke verbindet örtliche Baustoffproduktion, konkurrierende Bauarbeit, wirkliche Straßenlieferungen und ein durch Forschung freigeschaltetes Frontdepot. Der Spieler entscheidet über Standort, Schwerpunkt und Vorrang. Arbeiter und Lieferungen werden automatisch zugeordnet. Die gesamte Bedienung bleibt im bestehenden Ausbau-Reiter, mit hausweiter Forschung über den vorhandenen Plan.

Verglichen wurden drei Ansätze: reine Bauzeit benötigt wenig Eingriff, erzeugt aber nur schwache neue Entscheidungen; ausschließlich weitere Forschungsboni erweitern die vorhandene Zahlenentwicklung; eine finite Produktions-/Baukette erzeugt Standort-, Zeit-, Geld- und Versorgungsentscheidungen. Gewählt ist die vollständige Kette. Weitere Waren, Rezepte, Fuhrparkverwaltung und neue Hauptmenüs gehören nicht zu diesem Abschnitt.

## Verbindliche Zustände

Alle bestehenden 108 Regionen, Häuser und ihre Kapazitätsanteile bleiben erhalten. `economic_share` reicht tatsächlich von ungefähr 0,0006303 bis 3,76479. Neue Mengen verwenden deshalb Mikroeinheiten: `UNIT=1_000_000`, `weight_u=round(economic_share*UNIT)`, mindestens ein Mikroquantum, niemals ein ganzer Mindestbaustoff pro Region. Bei fehlendem Legacy-Gewicht gilt wie bisher Gewicht eins.

Jede Provinz erhält genau:

```text
production = {materials_u:int>=0, rate_carry:int[0,31]}
regional_project = {} oder Projekt
logistics_sites = {depot:int[0,1]}
```

Das Spiel erhält den monotonen `project_serial:int>=0`. Jeder angenommene neue Regional- oder Straßenauftrag erhält die nächste global eindeutige ID. Fehlgeschlagene Aktionen erhöhen ihn nicht. IDs werden nach Abbruch nicht wiederverwendet.

```text
Projekt = {id,builder,kind,target_level,paid_gold,
 material_total_u,material_spent_u,work_total_u,work_done_u,
 priority,started_month}
kind = market | barracks | walls | develop | depot
priority = 0 | 1
```

Je Provinz besteht höchstens ein Regionalprojekt. Anliegende Straßen dürfen gleichzeitig im Bau sein und teilen dieselbe örtliche Arbeit. Eine neue Straße behält ihre bisherigen Felder `from,to,builder,months,state` und erhält:

```text
construction = {id,paid_gold,priority,started_month,legs:[Bein,Bein]}
Bein = {province,material_total_u,material_spent_u,work_total_u,work_done_u}
```

Fertige Straßen besitzen `construction={}`. Historische angefangene Straßen besitzen `construction={}` und `legacy_construction=true`; sie behalten ihre bereits bezahlten Kosten, Restmonate und bisherige Besitzpause. Diese dokumentierte Ausnahme erzeugt keine neuen Baustoffe. Ihre aktiven Endpunkte reservieren bis zum Abschluss die örtliche Arbeit. Neu angenommene Straßen verwenden ausschließlich die neue Rechnung.

Neue Spiele und migrierte alte Regionen starten mit null Baustoffen und ohne Depot oder neuen Auftrag. Perspektivwechsel, neuer menschlicher LAN-Sitz und wiederholtes Laden schenken keine Ausstattung.

## Produktion und gemeinsame Arbeit

Monatsarbeit ist `C=2*weight_u`, Lagerkapazität `12*weight_u`. Freie Arbeit produziert Baustoffe. Ausgewogen, Kornkammer und Handelsort liefern normalerweise `8/32` Materialquanten je Arbeitsquantum; Wald/Hügel liefern `10/32`. Werkstätten liefern `32/32`, in Wald/Hügeln `40/32`. Der Rest modulo 32 wird gespeichert. Gelände ist damit ein Standortvorteil, keine kostenlose Ressource. Am Lagerlimit wird ungenutzte Produktion als Überlauf ausgewiesen, nicht als später abrufbare Schuld gespeichert.

Der vierte Schwerpunkt `workshops` heißt Werkstätten. Er verwendet die bisherigen Wechselkosten und zwölf Monate Bindung. Einkommen wird mit 0,80 und örtliche Versorgung mit 0,75 multipliziert. Die bisherigen drei Schwerpunktwirkungen bleiben erhalten.

Ein Projekt muss beim Start genügend Gold, aber noch nicht alle Baustoffe besitzen. Gold wird einmal abgezogen; Stufe, Entwicklung, Aufgebot und Verteidigung ändern sich erst bei Fertigstellung. Unter einer fremden Belagerung oder einer kampffähigen fremden Feldarmee ruhen Arbeit und Produktion. Der vorhandene Vorrat wird dadurch nicht gelöscht.

| Ziel | Gold | Material gesamt | Arbeit gesamt |
|---|---|---|---|
| Markt auf Stufe l=1..3 | bisheriger Gebäudegrundpreis/Rabatt | `(2+4*l)*weight_u` | `(2+2*l)*weight_u` |
| Kaserne auf l=1..3 | bisheriger Preis/Rabatt | `(4+4*l)*weight_u` | `(3+2*l)*weight_u` |
| Mauern auf l=1..3 | bisheriger Preis/Rabatt | `(6+4*l)*weight_u` | `(4+2*l)*weight_u` |
| Entwicklung +1 | bisheriger gewichteter Preis/Rabatt | `(6+2*floor((dev-1)/3))*weight_u` | derselbe Wert |
| Depot 0→1 | `max(1,round(50*w))` | `8*weight_u` | `6*weight_u` |

Kosten, Zielstufe und Anforderungen werden beim Start eingefroren. Beim Fortschritt ist der kumulative Materialverbrauch `ceil(material_total_u*work_done_u/work_total_u)`. Ein Abschluss verbraucht exakt die Gesamtmenge und wird genau einmal angewendet. Die reine lokale Planung findet die größtmögliche zulässige Arbeit, während die verbleibende Arbeit die erforderlichen Baustoffe erzeugt. Dies vermeidet den Kreislauffehler, dass eine Baustelle ihre eigene Materialproduktion vollständig verhindert.

Aufgaben derselben Priorität teilen das örtliche Monatsbudget gleichmäßig; ganzzahlige Reste rotieren deterministisch mit Monat und stabiler Aufgabenkennung. Vorrangige Aufgaben erhalten zuerst Arbeit, aber keine zusätzliche Arbeit. Für jeden Monat gilt verbrauchte Bauarbeit plus Produktionsarbeit höchstens C. Baustoffbuchung: Anfang + Produktion + Import − Verbrauch − Export − Überlauf = Ende; alle Mengen bleiben nichtnegativ.

Abbruch benötigt gültige Provinz- und Projekt-ID. Es gibt kein Gold- oder Verbrauchsmaterial zurück; unbenutzte örtliche Vorräte bleiben vorhanden. Die Oberfläche erklärt dies vor der Bestätigung und bindet diese an Auftrag und aktuellen Kontext. Normaler Besitzerwechsel über `_capture_province` beendet betroffene neue Regional- und Straßenprojekte ohne Fertigeffekt; die örtlichen Vorräte und fertigen Anlagen verbleiben am Gebiet. Historische Straßenbaustellen behalten ihre dokumentierte alte Pause.

## Straßen und Materialtransport

Für Endgewichte a,b ist `edge_u=floor(2*a*b/(a+b))`. Neue Straßen kosten `max(1,round(30*edge_u/UNIT))` Gold; Gesamtmaterial und Gesamtarbeit sind jeweils `6*edge_u`, auf beide Enden mit deterministischem Rest aufgeteilt. Beide Endarbeiten müssen fertig werden. Die vorhandenen Monate sind nur die verbleibende reine Arbeitsdauer von höchstens drei Monaten, kein zweiter Fertigstellungstimer.

Fertige, eigene, unbestrittene Straßen haben gemeinsam `4*edge_u` Materialtransportkapazität pro Monat und Kante. Doppelte/gegengerichtete Straßen erhöhen diese Kapazität nicht. Eigene Kontrolle muss auf jedem Wegknoten bestehen; Seewege und fremde Zwischengebiete transportieren keine Baustoffe. Straßenhandelsertrag wird künftig mit `2*edge_u/UNIT` je Verbindung gewichtet und erst hausweit gerundet. Dies ist eine ausdrückliche Balanceänderung auch für alte fertige Straßen.

Automatische Nachfrage entsteht ausschließlich an tatsächlichen Baustellen. Sie ist auf Restbedarf, freien Lagerraum und den Bedarf der nächsten zwei theoretischen Arbeitsmonate begrenzt. Quellen behalten `2*weight_u` Reserve sowie den Bedarf ihrer nächsten Monatsaufgabe. Nur verbleibende echte Bestände dürfen exportiert werden. Innerhalb gleicher Priorität rotiert die Empfängerreihenfolge nach Monat und stabiler ID; Pfadsuche und Rundung sind deterministisch. Eine Lieferung reserviert die Restkapazität jeder Kante ihres kürzesten gültigen Weges. Die gleiche Einheit wird im selben Monat nicht weiterexportiert.

Tickfolge: kontrollierte Wege zu Monatsbeginn einfrieren; örtliche Produktion/Arbeit planen und buchen; begrenzte Lieferungen buchen; fertige Effekte anwenden. Eingetroffene Baustoffe und neue Straßen wirken erst im nächsten Arbeitsmonat. Die vorhandene Jahresabrechnung bleibt zeitlich vor diesem Abschnitt; im Januar fertiggestellte neue Gebäude verdienen erstmals bei der nächsten Jahresabrechnung. Kein Frame-Timer erzeugt Material oder Arbeit.

## Forschung und Frontdepot

Die drei frühen Zeiten werden für frühere Nutzbarkeit auf Vermessung vier, Straßenbau sechs und Versorgungswesen sechs Monate gesetzt; Goldpreise und Voraussetzungen bleiben erhalten. Die übrigen Forschungszeiten bleiben gleich. Versorgungswesen behält seinen bisherigen 20-Prozent-Versorgungsbonus und schaltet zusätzlich das örtliche Depot frei. Der neue Bau hat genau eine Stufe und wird in `logistics_sites.depot` gespeichert, getrennt von den drei alten Gebäudelinien.

Ein Depot erzeugt keine Nahrung. Nach der vorhandenen Versorgung eigener Regionen kann es verbleibenden tatsächlichen Landwirtschaftsüberschuss aus seinem eigenen verbundenen Straßennetz an eigene Feldheere in unmittelbar landbenachbartem fremdem Gebiet liefern. Pro Depot gilt höchstens `floor(300*weight_u/UNIT)` Mann Durchsatz. Empfänger sind keine Transitknoten. Zwei Depots, mehrere Armeen und mehrere Quellen dürfen denselben Überschuss nicht vervielfachen. Eine fremde Belagerung, kampffähige fremde Armee oder ein unterbrochener Weg sperrt den betroffenen Pfad. Ein Depot in London beliefert keine Armee in Gallien.

Der Bericht erhöht reale Importsummen und senkt reale Fehlbedarfe. Dadurch verändert sich die bereits vorhandene Versorgungsbewertung von Belagerung und jährlichen Verlusten. Es wird kein paralleler abstrakter Kampfbonus hinzugefügt.

## Integration, Automatik und Bedienung

`Game` bleibt einziger Mutationsbesitzer. Kleine reine Module besitzen örtliche Planung, Transport und Depotverteilung. Bestehende `build`, `develop`, `build_road` starten die neuen Aufträge; Rekrutierung bleibt unverändert. Eine reine Wirtschafts-KI wählt höchstens einen bezahlten Auftrag je nichtmenschlichem Haus und Monat. Sie verwendet dieselben Vorschauen, Kosten und Befehle, berücksichtigt Marinereserven und Kriegsvorbereitung und verfolgt Quellen, Forschungsfreischaltung, Wege und einen nutzbaren Zielbau. Sie erhält kein Material oder Gold geschenkt.

Ausbau zeigt kompakt Bestand/Lageranteil, Erzeugung, laufenden Auftrag und dessen echte Arbeit/Materialfortschritte. Angeforderte Lieferungen, Vorrang und Abbruch sind dort erreichbar. Örtliche Straßen wandern aus dem Forschungsdialog in diesen Bereich. Fremde Regionen erhalten keine eigenen Verwaltungsaktionen. Fertige Gebäude und aktive Schwerpunkte behalten die gerade ausgelieferte kompakte Darstellung.

Karte und Atlas zeigen reale Baustellen in Übersicht und ab Zoom 2,5. Marker reservieren Kollisionsflächen; vorhandene Heeres-Trefferflächen, Flotten und Belagerungen bleiben bedienbar. Netz- und Projektberichte werden bei Spielaktualisierung berechnet und an die Karte übergeben; Schwenken berechnet keine Produktion oder Netze je Marker neu. Prozentwerte zeigen ausschließlich messbare Arbeits-/Materialanteile.

## Speicherung, LAN und Auslieferung

Schema 17 verlangt neue aktuelle Rohfelder ausdrücklich vor Defaulting. `SaveGame.migrate`, `Game.snapshot/restore` und `RegionMigration` erhalten die Zustände. Alte 49er-/108er-Stände erhalten auf ihren endgültigen Regionen null Bestände und leere Vorhaben; Material darf nicht in jeden Nachfolger kopiert werden. Eine Layoutkonvertierung bereits aktiver Schema-17-49er-Projekte wird ausdrücklich abgewiesen, statt sie still zu verlieren. Gleichbleibende Layouts erlauben normale Roundtrips.

Alle Mengen, IDs, Typen, Stufen, Verbrauchsrelationen, Besitzer, Endpunkte und Arrays sind begrenzt. Aktuelle beschädigte Pflichtfelder werden nicht als alte Stände behandelt. Höchstens ein Regionalprojekt pro Provinz und zwei Beine pro neuer Straße; keine unbeschränkte Produktionshistorie im Spielstand. Der entpackte LAN-Zustand bleibt unter zwei MiB.

Die echte freigegebene Schema-16-LAN-Datei mit SHA256 `2e2b8befa58ef22ec3547221af2b4a059d4b09df6264a028a012eb9aac563e40` und Fingerprint `dc8f13abb2f9b93c1aabfcf115f592df02c8af9ceb2b445127bdcefd22fd3903` wird bytegenau mit Provenienz als Fixture gesichert. Nur diese belegte alte Identitätsfamilie erhält lokale Migration und `.pre-production-schema16.bak`. Live-Handshakes bleiben streng. Fingerprintinhalt und Cacheidentität erfassen sämtliche neuen Regeln und Befehle.

Die Version bleibt 1.9.1, Android-Code wird 20, neue Dateinamen erhalten `-production`. Eine APK enthält alle eigenen Laufzeitdaten ohne Import und ohne Wine/Box64. Vorherige Dateien und Spielstände bleiben erhalten. Telefon und Standard-ADB bleiben frei; ausschließlich eigene isolierte Profile und der zugewiesene Emulator dürfen verwendet werden. Sichtbare Windowsläufe ausschließlich auf dem rechten physischen Monitor.

## Abnahme dieses Abschnitts

Erforderlich sind reine Belege für Quantisierung, gemeinsame Arbeit, FIFO-/Prioritätsfairness, konservierte Materialflüsse, Blockade/Wiederaufnahme, Lagerlimit und kleinste Region. Hinzu kommen echte Game-Kommandos mit einmaliger Zahlung/Fertigwirkung, verworfene Befehle ohne Zustandseffekt, Besitzerwechsel/Abbruch, Save-Migration/strenge negative Fälle und LAN-Autorität/Weltgleichheit.

Eine regulär finanzierte Unetice-/Sequana-Partie muss Produktion, konkurrierende nützliche Projekte, fertigen Weg, wirklichen Export und Zielabschluss erreichen. Ein bezahltes Depot muss einen echten Heeresfehlbedarf und die vorhandene Belagerungs-/Versorgungsfolge verändern. NPCs müssen dieselbe Investitionskette nachweisbar nutzen. Kontrollierte Sonderlagen werden von normalen Startbudgets getrennt gekennzeichnet. Wessex muss weiterhin seine tatsächlichen Marinekosten tragen.

Reale UI-Prüfungen umfassen eigene/fremde Auswahl, 100/200 Prozent Schrift, Touchflächen, Scrollen, laufende LAN-Bestätigung, veralteten Abbruch und Baustellen unter/über Zoom 2,5. Geänderte Karte benötigt vergleichbare echte Zeit-/Primitive-Messung; keine höhere Bildrate wird aus weniger Befehlen abgeleitet. Abschließend passende vollständige Regression, tatsächliche exportierte EXE, Paketparität/Signatur und gegebenenfalls eigener Android-Emulator. Keine dieser neuen Abnahmen ist durch den Entwurf schon erfüllt.
