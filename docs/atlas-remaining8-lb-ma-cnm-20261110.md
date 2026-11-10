# Quellenprüfung LB, MA und CNM vom 10.11.2026

Diese begrenzte zweite Quellenrunde ergänzt den erhaltenen Atlasstand 1.6.1
um konkrete neue Belege. Sie ändert keine bestehenden Provider, Geometrien,
Produktionsmanifeste oder territorialen Freigaben. Der parallel vorbereitete
neue Sakarya-Provider ist in `docs/atlas-sakarya-sources.md` getrennt beschrieben.

Die bisherigen Flächenprüfwerte von ungefähr 61,6658 % für Libanon, 99,4750 %
für Marokko und 99,8412 % für CNM sind Referenzwerte des bestehenden Atlas.
Sie wurden in dieser Runde nicht als neuer Gesamtatlas berechnet. Geometrische
Abdeckung, rechtliche Gebietsrolle, aktuelle tatsächliche Tätigkeit und
Weitergaberecht bleiben getrennte Prüffragen.

## Libanon: neuer UN-/Behördenweg, noch keine neue zugelassene Grenze

Ein öffentlich zugänglicher [UN-Habitat/UNICEF-Dienst](https://pro-ags2.dfs.un.org/arcgis/rest/services/Hosted/NonVulnerable_Cadastral_LBN_UNHabitat_2017_2023/FeatureServer/39?f=pjson)
führt administrative Namen, stellt bei näherer Prüfung aber thematisch
verknüpfte Kataster-/Unterkatastergebiete und Nachbarschaftsprofile dar. Die
gezielte Abfrage meldet 527.022 Datensätze; das sind keine 527.022 Gemeinden.
Die erhaltenen Methodenattribute nennen Erhebungs- und Profilierungsgebiete.
Das Lizenzattribut enthält ausdrücklich einen Rechtevorbehalt von UN-Habitat
und UNICEF. Aus dieser Quelle wurden **keine Geometrien übernommen** und keine
Katastergebiete zu Gemeinden umbenannt. Metadaten und zwei begrenzte
Attributproben bleiben im privaten Audit erhalten.

Der aktuelle [UNDP-/Umweltministeriumsbericht vom 22.07.2026](https://www.undp.org/lebanon/press-releases/lebanon-launches-new-national-planning-package-strengthen-waste-management)
belegt eine neue nationale GIS-Plattform für Abfallanlagen und deren
Versorgungsräume. Die tatsächlich verlinkte [TaDWIR-Studienseite](https://www.undp.org/lebanon/publications/tadwir-project-studies)
veröffentlicht Fachberichte. Ein frei weitergebbarer, als kommunaler
Grenzdatensatz qualifizierter Download ist dort bislang nicht belegt. Anlagen-
oder Versorgungsräume werden deshalb nicht als Gemeindegrenzen behandelt.

Ein weiterer öffentlich auffindbarer UNDP-Dienst mit dem Titel
`Municipality_boundaries` wurde nur anhand von 2.084 Byte Metadaten geprüft.
Sein räumlicher Ausschnitt liegt in Mittelamerika; er ist keine Libanonquelle.
Ein passender Titel allein genügt nicht.

Das [2024 von UNDP dokumentierte offizielle DGLAC-Portal](https://www.undp.org/lebanon/press-releases/european-union-and-united-nations-launch-directorate-general-local-administrations-and-councils-web-portal-and-automated-call)
ist als neuer unmittelbarer Behördenweg relevant. Der aktuelle Zugriff auf
`https://www.dglac.gov.lb` scheitert jedoch an einem abgelaufenen
TLS-Zertifikat (`SEC_E_CERT_EXPIRED`). Die Zertifikatsprüfung wurde nicht
abgeschaltet; ein öffentlich qualifizierbarer Grenzdownload konnte dort in
dieser Runde nicht festgestellt werden.

Der verbliebene Atlasflächenanteil ist weiterhin **keine automatisch fehlende
Gemeindegeometrie**. Der erhaltene amtliche Bestand unterscheidet Orte mit und
ohne Gemeinde; Katastergebiete können eine andere räumliche Einteilung haben.
Die ältere [CNRS-Produzentenstudie](https://lsj.cnrs.edu.lb/wp-content/uploads/2016/03/bakhos.pdf)
beschreibt gerade diese Beziehung zwischen Grundstückskreisen und teilweise
darauf aufbauenden Gemeindegebieten. Sie ist kein heutiger vollständiger
Gemeindegrenzensatz.

## Marokko: tatsächliche HCP-Originalpolygone, offene Nutzung und Grenzfassung

Das [offizielle HCP-Datenbankverzeichnis](https://www.hcp.ma/Bases-de-donnees_r631.html)
verlinkt das [RGPH-2024-Ergebnisportal](https://resultats2024.rgphapps.ma).
Dort ist eine originale [GeoJSON-Datei für Kénitra](https://resultats2024.rgphapps.ma/static/assets/860dfea3634721f55803.geojson)
öffentlich abrufbar. Die Datei umfasst 28 Features und 664.260 Byte;
SHA-256 `0782f4a0fd76d2cbaf6a6839c681d2b72bbc10c9de842cde90613c82288dee21`.
Die tatsächlich vorhandenen, getrennten und gültigen Originalpolygone heißen
`Sidi Mohamed Ben Mansour` mit Produzentenkennung `MA-04-281-05112` sowie
`Ben Mansour` mit `MA-04-281-05032`. Ihre Namen und Kennungen passen zu den
bereits gesicherten unterschiedlichen Gemeindeidentitäten. Es handelt sich
also um eine konkrete neue Quellenroute für die fehlende Fläche.

Die Datei erklärt ihre Koordinaten als `CRS84`, enthält tatsächlich aber
Meterwerte. Die ausdrücklich als **Interpretation** geprüfte Transformation
von Web Mercator/EPSG:3857 nach WGS84 führt in das erwartete Gebiet; eine
korrekte ursprüngliche EPSG-Deklaration des Produzenten ist damit nicht
nachgewiesen. Die erhaltenen Originalbytes werden nicht umetikettiert. Die
zwei so interpretierten Polygone überschneiden sich nicht und besitzen eine
exakt gemeinsame Grenzlinie. Ihr Abruf aus einem Portal für 2024 belegt kein
Vermessungsdatum der Linien.

Der Abgleich mit allen 44 bereits gesicherten Punkten der Rechtsentscheidungen
1635.20 und 1636.20 von 2020 zeigt teilweise erhebliche Unterschiede: maximal
rund 2.341 m für Ben Mansour und 2.062 m für Sidi Mohamed Ben Mansour. Die
Distanz bezieht sich auf den nächsten Punkt der jeweiligen kartografischen
Grenzlinie, nicht auf einen erfundenen zugehörigen Knoten. Deshalb wird keine
Gleichheit mit der gesetzlichen Fassung behauptet, keine Linie an einen
Rechtspunkt gezogen und keine Straße oder Küste zurechtgeschnitten.

Die [aktuellen ursprünglichen HCP-Nutzungsbedingungen](https://www.hcp.ma/Conditions-generales-d-utilisation-Version-1-0_a2194.html)
erlauben unter Ziffer 3 die Weiterverwendung von Indikatoren der benannten
Portale `hcp.ma` und `bds.hcp.ma` gemäß CC BY 4.0. Ziffer 5 enthält daneben
einen Rechtevorbehalt für Websitebestandteile mit Ausnahmen für entsprechende
Freigaben. Die eindeutige Anwendbarkeit der Indikatorenfreigabe auf diese
kartografischen Dateien des anderen Ergebnisportals ist noch nicht positiv
belegt. Die offene Lizenzbehauptung eines weiterverarbeitenden GitHub-Projekts
wird nicht als eigene Freigabe des Produzenten ausgegeben.

Ergebnis: Originaldatei, Rollenidentitäten, Koordinatenproblem und sämtliche
Punktdistanzen sind gesichert. **Noch kein MA-Import und keine neue
Vollständigkeitsfreigabe.** Die erhaltenen Rechtsbelege werden durch die
abweichende Kartografie nicht stillschweigend ersetzt.

## CNM: positiver begrenzter Rollenbefund für Pyla

Für genau **Pyla** liegt jetzt mehr als eine statistische Ortsklassifikation
vor. Der aktuelle konsolidierte [Communities Act 86(I)/1999, § 98A](https://www.cylaw.org/nomoi/enop/ind/1999_1_86/section-scbc1c9403-05a7-7d38-a31e-1f8085003095-ai52330e59-2aeb-40af-97b3-62dd446a6b5a.html)
nennt Pyla ausdrücklich: Die Gemeinde ist von der verpflichtenden Teilnahme
an einem Service-Cluster ausgenommen, ihr Community Council übt selbst die
Befugnisse eines Cluster-Councils aus. Absatz 6 beschreibt örtliche gemeinsame
Dienste. Das [Innenministerium nennt das Communities-Gesetz selbst als
Rechtsrahmen](https://www.gov.cy/moi/1-2-koinotites/).

Der vorhandene amtliche DLS-/CYSTAT-Abgleich identifiziert genau diese Einheit:

| Identitätsfeld | Erhaltener Wert |
| --- | --- |
| Ursprünglicher DLS-Name | ΠΥΛΑ |
| DLS `DIST_CODE` / `VIL_CODE` | `4` / `104` |
| DLS `OBJECTID` | `318` |
| Bisheriger geografischer Code | `4104` |
| CYSTAT-Code vom 09.06.2026 | `42004104` |
| CYSTAT-Rolle | `COMMUNITY` |
| Vorhandene Quellzeile | `dls:CY:local:42004104` |

Die aktuellen ursprünglichen Seiten des [Community Council Pyla](https://www.pyla.com.cy/)
belegen außerdem konkrete Tätigkeit. Das
[technische Department](https://www.pyla.com.cy/%CF%84%CE%B5%CF%87%CE%BD%CE%B9%CE%BA%CF%8C-%CF%84%CE%BC%CE%AE%CE%BC%CE%B1/)
beschreibt Unterhalt von Straßen, Gehwegen und Grünanlagen. Das
[Hygiene-/Reinigungsdepartment](https://www.pyla.com.cy/%CF%84%CE%BC%CE%AE%CE%BC%CE%B1-%CF%85%CE%B3%CE%B5%CE%B9%CE%BF%CE%BD%CE%BF%CE%BC%CE%B9%CE%BA%CF%8E%CE%BD-%CF%85%CF%80%CE%B7%CF%81%CE%B5%CF%83%CE%B9%CF%8E%CE%BD-%CE%BA%CE%B1%CE%B9-%CE%BA%CE%B1%CE%B8/)
nennt Reinigung, Abfall-/Recyclingdienste und geschäftsbezogene Freigaben.
Das trägt einen **positiven einzelnen örtlichen Rollenbefund**; der Rat wird
nicht aus einer geografischen Kennung allein erschlossen.

Die Einschränkung bleibt wesentlich. Abschnitt 5.11 des erhaltenen
[Planungshandbuchs des Innenministeriums, erste Revision 2025](https://eoal.org.cy/wp-content/uploads/2025/02/%CE%95%CE%B3%CF%87%CE%B5%CE%B9%CF%81%CE%AF%CE%B4%CE%B9%CE%BF-%CE%A0%CE%BF%CE%BB%CE%B5%CE%BF%CE%B4%CE%BF%CE%BC%CE%B9%CE%BA%CE%BF%CF%8D-%CE%95%CE%BB%CE%AD%CE%B3%CF%87%CE%BF%CF%85_%CE%A0%CF%81%CF%8E%CF%84%CE%B7-%CE%B1%CE%BD%CE%B1%CE%B8%CE%B5%CF%8E%CF%81%CE%B7%CF%83%CE%B7.pdf)
behandelt Genehmigungen in der Neutralzone gesondert. DLS prüft die Lage,
Verteidigungsstellen und die zuständige Distriktverwaltung werden beteiligt,
UN-Koordination und Bedingungen können erforderlich sein. Für bestätigte
Civil Use Areas gilt ein abweichender Mechanismus mit Standardbedingungen.
Die [UNFICYP-Beschreibung](https://unficyp.unmissions.org/en/about-buffer-zone)
unterscheidet ebenfalls zugängliche Civil Use Areas von anderen Teilen mit
Genehmigungspflichten.

Eine eigenständig validierte Grenzdatei der Civil Use Areas wurde in dieser
Runde nicht gefunden. Die Pyla-Belege beweisen deshalb weder ausschließliche
Vertretung beider Bevölkerungsgruppen noch uneingeschränkte tatsächliche Macht
auf jedem DLS-Grundstück. Andere CNM-Gebiete sind damit nicht einzeln
qualifiziert; die ganze UN-Pufferzone wird nicht zur Gemeinde erklärt.

Vorbereitet ist ausschließlich ein privater, exakt identitätsgebundener
Rollenbeleg für eine spätere koordinierte Qualifizierung. Der bestehende
Cyprus-Provider und seine CNM-Einschränkungen bleiben unverändert.

## Erhaltene Belege und Abschluss

Private Quellenbelege liegen unter
`.tools/atlas_sources/audit/remaining8-second-pass-20261110/tr-lb-ma-cnm/`.
Die wichtigsten neuen Prüfdateien sind:

- `MA-HCP-two-communes-cartography-audit.json`: Originaleigenschaften,
  Koordinateninterpretation, Topologie und alle 44 Rechtspunktdistanzen.
- `CNM-Pyla-positive-specific-role-audit.json`: genaue DLS-/CYSTAT-Identität,
  ursprüngliche Gesetzes- und Council-Belege, Funktionen und begrenzter Umfang.
- `LB-UNHabitat-provenance-attributes.body`: begrenzte Methoden-/Rechteprobe,
  ausdrücklich kein Geometrieimport.
- `transfer-budget.json`: maximal konservativ belastete direkte
  **14.454.541 von 25.000.000 Byte**, einschließlich fehlgeschlagener begrenzter
  Versuche. Es wurden keine TLS-Prüfungen abgeschaltet.

Neue Sakarya-Vertragsprüfungen wurden separat ausgeführt. Für LB, MA und CNM
wurde kein neuer Gesamtatlas, keine Godot-Ansicht, kein Export und kein
Smartphone-Test gestartet. Dieser Quellenpass ist abgeschlossen; die
konkreten offenen Fragen sind dokumentiert und keine Restflächen wurden
konstruiert.
