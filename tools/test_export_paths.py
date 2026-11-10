"""Export destination guards must agree with Godot's project-relative paths.

These tests never run Godot or a build tool: the fixture has no toolchain.
An existing destination must be rejected before any toolchain lookup.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash") if os.name != "nt" else shutil.which(
    "bash.exe", path=r"C:\Program Files\Git\bin"
)


class ExportDestinationTests(unittest.TestCase):
    def guarded_export(self, kind, explicit):
        self.assertIsNotNone(BASH, "Git Bash / Bash is required to verify export guards")
        with tempfile.TemporaryDirectory(prefix="bq export paths ") as temporary:
            base = Path(temporary)
            project, caller = base / "project with spaces", base / "other cwd"
            project.mkdir()
            caller.mkdir()
            script = project / f"export_{kind}.sh"
            shutil.copyfile(ROOT / script.name, script)
            (project / "project.godot").write_text(
                '[application]\nconfig/version="1.6.1"\n', encoding="utf-8"
            )
            extension = "exe" if kind == "windows" else "apk"
            relative = Path("build/exports") / (
                f"occupied.{extension}" if explicit else f"banger-queens-1.6.1.{extension}"
            )
            target = project / relative
            target.parent.mkdir(parents=True)
            sentinel = b"previous release must remain untouched\x00\xff"
            target.write_bytes(sentinel)
            argv = [BASH, str(script)]
            if explicit == "relative":
                argv.append(relative.as_posix())
            elif explicit == "absolute":
                argv.append(str(target))
            result = subprocess.run(
                argv, cwd=caller, capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=15,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Ausgabedatei existiert bereits", result.stderr, result.stdout + result.stderr)
            self.assertNotIn("Godot fehlt", result.stderr)
            self.assertEqual(target.read_bytes(), sentinel)
            self.assertEqual(sorted(p.name for p in caller.iterdir()), [])

    def test_project_relative_target_is_guarded_from_another_working_directory(self):
        for kind in ("windows", "android"):
            with self.subTest(kind=kind):
                self.guarded_export(kind, "relative")

    def test_absolute_target_with_spaces_is_guarded(self):
        for kind in ("windows", "android"):
            with self.subTest(kind=kind):
                self.guarded_export(kind, "absolute")

    def test_default_versioned_target_is_guarded_from_another_working_directory(self):
        for kind in ("windows", "android"):
            with self.subTest(kind=kind):
                self.guarded_export(kind, False)


if __name__ == "__main__":
    unittest.main()
