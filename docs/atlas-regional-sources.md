# Belegte obere Regionalebenen für FR, IT, ES und GB

Stand der Prüfung: 9. November 2026. Der neue Provider ergänzt tatsächlich
vorhandene obere Verwaltungseinheiten für vergleichbare Zoomstufen. Er erzeugt
keine gleich großen Spielgebiete und ersetzt keine Gemeinde- oder Kreisgrenzen.

| Land | Originale regionale Ebene | Rohobjekte | Im Atlasrechteck −12..52 / 33..72 | Quellstand | Individuelle Lizenz |
|---|---|---:|---:|---|---|
| FR | 12 Régions und Collectivité de Corse, IGN-Regionalprodukt | 13 | 13 | 2022 | Etalab Open License 2.0 |
| IT | 20 Regioni, ISTAT | 20 | 20 | 2023 | CC BY 3.0 laut fest gepinntem Quellenmetadatensatz |
| ES | 17 Comunidades Autónomas und zwei Ciudades Autónomas, IGN | 19 | 18 | 2017 | CC BY 4.0 |
| GB | Vier constituent countries, originales ONS-BGC-Produkt | 4 | 4 | Dezember 2024 | Open Government Licence v3.0 |

Die drei gbOpen-Geometrien sind ausdrücklich auf Commit `9469f09` und ihre
jeweiligen ADM-Metadaten festgelegt. Alle Rohanzahlen wurden am Originalabruf
gemessen und stimmen mit den zugehörigen Metadaten überein. Die Kanaren liegen
außerhalb des aktuellen Atlasrechtecks; der Provider behält trotzdem alle 19
spanischen Originaleinheiten. Er beschneidet keine Geometrie selbst.

## Tatsächliche Rollen statt einheitlicher ADM-Zahlen

Frankreich wird bei ADM1 ausgewählt. [INSEE bestätigt die 13 metropolitanen
Regionalgebiete](https://www.insee.fr/fr/metadonnees/definition/c1696). Korsika
bleibt als [Collectivité de Corse mit besonderem Status](https://www.collectivites-locales.gouv.fr/connaitre-les-acteurs-et-les-institutions/structures-territoriales/les-collectivites-statut-particulier/statut-particulier-la-corse)
erkennbar und wird nicht als gewöhnliche rechtliche Région ausgegeben.
Die [Original-Lizenz von Etalab](https://github.com/etalab/licence-ouverte/blob/master/LO.md)
gestattet kommerzielle Bearbeitung und Verteilung unter Quellen-/Datumsangabe.

Italien wird ausdrücklich bei **ADM2** ausgewählt: Das gbOpen-ADM1-Produkt
enthält nur fünf statistische Makrogebiete. [ISTAT trennt die drei
Verwaltungsebenen Regioni, Province und Comuni von den statistischen
Ripartizioni](https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici-al-1-gennaio-2018-2/).
Die 20 tatsächlich geladenen Originalnamen reichen von Piemonte und Valle
d'Aosta bis Sicilia und Sardegna. Das gepinnte individuelle CC-BY-3.0-Feld
wird bewahrt und nicht stillschweigend auf die heutige Webseitenlizenz umgestellt.

Spanien wird bei ADM1 ausgewählt. [IGN beschreibt Autonomien, autonome Städte
und darunterliegende Provinzen als unterschiedliche Ebenen](https://educativo.ign.es/atlas-didactico/organizacion-territorial-bach/organizacin_territorial_espaola.html).
Die gelieferten 19 Namen enthalten tatsächlich País Vasco/Euskadi, Aragón,
Comunidad Foral de Navarra usw. sowie ausdrücklich Ciudad Autónoma de Ceuta
und Ciudad Autónoma de Melilla. Die beiden Städte behalten `unit_type=Ciudad
autónoma`; andere Einheiten heißen `Comunidad autónoma`. Die 50 vorhandenen
Natural-Earth-Provinzen werden durch diesen Provider nicht als Autonomien
verwendet und nicht entfernt. Das [Original-IGN-Lizenzdokument](https://www.ign.es/resources/licencia/Condiciones_licenciaUso_IGN.pdf)
belegt die CC-BY-4.0-Nutzung.

## Großbritannien: ONS statt GISCO

Der gbOpen-GBR-ADM1-Kandidat enthält vier Länder, stammt aber ausdrücklich aus
Eurostat/GISCO. Sein pauschales CC-BY-Metadatenlabel ersetzt keine Prüfung der
ursprünglichen Nutzungsrestriktionen; dieser Kandidat bleibt ausgeschlossen.

Verwendet wird stattdessen das [originale ONS-Produkt Countries (December 2024)
Boundaries UK BGC](https://www.arcgis.com/home/item.html?id=0139831c7166457ab1f7b3ab1f919cba):
England `E92000001`, Northern Ireland `N92000002`, Scotland `S92000003` und
Wales `W92000004`. Diese vier originalen Code-/Namenspaare werden ausdrücklich
geprüft. Eigentümer `ONSGeography_data`, Service-Item-ID, Quellschema und
Originalanzahl müssen stimmen. Die 20-Meter-Geometrie ist am mittleren
Hochwasserstand auf die Küste begrenzt. Eine angeblich universelle numerische
ADM-Ebene wird nicht erfunden (`admin_level=null`).

Die [ONS-Lizenzseite](https://www.ons.gov.uk/methodology/geography/licences)
behandelt digitale Grenzen ausdrücklich unter OGL3. Beide vorgeschriebenen
Angaben stehen in der Attribution: ONS als Quelle und OS-Daten mit Crown
Copyright/Database Right 2024. Die gesonderten Einschränkungen für bestimmte
Nordirland-Postcodeprodukte werden nicht auf dieses digitale Grenzprodukt
übertragen. Originales Lizenz-HTML wird mit Hash als Abhängigkeit bewahrt.

## Schnittstelle, Ersetzung und Nachweis

```python
sources = prepare_sources(cache)
for row in iter_boundaries(cache, sources):
    # kind='region', echte native unit_type, stabile Quell-ID,
    # parent_id='country:'+ISO2, Shapely-Lon/Lat-Geometrie
    pass
```

Jede Quelle deklariert ausschließlich
`replace_natural_earth_kinds=["region"]`. Der Root-Merger ersetzt damit nur
die entsprechende obere NE-Ebene; `district`, `municipality` und sonstige
lokale Grenzen bleiben erhalten. Insbesondere ist die getrennte Korrektur
der irreführend als „Autonomous Community“ bezeichneten 50 NE-Provinzrecords
zu `district/Provincia` eine Aufgabe des Mergers, keine Umbenennung durch
diesen Quellreader.

Originalnamen und Quellfelder bleiben erhalten. Rohdateien liegen privat in
`.tools/atlas_sources/regional/`; ins Projektmanifest gelangen Herkunft,
Lizenzen, Attribution, Datenstände, Dateigrößen und SHA-256. Die drei
gbOpen-Originale messen zusammen 3.907.566 Bytes, ONS 12.556.314 Bytes:
insgesamt **16.463.880 Bytes** Geometrie und **56 echte Rohobjekte**.

Zehn Tests wurden zuerst rot und danach grün ausgeführt: italienische Ebene,
französische Sonderrolle/Lizenz, spanische Städte, GISCO-Ablehnung, strenger
Pin-/Lizenzabgleich, stabile IDs und Eltern, unpassende/fehlende Geometrien,
ONS-Countrycodes statt England-Statistikregionen, ONS-IPR-/Eigentümernachweis
sowie Hash-/Anzahlprüfung im tatsächlichen Iterator. Der reale Quellenlauf
lädt alle vier Länder, und eine Wiederholung erzeugt das Manifest byteidentisch.

```powershell
python -X utf8 -m unittest discover -s tools -p test_atlas_regional_sources.py
python -X utf8 tools/atlas_regional_sources.py
```

Diese Aufnahme belegt Quellrollen und vollständige Rohdatensätze. Die
geometrische Landesabdeckung und die sichtbare Darstellung bei Zoom3 werden
im gemeinsamen Build und dessen Laufzeitprüfung nachgewiesen.
