import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('listing', ROOT / 'tool/check_listing.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StoreListingTest(unittest.TestCase):
    def test_play_limits(self):
        found = module.sections((ROOT / 'store/listing-tr.md').read_text())
        for key, limit in module.LIMITS.items():
            self.assertTrue(0 < len(found[key]) <= limit, f'{key}: {len(found[key])} > {limit}')

    def test_store_graphics_have_play_sizes(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest('Pillow not installed')
        self.assertEqual(Image.open(ROOT / 'store/icon-512.png').size, (512, 512))
        self.assertEqual(Image.open(ROOT / 'store/feature-graphic.png').size, (1024, 500))
        for shot in (ROOT / 'store/screenshots').rglob('*.png'):
            width, height = Image.open(shot).size
            self.assertTrue(320 <= min(width, height) and max(width, height) <= 2 * min(width, height), shot.name)


if __name__ == '__main__':
    unittest.main()
