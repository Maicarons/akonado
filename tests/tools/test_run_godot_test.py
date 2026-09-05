import importlib.util
from pathlib import Path
import unittest
from unittest import mock


SCRIPT_PATH = Path(__file__).resolve().parents[2] / ".github" / "scripts" / "run_godot_test.py"
SPEC = importlib.util.spec_from_file_location("run_godot_test", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
RUN_GODOT_TEST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUN_GODOT_TEST)


class RunGodotTestTests(unittest.TestCase):
    def test_headless_mode_uses_dummy_renderer(self) -> None:
        with mock.patch(
            "sys.argv", ["run_godot_test.py", "--godot", "godot-test", "test.gd"]
        ), mock.patch.object(RUN_GODOT_TEST.subprocess, "run") as run, mock.patch.object(
            RUN_GODOT_TEST.sys.stdout, "write"
        ):
            run.return_value.returncode = 0
            run.return_value.stdout = "PASS"
            self.assertEqual(RUN_GODOT_TEST.main(), 0)

        command = run.call_args.args[0]
        self.assertEqual(command[:2], ["godot-test", "--headless"])
        self.assertEqual(run.call_args.kwargs["timeout"], 120)

    def test_rendering_mode_uses_compatibility_renderer(self) -> None:
        with mock.patch(
            "sys.argv",
            ["run_godot_test.py", "--godot", "godot-test", "--rendering", "test.gd"],
        ), mock.patch.object(RUN_GODOT_TEST.subprocess, "run") as run, mock.patch.object(
            RUN_GODOT_TEST.sys.stdout, "write"
        ):
            run.return_value.returncode = 0
            run.return_value.stdout = "PASS"
            self.assertEqual(RUN_GODOT_TEST.main(), 0)

        command = run.call_args.args[0]
        self.assertEqual(
            command[:5],
            [
                "godot-test",
                "--rendering-method",
                "gl_compatibility",
                "--audio-driver",
                "Dummy",
            ],
        )
        self.assertNotIn("--headless", command)

    def test_timeout_terminates_a_hung_test(self) -> None:
        timeout = RUN_GODOT_TEST.subprocess.TimeoutExpired(
            ["godot-test"], timeout=3, output="partial output\n"
        )
        with mock.patch(
            "sys.argv",
            [
                "run_godot_test.py",
                "--godot",
                "godot-test",
                "--timeout-seconds",
                "3",
                "test.gd",
            ],
        ), mock.patch.object(
            RUN_GODOT_TEST.subprocess, "run", side_effect=timeout
        ), mock.patch.object(
            RUN_GODOT_TEST.sys.stdout, "write"
        ) as stdout, mock.patch.object(
            RUN_GODOT_TEST.sys.stderr, "write"
        ):
            self.assertEqual(RUN_GODOT_TEST.main(), 124)

        stdout.assert_called_once_with("partial output\n")

    def test_non_positive_timeout_is_rejected(self) -> None:
        with mock.patch(
            "sys.argv", ["run_godot_test.py", "--timeout-seconds", "0", "test.gd"]
        ), mock.patch.object(RUN_GODOT_TEST.subprocess, "run") as run, mock.patch.object(
            RUN_GODOT_TEST.sys.stderr, "write"
        ):
            self.assertEqual(RUN_GODOT_TEST.main(), 2)

        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
