import importlib
import json
from pathlib import Path
import tempfile
import unittest

try:
    module = importlib.import_module("atlas_osm_sources")
except ModuleNotFoundError:
    module = None


def way(identifier, points, role="outer"):
    return {"type": "way", "ref": identifier, "role": role,
            "geometry": [{"lon": x, "lat": y} for x, y in points]}


def relation(identifier=123, country="RU", level="8", **changes):
    row = {"type": "relation", "id": identifier, "version": 3,
           "timestamp": "2026-01-01T00:00:00Z",
           "tags": {"type": "boundary", "boundary": "administrative", "admin_level": level,
                    "name": "Verwaltungseinheit", "addr:country": country},
           "members": [way(1, [(30,40),(34,40)]), way(2, [(34,44),(34,40)]),
                       way(3, [(34,44),(30,44)]), way(4, [(30,40),(30,44)])]}
    row.update(changes)
    return row


class OSMReaderTest(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(module, "Der getrennte OSM-Verwaltungsreader fehlt.")

    def test_settlement_polygon_without_administrative_boundary_is_rejected(self):
        row = relation()
        row["tags"] = {"type": "multipolygon", "place": "hamlet", "name": "Dorf"}
        with self.assertRaises(ValueError):
            module.normalize_relation(row, "RU", "test")

    def test_native_local_roles_are_not_flattened_into_belediye(self):
        self.assertEqual(module.role_for("TR", "8", {"name": "İçerenköy Mahallesi"}), ("local_admin", "Mahalle"))
        self.assertEqual(module.role_for("TR", "8", {"name": "Örnek Köyü"}), ("local_admin", "Köy"))
        self.assertEqual(module.role_for("TR", "7", {}), ("municipality", "Belde"))
        self.assertEqual(module.role_for("RU", "8", {"official_status": "ru:сельское поселение"}), ("municipality", "сельское поселение"))

    def test_wrong_country_and_unselected_levels_are_rejected(self):
        for row in [relation(country="TR"), relation(level="6")]:
            with self.subTest(row=row):
                with self.assertRaises(ValueError):
                    module.normalize_relation(row, "RU", "test")

    def test_fragmented_reversed_member_ways_form_real_polygon(self):
        record = module.normalize_relation(relation(), "RU", "test")
        self.assertAlmostEqual(record["geometry"].area, 16)
        self.assertEqual(record["id"], "osm:relation:123")
        self.assertEqual(record["osm_record_id"], "r123@3")
        self.assertEqual(record["osm_tags"]["boundary"], "administrative")

    def test_inner_rings_are_preserved_as_holes(self):
        row = relation()
        row["members"].append(way(5, [(31,41),(33,41),(33,43),(31,43),(31,41)], "inner"))
        record = module.normalize_relation(row, "RU", "test")
        self.assertAlmostEqual(record["geometry"].area, 12)
        self.assertEqual(len(record["geometry"].interiors), 1)

    def test_nested_inner_relation_keeps_role_parity(self):
        child = relation(456)
        child["members"] = [way(5, [(31,41),(33,41),(33,43),(31,43),(31,41)])]
        row = relation()
        row["members"].append({"type": "relation", "ref": 456, "role": "inner"})
        record = module.normalize_relation(row, "RU", "test", related={456: child})
        self.assertAlmostEqual(record["geometry"].area, 12)

    def test_island_inside_nested_inner_relation_remains_land(self):
        child = relation(456)
        child["members"] = [way(5, [(31,41),(33,41),(33,43),(31,43),(31,41)]),
                            way(6, [(31.5,41.5),(32.5,41.5),(32.5,42.5),(31.5,42.5),(31.5,41.5)], "inner")]
        row = relation()
        row["members"].append({"type": "relation", "ref": 456, "role": "inner"})
        record = module.normalize_relation(row, "RU", "test", related={456: child})
        self.assertAlmostEqual(record["geometry"].area, 13)
        from shapely.geometry import Point
        self.assertTrue(record["geometry"].covers(Point(32,42)), "Die Insel darf nicht mit dem Loch verschwinden.")

    def test_missing_member_geometry_is_reported_instead_of_invented(self):
        row = relation()
        del row["members"][1]["geometry"]
        with self.assertRaises(ValueError):
            module.normalize_relation(row, "RU", "test")

    def test_open_outer_chain_and_external_hole_are_rejected(self):
        opened = relation()
        opened["members"].pop()
        external = relation()
        external["members"].append(way(5, [(35,41),(36,41),(36,42),(35,42),(35,41)], "inner"))
        for row in [opened, external]:
            with self.assertRaises(ValueError):
                module.normalize_relation(row, "RU", "test")

    def test_bbox_clipping_does_not_fill_inner_ring(self):
        row = relation()
        row["members"].append(way(5, [(31,41),(33,41),(33,43),(31,43),(31,41)], "inner"))
        record = module.normalize_relation(row, "RU", "test", bounds=(30,40,33,44))
        self.assertAlmostEqual(record["geometry"].area, 8)

    def test_source_cache_is_reusable_offline_and_detects_changed_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = module.OverpassCache(Path(directory))
            payload = json.dumps({"osm3s": {"timestamp_osm_base": "2026-01-01T00:00:00Z"}, "elements": []}).encode()
            _, receipt = cache.request("sample", fetch=lambda query: payload)
            import hashlib
            self.assertEqual(receipt["query_sha256"], hashlib.sha256(b"sample").hexdigest())
            def unavailable(query):
                raise RuntimeError("offline")
            loaded, again = cache.request("sample", fetch=unavailable)
            self.assertEqual(loaded["elements"], [])
            self.assertEqual(receipt["sha256"], again["sha256"])
            (Path(directory) / receipt["path"]).write_bytes(b"changed")
            with self.assertRaises(ValueError):
                cache.request("sample", fetch=unavailable)

    def test_nested_requests_cannot_bypass_single_active_provider_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            with module.provider_lock(Path(directory)):
                with self.assertRaises(RuntimeError):
                    with module.provider_lock(Path(directory)):
                        self.fail("Eine zweite Provideranfrage wurde zugelassen.")

    def test_configured_provider_has_separate_cache_and_honest_receipt(self):
        import inspect
        self.assertIn("endpoint", inspect.signature(module.OverpassCache).parameters,
                      "Ein explizit konfigurierter Provider fehlt im Rohcachevertrag.")
        with tempfile.TemporaryDirectory() as directory:
            first = module.OverpassCache(Path(directory))
            alternate = module.OverpassCache(Path(directory), endpoint="https://overpass.private.coffee/api/interpreter")
            payload_a = json.dumps({"elements": [], "generator": "provider-a"}).encode()
            payload_b = json.dumps({"elements": [], "generator": "provider-b"}).encode()
            _, receipt_a = first.request("sample", fetch=lambda query: payload_a)
            loaded, receipt_b = alternate.request("sample", fetch=lambda query: payload_b)
            self.assertEqual(loaded["generator"], "provider-b")
            self.assertEqual(receipt_b["url"], "https://overpass.private.coffee/api/interpreter")
            self.assertNotEqual(receipt_a["path"], receipt_b["path"])

    def test_cached_receipt_cannot_change_origin_or_escape_provider_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            cache = module.OverpassCache(directory / "provider")
            payload = json.dumps({"elements": []}).encode()
            _, receipt = cache.request("sample", fetch=lambda query: payload)
            receipt_path = cache.root / Path(receipt["path"]).parent / "receipt.json"
            original = dict(receipt)
            for key, value in [("url", "https://other.invalid"), ("query_sha256", "0" * 64)]:
                with self.subTest(field=key):
                    receipt_path.write_text(json.dumps({**original, key: value}), encoding="utf-8")
                    with self.assertRaises(ValueError):
                        cache.request("sample")
            outside = directory / "outside.json"
            outside.write_bytes(payload)
            receipt_path.write_text(json.dumps({**original, "path": str(outside)}), encoding="utf-8")
            with self.assertRaises(ValueError):
                cache.request("sample")

    def test_full_api_member_nodes_form_actual_geometry_at_fixed_snapshot(self):
        self.assertTrue(callable(getattr(module, "full_geometry_relations", None)),
                        "Der begrenzte OSM-API-Geometriedecoder fehlt.")
        row = relation()
        nodes, ways = [], []
        for member in row["members"]:
            node_ids = []
            for point in member.pop("geometry"):
                identifier = len(nodes) + 1
                node_ids.append(identifier)
                nodes.append({"type": "node", "id": identifier, "version": 1,
                              "timestamp": "2026-01-01T00:00:00Z", **point})
            ways.append({"type": "way", "id": member["ref"], "nodes": node_ids,
                         "version": 2, "timestamp": "2026-01-02T00:00:00Z"})
        payload = {"elements": [*nodes, *ways, row]}
        related = module.full_geometry_relations(payload, "2026-01-03T00:00:00Z")
        record = module.normalize_relation(related[123], "RU", "api", related=related)
        self.assertAlmostEqual(record["geometry"].area, 16)
        with self.assertRaisesRegex(ValueError, "snapshot"):
            module.full_geometry_relations(payload, "2026-01-01T00:00:00Z")
        nodes.pop()
        with self.assertRaisesRegex(ValueError, "node"):
            module.full_geometry_relations({"elements": [*nodes, *ways, row]}, "2026-01-03T00:00:00Z")

    def test_full_api_response_cache_retains_exact_source_url_and_bytes(self):
        self.assertTrue(callable(getattr(module.OverpassCache, "request_url", None)),
                        "Ein unveränderlicher Cache für den expliziten API-Fallback fehlt.")
        with tempfile.TemporaryDirectory() as directory:
            cache = module.OverpassCache(Path(directory))
            url = "https://api.openstreetmap.org/api/0.6/relation/123/full.json"
            payload = json.dumps({"elements": []}).encode()
            _, receipt = cache.request_url(url, fetch=lambda address: payload)
            def unavailable(address):
                self.fail("Offlinewiederholung darf keine neue Anfrage starten.")
            loaded, again = cache.request_url(url, fetch=unavailable)
            self.assertEqual(loaded["elements"], [])
            self.assertEqual(again["url"], url)
            self.assertEqual(receipt["sha256"], module.sha256(payload))

    def test_bounded_pilot_uses_preverified_metadata_and_real_member_cache(self):
        import inspect
        from unittest.mock import patch
        self.assertIn("geometry_provider", inspect.signature(module.prepare_sources).parameters,
                      "Der explizite, begrenzte API-Geometrieweg fehlt.")
        self.assertTrue(callable(getattr(module, "pilot_metadata_query", None)))
        self.assertFalse(module.pilot_metadata_query("TR").endswith("\n\n"),
                         "Die Import-QL muss exakt die eine aufgezeichnete Schlusszeile behalten.")
        snapshot = "2026-01-03T00:00:00Z"
        root = relation(1306580)
        root["members"] = [{"type": "way", "ref": 1, "role": "outer"}]
        nodes = [{"type": "node", "id": i+1, "version": 1, "timestamp": "2026-01-01T00:00:00Z",
                  "lon": p[0], "lat": p[1]} for i,p in enumerate([(30,40),(34,40),(34,44),(30,44)])]
        full = {"elements": [*nodes, {"type": "way", "id": 1, "version": 1,
                                  "timestamp": "2026-01-01T00:00:00Z", "nodes": [1,2,3,4,1]}, root]}
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            store = module.OverpassCache(directory / "osm-administration")
            metadata = {"osm3s": {"timestamp_osm_base": snapshot}, "elements": [root, relation(999)]}
            store.request(module.pilot_metadata_query("RU"), fetch=lambda q: json.dumps(metadata).encode())
            store.request_url("https://api.openstreetmap.org/api/0.6/relation/1306580/full.json",
                              fetch=lambda u: json.dumps(full).encode())
            with patch.object(module, "MANIFEST", directory / "manifest.json"), \
                 patch.object(module.subprocess, "run", side_effect=AssertionError("Unexpected network request")):
                sources = module.prepare_sources(directory, countries=("RU",), geometry_provider="osm-api", max_relations=6)
                records = list(module.iter_boundaries(directory, sources))
                store.request(module.pilot_metadata_query("TR"), fetch=lambda q: json.dumps({
                    "osm3s": {"timestamp_osm_base": snapshot}, "elements": []}).encode())
                module.prepare_sources(directory, countries=("TR",), geometry_provider="osm-api", max_relations=6)
                manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual([row["id"] for row in records], ["osm:relation:1306580"])
            self.assertAlmostEqual(records[0]["geometry"].area, 16)
            self.assertEqual(sources[0]["metadata_unit_count"], 2)
            self.assertEqual(sources[0].get("pending_geometry_count"), 1,
                             "Metadaten ohne gelesene Geometrie müssen ausdrücklich offen bleiben.")
            self.assertEqual(sources[0].get("failed_geometry_count"), 0)
            self.assertIn("RU:pilot", sources[0].get("metadata_selections", []))
            self.assertEqual(sources[0]["replacement_scope"], "feature")
            self.assertTrue(sources[0]["blocks_full_coverage_claim"])
            self.assertEqual({entry["country"] for entry in manifest["sources"]}, {"RU", "TR"},
                             "Ein späterer Länderauftrag darf zuvor vorbereitete Quellen nicht aus dem Manifest entfernen.")

    def test_manifest_failures_are_counted_for_their_actual_administrative_level(self):
        state = {"snapshot": "2026-01-03T00:00:00Z", "prepared": {}, "completed_tiles": [],
                 "metadata": {"123": {"country": "TR", "version": 1, "level": 8}},
                 "failures": {"123": {"country": "TR", "reason": "Missing member geometry"}},
                 "raw_receipts": [], "feature_files": [], "request_failures": {}}
        with tempfile.TemporaryDirectory() as temporary:
            sources = module._sources_from_state(state, Path(temporary), ("TR",))
        self.assertEqual(sources[0]["admin_level"], 7)
        self.assertEqual(sources[0]["failures"], {}, "Ein TR8-Fehler gehört nicht gleichzeitig zu TR7.")
        self.assertEqual(len(sources[1]["failures"]), 1)

    def test_metadata_pass_records_a_tile_without_fetching_or_claiming_its_geometry(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            store = module.OverpassCache(directory / "osm-administration")
            payload = {"osm3s": {"timestamp_osm_base": "2026-01-03T00:00:00Z"}, "elements": [relation()]}
            store.request(module.metadata_query("RU", module.fixed_tiles("RU")[0]),
                          fetch=lambda query: json.dumps(payload).encode())
            with patch.object(module, "MANIFEST", directory / "manifest.json"), \
                 patch.object(module.subprocess, "run", side_effect=AssertionError("Metadata pass fetched geometry")):
                try:
                    sources = module.prepare_sources(directory, mode="metadata", countries=("RU",), max_tiles=1)
                except ValueError as error:
                    self.fail("Ein reiner Metadaten-Kacheldurchlauf fehlt: " + str(error))
            self.assertEqual(sources[0]["prepared_area_count"], 0)
            self.assertEqual(sources[0]["pending_geometry_count"], 1)
            self.assertEqual(sources[0]["metadata_selections"], ["RU:tile-0"])
            self.assertEqual(sources[0]["completed_tiles"], [])
            self.assertTrue(sources[0]["blocks_full_coverage_claim"])


if __name__ == "__main__":
    unittest.main()
