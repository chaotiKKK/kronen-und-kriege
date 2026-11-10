# Befunde – verbleibende Atlasgebiete

## Gesicherter Ausgangsstand

- main ist bei Beginn sauber, veröffentlichter Rückfallstand v1.6.0, Commit 913914f34cafc89d57d8f7ef15fe3393dc3e8b9a.
- 139.759 echte Atlasobjekte; 52 Gebiete geometrisch complete, 10 source_review, 5 gap und 3 single_jurisdiction.
- Die offenen Gebiete sind AM, AZ, CNM, CY, CYN, ESB, IL, IR, JO, KZ, LB, LY, MA, TR und WSB.
- AM hat bereits 62 aktuelle kommunale Identitäten; Lake Sevan und eine grobe Landesreferenz sind bekannte Prüfpunkte.
- AZ hat 685 aktuelle Gemeinden nach der Reform 2024/25, aber nur wenige belegte OSM-Gemeindepolygone. Rayons sind keine Ersatzgemeinden.
- JO liefert im bisherigen OSM-Adminlayer überwiegend Liwa/Qadaa; eine kommunale Rolle ist damit nicht belegt.
- LY enthält im bisherigen Layer 23 alte Distrikte und keine verifizierten Baladiya-Grenzen.
- MA fehlt konkret Sidi Mohamed Benmansour, Gemeindecode 042810511.
- Zypern verwendet bisher datierte 2009er Quellflächen; 610 Geometrien gegenüber 612 deklarierten sowie die Reform 2024 müssen tatsächlich geklärt werden.

## Schutz der Aussagekraft

Ein Statuswechsel muss durch neue Geometrie, nachgewiesene korrekte Rolle, einen geklärten Quellfehler oder eine unabhängige bessere Landreferenz begründet sein. Die lokale Verwaltungsdetaillierung darf nicht durch großflächige höhere Ersatzebenen nur rechnerisch verbessert werden.

## Neue Quellenprüfung am 10. November

- AM: unabhängiges Binnenwasser schneidet 1.236,824 km² aus der bisherigen Lücke; eine vorläufige physische Landmessung ergibt 97,2181 %. Noch keine Produktionsfreigabe; Herkunft und gemeinsame Staatsgrenze sind getrennt zu prüfen.
- KZ: Binnenwasser erklärt die Lücke nicht. Große echte Lücken liegen in Құрманғазы (22.282 km²) und Мұнайлы (11.565 km²).
- IL: Der Kartenausschnitt nördlich 33° enthält nur einen kleinen Landesanteil; die fehlenden 95,281 km² liegen teilweise außerhalb vorhandener höherer Rahmen. Territorialreferenzen gesondert prüfen.
- AZ: Staatliches Gemeindedienstportal bestätigt 685 Gemeinden, davon 74 Stadt-, 98 Siedlungs- und 513 Dorfgemeinden: https://e-belediyye.gov.az/ . Die vollständigen Grenzpolygone liefert diese Statistik nicht.
- gbOpen API: JOR bietet nur ADM2 mit 52 Einheiten aus 2006; AZE ADM2 mit 79 Einheiten aus 2020; LBY nur ADM1 mit 22 alten Einheiten. Keine dieser Dateien belegt die gesuchten heutigen Kommunalpolygone.
- Öffentliche ArcGIS-Suche: „Municipalities_Jordan“ ist tatsächlich Allegheny County/Pennsylvania und ungeeignet. „Libya Municipalities“ von Esri_cy_LY enthält tatsächlich 22 Shabyaat-Polygone und ist ebenfalls kein aktueller Baladiya-Datensatz. Worldbank-AzRIP enthält Projektpunkte, keine Gemeindegrenzen. Die identifizierten Ipsos-Libya- und USAID-Jordan-Accounts melden deaktivierte Subskriptionen (403); keine Umgehung versucht.
- Suchbelege und vollständige API-Antworten: .tools/atlas_sources/audit/remaining-20261110/ .
- Vollständige datierte OSM-PBF-Dateien zusätzlich geprüft: AZ 46.800.965 Bytes, JO 31.140.246 Bytes, LY 76.737.553 Bytes. Kein vollständiger Kommunalsatz unter verstecktem `boundary=municipality` gefunden; LY enthält dort drei tunesische Nachbarobjekte. Originale Relations-/Way-Tags werden getrennt protokolliert.
- AZ: Die acht bisher übernommenen Admin8-Kandidaten belegen keine gesicherte Gemeindefläche. Sechs nennen ausdrücklich Stadtbezirke, Sumqayıt identifiziert einen Stadtumriss ohne Flächengleichheitsbeleg, ein grenznaher Dorfdatensatz hat keine gesicherte staatliche/kommunale Identität. Die amtliche Gəncə-Seite bestätigt zudem, dass die Gemeinde Kəpəz gerade nicht den gesamten gleichnamigen alten Bezirk umfasst (Hacıkənd ausgeschlossen): https://ganja-ih.gov.az/az/belediyyeler.html . Originaldaten bleiben erhalten; acht konkrete Quarantänen sind vorbereitet.
- JO: Im tatsächlich dargestellten Ausschnitt nördlich 33° liegt im bisherigen SHP nur Rwaished Sub-District. Das Innenministerium führt Ruwaished als Liwa, und RSCN beschreibt die nahe Borku-Reserve ausdrücklich außerhalb von Gemeindegrenzen. Diese Wüstenfläche darf nicht zu einer erfundenen flächendeckenden Gemeinde werden: https://www.rscn.org.jo/public/reserve/5 .
- AM: Die konservative produktive Referenz lässt die NE-Staatszuordnung vollständig unverändert und entfernt ausschließlich separat kartiertes physisches Wasser. Ergebnis97,340036%;62 rechtlich qualifizierte Kommunalidentitäten unverändert. Die detaillierte OSM-Staatsrahmenalternative wird wegen veränderter Nachbarzuordnungen ausdrücklich nicht integriert. IL bleibt mit derselben konservativen Methode92,696891% und offen.
- CY: Amtliche DLS-Flächen und eindeutige CYSTAT2026-Zuordnung ergeben20 Reformgemeinden,91 kommunale Quartiere und511 territorialeCommunity-Flächen; keine Gleichsetzung mit511 Räten. CY98,9917437% undWSB96,3751010% sind fachlich freigegeben. ESB94,5011144% bleibt echte geometrische Lücke; CNM99,8411862% bleibt territorialer Rollenprüfungsvorbehalt. Norden CYN wird vom neuen Provider nicht als laufende republikanischeGemeindeverwaltung beansprucht.
- LY: Der zusätzlich tatsächlich heruntergeladene HDX-Admin3-Originaldatensatz ist ein Punkt-Shapefile mit100Punkten, kein kommunaler Flächensatz. WOF liefert22alteRegionen und nur2Locality-Polygone. AZ-WOF liefert78Regionen,1County,1Locality-Polygon und5.022Orts-Punkte; kein fehlender685-Gemeindesatz. Diese Routen wurden nicht als kommunale Vollabdeckung importiert.
- MA: Originaldruck BO 6964 vom 25. Februar 2021 ist über den öffentlich verlinkten Rechtsbibliothek-Spiegel gesichert (6.224.985 Bytes). Druckseiten1450–1453 enthalten die beiden Innenministerentscheidungen1635.20 und1636.20 mit25bzw.19Lambert-Grenzpunkten für Ben Mansour und Sidi Mohamed Benmansour. Alle19Sidi-Punkte wurden am Seitenbild gegengeprüft. Vier ausdrückliche Sidi-Verlaufsausnahmen: Fekroun2–3, RP4201-Straßenachse12–13, Sebou14–15, Atlantikküste19–1. Ben-Mansours gemeinsame Punktfolge ist umgekehrt gleich, nennt aber dieStraßenausnahme nicht ausdrücklich: keine stillschweigende Rechtsauslegung.
- MA-Geometrieprüfung: Merchich/Nord-Maroc(EPSG26191) passt unabhängig zu Original-OSM-RP4201 auf0,9–4,2m und CanalBoufakroune auf3,8–5,7m. Die jetzige Sebou-Achse weicht an legalen Anschlusspunkten63/109m ab, Küste15/39m. Die vorhandene OSM-Ben-Mansour-Fläche enthält den geradlinigen Sidi-Testzug zu96,8%; eine neue Sidi-Fläche darf deshalb nicht einfach darübergelegt werden. Beide gesetzliche Umrisse und alle ausdrücklich nichtgeraden Verläufe werden gesondert rekonstruiert; noch keine produktive MA-Freigabe.
- IR: Originaler 2021er Producer-SHP-Satz hat2815Records, derRelease2772. Sechs exakt doppelte Paare und überlagerteStadtflächen sind nachgewiesen; dieGesamtunion ist fastidentisch. Die43Differenz beweist keine43fehlendenFlächen. 2514Namen sind bereits imRaw-DBF beschädigt; gemischte Stadt-/Dehestanrollen lassen keine pauschale Municipality-Zuordnung zu. Der aktuelle Geofabrik-Snapshot ist selektiv gesichert und enthält2731positiv alsDehestan benannte Kandidaten; neuer getrennterProvider inArbeit.
