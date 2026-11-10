# AM, KZ und IL: echte lokale Lücken gegenüber physischen Referenzfehlern

Prüfdatum: 10. November 2026. Originale und Rechenbelege liegen privat unter
`.tools/atlas_sources/audit/AM-KZ-IL-20261110/`. Der produktive Stand behält
die bisherige territoriale Grundentscheidung **Natural Earth admin0 v5.1.2**
vollständig bei. Gemeindepolygone liefern keinen Landesnenner.

## Produktiv: ursprünglicher Staatsrahmen, unabhängige physische Wasserflächen

Die originale nationale NE-Geometrie wird mit dem getrennten globalen
physischen Land-/Küstenprodukt derselben Veröffentlichung geschnitten. Davon
werden alle echten Wasser-, Reservoir-, Flussflächen- und Hafenbeckenpolygone
des datierten Geofabrik-Wasserprodukts abgezogen. Die Codes 8200–8203 werden
mit ihren originalen `fclass`-Werten geprüft. Feuchtgebiete, Nasswiesen,
Moore und Gletscher bleiben Land.

Wassergeometrien bleiben unverändert: keine Reparatur, Pufferung, Verschiebung,
Rundung, erfundene Verbindung oder datenabhängige Lückenauswahl. Fehlende oder
ungültige Wassergeometrien führen zum Fehler. Die fünf ursprünglichen
SHP-Komponenten und README bleiben mit Original-CRC, Dateigröße, SHA-256 und
festem Datenstand **2026-11-08T21:21:00Z** erhalten.

| Land / bestehende lokale Quelle | Physisches Land im Atlasrechteck | Davon bedeckt | Anteil | Verbleibende Differenz |
|---|---:|---:|---:|---:|
| AM: unveränderte 62 rechtlich qualifizierte Gemeindeidentitäten einschließlich Yerevan | 28.167,155701 km² | 27.417,919549 km² | **97,340036 %** | 749,236153 km² |
| IL: vorhandene 235 lokale Quellfeatures, ohne neue Vollständigkeitsbehauptung | 1.304,308683 km² | 1.209,053594 km² | **92,696891 %** | 95,255089 km² |

Quelle `ne-physical-water-AM-20261108` bzw.
`ne-physical-water-IL-20261108`. Die bisherige Länderzuordnung bleibt erhalten;
es wird kein Land aus Nachbarreferenzen übernommen. Bei IL bleibt die
Lücke ausdrücklich offen. Im Atlas wird nur der nördliche Ausschnitt ab33°N
gemessen, nicht die gesamte Landesfläche.

Die originalen [Wasser-/Geodatenklassen von Geofabrik](https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf)
und die OSM-Daten stehen unter ODbL1.0. Das separate
[Natural-Earth-Produkt ist Public Domain](https://www.naturalearthdata.com/about/terms-of-use/).
Beide Lizenzschichten und ihre Attribution sind im Landreferenzmanifest
getrennt dokumentiert. Physische Originaldateien:

- `ne_10m_land.geojson`, Version v5.1.2, 10.157.965Bytes,
  SHA-256 `1ac90796408bc6ad6911d69448485d3c4dbf2190370080368a09976e1c9f7416`.
- [Armenia-Archiv vom 8.November2026](https://download.geofabrik.de/asia/armenia-261108-free.shp.zip),
  selektiv nur ursprüngliche Wasserkomponenten und README geladen.
- [Israel-and-Palestine-Archiv vom 8.November2026](https://download.geofabrik.de/asia/israel-and-palestine-261108-free.shp.zip),
  ebenfalls selektive physische Wasserkomponenten. Nationale Zuordnung erfolgt
  erst durch den unveränderten originalen NE-Staatsrahmen.

## AM: konkrete Ursache des früheren93%-Flags

Der Sewansee ist im groben administrativen NE-Staatsumriss Landfläche. Das
separate alte NE-Seepolygon misst1.377,018786km² und ist selbst deutlich
generalisiert. Die neu geladene physische OSM-Wassergeometrie36956
`Սևանա լիճ` misst1.267,962480km². Die Größenordnung wird unabhängig durch
die [Beschreibung des armenischen Umweltministeriums zum Sevan-Nationalpark](https://environment.gov.am/en/national-parks)
gestützt: Parkfläche mit und ohne See werden getrennt ausgewiesen; die
Differenz beträgt1.247,58km². Unterschiedliche Aufnahmezeitpunkte und Definitionen
bleiben erkennbar; die Geometrie wird nicht an einen Literaturwert angepasst.

Der aktuelle Verwaltungsprovider wurde nicht geändert. Seine62 heutigen
Identitäten wurden zuvor gegen das [konsolidierte amtliche Gesetz](https://www.arlis.am/hy/acts/231073)
und die seit19.September2026 wirksamen Fusionen geprüft. Yerevan wird einmal
als lokale Körperschaft gezählt; seine12Bezirke bleiben getrennte untere
Verwaltungsobjekte. Die fehlende Chambarak-Geometrie ist bereits im aktuellen
Provider über originale OSM-Mitglieder ergänzt. Die13gezielten Rechts-/
Identitäts-/Geometrietests bestehen auch im jetzigen erneuten Lauf.

Für eine gezielte Neubewertung des AM-Quellenflags liegen daher drei
unterschiedliche Belege vor: vollständiger rechtlicher Identitätsabgleich,
unveränderte und gehashte aktuelle Originalgeometrien sowie ein vom Ziel-
Gemeindesatz unabhängiger, territorial konservativer physischer Nenner.
Die frühere konkrete93,1629%-Sorge wird damit durch97,3400% aufgelöst.
Eine amtliche Katasterzertifizierung oder hundertprozentige Landesabdeckung
folgt daraus nicht;749,236km² bleiben gemessene Restdifferenz. Das Flag wurde
von diesem Reader **nicht selbst entfernt**. Die Entscheidung liegt beim
Quellenreview des Root-/Armenien-Providers und muss an genau diesen
Referenzstand und diese Nachweise gebunden bleiben.

## Nur Vergleich: detaillierte nationale OSM-Rahmen nicht integriert

Als Diagnose wurden separat geschlossene nationale OSM-Rahmen geprüft:
AM364066@441 und IL1473946@345, jeweils admin_level2, passendeISO-Tags und
sämtliche Mitglieder spätestens am gemeinsamen8.November-Snapshot.
Damit steigt die physische lokale Überlappung auf99,999642% bzw.97,824763%.
Diese höheren Werte werden **nicht** zur produktiven Qualitätsfreigabe benutzt.

Der Grund ist ein echter Wechsel der territorialen Referenz: Gegenüber der
bisherigen NE-Zuordnung lägen870,572km² neuer AM-Landfläche und57,783km²
neuer IL-Landfläche in dortigen Nachbarlandreferenzen. Die Zuordnung müsste
mit diesen Nachbarrahmen konsistent koordiniert werden. Die Diagnose dient
der Lokalisierung von Grenz-/Generalisierungsunterschieden und ist keine
unilaterale amtliche Grenzbehauptung. Cachebelege
`independent-boundary-differences.json` und die ursprünglichen OSM-API-
Antworten bleiben erhalten; kein Zielgemeindenverband wird als Staatsgrenze
verwendet.

## KZ: verbleibende echte örtliche Geometrielücken

Der vorhandene ländliche Okrug-Satz bedeckt77,5732% des Kartenausschnitts.
Generisches Abziehen aller schneidenden separaten NE-Binnenwasserpolygone
ergibt nur77,5964%; Wasser erklärt die Lücke somit nicht. Zwei größte
unbedeckte Komponenten liegen im Kurmangazy-Audan(22.282km²) und im
Munaily-Audan(11.565km²). Ihre Raionpolygone werden nicht ersatzweise zu
Gemeinden erklärt.

Die Differenz zwischen927rohen ADM8-Records und908normalisierten KZ-Einheiten
wurde vollständig durchgesehen. Die19übrigen Records sind überwiegend
Nachbarland-Pufferobjekte sowie eine geometrieleere östliche KZ-Einheit.
Sie enthalten keinen übersehenen großen westlichen Okrug-Satz, der die
Lücke ehrlich schließen würde. ADM9/10 im Westen enthalten einzelne
Siedlungsumrisse, keine Flächenvertretung für die fehlenden Okrugs.

Die [amtliche aktuelle Übersicht der Kurmangazy-Verwaltung](https://www.gov.kz/org/atyrau-kurmangazy/documents/details/939692?lang=kk)
belegt tatsächlich bestehende ländliche Verwaltungen. Ein alternativer
regionaler GIS-Dienst ist über den [amtlich beschriebenen Atyrau-Geoinformationsportal](https://www.gov.kz/org/atyrau/projects/details/1976?lang=en)
und den [nationalen NIPD-Dienstekatalog](https://map.gov.kz/services/?limit=5)
nachweisbar. Weitergabe- und Rollenprüfung dieses GIS laufen getrennt;
öffentliche Sichtbarkeit allein wird nicht als kommerzielle Open-Data-Lizenz
ausgegeben.

## Reproduzierbarkeit und Testumfang

33Landreferenztests bestehen nach beobachteten roten Fällen. Neue Fälle
sichern unveränderte Wassergeometrien, erhaltene Feuchtgebiete/Gletscher,
ursprüngliche nationale Identitäten und geschlossene Mitgliederketten,
Integrität sämtlicher Eingabebytes sowie den unveränderten NE-Staatsrahmen.
Die33Tests umfassen auch alle bisherigen acht Länderreferenzen. Keine
Godot-Prozesse, Exporte oder Smartphonezugriffe wurden gestartet.


## Abschluss der KZ-Quellenwege am 10. November 2026

Drei originale Stadtverwaltungsflächen sind positiv als zusätzliche örtliche
Verwaltung qualifiziert: Atyrau (Relation 3389541), Oral (3767383) und Aktau
(5515125). Die bestehende Bezirksebene bleibt erhalten; die zusätzliche Rolle
heißt `local_admin`, nicht neue Gemeinde oder ländlicher Okrug. Zusammen
repräsentieren sie 2.333,507 km² bislang nicht durch Okrugs vertretene Fläche.
Die Integration und Tests dieser drei Rollen liegen beim Geofabrik-Owner.

Die vollständigen aktuellen amtlichen Stadtportale und das aktualisierte
allgemeine Kommunalverwaltungsgesetz, Artikel 2-1 Absatz 2, wurden lokal mit
URL, Bytezahl und SHA256 gesichert. Die alte Aktau-Satzung von 2015 ist seit
der [Aufhebungsverordnung vom 15. Januar 2019](https://old.adilet.zan.kz/rus/docs/V19MA003783)
aufgehoben und bleibt ausdrücklich nur historischer Beleg. Die aktuelle
Rollenqualifikation stützt sich auf das heutige Stadtportal und das geltende
allgemeine Gesetz. Zwei kleine Adilet-SPA-Bootstrapdateien enthalten keinen
Gesetzestext und sind als ungeeignet markiert. Die endgültige Sammelquittung
liegt privat unter `audit/AM-KZ-IL-20261110/KZ-city-administration-role-evidence.json`.

Der öffentlich und mit regulärer TLS-Prüfung erreichbare amtliche Atyrau-WFS
enthält in den vier plausiblen Verwaltungs-Layern nur acht beziehungsweise
neun Bezirks-/Stadtobjekte. Die Originalattribute benennen Bezirksgrenzen,
keine fehlenden ländlichen Okrugs. Ein verbindlicher offener Weitergabe-
Lizenztext wurde nicht gefunden. Der nationale öffentliche Katasterdienst
liefert Capabilities und Schemata anonym, weist aber den einzigen eng auf
Verwaltungsattribute beschränkten Featureabruf mit HTTP 403 ab. Danach wurde
abgebrochen; keine Anmeldung oder Zugangssperre wurde umgangen. Ein einmalig
autorisierter isolierter TLS-Ausnahmetest am ausdrücklich amtlich genannten
alten Diensthost ergab HTTP 404; Systemeinstellungen blieben unverändert.

Der separate 6,64-MB-Who's-On-First-KZ-Download enthält nur nationale,
regionale und Bezirksflächen sowie vier einzelne Ortsflächen. Keine davon
ist der fehlende westliche ländliche Okrug-Satz. Dorfgrundrisse, Parzellen
oder höhere Bezirke werden deshalb nicht zu fehlenden Kommunalflächen
umetikettiert. Kasachstans erhebliche Restlücken bleiben ausdrücklich offen.

Die produktiven Landreferenzen sind eingefroren. Die konservative armenische
Referenz erhält den bisherigen Staatsrahmen; Israels Restunsicherheit bleibt
offen. Es wurde keine neue Hoheits- oder Katastergrenze behauptet und kein
Review-Flag allein wegen einer günstigeren Prozentzahl entfernt.
