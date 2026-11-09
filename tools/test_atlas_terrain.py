import unittest

from build_atlas_terrain import pixel_bounds


class TerrainGeoreferenceTest(unittest.TestCase):
    def test_europe_corners_match_existing_map_projection(self):
        self.assertEqual(pixel_bounds((21600, 10800), (-12, 33, 52, 72)), (10080, 1080, 13920, 3420))

    def test_full_world_does_not_lose_a_border_pixel(self):
        self.assertEqual(pixel_bounds((21600, 10800), (-180, -90, 180, 90)), (0, 0, 21600, 10800))

    def test_reversed_geographic_bounds_are_rejected(self):
        with self.assertRaises(ValueError):
            pixel_bounds((21600, 10800), (52, 72, -12, 33))


if __name__ == "__main__":
    unittest.main()
