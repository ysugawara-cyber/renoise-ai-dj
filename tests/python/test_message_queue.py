import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "host/osc"))

from message_queue import MessageValidationError, queue_message  # noqa: E402


class MessageQueueTest(unittest.TestCase):
    def test_atomic_queue_leaves_only_complete_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            outbox = Path(tmp)
            path = queue_message(outbox, "/ai/bpm", [174.0], "tui4")
            self.assertEqual(list(outbox.glob("*.tmp")), [])
            self.assertEqual(json.loads(path.read_text())["args"], [174])

    def test_rejects_non_integral_float(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(MessageValidationError):
                queue_message(Path(tmp), "/ai/swing", [0.5], "tui4")
            self.assertEqual(list(Path(tmp).glob("*.json")), [])

    def test_rejects_invalid_path_and_nul(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(MessageValidationError):
                queue_message(Path(tmp), "ai/bpm", [174])
            with self.assertRaises(MessageValidationError):
                queue_message(Path(tmp), "/ai/note", ["a\0b"])

    def test_filename_order_survives_clock_regression(self):
        with tempfile.TemporaryDirectory() as tmp, patch(
            "message_queue.time.time_ns", side_effect=[100, 99]
        ):
            outbox = Path(tmp)
            first = queue_message(outbox, "/ai/bpm", [174], "tui4")
            second = queue_message(outbox, "/ai/bpm", [175], "tui4")
            self.assertEqual(sorted((first, second)), [first, second])

    def test_rejects_non_decimal_note_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(MessageValidationError, "decimal row"):
                queue_message(
                    Path(tmp), "/ai/pattern/write",
                    ["1", "Kick Generator", "0A", "C-4", 100, ""], "tui3"
                )

    def test_rejects_track_outside_tui_ownership(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(MessageValidationError):
                queue_message(
                    Path(tmp), "/ai/pattern/write",
                    ["1", "Kick Generator", "0", "C-4", 100, ""], "tui1"
                )

    def test_pattern_write_acquires_session_row_lock(self):
        with tempfile.TemporaryDirectory() as tmp:
            outbox = Path(tmp) / "host/osc/outbox"
            queue_message(
                outbox, "/ai/pattern/write",
                ["1", "Kick Generator", "7", "C-4", 100, ""], "tui3"
            )
            state = json.loads((Path(tmp) / "host/state/session.json").read_text())
            self.assertEqual(state["tracks"]["1"]["locked_rows"]["7"], "tui3")


if __name__ == "__main__":
    unittest.main()
