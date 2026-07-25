import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "tools/AIDJ/validate_dryrun.lua"


@unittest.skipUnless(shutil.which("lua5.4"), "lua5.4 is not installed")
class ValidateDryrunTest(unittest.TestCase):
    def run_fixture(self, name):
        return subprocess.run(
            ["lua5.4", str(VALIDATOR), str(ROOT / "tests/fixtures" / name)],
            capture_output=True,
            text=True,
        )

    def test_valid_syntax(self):
        self.assertEqual(self.run_fixture("valid.lua").returncode, 0)

    def test_syntax_error(self):
        self.assertEqual(self.run_fixture("syntax_error.lua").returncode, 1)

    def test_forbidden_token(self):
        self.assertEqual(self.run_fixture("forbidden.lua").returncode, 1)


if __name__ == "__main__":
    unittest.main()
