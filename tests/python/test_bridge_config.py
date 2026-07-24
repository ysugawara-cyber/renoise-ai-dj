import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "host/osc"))

import osc_bridge  # noqa: E402


class BridgeConfigTest(unittest.TestCase):
    def test_macro_master_volume_uses_mixer_volume(self):
        old = osc_bridge.MACROS
        try:
            osc_bridge.MACROS = {
                "master_volume": {"target": {"track": "master", "param": "volume"}}
            }
            self.assertEqual(
                osc_bridge._expand_macro("master_volume", 500),
                [("/ai/mixer/volume", ["master", 500])],
            )
        finally:
            osc_bridge.MACROS = old

    def test_unknown_macro_is_rejected_before_dispatch(self):
        old = osc_bridge.MACROS
        try:
            osc_bridge.MACROS = {}
            with self.assertRaisesRegex(ValueError, "unknown or invalid macro"):
                osc_bridge._messages_for_dispatch({
                    "path": "/ai/fx/macro", "args": ["typo", 500]
                })
        finally:
            osc_bridge.MACROS = old

    def test_malformed_status_does_not_mark_dirty(self):
        osc_bridge._status_dirty = False
        with redirect_stdout(io.StringIO()):
            osc_bridge._update_state_from_status(["bad", 1, 0, "[]"])
        self.assertFalse(osc_bridge._status_dirty)

    def test_tool_dir_environment_override(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(
            "os.environ", {"AIDJ_RENOISE_TOOL_DIR": tmp}, clear=False
        ):
            self.assertEqual(osc_bridge._detect_tool_dir(), Path(tmp))

    def test_tool_detection_uses_numeric_version_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            data_dir = Path(tmp) / "user/AppData/Roaming/Renoise"
            old_tool = data_dir / "V3.9/Scripts/Tools/com.aidj.live.xrnx"
            new_tool = data_dir / "V3.10/Scripts/Tools/com.aidj.live.xrnx"
            old_tool.mkdir(parents=True)
            new_tool.mkdir(parents=True)
            with patch.object(
                osc_bridge, "_candidate_renoise_data_dirs", return_value=[data_dir]
            ):
                self.assertEqual(osc_bridge._detect_tool_dir(), new_tool)

    def test_existing_bind_host_is_preserved_without_environment_override(self):
        with tempfile.TemporaryDirectory() as tmp:
            tool_dir = Path(tmp)
            (tool_dir / "osc_bind_host.txt").write_text("0.0.0.0")
            with patch.dict("os.environ", {}, clear=True):
                self.assertEqual(
                    osc_bridge._resolve_renoise_bind_host(tool_dir), "0.0.0.0"
                )

    def test_status_merge_preserves_agent_fields(self):
        old_state, old_lock = osc_bridge.STATE, osc_bridge.LOCK
        try:
            with tempfile.TemporaryDirectory() as tmp:
                osc_bridge.STATE = Path(tmp) / "session.json"
                osc_bridge.LOCK = Path(tmp) / "session.lock"
                osc_bridge.LOCK.touch()
                osc_bridge.STATE.write_text(json.dumps({
                    "tracks": {"1": {"locked_rows": {"0": "tui3"}}},
                    "tui_instances": {"tui3": "dj_live_drums"},
                }))
                osc_bridge._merge_status_into_state({
                    "bpm": 180.0,
                    "active_scene": 2,
                    "play_state": "playing",
                    "tracks": [{"v": 1.41253, "m": 0, "s": 0}],
                    "renoise_heartbeat": 123,
                })
                result = json.loads(osc_bridge.STATE.read_text())
                self.assertEqual(result["tracks"]["1"]["locked_rows"], {"0": "tui3"})
                self.assertEqual(result["tui_instances"], {"tui3": "dj_live_drums"})
                self.assertAlmostEqual(result["tracks"]["1"]["volume"], 1.0)
        finally:
            osc_bridge.STATE, osc_bridge.LOCK = old_state, old_lock


if __name__ == "__main__":
    unittest.main()
