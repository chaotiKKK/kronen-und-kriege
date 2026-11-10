"""Independent country geometry must not be synthesized from target communes."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from shapely.geometry import box, mapping

PATH = Path(__file__).resolve().with_name("atlas_land_references.py")
if PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_land_references", PATH)
    land = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(land)
else:
    land = None


class IndependentLandReferenceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(land, "Unabhängige Landesreferenzen fehlen.")

    def test_swiss_service_requires_liechtenstein_and_reviewed_layer(self):
        feature = {"featureId": "LI", "layerBodId": "ch.swisstopo.swissboundaries3d-land-flaeche.fill",
                   "geometry": mapping(box(9.5, 47.1, 9.6, 47.2))}
        self.assertGreater(land.swiss_liechtenstein({"results": [feature]}).area, 0)
        for invalid in [{**feature, "featureId": "CH"}, {**feature, "layerBodId": "unreviewed"}]:
            with self.assertRaises(ValueError):
                land.swiss_liechtenstein({"results": [invalid]})

    def test_closed_italian_enclave_is_independent_of_san_marino_communes(self):
        extent = box(12.2, 43.7, 12.7, 44.2)
        hole = box(12.4, 43.9, 12.5, 44.0)
        result = land.derive_san_marino_enclave([extent.difference(hole)], source_country="IT")
        self.assertTrue(result.equals(hole))

    def test_open_frame_cannot_be_admitted_as_a_country(self):
        with self.assertRaises(ValueError):
            land.derive_san_marino_enclave([], source_country="IT")

    def test_target_municipalities_cannot_define_their_own_denominator(self):
        with self.assertRaises(ValueError):
            land.derive_san_marino_enclave([box(12.2, 43.7, 12.7, 44.2)], source_country="SM")

    def test_seed_outside_a_closed_enclave_is_rejected(self):
        extent = box(12.2, 43.7, 12.7, 44.2)
        with self.assertRaises(ValueError):
            land.derive_san_marino_enclave([extent.difference(box(12.21, 43.71, 12.22, 43.72))], source_country="IT")

    def test_cached_official_response_is_hash_checked_before_use(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            path = cache / "reference.json"
            document = {"results": [{"featureId": "LI", "layerBodId": "ch.swisstopo.swissboundaries3d-land-flaeche.fill",
                                     "geometry": mapping(box(9.5, 47.1, 9.6, 47.2))}]}
            path.write_text(json.dumps(document), encoding="utf-8")
            source = {"id": "swisstopo-land-LI-2026", "country": "LI", "source_type": "swiss-identify",
                      "cache_file": path.name, "bytes": path.stat().st_size,
                      "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            self.assertIn("LI", land.load_references(cache, [source]))
            path.write_text("{}", encoding="utf-8")
            with self.assertRaises(ValueError):
                land.load_references(cache, [source])

    def test_aland_frame_requires_unique_official_regional_identity(self):
        document = {"features": [
            {"properties": {"NATCODE": "21", "NAMEFIN": "Ahvenanmaa", "NAMESWE": "Åland"},
             "geometry": mapping(box(19, 59, 21, 60))}]}
        frame = land.aland_territorial_frame(document)
        self.assertAlmostEqual(frame.area, 2)
        with self.assertRaises(ValueError):
            land.aland_territorial_frame({"features": [{"properties": {"NATCODE": "035"},
                                                       "geometry": mapping(box(19, 59, 21, 60))}]})
        with self.assertRaises(ValueError):
            land.aland_territorial_frame({"features": document["features"]*2})

    def test_aland_land_is_physical_coastline_not_marine_frame(self):
        frame = box(19, 59, 22, 62)
        islands = [box(19.1, 59.1, 19.2, 59.2), box(20, 60, 20.1, 60.1), box(23, 63, 24, 64)]
        result = land.derive_aland_land(islands, frame,
            coastline_source="SYKE:Ranta10_merisaari", territorial_source="MML:maakunta2025_10k")
        self.assertAlmostEqual(result.area, 0.02)
        self.assertLess(result.area, frame.area / 100)

    def test_aland_target_municipalities_and_missing_coastline_are_rejected(self):
        for source in ("statfi:kunta1000k_2026", "unreviewed"):
            with self.assertRaises(ValueError):
                land.derive_aland_land([box(19, 59, 20, 60)], box(19, 59, 22, 62),
                    coastline_source=source, territorial_source="MML:maakunta2025_10k")
        with self.assertRaises(ValueError):
            land.derive_aland_land([], box(19, 59, 22, 62),
                coastline_source="SYKE:Ranta10_merisaari", territorial_source="MML:maakunta2025_10k")

    def test_wfs_pages_require_exact_counts_and_unique_source_ids(self):
        first = {"type": "FeatureCollection", "numberMatched": 3, "numberReturned": 2,
                 "features": [{"id": "island.1"}, {"id": "island.2"}]}
        last = {"type": "FeatureCollection", "numberMatched": 3, "numberReturned": 1,
                "features": [{"id": "island.3"}]}
        self.assertEqual(len(land.validate_wfs_pages([first, last])), 3)
        for invalid in ([first], [first, {**last, "numberMatched": 4}],
                        [first, {**last, "features": [{"id": "island.2"}]}]):
            with self.assertRaises(ValueError):
                land.validate_wfs_pages(invalid)

    def test_mml_dbf_uses_declared_western_european_encoding(self):
        header = bytearray(32)
        header[29] = 3
        self.assertEqual(land.mml_dbf_encoding(bytes(header)), "cp1252")
        header[29] = 0
        with self.assertRaises(ValueError):
            land.mml_dbf_encoding(bytes(header))

    def test_independent_aland_reference_checks_every_dependency_hash(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            coastline = cache / "coast.json"
            coastline.write_text("[]", encoding="utf-8")
            dependency = {"cache_file": coastline.name, "bytes": coastline.stat().st_size,
                          "sha256": hashlib.sha256(coastline.read_bytes()).hexdigest()}
            output = cache / "aland.json"
            output.write_text(json.dumps(mapping(box(19, 59, 19.1, 59.1))), encoding="utf-8")
            source = {"country": "AX", "source_type": "aland-physical-coastline", "cache_file": output.name,
                      "bytes": output.stat().st_size, "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
                      "coastline_product": "syke_rantaviiva:Ranta10_merisaari",
                      "territorial_frame": {"product": "SuomenMaakuntajako_2025_10k", "NATCODE": "21"},
                      "independent_of_target_municipalities": True, "input_files": [dependency]}
            self.assertIn("AX", land.load_references(cache, [source]))
            coastline.write_text("{}", encoding="utf-8")
            with self.assertRaises(ValueError):
                land.load_references(cache, [source])

    def test_verified_aland_derived_cache_is_reused_without_rederiving_geometry(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            directory = cache / "land-references"
            directory.mkdir()
            polygon = cache / "coast.geojson"
            polygon.write_text(json.dumps(mapping(box(19, 59, 19.1, 59.1))), encoding="utf-8")
            receipt = {"cache_file": polygon.name, "bytes": polygon.stat().st_size,
                       "sha256": hashlib.sha256(polygon.read_bytes()).hexdigest()}
            source = {**receipt, "id": "syke-physical-land-AX-MML2025", "derivation_version": 1,
                      "country": "AX", "source_type": "aland-physical-coastline",
                      "coastline_product": "syke_rantaviiva:Ranta10_merisaari",
                      "territorial_frame": {"product": "SuomenMaakuntajako_2025_10k", "NATCODE": "21"},
                      "independent_of_target_municipalities": True,
                      "input_files": [receipt]}
            (directory / "AX-independent-source.json").write_text(json.dumps(source), encoding="utf-8")
            with patch.object(land, "_mml_region", side_effect=AssertionError("Cached inputs must not be rederived")):
                self.assertEqual(land._prepare_aland(cache), source)
            polygon.write_text("{}", encoding="utf-8")
            with self.assertRaises(ValueError):
                land._prepare_aland(cache)

    def test_luxembourg_reference_uses_separate_country_layer_not_communes(self):
        document = {"features": [{"geometry": mapping(box(6, 49.5, 6.3, 49.7))}]}
        self.assertGreater(land.luxembourg_national_outline(document, source_layer="LIMADM_PAYS").area, 0)
        for layer in ["LIMADM_COMMUNES", "LIMADM_DISTRICTS", "LIMADM_GEN_PAYS"]:
            with self.assertRaises(ValueError):
                land.luxembourg_national_outline(document, source_layer=layer)
        with self.assertRaises(ValueError):
            land.luxembourg_national_outline({"features": document["features"]*2}, source_layer="LIMADM_PAYS")

    def test_luxembourg_csv_keeps_lau_leading_zero_and_rejects_conflicts(self):
        text = "COMMUNE,CODE_LAU2,DISTRICT\nHesperange,0303,Luxembourg\nMertert,1107,Grevenmacher\n"
        self.assertEqual(land.luxembourg_commune_codes(text), {"0303": "Hesperange", "1107": "Mertert"})
        with self.assertRaises(ValueError):
            land.luxembourg_commune_codes(text + "Anderer Name,0303,Luxembourg\n")

    def test_luxembourg_legacy_wkt_requires_declared_2169_and_exact_projection(self):
        wkt = 'PROJCS["Luxembourg_1930_Gauss",GEOGCS["GCS_Luxembourg_1930",DATUM["D_Luxembourg_1930",SPHEROID["International_1924",6378388.0,297.0]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",80000.0],PARAMETER["False_Northing",100000.0],PARAMETER["Central_Meridian",6.166666666666667],PARAMETER["Scale_Factor",1.0],PARAMETER["Latitude_Of_Origin",49.83333333333334],UNIT["Meter",1.0],AUTHORITY["EPSG",2169]]'
        self.assertEqual(land.luxembourg_source_epsg(wkt), 2169)
        for bad in [wkt.replace('EPSG",2169', 'EPSG",4326'), wkt.replace('80000.0', '500000.0')]:
            with self.assertRaises(ValueError):
                land.luxembourg_source_epsg(bad)

    def test_faroe_reference_preserves_separate_physical_islands(self):
        document = {"type": "FeatureCollection", "features": [
            {"id": 1, "properties": {"OBJECTID": 1}, "geometry": mapping(box(-7, 62, -6.9, 62.1))},
            {"id": 2, "properties": {"OBJECTID": 2}, "geometry": mapping(box(-6.8, 62, -6.79, 62.01))}]}
        metadata = {"id": 15, "name": "Oyggjar", "geometryType": "esriGeometryPolygon"}
        geometry = land.faroe_physical_land(document, metadata, declared_count=2)
        self.assertAlmostEqual(geometry.area, 0.0101)
        self.assertEqual(len(geometry.geoms), 2)
        for invalid in [document["features"][:1], document["features"]*2,
                        [document["features"][0], {**document["features"][1], "id": 1}]]:
            with self.assertRaises(ValueError):
                land.faroe_physical_land({"type": "FeatureCollection", "features": invalid}, metadata, declared_count=2)

    def test_faroe_reference_rejects_municipal_or_marine_layer_and_missing_geometry(self):
        feature = {"id": 1, "properties": {"OBJECTID": 1}, "geometry": mapping(box(-7, 62, -6.9, 62.1))}
        metadata = {"id": 15, "name": "Oyggjar", "geometryType": "esriGeometryPolygon"}
        for invalid in [{**metadata, "name": "Kommunur", "id": 0}, {**metadata, "name": "Sjógvur"}]:
            with self.assertRaises(ValueError):
                land.faroe_physical_land({"type": "FeatureCollection", "features": [feature]}, invalid, declared_count=1)
        with self.assertRaises(ValueError):
            land.faroe_physical_land({"type": "FeatureCollection", "features": [{**feature, "geometry": None}]}, metadata, declared_count=1)

    def test_faroe_cached_reference_checks_physical_role_and_all_input_hashes(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            original = cache / "islands.geojson"
            original.write_text("{}", encoding="utf-8")
            dependency = {"cache_file": original.name, "bytes": original.stat().st_size,
                          "sha256": hashlib.sha256(original.read_bytes()).hexdigest()}
            output = cache / "faroe.geojson"
            output.write_text(json.dumps(mapping(box(-7, 62, -6.9, 62.1))), encoding="utf-8")
            source = {"country": "FO", "source_type": "faroe-physical-islands", "source_layer": "lendiskort/us_lendiskort/15",
                      "independent_of_target_municipalities": True, "input_files": [dependency],
                      "cache_file": output.name, "bytes": output.stat().st_size,
                      "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}
            self.assertIn("FO", land.load_references(cache, [source]))
            with self.assertRaises(ValueError):
                land.load_references(cache, [{**source, "source_layer": "us_kommunur/0"}])
            original.write_text("[]", encoding="utf-8")
            with self.assertRaises(ValueError):
                land.load_references(cache, [source])

    def test_estonia_reference_uses_all_separate_counties_and_physical_coast(self):
        codes = ["0037", "0039", "0045", "0050", "0052", "0056", "0060", "0064", "0068", "0071", "0074", "0079", "0081", "0084", "0087"]
        counties = [{"properties": {"MKOOD": code}, "geometry": mapping(box(24+i*.01, 58, 24+(i+1)*.01, 58.1))}
                    for i, code in enumerate(codes)]
        # The physical source also includes foreign land. Only the independent
        # county frame supplies national membership; the inland-water hole stays.
        water = box(24.02, 58.02, 24.03, 58.03)
        physical = box(23, 57, 27, 59).difference(water)
        result = land.estonia_physical_land(counties, physical, source_layer="maakond")
        self.assertAlmostEqual(result.area, .015-.0001)
        self.assertFalse(result.intersects(water.buffer(-.00001)))
        self.assertLess(result.bounds[2], 24.16)

    def test_estonia_reference_rejects_municipal_frame_and_missing_or_duplicate_counties(self):
        codes = ["0037", "0039", "0045", "0050", "0052", "0056", "0060", "0064", "0068", "0071", "0074", "0079", "0081", "0084", "0087"]
        counties = [{"properties": {"MKOOD": code}, "geometry": mapping(box(24, 58, 25, 59))} for code in codes]
        for features, layer in [(counties, "omavalitsus"), (counties[:-1], "maakond"), (counties[:-1]+[counties[0]], "maakond")]:
            with self.assertRaises(ValueError):
                land.estonia_physical_land(features, box(23, 57, 27, 59), source_layer=layer)

    def test_estonia_cached_reference_requires_independent_role_and_hashes(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            original = cache / "counties.json"
            original.write_text("{}", encoding="utf-8")
            dependency = {"cache_file": original.name, "bytes": original.stat().st_size,
                          "sha256": hashlib.sha256(original.read_bytes()).hexdigest()}
            output = cache / "ee.geojson"
            output.write_text(json.dumps(mapping(box(24, 58, 25, 59))), encoding="utf-8")
            source = {"country": "EE", "source_type": "estonia-physical-land", "source_layer": "maakond",
                      "coastline_product": "ETAK:eesti_mask", "county_codes": ["0037", "0039", "0045", "0050", "0052", "0056", "0060", "0064", "0068", "0071", "0074", "0079", "0081", "0084", "0087"],
                      "independent_of_target_municipalities": True, "input_files": [dependency],
                      "cache_file": output.name, "bytes": output.stat().st_size,
                      "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}
            self.assertIn("EE", land.load_references(cache, [source]))
            with self.assertRaises(ValueError):
                land.load_references(cache, [{**source, "source_layer": "omavalitsus"}])
            original.write_text("[]", encoding="utf-8")
            with self.assertRaises(ValueError):
                land.load_references(cache, [source])

    def test_estonia_legacy_wkt_requires_explicit_code_and_original_projection_parameters(self):
        wkt = 'PROJCS["Estonia_1997_Estonia_National_Grid",GEOGCS["GCS_Estonia_1997",DATUM["D_Estonia_1997",SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Lambert_Conformal_Conic"],PARAMETER["False_Easting",500000.0],PARAMETER["False_Northing",6375000.0],PARAMETER["Central_Meridian",24.0],PARAMETER["Standard_Parallel_1",58.0],PARAMETER["Standard_Parallel_2",59.33333333333334],PARAMETER["Latitude_Of_Origin",57.51755393055556],UNIT["Meter",1.0],AUTHORITY["EPSG",3301]]'
        self.assertEqual(land.estonia_source_epsg(wkt), 3301)
        for invalid in [wkt.replace('EPSG",3301', 'EPSG",4326'), wkt.replace('6375000.0', '5000000.0'), wkt.replace('298.257222101', '298.3')]:
            with self.assertRaises(ValueError):
                land.estonia_source_epsg(invalid)

    def test_channel_islands_reference_keeps_whole_independent_physical_islands(self):
        features = [{"id": i, "properties": {"FID": i}, "geometry": mapping(g)}
                    for i, g in enumerate([box(-2.6, 49.4, -2.5, 49.5), box(-2.4, 49.6, -2.39, 49.61), box(-1.9, 48.9, -1.89, 48.91)])]
        frame = box(-2.8, 49.3, -2.1, 49.8)
        geometry = land.channel_islands_physical_land(features, frame, country="GG")
        self.assertAlmostEqual(geometry.area, .0101)
        self.assertEqual(len(geometry.geoms), 2)
        # Crossing an island with an arbitrary territorial cut must fail,
        # rather than manufacturing a favourable continental/coastal chip.
        with self.assertRaises(ValueError):
            land.channel_islands_physical_land(features, box(-2.55, 49.3, -2.1, 49.8), country="GG")
        with self.assertRaises(ValueError):
            land.channel_islands_physical_land(features, frame, country="FR")

    def test_channel_islands_missing_duplicate_or_continental_geometry_is_rejected(self):
        feature = {"id": 1, "properties": {"FID": 1}, "geometry": mapping(box(-2.6, 49.4, -2.5, 49.5))}
        frame = box(-2.8, 49.3, -2.1, 49.8)
        for features in [[feature, feature], [{**feature, "geometry": None}],
                         [{**feature, "geometry": mapping(box(-10, 40, 30, 60))}]]:
            with self.assertRaises(ValueError):
                land.channel_islands_physical_land(features, frame, country="GG")

    def test_channel_islands_country_frame_requires_original_iso_and_snapshot_members(self):
        stamp = "2026-11-07T12:00:00Z"
        elements = [{"type": "node", "id": i+1, "version": 1, "timestamp": stamp, "lon": xy[0], "lat": xy[1]}
                    for i, xy in enumerate([(-2.8, 49.3), (-2.1, 49.3), (-2.1, 49.8), (-2.8, 49.8)])]
        elements += [{"type": "way", "id": 10, "version": 1, "timestamp": stamp, "nodes": [1, 2, 3, 4, 1]},
                     {"type": "relation", "id": 270009, "version": 69, "timestamp": stamp,
                      "tags": {"ISO3166-1": "GG", "admin_level": "2", "boundary": "administrative", "type": "boundary"},
                      "members": [{"type": "way", "ref": 10, "role": "outer"}]}]
        payload = {"elements": elements}
        geometry = land.channel_islands_country_frame(payload, country="GG")
        self.assertAlmostEqual(geometry.area, .35)
        with self.assertRaises(ValueError):
            land.channel_islands_country_frame(payload, country="JE")
        with self.assertRaises(ValueError):
            land.channel_islands_country_frame({"elements": [{**e, "timestamp": "2026-11-09T12:00:00Z"} for e in elements]}, country="GG")

    def test_channel_islands_cached_land_requires_country_frame_role_and_input_integrity(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            original = cache / "coastline.json"; original.write_text("{}", encoding="utf-8")
            dependency = {"cache_file": original.name, "bytes": original.stat().st_size,
                          "sha256": hashlib.sha256(original.read_bytes()).hexdigest()}
            output = cache / "je.geojson"; output.write_text(json.dumps(mapping(box(-2.2, 49.1, -2.1, 49.2))), encoding="utf-8")
            source = {"country": "JE", "source_type": "eea-physical-islands", "physical_product": "EEA:coastline2017-v3",
                      "territorial_frame": {"ISO3166-1": "JE", "admin_level": 2, "relation_id": 367988},
                      "independent_of_target_municipalities": True, "input_files": [dependency],
                      "cache_file": output.name, "bytes": output.stat().st_size,
                      "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}
            self.assertIn("JE", land.load_references(cache, [source]))
            with self.assertRaises(ValueError):
                land.load_references(cache, [{**source, "territorial_frame": {"ISO3166-1": "JE", "admin_level": 8}}])
            original.write_text("[]", encoding="utf-8")
            with self.assertRaises(ValueError):
                land.load_references(cache, [source])

    def test_national_physical_land_excludes_actual_water_but_preserves_wetland_and_glacier(self):
        frame = box(43, 39, 47, 42)
        physical = box(44, 39, 47, 42)  # Independently excludes the marine side.
        water = [{"properties": {"osm_id": "36956", "fclass": "water", "code": 8200},
                  "geometry": mapping(box(45, 40, 46, 41))},
                 {"properties": {"osm_id": "w2", "fclass": "wetland", "code": 8220},
                  "geometry": mapping(box(44, 39, 45, 40))},
                 {"properties": {"osm_id": "g1", "fclass": "glacier", "code": 8211},
                  "geometry": mapping(box(46, 41, 47, 42))}]
        original = json.dumps(water, sort_keys=True)
        geometry = land.national_physical_land(frame, physical, water, country="AM")
        self.assertAlmostEqual(geometry.area, 8)
        self.assertEqual(json.dumps(water, sort_keys=True), original)
        self.assertTrue(geometry.covers(box(44.1, 39.1, 44.9, 39.9)))
        self.assertTrue(geometry.covers(box(46.1, 41.1, 46.9, 41.9)))

    def test_national_water_geometry_is_never_repaired_or_guessed(self):
        properties = {"osm_id": "36956", "fclass": "water", "code": 8200}
        invalid = {"type": "Polygon", "coordinates": [[[44, 40], [46, 41], [44, 41], [46, 40], [44, 40]]]}
        for feature in [{"properties": properties, "geometry": None}, {"properties": properties, "geometry": invalid},
                        {"properties": {**properties, "code": 8220}, "geometry": mapping(box(44, 40, 45, 41))}]:
            with self.assertRaises(ValueError):
                land.national_physical_land(box(43, 39, 47, 42), box(43, 39, 47, 42), [feature], country="AM")

    def test_detailed_national_frame_requires_independent_original_iso_and_complete_boundary(self):
        stamp = "2026-11-06T12:00:00Z"
        nodes = [{"type": "node", "id": i+1, "version": 1, "timestamp": stamp, "lon": xy[0], "lat": xy[1]}
                 for i, xy in enumerate([(43, 39), (47, 39), (47, 42), (43, 42)])]
        way = {"type": "way", "id": 10, "version": 1, "timestamp": stamp, "nodes": [1, 2, 3, 4, 1]}
        relation = {"type": "relation", "id": 364066, "version": 441, "timestamp": stamp,
                    "tags": {"ISO3166-1": "AM", "admin_level": "2", "boundary": "administrative", "type": "boundary"},
                    "members": [{"type": "way", "ref": 10, "role": "outer"}]}
        payload = {"elements": [*nodes, way, relation]}
        self.assertAlmostEqual(land.detailed_national_frame(payload, country="AM").area, 12)
        with self.assertRaises(ValueError):
            land.detailed_national_frame(payload, country="IL")
        with self.assertRaises(ValueError):
            land.detailed_national_frame({"elements": [*nodes, {**way, "nodes": [1, 2, 3]}, relation]}, country="AM")

    def test_detailed_physical_reference_requires_separate_frame_water_and_all_hashes(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            raw = cache / "water.shp"; raw.write_bytes(b"original physical water")
            output = cache / "am.geojson"; output.write_text(json.dumps(mapping(box(44, 40, 45, 41))), encoding="utf-8")
            source = {"country": "AM", "source_type": "national-physical-land",
                      "physical_product": "NaturalEarth:10m_land:v5.1.2", "water_product": "Geofabrik:gis_osm_water_a_free",
                      "national_frame": {"ISO3166-1": "AM", "admin_level": 2, "relation_id": 364066, "relation_version": 441},
                      "independent_of_target_municipalities": True, "cache_file": output.name, "bytes": output.stat().st_size,
                      "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
                      "input_files": [{"cache_file": raw.name, "bytes": raw.stat().st_size, "sha256": hashlib.sha256(raw.read_bytes()).hexdigest()}]}
            self.assertIn("AM", land.load_references(cache, [source]))
            with self.assertRaises(ValueError):
                land.load_references(cache, [{**source, "water_product": "target municipality union"}])
            raw.write_bytes(b"modified")
            with self.assertRaises(ValueError):
                land.load_references(cache, [source])

    def test_conservative_reference_never_changes_the_existing_national_assignment(self):
        original = box(44, 39, 46, 41)
        countries = {"features": [{"properties": {"ISO_A2": "AM", "ADMIN": "Armenia"}, "geometry": mapping(original)},
                                  {"properties": {"ISO_A2": "AZ", "ADMIN": "Azerbaijan"}, "geometry": mapping(box(46, 39, 47, 41))}]}
        physical = box(43, 38, 48, 42)
        water = [{"properties": {"osm_id": "36956", "fclass": "water", "code": 8200},
                  "geometry": mapping(box(45, 40, 45.5, 40.5))}]
        geometry = land.conservative_physical_land(countries, physical, water, country="AM")
        self.assertAlmostEqual(geometry.area, 3.75)
        self.assertTrue(original.covers(geometry))
        with self.assertRaises(ValueError):
            land.conservative_physical_land({"features": countries["features"]*2}, physical, water, country="AM")

    def test_conservative_cached_reference_requires_original_ne_territorial_policy(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            original = cache / "country.json"; original.write_text("{}", encoding="utf-8")
            output = cache / "land.geojson"; output.write_text(json.dumps(mapping(box(44, 40, 45, 41))), encoding="utf-8")
            source = {"country": "AM", "source_type": "ne-territorial-physical-land",
                      "physical_product": "NaturalEarth:10m_land:v5.1.2", "water_product": "Geofabrik:gis_osm_water_a_free",
                      "national_frame": {"ISO3166-1": "AM", "product": "NaturalEarth:admin0:v5.1.2", "territorial_policy": "original-reference-unchanged"},
                      "independent_of_target_municipalities": True, "cache_file": output.name, "bytes": output.stat().st_size,
                      "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
                      "input_files": [{"cache_file": original.name, "bytes": original.stat().st_size, "sha256": hashlib.sha256(original.read_bytes()).hexdigest()}]}
            self.assertIn("AM", land.load_references(cache, [source]))
            with self.assertRaises(ValueError):
                land.load_references(cache, [{**source, "national_frame": {"ISO3166-1": "AM", "product": "OSM current national claims"}}])


if __name__ == "__main__":
    unittest.main()
