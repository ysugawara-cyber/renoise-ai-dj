import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "host/osc"))

from directive_queue import ack_directives, claim_directives, publish_directive


class DirectiveQueueTest(unittest.TestCase):
    def test_publishes_and_consumes_fifo(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            publish_directive(["tui2"], "first", root)
            publish_directive(["tui2"], "second", root)
            token, body = claim_directives("tui2", root)
            self.assertEqual(body, "first\n\nsecond")
            self.assertEqual(claim_directives("tui2", root), (token, body))
            ack_directives("tui2", token, root)
            self.assertEqual(claim_directives("tui2", root), ("", ""))

    def test_publishes_to_multiple_targets(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            publish_directive(["tui1", "tui3"], "drop", root)
            self.assertEqual(claim_directives("tui1", root)[1], "drop")
            self.assertEqual(claim_directives("tui3", root)[1], "drop")

    def test_consumes_legacy_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            root.mkdir(exist_ok=True)
            (root / "tui2.md").write_text("legacy", encoding="utf-8")
            self.assertEqual(claim_directives("tui2", root)[1], "legacy")

    def test_rejects_unknown_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                publish_directive(["tui4"], "bad", Path(tmp))

    def test_recovers_interrupted_claim(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            interrupted = root / ".inflight/tui2/.deadbeef.tmp"
            interrupted.mkdir(parents=True)
            (interrupted / "00000000000000000001_a.md").write_text(
                "recovered", encoding="utf-8"
            )
            self.assertEqual(claim_directives("tui2", root)[1], "recovered")

    def test_discards_empty_batch_without_blocking_queue(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            empty = root / ".inflight/tui2/00000000000000000000000000000000"
            empty.mkdir(parents=True)
            publish_directive(["tui2"], "next", root)
            self.assertEqual(claim_directives("tui2", root)[1], "next")


if __name__ == "__main__":
    unittest.main()
