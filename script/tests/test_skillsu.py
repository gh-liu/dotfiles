"""Isolated regression tests: python3 -m unittest discover -s script/tests."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "xdg_config/bin/skillsu"
LOCAL_SKILLS = SCRIPT.resolve().parent / "../agents/skills"


class SkillsuTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls"
        self.config = self.root / "custom agent"
        self.link = self.home / ".pi/agent/skills"
        self.env = dict(os.environ, HOME=str(self.home),
                        PI_CODING_AGENT_DIR=str(self.config),
                        PATH=f"{self.bin}:/usr/bin:/bin", CALLS=str(self.log))
        self.env.pop("FAIL_SOURCE", None)
        mock = self.bin / "skills"
        mock.write_text('#!/bin/bash\n'
                        'printf "%s\\n" "$*" >> "$CALLS"\n'
                        'if [[ $2 == ${FAIL_SOURCE:-} ]]; then exit 42; fi\n')
        mock.chmod(0o755)

    def run_script(self, *args, cwd=None):
        return subprocess.run(["/bin/bash", str(SCRIPT), *args], env=self.env,
                              cwd=cwd, capture_output=True, text=True)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_default_adds_only_selected_skills_and_keeps_unrelated(self):
        unrelated = self.config / "skills/local/SKILL.md"
        unrelated.parent.mkdir(parents=True)
        unrelated.write_text("keep")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [
            "add obra/superpowers --skill brainstorming -g -y -a pi",
            "add vercel-labs/agent-browser --skill agent-browser -g -y -a pi",
            "add typesafe-ai/skills --skill typesafe-ai -g -y -a pi",
            "add max-sixty/worktrunk --skill worktrunk -g -y -a pi",
        ])
        self.assertEqual(self.link.resolve(), (self.config / "skills").resolve())
        self.assertEqual(unrelated.read_text(), "keep")
        inode = self.link.lstat().st_ino
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.link.lstat().st_ino, inode)

    def test_explicit_agent_syncs_local_skills_and_does_not_change_pi(self):
        self.assertEqual(self.run_script("codex").returncode, 0)
        self.assertEqual(self.calls(), [
            f"add {LOCAL_SKILLS} --skill * -g -y -a codex",
            "add obra/superpowers --skill brainstorming -g -y -a codex",
            "add vercel-labs/agent-browser --skill agent-browser -g -y -a codex",
            "add typesafe-ai/skills --skill typesafe-ai -g -y -a codex",
            "add max-sixty/worktrunk --skill worktrunk -g -y -a codex",
        ])
        self.assertFalse(self.link.exists())
        self.assertFalse(self.config.exists())

    def test_no_custom_directory_uses_default_pi_path(self):
        self.env.pop("PI_CODING_AGENT_DIR")
        self.assertEqual(self.run_script().returncode, 0)
        self.assertFalse(self.link.is_symlink())
        self.assertEqual(len(self.calls()), 4)

    def test_first_install_failure_stops(self):
        self.env["FAIL_SOURCE"] = "obra/superpowers"
        self.assertEqual(self.run_script().returncode, 42)
        self.assertEqual(len(self.calls()), 1)

    def test_last_install_failure_is_returned(self):
        self.env["FAIL_SOURCE"] = "max-sixty/worktrunk"
        self.assertEqual(self.run_script().returncode, 42)
        self.assertEqual(len(self.calls()), 4)

    def test_nonempty_directory_and_regular_file_are_preserved(self):
        self.link.mkdir(parents=True)
        existing = self.link / "SKILL.md"
        existing.write_text("keep")
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(existing.read_text(), "keep")
        existing.unlink()
        self.link.rmdir()
        self.link.write_text("keep file")
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.link.read_text(), "keep file")
        self.assertEqual(self.calls(), [])

    def test_empty_directory_and_stale_symlink_can_be_replaced(self):
        self.link.mkdir(parents=True)
        self.assertEqual(self.run_script().returncode, 0)
        self.assertTrue(self.link.is_symlink())
        self.link.unlink()
        self.link.symlink_to(self.root / "missing")
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.link.resolve(), (self.config / "skills").resolve())

    def test_relative_config_path_produces_absolute_link(self):
        self.env["PI_CODING_AGENT_DIR"] = "relative agent"
        self.assertEqual(self.run_script(cwd=self.root).returncode, 0)
        self.assertEqual(self.link.readlink(), (self.root / "relative agent/skills").resolve())

    def test_directory_creation_failure_stops_before_install(self):
        self.config.write_text("not a directory")
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_missing_cli_and_invalid_usage_have_no_side_effects(self):
        (self.bin / "skills").unlink()
        self.assertEqual(self.run_script().returncode, 127)
        self.assertFalse(self.config.exists())
        self.assertEqual(self.run_script("pi", "codex").returncode, 2)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
