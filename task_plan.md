# Vergleichbare echte Verwaltungsebenen – verbleibende 15 Gebiete

Stand: 10. November 2026. Fortsetzung des genehmigten Atlasentwurfs; die veröffentlichte Version 1.6.0 bleibt als Rückfallstand erhalten.

## Ziel und Abnahme

Alle im Kartenrechteck vorhandenen Gebiete sollen echte, vergleichbar detaillierte lokale Verwaltung besitzen. Keine erfundenen Flächen, keine Umbenennung höherer Ebenen zur Beschönigung der Abdeckung. Quellenstand, rechtliche Rolle, Lizenz, Herkunft und verbleibende Unsicherheit bleiben sichtbar. Eine geometrische Abdeckung von mindestens 95 % gegen eine unabhängige Landreferenz ersetzt keinen Nachweis der korrekten Verwaltungsrolle.

## Phasen

1. Bestandsaufnahme und Arbeitsteilung: complete.
2. Primärquellen, Rollen und echte fehlende Geometrien: partial / external_sources_required (sieben der 15 Fälle geklärt, acht offen).
3. Getestete Provider, unveränderliche Quellcaches und Integration: complete für alle positiv zugelassenen Quellen; keine unsicheren Kandidaten integriert.
4. Gemeinsamer Atlasbuild, Regressionen, Darstellung und Leistungsprüfung: complete (391 Python-Tests; 41 Godot-Suiten / 31.746 Assertions; 148 isolierte Paketlauf-Prüfungen).
5. Dokumentierter geprüfter Zwischenstand und lokale Pakete: complete. Veröffentlichungsbeleg: GitHub-Release v1.6.1. Das Gesamtziel bleibt wegen acht konkreter Quellen-/Geometrielücken offen.

## Gebiete und Verantwortliche

| Gebiet | Ausgangsstatus / Abdeckung | Bearbeitung |
|---|---|---|
| AM | source_review / 93,16 % | coverage_research: unabhängige Landreferenz und Identitäten |
| AZ | gap / 3,45 % | Root: aktuelle bələdiyyə-Grenzen |
| CNM, CY, CYN, ESB, WSB | source_review / 95,87–99,87 % | atlas_independent_review: datierte Rollen, Reform und Quellzählung |
| IL | gap / 92,75 % | coverage_research: echte Räte und Referenz |
| IR | source_review / 98,74 % | atlas_release_review: aktueller positiver Dehestan-Satz; Altquelle quarantänisiert |
| JO | gap / 0 % | Root: reale Kommunalquelle |
| KZ | source_review / 77,57 % | coverage_research: ländliche/urbane örtliche Verwaltung |
| LB | gap / 61,67 % | atlas_release_review: echte Gemeinden und nichtkommunale Gebiete |
| LY | gap / 0 % | Root: aktuelle Baladiya-Grenzen |
| MA | source_review / 99,48 % | atlas_independent_review: fehlende echte Gemeinde |
| TR | source_review / 55,59 % | atlas_release_review: lokale Gebietsrollen und echte fehlende Flächen |

## Koordination

- Projekt: C:\Crusader Kings III\mobile-godot. F: ist derzeit nicht erreichbar.
- Root besitzt Builder, Integration und diese Planungsdateien. Agenten haben getrennte Providerbereiche.
- Godot, Atlasbuild und Exporte laufen jeweils einzeln und koordiniert. Kein Telefon ohne neue exklusive Übergabe.
- Rohquellen und Auditdownloads bleiben in .tools/atlas_sources; eingebettete Daten werden vollständig mitgeliefert.
- Aktuelle atlas.json ist 97.749.149 Bytes groß. Vor weiterer Veröffentlichung GitHubs 100-MiB-Grenze prüfen und bei Bedarf sauber aufteilen.

## Next Step

Geprüfter Zwischenstand: Version 1.6.1; Veröffentlichungsstand unter https://github.com/chaotiKKK/kronen-und-kriege/releases/tag/v1.6.1. Für weitere reale Abdeckung benötigen AZ/CNM/IL/KZ/LB/LY/MA/TR die im 15-Gebiete-Audit konkret bezeichneten fehlenden Primärgeometrien beziehungsweise Rollen-/Nutzungsbelege.

## Errors Encountered

| Fehler | Ursache | Umgang |
|---|---|---|
| Überlange Bestandsausgabe abgeschnitten | Vollständige Coverage-Metadaten zusammen ausgegeben | Nur gezielte Schlüssel und kurze Dateiausschnitte lesen |
| rg-Dateiglob unter PowerShell nicht expandiert | Glob als Pfad übergeben | rg mit -g-Dateifilter oder vorheriger Dateiliste verwenden |
| Overpass POST 406; erster GET 429 | Öffentlicher Dienst lehnt generischen Client ab | Ein begrenzter GET mit aussagekräftigem User-Agent; keine Endlosschleife |
| Zwei ArcGIS-Items 403 | Öffentliche Anbieter-Subskriptionen deaktiviert | Andere legale öffentliche Quellen suchen; kein Zugriffsumgehen |
| Minifiziertes atlas.json als ganze ersteZeile ausgegeben | Get-Content -TotalCount begrenzt Zeilen, nichtBytes | Große JSON-Dateien ausschließlich perParser gezielt projizieren |
| JO-CLI UnicodeEncodeError | Windows-Standardkonsole cp1252 | ASCII-sicheres JSON amCLI-Ausgang und UTF-8-Dateien |
| JO-Neucachewiederherstellung .read-Attributfehler | RangeSource-Vertrag hat.fetch | FrischerCache-Regressionstest und gezielteMethodenkorrektur |
