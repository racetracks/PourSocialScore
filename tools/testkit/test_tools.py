#!/usr/bin/env python3
"""TestKit tool tests TK-UT-21 to TK-UT-23 (TK-A-105). stdlib unittest."""
import glob
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures")


def run(*args):
    return subprocess.run([sys.executable, *args], capture_output=True, text=True)


class Tools(unittest.TestCase):
    def test_ut21_make_string_matches_example(self):
        with tempfile.TemporaryDirectory() as d:
            r = run(os.path.join(HERE, "make_string.py"), os.path.join(FIX, "example-build.json"),
                    "--out", d, "--check")
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertRegex(r.stdout, r"^3\.9\.0\.156-1: 2 checks, \d+ chars\n$")
            with open(os.path.join(d, "3.9.0.156-1.txt"), "rb") as a, \
                    open(os.path.join(FIX, "example.txt"), "rb") as b:
                self.assertEqual(a.read(), b.read())

    def test_ut22_registry_miss(self):
        with tempfile.TemporaryDirectory() as d:
            reg = os.path.join(d, "REGISTRY.md")
            with open(reg, "w") as f:
                f.write("CHK-00226 CHK-00219\n")
            r = run(os.path.join(HERE, "make_string.py"), os.path.join(FIX, "bad", "unregistered-key.json"),
                    "--out", d, "--registry", reg)
            self.assertEqual(r.returncode, 1)
            self.assertEqual(r.stdout.strip(), "CHK-0000X: not in the registry")

    def test_ut23_bad_fixtures(self):
        files = sorted(glob.glob(os.path.join(FIX, "bad", "*.json")))
        self.assertGreater(len(files), 0)
        for p in files:
            r = run(os.path.join(HERE, "check_strings.py"), p)
            self.assertEqual(r.returncode, 1, p)
            self.assertTrue(r.stdout.startswith(p + ": "), r.stdout)
        good = glob.glob(os.path.join(FIX, "*.json")) + [os.path.join(FIX, "example.txt")]
        r = run(os.path.join(HERE, "check_strings.py"), *good)
        self.assertEqual((r.returncode, r.stdout), (0, ""))


if __name__ == "__main__":
    res = unittest.main(exit=False, verbosity=0).result
    if not res.wasSuccessful():
        sys.exit(1)
    print("test_tools: ok")
