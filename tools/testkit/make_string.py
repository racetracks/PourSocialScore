#!/usr/bin/env python3
"""TestKit string writer (TK-A-101). Python 3 stdlib only."""
import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
CODEC = os.path.normpath(os.path.join(HERE, "..", "..", "PSS_TestKit", "PSS_TK_Codec.lua"))

DRIVER = r'''
local codec, file = arg[1], arg[2]
local f = assert(io.open(file, "rb"))
local text = f:read("*a")
f:close()
local TK = { N = 1 }
assert(loadfile(codec))(nil, TK)
local env, err = TK.Decode(text)
if not env then
	io.write("ERR\t", err, "\n")
	os.exit(0)
end
local function hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end
local out = {}
local function walk(v, p)
	local t = type(v)
	if t == "table" then
		if next(v) == nil then out[#out + 1] = p .. "\tempty"; return end
		for k, x in pairs(v) do
			if type(k) == "number" then walk(x, p .. "[" .. k .. "]") else walk(x, p .. "." .. k) end
		end
	elseif t == "string" then
		out[#out + 1] = p .. "\ts" .. hex(v)
	elseif t == "number" then
		out[#out + 1] = p .. "\tn" .. string.format("%.14g", v)
	else
		out[#out + 1] = p .. "\tb" .. tostring(v)
	end
end
walk(env, "")
io.write("OK\n")
for i = 1, #out do io.write(out[i], "\n") end
'''


def encode(env):
    payload = json.dumps(env, separators=(",", ":"), sort_keys=True, ensure_ascii=False).encode("utf-8")
    b64 = base64.b64encode(payload).decode("ascii")
    return payload, "!PSSTK1!" + b64 + "!" + format(zlib.adler32(payload) & 0xFFFFFFFF, "08x")


def flatten(v, p, out):
    if isinstance(v, dict):
        if not v:
            out[p] = "empty"
        for k, x in v.items():
            flatten(x, p + "." + k, out)
    elif isinstance(v, list):
        if not v:
            out[p] = "empty"
        for i, x in enumerate(v):
            flatten(x, p + "[" + str(i + 1) + "]", out)
    elif isinstance(v, bool):
        out[p] = "b" + ("true" if v else "false")
    elif isinstance(v, (int, float)):
        out[p] = "n" + ("%.14g" % v)
    else:
        out[p] = "s" + v.encode("utf-8").hex()


def decode(text):
    """Run the kit decoder. Returns (error text or None, {path: value})."""
    with tempfile.TemporaryDirectory() as d:
        drv = os.path.join(d, "drv.lua")
        txt = os.path.join(d, "s.txt")
        with open(drv, "w") as f:
            f.write(DRIVER)
        with open(txt, "w", encoding="utf-8") as f:
            f.write(text)
        r = subprocess.run(["lua5.1", drv, CODEC, txt], capture_output=True, text=True)
    if r.returncode != 0:
        return "lua5.1 failed: " + r.stderr.strip(), {}
    lines = r.stdout.split("\n")
    if lines[0].startswith("ERR\t"):
        return lines[0][4:], {}
    got = {}
    for ln in lines[1:]:
        if ln:
            p, _, v = ln.partition("\t")
            got[p] = v
    return None, got


def build_env(src):
    """File envelope to string envelope: add fmt and id, drop run."""
    env = dict(src)
    run = env.pop("run", 1)
    env["fmt"] = 1
    env["id"] = "%s-%s" % (env.get("build"), run)
    return env


def make(src, registry=None):
    """Returns (id, text, error). error is None on success."""
    if registry is not None:
        with open(registry, encoding="utf-8") as f:
            reg = f.read()
        for c in src.get("checks", []) if isinstance(src.get("checks"), list) else []:
            k = c.get("key") if isinstance(c, dict) else None
            if isinstance(k, str) and k not in reg:
                return None, None, "%s: not in the registry" % k
    env = build_env(src)
    payload, text = encode(env)
    err, got = decode(text)
    if err:
        return None, None, err
    return env["id"], text, None, env, got


def main(argv):
    ap = argparse.ArgumentParser(prog="make_string.py")
    ap.add_argument("build_file")
    ap.add_argument("--out", required=True)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--registry")
    a = ap.parse_args(argv)
    with open(a.build_file, encoding="utf-8") as f:
        src = json.load(f)
    res = make(src, a.registry)
    if res[2]:
        print(res[2])
        return 1
    ident, text, _, env, got = res
    if a.check:
        want = {}
        flatten(env, "", want)
        for p in sorted(set(want) | set(got)):
            if want.get(p) != got.get(p):
                print("round trip differs at " + (p.lstrip(".") or "envelope"))
                return 1
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, ident + ".txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text + "\n")
    print("%s: %d checks, %d chars" % (ident, len(env["checks"]), len(text)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
