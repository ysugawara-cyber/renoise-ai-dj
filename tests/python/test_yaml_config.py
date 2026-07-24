import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]


class YamlConfigTest(unittest.TestCase):
    def test_configs_parse(self):
        for name in ("macros.yaml", "scenes.yaml", "fx_mapping.yaml"):
            data = yaml.safe_load((ROOT / "config" / name).read_text())
            self.assertIsInstance(data, dict, name)

    def test_scene_ids_are_sequential(self):
        data = yaml.safe_load((ROOT / "config/scenes.yaml").read_text())
        self.assertEqual([scene["id"] for scene in data["scenes"]], [1, 2, 3, 4, 5])


if __name__ == "__main__":
    unittest.main()
