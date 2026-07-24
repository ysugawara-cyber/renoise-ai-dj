import io
import sys
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "host/osc"))

import verify_roundtrip  # noqa: E402


class VerifyRoundtripTest(unittest.TestCase):
    def test_refuses_incomplete_state(self):
        baseline = {
            "bpm": 180.0,
            "renoise_heartbeat": int(time.time()),
            "tracks": {"1": {"mute": False}},
        }
        with patch.object(verify_roundtrip, "read_state", return_value=baseline), \
             patch.object(verify_roundtrip, "send") as send:
            with redirect_stdout(io.StringIO()):
                self.assertEqual(verify_roundtrip.run(), 2)
            send.assert_not_called()

    def test_refuses_fractional_bpm(self):
        baseline = {
            "bpm": 174.5,
            "renoise_heartbeat": int(time.time()),
            "tracks": {"1": {"mute": False, "solo": False, "volume": 0.75}},
        }
        with patch.object(verify_roundtrip, "read_state", return_value=baseline), \
             patch.object(verify_roundtrip, "send") as send:
            with redirect_stdout(io.StringIO()):
                self.assertEqual(verify_roundtrip.run(), 2)
            send.assert_not_called()

    def test_restores_all_state_after_exception(self):
        baseline = {
            "bpm": 180.0,
            "renoise_heartbeat": int(time.time()),
            "tracks": {"1": {"mute": True, "solo": True, "volume": 0.75}},
        }
        sent = []

        def record(path, *args):
            sent.append((path, args))
            return True

        with patch.object(verify_roundtrip, "read_state", return_value=baseline), \
             patch.object(verify_roundtrip, "send", side_effect=record), \
             patch.object(verify_roundtrip, "wait_for", side_effect=RuntimeError("boom")):
            with redirect_stdout(io.StringIO()), self.assertRaises(RuntimeError):
                verify_roundtrip.run()

        self.assertIn(("/ai/bpm", (180,)), sent)
        self.assertIn(("/ai/mixer/mute", ("1", 1)), sent)
        self.assertIn(("/ai/mixer/solo", ("1", 1)), sent)
        self.assertIn(("/ai/mixer/volume", ("1", 750)), sent)


if __name__ == "__main__":
    unittest.main()
