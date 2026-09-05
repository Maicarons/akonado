import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT_PATH = (
    Path(__file__).resolve().parents[2] / ".github" / "scripts" / "run_godot_export.py"
)
SPEC = importlib.util.spec_from_file_location("run_godot_export", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
RUN_GODOT_EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUN_GODOT_EXPORT)


class RunGodotExportTests(unittest.TestCase):
    def _run_helper(
        self, output: Path, emitted_output: str, command_status: int
    ) -> subprocess.CompletedProcess[str]:
        command = [
            sys.executable,
            str(SCRIPT_PATH),
            "--cleanup",
            str(output),
            "--",
            sys.executable,
            "-c",
            f"print({emitted_output!r}); raise SystemExit({command_status})",
        ]
        return subprocess.run(
            command,
            cwd=Path.cwd(),
            check=False,
            capture_output=True,
            text=True,
        )

    def test_success_preserves_output(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path.cwd()) as temporary_directory:
            output = Path(temporary_directory) / "build"
            output.mkdir()
            result = self._run_helper(output, "Export complete", 0)
            self.assertEqual(result.returncode, 0)
            self.assertTrue(output.exists())

    def test_hidden_script_error_removes_partial_output(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path.cwd()) as temporary_directory:
            output = Path(temporary_directory) / "build"
            output.mkdir()
            result = self._run_helper(output, "SCRIPT ERROR: export failed", 0)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(output.exists())

    def test_protection_error_removes_partial_output(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path.cwd()) as temporary_directory:
            output = Path(temporary_directory) / "protected.pck"
            output.write_bytes(b"partial")
            result = self._run_helper(
                output, "ERROR: KonadoScript Protection: encryption failed", 0
            )
            self.assertEqual(result.returncode, 1)
            self.assertFalse(output.exists())

    def test_generic_godot_error_removes_partial_output(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path.cwd()) as temporary_directory:
            output = Path(temporary_directory) / "build"
            output.mkdir()
            result = self._run_helper(output, "ERROR: resource failed to load", 0)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(output.exists())

    def test_nonzero_exit_removes_partial_output(self) -> None:
        with tempfile.TemporaryDirectory(dir=Path.cwd()) as temporary_directory:
            output = Path(temporary_directory) / "build"
            output.mkdir()
            result = self._run_helper(output, "Export failed", 7)
            self.assertEqual(result.returncode, 7)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
