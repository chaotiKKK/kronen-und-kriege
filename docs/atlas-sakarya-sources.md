# Sakarya: originale Mahalle-Grenzen

Dieser getrennte Provider bereitet **662** gültige originale Mahalle-Flächen als
`local_admin` vor. Die zentrale Aufnahme ist seit dem geprüften 1.7.0-Atlasbuild erfolgt; der Provider allein erteilt keine pauschale Zulassung anderer Quellen.
Bestehende Geofabrik-Dateien werden weder verändert noch pauschal ersetzt.

## Produzent, Nutzung und Datum

Die [Datensatzseite der Stadt Sakarya](https://veri.sakarya.bel.tr/dataset/92)
veröffentlicht das KMZ aus der Coğrafi Bilgi Sistemleri Şube Müdürlüğü. Die dort
verlinkten [Originalnutzungsbedingungen](https://veri.sakarya.bel.tr/license)
erlauben mit Quellenangabe Kopie, Veröffentlichung, Verteilung, Bearbeitung und
Kombination einschließlich kommerzieller Anwendungen. Das ist die konkrete
Sakarya-Freigabe; sie gilt nicht automatisch für andere türkische Portale oder
die weiterhin ungeklärten Osmaniye-Kandidaten.

Der gespeicherte Originaltext der Bedingungen hat SHA-256
`adf280d7cb0deb30458dcb3d7cc17c811808c569a4c68960b8d83c3482007988`.
Der Datensatz nennt den **15.05.2024** als Attributdatum jedes Originals;
die Portalmetadaten wurden am **09.09.2025** aktualisiert. Abruf und Prüfung
erfolgten am 10.11.2026. Die Grenzen werden dadurch nicht als 2026 neu vermessen
ausgegeben.

Der [öffentliche originale KMZ-Download](https://veri.sakarya.bel.tr/dataset/67faf6a1-18d6-440c-89ed-7c5374edf70e/resource/eede1456-63d4-4fc9-805d-cfc435158995/download/mahalle-snrlar-kmz-verileri.kmz)
umfasst 4.560.473 Byte; SHA-256:
`d6befd154cda3e000c18378166a4f26d0208e7d0804099f686bca53cd8589a74`.
Der einzige ZIP-Member `doc.kml` umfasst 12.800.420 Byte, CRC32 `f49de0dc`,
SHA-256 `1ab9401fd7a8472021cb35942b366f4e6f059ebfff9a2351b093a525dce5ac07`.

## Aufnahme und konkrete Ausnahmen

Das Original enthält 677 eindeutig benannte GIS-Objekte mit unterschiedlichen
`objectid`-Werten. Fünf sind ausdrücklich Industriegebiete (OSB), 672 sind
reguläre Mahalle. Der Reader bewahrt die ursprünglichen Namen, IDs, Bezirke,
Datumsattribute, Polygonteile und Innenringe. Die `objectid` ist eine native
GIS-Kennung; ein nationaler amtlicher Mahalle-Code ist daraus nicht belegt und
wird nicht erfunden. Die Zuordnung erfolgt zu den 16 vorhandenen, exakt
namensgleichen Kreisen unter Sakarya.

Die Originale bleiben vollständig im privaten Roharchiv und Ausschlussaudit:

| Gruppe | Anzahl | Konkretisierung |
| --- | ---: | --- |
| OSB, keine regulären Mahalle | 5 | `11634`, `11878`, `12216`, `12843`, `12844` |
| Ungültige Originalpolygone | 2 | Uğurlu/Taraklı `12264`; Kemalpaşa/Serdivan `13375` |
| Ungeklärte Schreibidentität | 1 | Hastahane/Akyazı `13252` gegenüber GF-Hastane `13999454` |
| Begrenzte Editionskonflikte | 7 | Esentepe/Serdivan `13363`, Otuziki Evler/Serdivan `13367`, Beşköprü/Serdivan `13365`, Şirinevler/Adapazarı `13748`, Mithatpaşa/Adapazarı `13750`, Semerciler/Adapazarı `13746`, Arifbey/Arifiye `13347` |
| Zugelassene Originalflächen | **662** | Unveränderte WGS84-Längen-/Breitenkoordinaten aus dem KML |

Der Reader repariert, schneidet, vereinfacht oder ergänzt keine dieser Flächen.
Die ungültigen Originale werden insbesondere nicht mit `buffer(0)` verändert.

## Individuelle Ersetzungen und Konfliktabschluss

Vergleichsbasis ist der erhaltene Geofabrik-Stand vom 08.11.2026,
`normalized-TR-v4-r5-metropolitan-9fc82d8e3449.jsonl.gz`, SHA-256
`71dba0026f521a8440b555927d8faf163c78de189f8a0f0ebe5c4956b1fc68ad`.
Darunter befinden sich 198 Mahalle-Flächen unter den Sakarya-Kreisen.

189 erste Namens-/Kreiszuordnungen enthielten bereits das ungültige
Kemalpaşa-Original. Von neun zunächst nicht zugeordneten GF-Namen ließen sich
fünf über explizite Mahalle-Endungen und drei über feste, belegte Varianten
zuordnen. Die Neighbourhood-Rolle wird dabei nicht aus einer Überlappungsquote
abgeleitet. Für die drei konkreten Varianten gelten:

- Damlık `12233` ↔ Esentepe, GF `13763940`, Ferizli: Die
  [Originalseite des Justizministeriums](https://sakarya2lcik.adalet.gov.tr/kurum-mudurumuzun-mesaji)
  bezeichnet Esentepe ausdrücklich als früheres Damlık. Ein exaktes Rechtsdatum
  der Umbenennung wird daraus nicht behauptet.
- Çatalövez `13527` ↔ Çatalüvez, GF `13427021`, Karasu: Die
  [Gemeindeverwaltung](https://www.karasu.bel.tr/muhtarliklarimiz) und die
  [Kreisverwaltung](https://www.karasu.gov.tr/cataluvez) dokumentieren die beiden
  Schreibweisen der dortigen eindeutigen Mahalle. Die Originalschreibweisen
  bleiben erhalten.
- Yeni `13662` ↔ Yenimahalle, GF `14156638`, Hendek: Ein
  [kommunaler Artikel von 2019](https://www.hendek.bel.tr/haberler/yenimahalleye-semt-pazari-1)
  verwendet ausdrücklich beide Namensformen für dieselbe Mahalle.

Hastahane/Hastane wurde mangels ebenso eindeutiger Identitätsfreigabe
zurückgestellt. Nach der anfänglichen Qualifizierung gab es damit 196 mögliche
gültige Ersetzungen und zwei unverändert zu erhaltende GF-Fallbacks.

Die Editionskonfliktprüfung nimmt eine neue Originalfläche vollständig aus der
Zulassung, sobald ihre Überlappung mit einem beibehaltenen GF-Fallback mindestens
1 % einer der beiden Flächen beträgt. Numerische Schnittreste bis
`1e-10` Quadratgrad lösen keine Quarantäne aus. Besitzt die ausgeschlossene neue
Fläche einen positiv identifizierten GF-Altstand, bleibt dieser ebenfalls
erhalten und wird erneut geprüft. Der Vorgang bricht bei mehr als 70 weiteren
Ausschlüssen ohne neue Ausgabe ab. Tatsächlich konvergierte er nach **sieben**
Ausschlüssen. Sämtliche Auslöser, IDs, Originalnamen, Kreise, Flächenquoten und
Geometriehashes stehen im Audit. Es gibt danach **neun GF-Fallbacks**, **189**
einzelne Ersetzungen und keine verbliebene relevante Alt/Neu-Überlappung ab 1 %.
Die größte verbleibende Quote beträgt rund 0,772952 %.

Die 670 zunächst gültigen Originalpolygone haben untereinander 26 kleine
Randüberlappungen oberhalb `1e-12` Quadratgrad. Keine erreicht 1 % einer
beteiligten Originalfläche; die größte gemessene Schnittfläche beträgt etwa
0,039261 km². Sie sind dokumentiert und bleiben unverändert.

Fünf positiv benannte Ersetzungen haben erhebliche Grenzabweichungen zwischen
dem Original von 2024 und GF 2026: Gündoğan/Söğütlü `11650`,
İnönü/Karapürçek `12205`, Camitepe/Karasu `13519`, Tepetarla/Karasu `13530`
und Bayraktepe/Hendek `13654`. Der Audit enthält ihre konkreten Vergleichsquoten.
Gültige Koordinaten, positive Namensidentität und offene Nutzungsbedingungen
beweisen keine heutige Gleichheit beider Grenzfassungen.

## Schnittstelle und Reproduktion

`tools/atlas_sakarya_sources.py` bietet `prepare_sources(cache)` und
`iter_boundaries(cache, sources)`. Die unveränderlichen Ausgaben liegen unter
`.tools/atlas_sources/sakarya-mahalle-20240515/v3/`; frühere Prüfstände `v1` und
`v2` bleiben erhalten. Die separate öffentliche Projektbeschreibung steht in
`data/atlas_sakarya_sources.json`. Kein bestehender Provider oder globaler
Builder wird durch diesen Reader verändert.

Die Vorbereitung verlangt das gepinnte KMZ, die erhaltene Datensatz- und
Lizenzseite, den Originalbeleg zur Umbenennung sowie die genaue erhaltene
GF-Vergleichsbasis. Alle Rohdateien liegen im privaten Auditpfad
`.tools/atlas_sources/audit/remaining8-second-pass-20261110/tr-lb-ma-cnm/`.
Veränderte Originalbytes werden abgewiesen; sie erfordern eine neu geprüfte
Revision. Ein Download einer neuen aktuellen Grenzfassung ersetzt diese
gepinnten Belege nicht stillschweigend.

```powershell
python tools/atlas_sakarya_sources.py --cache .tools/atlas_sources
python -m unittest discover -s tools -p test_atlas_sakarya_sources.py -q
```

Die gezielten 27 Prüfungen umfassen native Rollen, OSB-Ausschluss, ungültige
Originale, Elternidentitäten, explizite Namensvarianten, Polygonteile und
Innenringe, geschlossene Originalringe, unveränderliche Hashes, fehlende oder
veränderte Qualifikationsaudits bei Cache-Wiederverwendung, die begrenzte
Konfliktkaskade sowie bytegleiche WKB-Geometrien aller aufgenommenen und
ausgeschlossenen Originale. Ohne den vorbereiteten privaten Rohcache werden
die zwei ausdrücklich als solche gekennzeichneten realen Quellenprüfungen
übersprungen; die synthetischen Vertragsprüfungen bleiben ausführbar.

Der Gesamtatlas wurde mit dieser Quelle noch nicht gebaut oder in Godot
geprüft. Eine bessere lokale Detaillierung ist belegt; eine vollständige heutige
Türkei-Karte oder ein neuer nationaler Flächenprüfwert ist damit nicht belegt.
