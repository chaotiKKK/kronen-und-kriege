# Zivile Vorräte, Rationen und Zufriedenheit

## Ziel und Freigabe

Die nächste Stronghold-/Civ-Spielschleife verbindet echte Nahrung, örtliche Arbeit, Ausbau, Abgaben und Kriegsrisiko. Der Nutzer hat autonome Entwurfs- und Umsetzungsentscheidungen ausdrücklich freigegeben. Die vorherige Lieferung53050c0/Trade22 ist abgeschlossen; diese neue Architektur wird vor Code festgelegt. Der Gesamtauftrag Spielspaß/4200Jahre/AAA bleibt größer als dieser Abschnitt.

## Konkrete Entscheidungen

Eine Region kann ihre verfügbare Arbeit für Ernährung oder für vorhandene Baustoffproduktion und Bau einsetzen. Knappere Rationen verringern den Bedarf, verursachen aber Unzufriedenheit. Großzügige Rationen kosten25% mehr und verbessern die Zufriedenheit; hohe Abgaben wirken dagegen. Eine Kornkammer füllt eine größere Reserve und produziert effizienter Nahrung, während ihre bestehenden Gold-/Militärkosten gelten. Krieg unterbricht Produktion; tatsächlich gespeicherte Vorräte überbrücken den Ausfall.

Der erste vollständige Kreislauf ist lokal. Bestehende Soldatenkapazität bleibt eine eigenständige militärische Größe, die nicht als Nahrung ausgegeben wird. Nahrungsfracht und Heerrationen sind eine anschließende eigene Logistikstrecke mit gemeinsamem Frachtbudget; in dieser Fassung wird keine zusätzliche Straßenkapazität behauptet oder doppelt genutzt.

## Gewicht, Zustand und Zahlen

Alle Mengen sind Festkommaquanten mit UNIT=1000000 und MAX_UNITS=1000000000000. Ausschließlich Production.weight_u(p) liefert das kanonische Gewicht w; weder Anzahl der Teilgebiete, heutige Atlasbevölkerung noch Aufgebote bestimmen Bedarf. Ein normaler ziviler Monatsbedarf ist N=w. Die vorhandene Basisarbeit ist C=2w.

Jede Provinz erhält provisioning mit exakt diesen Feldern:

```
{food_u, harvest_carry, ration_carry, satisfaction, rations, changed_month}
```

food_u ist0..MAX_UNITS; harvest_carry0..9999; ration_carry0..99; satisfaction0..100; rations einer von scarce/normal/generous; changed_month=-1 oder0..heutigerMonat. Rohe Boolzahlen, Brüche, NaN, Zusatzfelder und unbekannte Rationen sind ungültig. Endliche ganze JSON-Zahlen dürfen erst nach Rohvalidierung kanonisiert werden.

Neues Spiel und Migration vor19 beginnen einheitlich mit3N Nahrung, beiden Resten0, Zufriedenheit50, normalen Rationen und changed_month=-1. Das ist ausdrücklich die Initialisierung einer neuen Ressource; kein historisch gemessener Vorrat. Gold, Baustoffe, Projekte, Forschungen, bestehende Handelsverträge, Alter und Besitz bleiben gleich. Es gibt keinen Ressourcenimport oder einen Geldumtausch dieser Anfangsreserve.

## Reiner Monatsplan

CivicProvision.plan(region, month_index, tax_level, bonuses={}, blocked=false) liefert ausschließlich einen neuen provisioning-Zustand und Ledger. Das Modul darf Production für w/C lesen; Production importiert CivicProvision nicht. Boni sind harvest_percent0..100 und storage_percent0..100; Game liefert tatsächliche Forschung.

Rationsbedarf ist floor((N*rate+ration_carry)/100), der neue Rest das Modulo100. Raten scarce75, normal100, generous125. Lagerkapazität ist6N, bei100% Lagerbonus12N. Geplanter Endreservewunsch ist3N; beim Fokus agriculture6N, begrenzt durch die aktuelle Kapazität. Vorübergehend über der neuen Kapazität befindliche echte Alt-/Eroberungsbestände bleiben roh ladbar und werden erst im nächsten Plan ausdrücklich als Überlauf gebucht.

Nahrungsmenge pro landwirtschaftlicher Arbeit: balanced2, agriculture3, trade1.6, workshops1.5. Der ganzzahlige Ertragszähler ist Fokuswert200/300/160/150 mal(100+harvest_percent), Nenner10000; harvest_carry wird einmal weitergetragen. Unterschiedliche Foki behalten ihre tatsächlichen bisherigen Gold-/Heeres-/Baustoffeffekte.

Arbeitsleistung vor der Planung beträgt floor(C*(80+floor(min(satisfaction,50)*2/5))/100), also80..100% von C. Landwirtschaft darf höchstens75% dieser Arbeit einsetzen. Gewünschte Erzeugung ist max(0, gewünschteEndreserve+angeforderteRation-Anfangsbestand); der Plan ermittelt die kleinste nötige ganzzahlige Arbeit bis zum landwirtschaftlichen Budget. Der vorhandene Restübertrag zählt bei dieser Suche mit. Eine ungestörte Region kann dadurch mit jedem Fokus normale Rationen decken; selbst bei Zufriedenheit0 bleiben mindestens1.2N Farmarbeit und damit1.8N Nahrung im schwächsten Fokus möglich.

Verbrauch ist min(angefordert, Anfang+Erzeugung). Fehlbedarf und Überlauf werden ausgewiesen, negative Bestände sind verboten. Erst nach Verbrauch wird auf Kapazität begrenzt. Die Bilanz lautet:

```
Ende = Anfang + erzeugt - verbraucht - Überlauf
```

Bei Produktionsblockade sind Farmarbeit und Industriearbeit0, Erzeugung0; vorhandener Vorrat wird trotzdem normal verbraucht. Kein Get-/Vorschau-/Frameaufruf bucht Mengen.

Wenn die angeforderte Ration voll gedeckt ist: scarce verändert Zufriedenheit um-1; normal bewegt sie um1 Richtung50; generous erhöht sie um2 bis75. Steuern0 addieren1, Steuern1 addieren0, Steuern2 subtrahieren2. Bei Fehlbedarf entfällt der positive Rationseffekt und zusätzlich fallen ceil(8*Fehlbedarf/angefordert), mindestens1 und höchstens8, an. Gesamtzufriedenheit bleibt0..100. Ohne Fehlbedarf kann Erholung durch normale Steuern und großzügige Rationen immer stattfinden.

Das verbleibende Industriebudget ist max(0,min(ArbeitsleistungVorher,ArbeitsleistungNachher)-Farmarbeit). Damit gilt auch nach einer Zufriedenheitsänderung: Farmarbeit+Bauarbeit+Baustoffarbeit höchstens das gemeinsame tatsächliche Arbeitsbudget. RegionalProduction.plan_local erhält dafür ein optionales available_labor_u=-1; -1 erhält den bisherigen reinen Basismodulvertrag, Game verwendet immer das echte Industriebudget. Es entsteht keine zweite volle Arbeitsmenge.

## Wirkungen und Forschung

Der Zufriedenheitsfaktor für regionale Grund-/Markteinnahmen sowie Aufgebotsauffüllung ist clamp(100+floor((satisfaction-50)*2/5),80,110)%. Grundbeiträge werden für das Haus ungerundet summiert und erst einmal gerundet, damit kleine Regionen keinen Rundungsbonus erhalten. Herrscher-/Vasallen-/Vermächtniserträge bleiben getrennte Quellen. Bestehende Steuerstufen wirken anschließend mit ihren tatsächlichen15%-Schritten. Zufriedenheit50 ist neutral.

Fruchtwechsel erhält zusätzlich harvest_percent10 auf seinem vorhandenen Geländefilter; Bewässerung zusätzlich8 auf ihrem Filter. Vorratslager erhält storage_percent100 neben dem bisherigen militärischen Bonus. Forschungskosten, Anforderungen und laufende historische Fristen bleiben erhalten. Grundsubsistenz hängt nicht von diesen Forschungen ab.

Das Ereignis GuteErnte darf künftig keine Nahrungseinlagerung behaupten, wenn sein Effekt Gold oder Aufgebote ist. Seine vorhandenen Effekte bleiben erhalten, der Text beschreibt eindeutig Ernteabgaben beziehungsweise Ausrüstung. Alte bereits gespeicherte Entscheidungen werden nicht rückwirkend umgeschrieben. Echte ortsgebundene Nahrungsereignisse bleiben eine anschließende Erweiterung dieses Mengenmodells.

## Game, Vorschau und KI

Game ist alleiniger Mutationsbesitzer. APIs:

- provision_preview(id:String,rations:String="",hi:int=-1)->Dictionary
- set_province_rations(id:String,rations:String,hi:int=-1)->Dictionary
- provision_report(hi:int=-1)->Dictionary
- _tick_provisioning()->void
- _run_ai_provisioning()->void
- _industry_budget(id:String,month_offset:int=1)->int

Eine Rationsentscheidung braucht gültige eigene Provinz, bekannte Ration und laufendes Spiel. Sie kostet kein Gold und verändert sofort nur die gewählte Politik/changed_month; Mengen und Zufriedenheit ändern sich erst beim nächsten Weltschritt. Wiederholung ist ein unveränderter Noop. Menschenhäuser werden niemals durch KI umgestellt.

Monatsfolge: bestehende Jahres-/Familien-/Marine-/Dynastie-/Forschungsphase, dann freie nichtmenschliche Rationspolitik, dann genau eine zivile Mengenabrechnung, dann bestehender Materialhandel/Regionalproduktion und bezahlte KI. Die alte Straßensnapshotregel bleibt erhalten. _provisioning_settled_month verhindert Doppelbuchung im selben Monat; Restore setzt die Phase auf den geladenen Monat ohne Nachverbrauch.

Alle Produktions-/Bau-/Materialhandelsbedarfs- und Eigenreservevorschauen benutzen dieselbe reine zivile Planung und das daraus verbleibende Arbeitsbudget. Tatsächliche Regionalproduktion verwendet den bereits gebuchten Budgetwert des aktuellen Monats und plant nicht versehentlich erneut aus dem Endbestand. Angezeigte Vorschauen gelten ausdrücklich bei unverändertem heutigen Stand; Forschung/Steuern/Blockaden dürfen am folgenden Monat anders sein.

Die Schwerpunktvorschau zeigt den bisher fehlenden positiven Baustoffvergleich: theoretischer Ausstoß mit verbleibender Produktionsarbeit sowie Ernährung/Arbeitsanteil, neben Gold und Heeresversorgung. Aktive Baustellen, Lager und Blockaden bleiben echte Begrenzungen; Potenzial wird nicht als garantierte Lieferung bezeichnet.

Nichtmenschliche Politik: Bei Blockade und weniger als2N Vorrat scarce, sonst bei Steuer2 oder Zufriedenheit<50 generous, sonst normal. Unter40 Zufriedenheit normalisiert die KI über den bestehenden Gesetzespfad Steuern auf1, bis Erholung möglich ist. Freie Politik ist von der bestehenden einen bezahlten Wirtschaftsabsicht je Monat getrennt. Kein NPC erhält Nahrung oder Gold geschenkt.

## Ledger, Save und LAN

CivicProvisionReport ist eine eigene begrenzte reine DTO-Grenze für maximal256 Regionen. Ein Bericht hat month_index und regions; leer hat month_index=-1 und regions={}. Jede Zeile enthält owner, before_u, produced_u, consumed_u, requested_u, shortfall_u, wasted_u, after_u, farm_work_u, industry_labor_u, total_labor_u, satisfaction_before, satisfaction_after, rations. Mengen sind ganzzahlig0..MAX_UNITS; Zufriedenheit0..100. owner muss ein gültiger historischer Hausindex sein. after_u muss dem aktuellen Provinzbestand entsprechen; satisfaction_after darf nach einer Politikänderung gleich bleiben, der letzte Rationswert darf historisch sein. Produktion und Arbeit erhalten überprüfbare globale gewichtete Obergrenzen; Bilanz, Fehlbedarf und Arbeitssumme sind verpflichtend. Es gibt keine Import-/Exportfelder, weil diese Fassung keinen Nahrungsverkehr bucht.

Schema19 ergänzt provisioning in allen Regionen und einen provisioning_report im Snapshot. Migration ergänzt einen leeren Bericht und nur die oben dokumentierten neuen Ressourcenfelder. Bericht und neue rohe Mengen werden vor Normalisierung geprüft. Bestehende Originaldateien/Backups bleiben bytegleich; das neue tatsächliche18-Original wird aus der unveränderten Trade22-EXE erzeugt und als Fixture mit Herkunft dokumentiert. Laufende Legacy-Forschung bleibt vollständig erhalten.

Neue UiKernel-/LAN-Absicht province_rations {rations}; Provinz kommt aus der autorisierten Auswahl, Haus aus der authentisierten Rolle. Clientmengen/Zufriedenheit sind verboten. Regeln von CivicProvision, Report und Game-Politik gehören in Inhaltsfingerprint und Cacheidentität. Eine echte Zwei-Menschen-Sitzung belegt gleiche Mengen/Hashes, klare Akteurgrenzen und genau einen gemeinsamen Verbrauch.

## Kompakte Oberfläche und Karte

CivicProvisionPanel erscheint ausschließlich im vorhandenen eigenen Ausbauabschnitt. Geschlossen zeigt es Vorrat in Monatsrationen und Zufriedenheit; eine kurze eigene Planansicht zeigt drei Rationen, tatsächliche Politik-/Steuerwirkung, Farm-/Industrieanteil und den begründeten nächsten Monatsstand. Anwenden erscheint nur bei einer anderen Politik. Gleiche Auswahl bleibt ohne unnötigen Button. Details enthalten die echte Monatsbilanz. In fremdem Land erscheinen keine eigenen Vorrats-/Rationsregler.

Vorhandene gemeinsame Thematisierung, mindestens44px Touchziele, Umbruch und Scrollzugang bei100/200% gelten. Ein neuer eigener Warnmarker verwendet nur vorhandene Kartendatenprojektion, wird nach tatsächlicher Simulation statt beim Schwenken berechnet und darf kein neues volles Kartenlayer oder zusätzliche dauerhafte Textkollision erzeugen. Wenn eine kompakte Warnung im vorhandenen Provinzbadge ausreicht, ist kein weiterer Marker nötig.

## Abnahme und Lieferung

Vor Produktcode jeweils fachlich richtiger Rotfall. Reine Mengen-/Rundungs-/Erhaltungsregeln; normale Subsistenz über alle Foki und kleinste/größte Gewichte; drei blockierte Monate/Erholung; Steuer-/Rationstausch mit echten Arbeitskosten; Vorschauzustandsreinheit und echte spätere Übereinstimmung; Abbruch/Besitzwechsel/Restore; NPC-Menschen-Grenze; Save18→19/alte Legacy-Fristen; autoritative ENet-Absichten und gleiche Welt.

Normale Kampagnen mit zwei festen Seeds, zwei Häusern und einem kleinen selbst gestalteten Einregionenhaus müssen ohne Debuggold/Bestandsinjektion funktionieren. Eine gepaarte Vergleichswelt muss zeigen, dass großzügige Rationen tatsächlich mehr Arbeit/Nahrung kosten und Zufriedenheit/Ertrag verbessern; echte Blockade muss einen endlichen Vorrat aufbrauchen und nach Entlastung aus eigener Arbeit regenerieren. Bestehende Handels-/Bau-/Feldzugnormalläufe werden gegen ihre tatsächlichen neuen Fristen bilanziert, nicht durch zusätzliche Geschenke passend gemacht.

Version1.9.1 bleibt; nächste private APK Code23, Schema19, neue Artefaktnamenprovisions. Alte Dateien/303 fremde Änderungen bleiben erhalten. Sourcefreeze, volle relevante Regression, unveränderte tatsächliche Exporttreiber, APK-Signatur/Byteparität, neue private Emulatorprüfung und hashgleiche Downloads/Quellpush gehören zur Abnahme. StandardADB/Telefon bleiben frei; sichtbare Windows ausschließlich rechterDISPLAY3. Keine ungemessene FPS- oder Poco-Leistungszusage.

## Verbindliche zusätzliche Schnittstellen

CivicProvision.gd besitzt RULES und statische Methoden initial_state(region:Dictionary)->Dictionary, state_errors(raw:Variant,month_index:int)->Array, need_u(region:Dictionary)->int, capacity_u(region:Dictionary,bonuses:Dictionary={})->int, work_percent(satisfaction:int)->int, income_percent(satisfaction:int)->int, ration_rate(id:String)->int und plan(region:Dictionary,month_index:int,tax_level:int,bonuses:Dictionary={},blocked:bool=false)->Dictionary. plan liefert {ok:true,reason:"",state:neuesProvisioning,ledger:Zeile} oder {ok:false,reason:deutscherFehler}; fehlender/ungültiger Zustand darf nicht still initialisiert werden. Nur explizite Initialisierung/Migration erzeugt Anfangsvorrat. Das Modul hängt von RegionalProduction ab; RegionalProduction kennt CivicProvision nicht.

CivicProvisionReport.gd besitzt RULES, empty()->Dictionary mit {month_index:-1,regions:{}} und validate(raw:Variant,state:Dictionary)->Dictionary gemäß bestehendem ProductionNetworkReport-Vertrag {ok,data,reason}. Nichtleere Reports umfassen exakt alle aktuellen Provinzen. Wenn ein gleichmonatiger production_report vorliegt, muss dessen work_u+production_work_u+legacy_work_u je Region höchstens dem gemeldeten industry_labor_u entsprechen. Ein leerer neuer Foodbericht darf bei frisch migrierten Altständen mit altem Produktionsbericht vorkommen; er behauptet keine rückwirkende Foodphase.

Game.provision_preview liefert {id,rations,current_rations,reason,ok,next,stock_months,capacity_months,satisfaction,tax_level,ration_rate,blocked_reason}; next ist die reine nächste Ledgerzeile. Keine eigene Vorschau in Fremdland. Game.province_economy_preview ergänzt current_industry_labor_u,projected_industry_labor_u,current_material_potential_u,projected_material_potential_u. Die positiven Materialpotenziale werden mit voller verbleibender Produktionsarbeit, nicht als garantierte Baustellen-/Lieferergebnisse bezeichnet.

CivicProvisionPanel wird in ProvinceInspector eingerichtet. setup(main:Node)->void und refresh(game,id:String)->void sind die äußeren Schnittstellen; Elternknoten ist der bestehende eigene Ausbau-VBox. Es sendet ausschließlich UiKernel-Absichten, keine Game-Direktmutation. Gleichmonatige Politik-/Auswahl-/Besitzerwechsel dürfen keine alten Callbacks zur falschen Provinz anwenden.
