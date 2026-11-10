# Zypern: DLS-Flächen, aktuelle Identitäten und überlappende SBA-Rollen

Stand: 10. November 2026. Der Provider liefert zwei getrennte Quellen. Die
bisherige DLS-/CYSTAT-Quelle enthält unverändert 20 aktuelle Gemeinden und
602 örtliche territoriale Einheiten: 91 Gemeindeviertel und 511 statistische
Community-Gebiete. Ein statistischer Code allein belegt keinen unabhängig
gewählten Gemeinderat. Die bestehende gesonderte Prüfgrenze für CNM bleibt
erhalten.

## Zusatzquelle ausschließlich für zwei ESB-Teile

`DLS-SBA-overlapping-local-areas-2024-CYSTAT20260609` qualifiziert genau zwei
bereits vorhandene, positiv identifizierte DLS-Originalflächen:

| Amtliche Identität | CYSTAT-Code 2026 | Original-DLS-Code | ID des territorialen Atlasobjekts |
| --- | --- | --- | --- |
| Ammochostos | `31033000` | `3000` | `dls:ESB:overlap:31033000` |
| Lysi | `31063202` | `3202` | `dls:ESB:overlap:31063202` |

Die Einträge sind `local_admin`, keine neu geschaffenen Gemeinden. Native
Originalnamen, vollständige ursprüngliche DLS-Attribute, alte und aktuelle
Codes, Originalstaat `CY` und der positive ursprüngliche Identitätstyp
`MUNICIPALITY` bleiben erhalten. Die Rohgeometrie wird unverändert aus dem
Original übernommen. Erst der bestehende Atlas-Merger schneidet sie mit dem
unveränderten unabhängigen ESB-Rahmen.

Die Quelle hat `scope_countries=["ESB"]`, `clip_to_scope=true` und
`replacement_scope="feature"`. Dadurch werden keine übrigen Teile der beiden
Originalgemeinden nach CYN oder CY importiert, keine bestehenden Gemeinden
ersetzt und keine Zuständigkeiten außerhalb ESB behauptet. Elternobjekt der
zwei dargestellten Teile ist `country:ESB`.

## Positiver Rechtsgrund und konkrete Einschränkungen

Die [SBA Overlapping Municipalities Ordinance 14/2024](https://www.sbaadministration.org/home/legislation/01_02_09_05_ORDINANCES/01_02_09_05_65_ORD_2024/20240628_ORD-14_G2093.pdf)
begründet die örtliche zivile Rolle innerhalb der Basen: § 2 definiert die
überlappenden Gemeinden räumlich, § 6 behandelt die Rechtspersönlichkeit,
§§ 42–43 konkrete örtliche Aufgaben und § 155 die dortigen Befugnisse der
Gemeinderäte unabhängig vom Wahlort. Die maßgeblichen PDF-Seiten sind
6–10 und 32. Das Inhaltsverzeichnis nennt den letzten Punkt irrtümlich § 156;
der tatsächliche Gesetzestext verwendet § 155.

Die §§ 160–161 auf PDF-Seiten 33–34 enthalten Crown- und
Militärliegenschaftsausnahmen. Auf militärischen Grundstücken gilt die
Verordnung nur im Umfang einer öffentlichen Anordnung des Administrators.
Der Provider behauptet deshalb ausdrücklich keine tatsächlich uneingeschränkte
Machtausübung auf jedem Grundstück und keine überall verifizierte Erbringung
örtlicher Dienste. Ein Grundstücksregister oder solche öffentlichen
Einzelanordnungen werden nicht aus dem bloßen Gemeindeschnitt abgeleitet.

Dieser vollständige Vorbehalt steht als deutscher Top-Level-Wert
`territorial_scope_note` im Manifest und wird vom vorhandenen Quellen-Dialog
angezeigt. Die positiv belegten und die begrenzenden Paragrafen sind zusätzlich
strukturiert an Quelle und Objekten hinterlegt. DLS-CC-BY-4.0- und
CYSTAT-Zuschreibungen bleiben getrennt erhalten; Rohgesetz und amtliche
Originaldaten liegen mit ihren vorhandenen Hashes nur im privaten Quellcache.

## Getrennter physischer Vergleich: keine Küstenlösung der Restlücke

Der separate Audit liegt unter
`.tools/atlas_sources/audit/ESB-CNM-physical-20261110/`. Er ändert keine
produktive Landreferenz und verwendet keine Zielgemeindenunion als Nenner.
Die ursprüngliche territoriale NE-Zuordnung bleibt unverändert.

| Unabhängige Referenz | Landfläche km² | Abdeckung vor Zusatzquelle | Restfläche km² |
| --- | ---: | ---: | ---: |
| Unveränderter NE-ESB-Rahmen | 127,431395 | 94,501049 % | 7,007390 |
| Derselbe Rahmen ∩ separates NE-Land, ohne NE-Seen | 127,431347 | 94,501053 % | 7,007383 |
| Zusätzlich ohne originale OSM-Offenwasserpolygone | 127,039490 | 94,488673 % | 7,001562 |

Die NE-Küstenkorrektur beträgt nur rund 48 m²; kein NE-Seepolygon schneidet
ESB. Der zusätzliche unabhängige Wasservergleich ändert daran nichts
Wesentliches. Dafür wurden ausschließlich fünf Wasser-SHP-Komponenten und
README aus dem datierten Geofabrik-Archiv geladen: 379.665 echte Rangebytes,
starker ETag, exakte HTTP-Ranges, ZIP-CRC und Member-SHA256 geprüft.
Originale Wassergeometrien bleiben unverändert; Feuchtgebiete bleiben Land.

Die zwei positiv qualifizierten lokalen Teile ergänzen 0,318573 km² und
1,079001 km². Gegen den unveränderten NE-Rahmen ergibt der reine
Originaldatenvergleich damit ungefähr 95,597775 % örtliche Flächenabdeckung.
Rund 5,610 km² Rest bleiben ausdrücklich offen. Dieser Prüfwert ist keine
hundertprozentige Verwaltungsvermessung und noch kein Nachweis des erneuten
Gesamt-Atlasbuilds. Kleine Unterschiede zur Laufzeit entstehen durch dessen
Koordinatenquantisierung.

## CNM bleibt gesondert eingeordnet

Die aktuellen amtlichen UN-Seiten
[UNFICYP Civil Affairs](https://unficyp.unmissions.org/en/node/73092) und
[About the buffer zone](https://unficyp.unmissions.org/en/about-buffer-zone)
belegen zivile Genehmigungs- und Koordinationsaufgaben von UNFICYP sowie
besonders geregelte Civil Use Areas. Die Originalseiten sind separat gehasht
gesichert. Daraus folgt kein Nachweis eigener kommunaler Körperschaften,
keine Gleichsetzung der DLS-Gemeindeflächen mit UN-Sektoren und keine
Aufhebung der bestehenden territorialen CNM-Prüfgrenze. Die SBA-Verordnungen
werden nicht auf den UN-Puffer ausgedehnt.

## Reproduzierbarkeit und Prüfung

Quellen vorbereiten: `python -X utf8 tools/atlas_cyprus_sources.py`.
Gezielte Tests: `python -X utf8 -m unittest discover -s tools -p test_atlas_cyprus_sources.py`.
15 Tests bestehen nach beobachtetem RED→GREEN. Die sieben neuen Fälle prüfen
positive Identität, stabile Originalcodes, unveränderte Geometrie mit Loch,
Ablehnung ungültiger Originale, ESB-only-Schnitt ohne CYN-Leck, deutsche
Rechtsgrenzen, die deutsche sichtbare Gebietseinordnung ohne veralteten
ESB-Abdeckungswert und den Erhalt der bisherigen Quelle.

Zusätzlich wurden die beiden echten Rohgeometrien exakt gegen DLS verglichen,
die tatsächlichen ESB-Schnitte über den vorhandenen Merger geprüft und ein
zweiter realer `prepare_sources()`-Lauf auf byteidentisches Manifest geprüft.
Die eingefrorene Quittung ist
`ESB-CNM-physical-20261110/ESB-source-freeze-receipt.json` im privaten Cache.
Fünf zusätzliche Audit-Tests sichern das konservative physische Verfahren.
Es wurden kein Atlasbuild, kein Godot-Prozess, kein Export und kein
Smartphonezugriff gestartet.
