# Atlas: Fortschritt bei den 15 zunächst offenen Gebieten

Stand: 10. November 2026. Dieser Bericht beschreibt die Quellen- und
Verwaltungsprüfung und den endgültigen Datenbuild. Die Gesamtprüfungen und
Paketnachweise stehen im [aktuellen Prüfbericht](atlas-progress.md).

Bei **sieben der 15 Gebiete** ist das begrenzte Prüfkriterium inzwischen
erfüllt. **Acht Gebiete bleiben offen.** Der gemeinsame Build bestätigt
Dekelia mit 95,597840 %. Die Fortschritte bestehen sowohl aus zusätzlichen echten
Verwaltungsflächen als auch aus der Entfernung falsch eingeordneter Altdaten
und der Korrektur unabhängiger Landreferenzen.

## Was hier als geklärt gilt

Der Atlas betrachtet ausschließlich das Rechteck **12° West bis 52° Ost und
33° bis 72° Nord**. Ein Wert bezieht sich deshalb auf die darin liegende
Referenzlandfläche eines Gebiets, nicht automatisch auf dessen gesamtes
Staatsgebiet. Jordanien und Israel sind besonders deutlich nur in kleinen
nördlichen Ausschnitten vertreten.

Das begrenzte Kriterium verlangt mindestens **95 % gemessene örtliche
Verwaltungsabdeckung** und einen hinreichend belegten tatsächlichen
Verwaltungstyp ohne fortbestehende Sperre der dafür verwendeten Quelle.
Örtliche Verwaltung kann je nach Land eine Gemeinde, eine andere lokale
Verwaltungseinheit oder eine ausdrücklich belegte staatliche örtliche
Zuständigkeit sein. Diese Rollen werden nicht pauschal zu Gemeinden erklärt.

„Geklärt“ bedeutet hier weder 100 % Abdeckung noch eine heutige nationale
Behördenvollzählung oder amtlich zertifizierte Grenzgenauigkeit. Es ist auch
keine Aussage über die grafische Qualität oder die vollständige Spielabnahme.
Die **49 Simulationsgebiete bleiben unverändert**. Die reale
Verwaltungsunterteilung wird damit nicht künstlich auf gleiche Gemeindezahlen
oder gleich große Flächen gebracht.

## Vorher und nachher

Die Vorher-Werte wurden selektiv aus `HEAD:data/atlas.json` des Commits
`913914f34cafc89d57d8f7ef15fe3393dc3e8b9a` gelesen. Die Nachher-Werte stammen
aus dem endgültigen gemeinsamen Atlasbuild mit 139.571 Objekten. Alle
22 eingefrorenen Eingabereceipts blieben während dieses Builds unverändert. Die Nachkommastellen beschreiben
das rechnerische Prüfergebnis, keine entsprechende Vermessungsgenauigkeit.

| Gebiet | Vorher: Abdeckung und Prüfstatus | Nachher: Abdeckung | Aktuelle Einordnung |
| --- | --- | ---: | --- |
| Armenien · AM | 93,162904 % · Quellenprüfung | 97,340036 % | Nach dem begrenzten Kriterium geklärt |
| Aserbaidschan · AZ | 3,448836 % · Flächenlücke | 0 % | Quellenprüfung; falsche Altflächen ausgeschlossen |
| UN-Pufferzone Zypern · CNM | 99,865814 % · Quellenprüfung | 99,841186 % | Zuständigkeitsfrage weiterhin offen |
| Republik Zypern · CY | 99,023830 % · Quellenprüfung | 98,991744 % | Nach dem begrenzten Kriterium geklärt |
| Nordzypern · CYN | 98,053905 % · Quellenprüfung | 95,169134 % | Nach dem begrenzten Kriterium geklärt |
| Dekelia · ESB | 95,870533 % · Quellenprüfung | 95,597840 % | Nach dem begrenzten Kriterium geklärt |
| Israel · IL | 92,749634 % · Flächenlücke | 92,696891 % | Flächen- und Referenzlücke offen |
| Iran · IR | 98,739038 % · Quellenprüfung | 97,597428 % | Nach dem begrenzten Kriterium geklärt |
| Jordanien · JO | 0 % · Flächenlücke | 95,817014 % | Belegte örtliche staatliche Zuständigkeit; keine Gemeindegrenze |
| Kasachstan · KZ | 77,573196 % · Quellenprüfung | 78,685806 % | Echte örtliche Flächenlücken bleiben |
| Libanon · LB | 61,665802 % · Flächenlücke | 61,665802 % | Quellenprüfung und Flächenlücke bleiben |
| Libyen · LY | 0 % · Flächenlücke | 0 % | Keine geeigneten aktuellen örtlichen Grenzpolygone gefunden |
| Marokko · MA | 99,475034 % · Quellenprüfung | 99,475034 % | Konkrete fehlende Gemeinde weiterhin offen |
| Türkei · TR | 55,590184 % · Quellenprüfung | 55,590184 % | Flächenlücke und fehlender Nutzungsbeleg bleiben |
| Akrotiri · WSB | 96,968515 % · Quellenprüfung | 96,375101 % | Nach dem begrenzten Kriterium geklärt |

Eine sinkende Prozentzahl ist hier teilweise das Ergebnis einer sachlichen
Bereinigung. Beispielsweise werden falsch als Gemeinden eingeordnete Flächen
in Aserbaidschan nicht weitergezählt. In Zypern und Iran ersetzen besser
qualifizierte Identitäten und Geometrien die zuvor großzügiger oder falsch
klassifizierten Altdaten. Quellenprüfung und Flächenmessung bleiben deshalb
getrennte Aussagen.

## Konkreter Fortschritt und nächster fehlender Beleg

### Die sieben nach dem begrenzten Kriterium geklärten Gebiete

**Armenien:** Die 62 heutigen kommunalen Identitäten wurden gegen das
konsolidierte Gesetz geprüft, einschließlich der Fusionen vom September 2026.
Die alte Quelle mit 39 nicht amtlichen Emergency-Regionen bleibt ausgeschlossen.
Der unabhängige physische Nenner zählt den Sewansee nicht länger als Land;
der bisherige territoriale Staatsrahmen bleibt dabei unverändert. Rund
749 km² Restdifferenz werden weiterhin ausgewiesen. Für eine weitergehende
Genauigkeitsprüfung fehlen amtlich abgestimmte aktuelle Grenzgeometrien der
betroffenen Randflächen. Näheres: [AM/KZ/IL-Quellenprüfung](atlas-AM-KZ-IL-audit.md).

**Republik Zypern:** Originale DLS-Flächen wurden mit der amtlichen
CYSTAT-Klassifikation vom Juni 2026 und der Reform von 2024 verknüpft. Der
Provider unterscheidet 20 aktuelle Gemeinden, 91 Gemeindeviertel und
511 statistische Community-Gebiete. Ein Community-Code wird nicht als
Nachweis eines unabhängig gewählten Gemeinderats ausgegeben. Für das
begrenzte Kriterium ist kein weiterer pauschaler Quellenersatz nötig;
Restflächen und künftige Reformen benötigen fortgeschriebene amtliche
DLS-Geometrien mit derselben klaren Identitätszuordnung. Näheres:
[Zypernquellen](atlas-cyprus-sources.md).

**Nordzypern:** Die 18 kommunalen Identitäten sind positiv mit Gesetz 15/2022
und den tatsächlichen Quellrelationen verbunden. Die Darstellung bleibt auf
den bestehenden unabhängigen CYN-Rahmen begrenzt. Vier der 213 gedruckten
Ortsnamen konnten nicht eindeutig räumlich verknüpft werden; dafür wurden
keine Aliasse oder Ortsflächen erfunden. Der nächste konkrete Zusatzbeleg
wäre eine amtliche kartografische Zuordnung dieser vier Namen und der
gemessenen Randdifferenzen. Näheres:
[Nordzypernquellen](atlas-north-cyprus-sources.md).

**Dekelia:** Die Original-DLS-Teile von Lysi und Ammochostos innerhalb ESB sind
jetzt als eigene, ausschließlich auf ESB begrenzte `local_admin`-Quelle
qualifiziert. Ihr positiver Rechtsgrund sind die örtlichen zivilen Aufgaben
nach der SBA-Verordnung 14/2024. Die konkrete Crown- und
Militärliegenschaftsausnahme bleibt sichtbar; es wird keine tatsächlich
uneingeschränkte Machtausübung auf jedem Grundstück behauptet. Die beiden
Teile ergänzen zusammen etwa 1,398 km². Der endgültige Atlasbuild bestätigt
95,597840 %; etwa 5,61 km² bleiben offen. Benötigt werden als nächster
Genauigkeitsbeleg eine abgestimmte amtliche DLS-/SBA-Kartengrundlage für diese
Restflächen und gegebenenfalls die einschlägigen öffentlichen Anordnungen
für Militärliegenschaften. Der Buildwert beruht auf den tatsächlich zusammengeführten Daten.
[Rechtsgrund und räumliche Begrenzung](atlas-cyprus-sources.md).

**Iran:** Im Kartenausschnitt sind 1.188 positiv qualifizierte Dehestan als
örtliche Verwaltungseinheiten vertreten. Sie sind keine pauschal neu
behaupteten selbstverwalteten Gemeinden. Die neue getrennte Quelle bewahrt
lesbare Originalnamen, Kennungen, tatsächliche Rollen und Herkunftsbelege;
die alte gemischte gbOpen-Quelle bleibt für Verwaltungsdarstellung ausgeschlossen. Sämtliche 52 ausgeschlossenen
Kandidaten und die fehlende Bushehr-Provinzreferenz liegen außerhalb des
Atlasrechtecks. Die verbleibenden rund 2,4 % sind noch nicht in tatsächliche
Quelllücken, Stadtflächen und Referenzunterschiede aufgeteilt. Dafür werden
positiv typisierte örtliche Grenzpolygone und ein amtlicher Rollenabgleich
der konkreten Restflächen benötigt. Eine nationale Behördenvollzählung wird
nicht behauptet. Näheres: [Iranquellen](atlas-iran-sources.md).

**Jordanien:** Im kleinen Ausschnitt nördlich von 33° ist das tatsächliche
Ruwaished-Liwa als `district` erhalten. Hinzu kommt eine positiv belegte,
terminale staatliche `local_admin`-Zuständigkeit. Diese dekonzentrierte
Verwaltung wird ausdrücklich nicht als Gemeinde oder Gemeindegrenze
bezeichnet. Der fast deckungsgleiche ältere Eintrag wird nicht als zweite
örtliche Behörde gezählt. Eine künftige echte Kommunaldarstellung benötigt
gesondert belegte Gemeindegrenzen und deren Geltungsbereich; die derzeitige
örtliche staatliche Rolle ersetzt diesen fehlenden Beleg nicht.
[Jordanienprüfung](atlas-jordan-sources.md).

**Akrotiri:** DLS-/CYSTAT-Identitäten und die SBA-Verordnungen erlauben eine
belastbarere Einordnung der überlappenden örtlichen zivilen Gebiete. WSB wird
nicht als eine einzige Gemeinde dargestellt. Die unabhängige Referenz misst
weiterhin eine Restfläche; für die nächste Genauigkeitsstufe werden
abgestimmte amtliche DLS-/SBA-Grenzen und gegebenenfalls grundstücksbezogene
Geltungsbelege benötigt. [Zypern- und SBA-Quellen](atlas-cyprus-sources.md).

### Die acht weiter offenen Gebiete

**Aserbaidschan:** Acht falsch eingeordnete Altobjekte sind jetzt
quarantänisiert. Die daraus folgenden 0 % sind eine ehrliche Korrektur und
kein Verlust zuvor nachgewiesener Kommunen. Die amtliche Quellenkette wurde
bis zum zuständigen Katasterdienst `dedkr.gov.az` verfolgt; ein öffentlich
abrufbarer geeigneter Geometriedownload mit belegter Weitergabe wurde nicht
gefunden. Nötig sind echte lokale Grenzpolygone mit positiver Körperschafts-
oder Verwaltungsrolle und ausdrücklichen Nutzungsbedingungen. Höhere Bezirke
werden nicht ersatzweise zu Gemeinden umbenannt.

**UN-Pufferzone Zypern:** Die hohe Flächenüberlappung belegt zunächst nur
territoriale Referenzteile. Aktuelle UNFICYP-Quellen bestätigen zivile
Genehmigungen, Koordination und besonders geregelte Civil Use Areas. Sie
begründen weder eigene kommunale UN-Körperschaften noch die Gleichsetzung
aller DLS-Teile mit einer überall wirksam ausgeübten kommunalen Zuständigkeit.
Der nächste fehlende Beleg ist die konkrete, räumlich zuordenbare Verbindung
zwischen den betreffenden lokalen Einheiten, ihren Zuständigkeiten und den
UN-Regelungen. Ein künstlicher Municipalstatus wird nicht eingeführt.
[Einordnung der Pufferzone](atlas-cyprus-sources.md).

**Israel:** Eine konservative physische Wasserprüfung mit unverändertem
territorialem Rahmen ergibt weiterhin weniger als 95 %. Ein alternativer
detaillierterer Länderrahmen würde Flächen gegenüber Nachbarn anders
zuordnen und wurde deshalb nicht einseitig übernommen. Für die rund
95 km² Restdifferenz im Kartenausschnitt fehlen eine konsistent abgestimmte
unabhängige Grenzreferenz und die zugehörigen positiv qualifizierten lokalen
Flächen. Keine nationale Zuordnungsänderung wird allein zur Verbesserung
der Prozentzahl eingesetzt. [Vergleich und Grenzen](atlas-AM-KZ-IL-audit.md).

**Kasachstan:** Drei echte Stadtverwaltungen – Atyrau, Oral und Aktau – sind
als zusätzliche örtliche Verwaltungsrollen qualifiziert, ohne ihre bestehende
Bezirksebene in ländliche Gemeinden umzudeuten. Die großen fehlenden
ländlichen Okrug-Flächen im Westen bleiben real offen. Der amtliche
Atyrau-GIS liefert in den geprüften plausiblen Layern nur Bezirksgrenzen;
der eng begrenzte öffentliche Kataster-Featureabruf wurde abgewiesen.
Gesucht werden vollständige echte ländliche Verwaltungsgrenzen, insbesondere
für die offenen Kurmangazy- und Munaily-Teile, mit belegter öffentlicher
Weitergabe. Wasserabzug, Dorfgrundrisse oder höhere Bezirke schließen diese
Lücke nicht. [KZ-Quellenwege](atlas-AM-KZ-IL-audit.md).

**Libanon:** Zwölf Beiruter Viertel sind sachgerecht einer tatsächlichen
Gemeinde zugeordnet; sie werden nicht als zwölf unabhängige Gemeinden
gezählt. Der Flächenwert bleibt dabei gleich. Katastergebiete sind ebenfalls
kein automatischer Gemeindenachweis. Es fehlen ein belastbarer landesweiter
Identitätsabgleich der tatsächlichen Gemeinden und deren zugehörige
weiterverteilbare Grenzpolygone für die offenen Flächen.

**Libyen:** Die geprüfte HDX-Admin3-Quelle enthält nur 100 Punkte und liefert
damit keine Grenzpolygone. Die 22 Who's-On-First-Flächen sind ältere Regionen;
im geprüften PBF wurden keine verwendbaren aktuellen Baladiya-Grenzen
nachgewiesen. Als nächstes fehlt ein aktueller amtlicher oder anderweitig
positiv belegter Baladiya-Polygonsatz mit Identitäten, Datenstand und
Weitergaberechten. Punkte oder alte Regionen werden nicht als heutige
Gemeindegebiete ausgegeben.

**Marokko:** Die fehlende Gemeinde Sidi Mohamed Benmansour ist rechtlich
und namentlich von Ben Mansour getrennt. Der zusätzliche Audit hat
44 gedruckte Rechtspunkte mit zehn ursprünglichen OSM-Wegen und 603 Knoten
rekonstruiert. **Diese Rekonstruktion ist ausdrücklich nicht für die
produktive Darstellung zugelassen:** Die Kandidaten enthalten ungeklärte
Küstenanschlüsse und Selbstüberschneidungen; außerdem ist der gemeinsame
Straßenverlauf nicht identisch festgelegt. Nötig sind die maßgebliche
kartografische Anlage oder eine autoritative Auflösung dieser konkreten
Anschlüsse. Eine Restfläche wird nicht künstlich ergänzt.
[Vollständiger Rechts- und Geometrieaudit](atlas-morocco-legal-audit.md).

**Türkei:** Der vorhandene geprüfte Ausschnitt bleibt lückenhaft; Dorf-,
Nachbarschafts- und Gemeinderollen werden nicht pauschal gleichgesetzt.
30 zusätzliche Osmaniye-Kandidaten sind weiter nicht zugelassen, weil die
ursprünglichen ULASAV-Nutzungsbedingungen nicht verifiziert werden konnten.
Der Portalhost war nicht per DNS erreichbar, eine passende verifizierte
Archivkopie ist nicht bekannt. Die nächste fehlende Quelle ist der
ursprüngliche ausdrückliche Weitergabebeleg für genau diesen Datensatz oder
ein anderer aktueller Grenzdatensatz mit nachgewiesener Rolle und Lizenz.
Öffentliche Sichtbarkeit allein reicht nicht als Nutzungsrecht.

## Endgültiger Build und Paketnachweis

Der gemeinsame Atlasbuild bestätigt sieben geklärte und acht offene Fälle
nach dem begrenzten Kriterium. Er enthält 139.571 Objekte und keine offenen
oder länderfremden Elternverweise; alle 22 Eingabereceipts blieben unverändert.
391 Python-Tests und alle 41 Godot-Suiten mit 31.746 Assertions bestanden.

Windows-EXE und Offline-APK wurden mit identischen eingebetteten Atlasdaten
gebaut und statisch geprüft. Der isolierte tatsächliche Windowslauf bestand
148 Prüfungen einschließlich neuer Partie, Quellen bei 200 % Textskalierung
sowie Speichern und Wiederladen. Ein physischer Android-Gerätelauf wurde
nicht durchgeführt. Dateihashes, genaue Aussagegrenzen, Rohquellenbelege und
reproduzierbare Prüfkommandos stehen im [aktuellen Prüfbericht](atlas-progress.md).
