# Northern Cyprus: eighteen current municipal identities

Audit date: 10 November 2026. This provider is separate from the Republic of
Cyprus DLS/CYSTAT provider and its nine northern claimed municipalities.

`tools/atlas_north_cyprus_sources.py` exposes `prepare_sources(cache)` and
`iter_boundaries(cache, sources)`. It admits eighteen actual northern
**Belediye** identities by an explicit join of three independent facts:

1. The numbered names in the second schedule of the consolidated
   [Law 15/2022](https://mevzuat.gov.ct.tr/Portals/48/15-2022%20Belediyelerin%20Birlestirilmesine%20Iliskin%20%28Ozel%29%20Yasa.pdf),
   including its 2023/2024 amendments.
2. Unmodified native names and relation IDs in the dated
   [Geofabrik extract](https://download.geofabrik.de/europe/cyprus-261108-free.shp.zip).
3. Original OSM relation metadata fetched with explicit historical versions.
   Each ID, version, timestamp, name, boundary tag and native level must agree.

The archive README dates the geometry to **2026-11-08T21:21:00Z** and declares
Open Database License 1.0. The metadata snapshots are at or before that time.
The admin-level number alone cannot admit a municipality. The source keeps its
original Turkish names and its native role instead of substituting Republic
of Cyprus claim names. The law's staged commencement provision is retained:
the new municipal framework followed the 2022 election-result publication;
the provider does not invent a single exact commencement day for every clause.

## Territory and remaining geometry

The source replaces only the old CYN municipal dataset. Its manifest declares
`scope_countries=["CYN"]` and `clip_to_scope=true`. The shared merger must
intersect display geometry with the existing Natural Earth v5.1.2 CYN
reference. This is a display intersection, not a certified state boundary or
an assertion of international recognition. It grants no northern municipal
powers in the UN buffer, Republic-controlled territory or either sovereign
base area. Every clipped result needs an explicit derivation note; all
original source bytes remain in the ignored cache.

All eighteen original polygons are valid. They need no repair, artificial
union or gap filling. Against the unchanged NE CYN reference they cover
approximately **95.1691%**: 3,159.093 of 3,319.451 km². Approximately
160.358 km² remains unfilled. The original source polygons also contain
approximately 92.547 km² outside that reference. That outside area is not
silently assigned to another atlas territory.

The second schedule names **213 settlements**. An additional reproducible
check matches 209 names after explicit case, spacing and diacritic
normalization to original village polygons whose representative points lie
inside the corresponding original municipality. This is a name and spatial
cross-check, not a reconstruction of legal boundaries from village centroids.
Four names remain unjoined:

| Municipality | Legal settlement | Observed source difference |
| --- | --- | --- |
| Lapta–Alsancak–Çamlıbel | Kılıçarslan | OSM uses `Kılıçaslan`; no silent spelling alias is inserted. |
| Girne | Edremit | OSM uses `Erdemit`; original spelling is retained. |
| Gazimağusa | Yukarı Derinya | OSM `Derinya` describes the northern-administered part; a name equality is not invented. |
| Değirmenlik–Akıncılar | Dereliköy | No exact corresponding original village polygon was joined. It is not silently identified with Margo. |

The Erenköy enclave is correctly included in **Lefke**, as the current legal
schedule requires. **Erenköy–Karpaz** instead contains the scheduled Karpas
settlements, including Yeni Erenköy. The four unjoined village names do not
become four invented missing municipalities. All eighteen municipal identities
are independently positively matched. The manifest retains this distinction;
geometric coverage and its unfilled remainder remain explicit.

## Reproduction and checks

The public provider includes the full qualification and selective-download
logic. Python requires the project's existing Shapely/pyshp environment plus
the open-source `pypdf` package for extracting the original legal schedule.
Run from the project directory:

```powershell
python -X utf8 -B tools/atlas_north_cyprus_sources.py
python -X utf8 -B -m unittest discover -s tools -p test_atlas_north_cyprus_sources.py -v
```

Preparation selectively fetches only the five administrative shapefile
components and README, approximately 6.73 MB of compressed ranges from the
81 MB archive, plus the 517 KB law and 37 KB fixed-version metadata response.
The eight original files total **11,214,507 bytes** uncompressed. Each is
pinned by URL, size and SHA-256; the archive is additionally bounded by a
strong ETag, total size, verified HTTP ranges and ZIP member CRCs. Existing
original files are verified without overwriting them. Changed upstream bytes
fail closed. The original law stays only in the private cache; the public
manifest contains factual identities, links and hashes.

Ten focused tests pass. Nine initial admission/contract tests were observed
failing before implementation, then passing. The tests cover positive identity,
wrong level/name/version/date, invalid polygons without repair, holes, legal
page breaks/counts, absent village aliases, original-file tampering and a
selective fresh-cache fetch using the correct `RangeSource.fetch` interface.
The real eighteen-row offline iteration also passed with network subprocesses
disabled. All eighteen deliberately clipped polygons passed the actual
`feature_record` import in memory. That check did not write atlas output or
start Godot; central scope-clipping integration remains the builder owner's
separate responsibility.
