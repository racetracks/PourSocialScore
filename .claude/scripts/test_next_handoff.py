import os
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parent / "next_handoff.py"
MORE = "- +2 more under scratch:temp/ (*/.next/NEXT.md, last 24 h)"


def write(path, session, extra=""):
    path.parent.mkdir(parents=True, exist_ok=True)
    now = time.strftime("%Y-%m-%d %H:%M", time.gmtime())
    path.write_text("# NEXT: step %s\n\nfrom %s · %s UTC · status ready · temp root x\n%s" % (session, session, now, extra), encoding="utf-8")


class Start(unittest.TestCase):
    def run_start(self, root_extra, n):
        with tempfile.TemporaryDirectory() as d:
            sc = pathlib.Path(d)
            write(sc / ".next" / "NEXT.md", "main", root_extra)
            for i in range(n):
                write(sc / ("temp/2026/10/19/10-00-0%d-Mon-s%d/.next/NEXT.md" % (i, i)), "sess%d" % i)
            env = dict(os.environ, PSS_SCRATCH=d)
            r = subprocess.run([sys.executable, str(SCRIPT), "start"], capture_output=True, text=True, env=env)
            return r.stdout

    def test_dedupe(self):
        out = self.run_start("\n## Parallel\n- old row\n", 1)
        self.assertEqual(out.count("\n## Parallel"), 1)
        self.assertNotIn("old row", out)
        self.assertIn("sess0", out)

    def test_cap(self):
        out = self.run_start("", 7)
        tail = out.split("\n## Parallel (")[1].strip().split("\n")[1:]
        self.assertEqual(len(tail), 6)
        self.assertEqual(sum(l.startswith("- ") and "sess" in l for l in tail), 5)
        self.assertEqual(tail[-1], MORE)

    def test_none(self):
        out = self.run_start("", 0)
        self.assertEqual(out.split("\n## Parallel (")[1].strip().split("\n")[1], "None")


if __name__ == "__main__":
    unittest.main()
