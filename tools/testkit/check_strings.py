#!/usr/bin/env python3
"""TestKit string checker (TK-A-102). Python 3 stdlib only."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_string  # noqa: E402


def check(path):
    try:
        with open(path, encoding="utf-8") as f:
            raw = f.read()
        if path.endswith(".txt"):
            err, _ = make_string.decode(raw)
            return err
        src = json.loads(raw)
        if not isinstance(src, dict):
            return "field envelope: object"
        res = make_string.make(src)
        return res[2]
    except (OSError, ValueError) as e:
        return "unreadable: %s" % e


def main(argv):
    bad = 0
    for p in argv:
        err = check(p)
        if err:
            print("%s: %s" % (p, err))
            bad = 1
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
