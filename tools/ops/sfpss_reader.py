#!/usr/bin/env python3
"""Offline Spyglass reader (search-helper STP-00250). Not shipped.

Reads a WTF SavedVariables file (or a folder of them) without the game and writes the indexes it can rebuild
from saved data as CSV, one file per index:
  log   the block log v2 (PSS_LoggingDB.blockLog groups) and the lines waiting in PourSocialScoreDB.outbox
  pss   the internal log (PSS_LoggingDB.pss, SAV-00078 segments) and the hot ring (PourSocialScoreDB.pssHot)
  sq    the saved queries (PSS_OptionsDB.sqSaved, SAV-00080)

  python3 tools/ops/sfpss_reader.py --counts <file or folder>     one line: log <n> pss <n> sqSaved <n>
  python3 tools/ops/sfpss_reader.py <file or folder> <out dir>      log.csv, pss.csv, sq.csv
"""
import csv
import os
import re
import sys


class LuaParser:
    """The subset of Lua the client writes into SavedVariables: name = value lines, tables, strings, numbers."""

    def __init__(self, text):
        self.s, self.i, self.n = text, 0, len(text)

    def ws(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in ' \t\r\n,;':
                self.i += 1
            elif s.startswith('--', self.i):
                j = s.find('\n', self.i)
                self.i = n if j < 0 else j + 1
            else:
                break

    def string(self):
        q = self.s[self.i]
        self.i += 1
        out = []
        esc = {'n': '\n', 't': '\t', 'r': '\r', '\\': '\\', '"': '"', "'": "'", 'a': '\a', 'b': '\b', 'f': '\f', 'v': '\v'}
        while True:
            c = self.s[self.i]
            if c == q:
                self.i += 1
                return ''.join(out)
            if c == '\\':
                d = self.s[self.i + 1]
                if d.isdigit():
                    m = re.match(r'\d{1,3}', self.s[self.i + 1:self.i + 4])
                    out.append(chr(int(m.group(0))))
                    self.i += 1 + len(m.group(0))
                    continue
                if d == '\n':
                    out.append('\n')
                else:
                    out.append(esc.get(d, d))
                self.i += 2
                continue
            out.append(c)
            self.i += 1

    def value(self):
        self.ws()
        s = self.s
        c = s[self.i]
        if c == '{':
            return self.table()
        if c in '"\'':
            return self.string()
        for word, v in (('true', True), ('false', False), ('nil', None)):
            if s.startswith(word, self.i):
                self.i += len(word)
                return v
        m = re.compile(r'-?(0x[0-9a-fA-F]+|\d+\.?\d*(e[-+]?\d+)?|\.\d+)').match(s, self.i)
        if not m:
            raise ValueError('bad value at %d: %r' % (self.i, s[self.i:self.i + 20]))
        self.i = m.end()
        t = m.group(0)
        if 'x' in t:
            return int(t, 16)
        v = float(t)
        return int(v) if v == int(v) and '.' not in t and 'e' not in t else v

    def table(self):
        self.i += 1
        t, k = {}, 1
        while True:
            self.ws()
            if self.s[self.i] == '}':
                self.i += 1
                return t
            if self.s[self.i] == '[':
                self.i += 1
                key = self.value()
                self.ws()
                assert self.s[self.i] == ']'
                self.i += 1
                self.ws()
                assert self.s[self.i] == '='
                self.i += 1
                t[key] = self.value()
                continue
            m = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)\s*=').match(self.s, self.i)
            if m and not self.s.startswith('==', m.end() - 1):
                self.i = m.end()
                t[m.group(1)] = self.value()
                continue
            t[k] = self.value()
            k += 1

    def globals(self):
        g = {}
        while True:
            self.ws()
            if self.i >= self.n:
                return g
            m = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)\s*=').match(self.s, self.i)
            if not m:
                raise ValueError('bad line at %d' % self.i)
            self.i = m.end()
            g[m.group(1)] = self.value()


def array(t):
    out, i = [], 1
    while isinstance(t, dict) and i in t:
        out.append(t[i])
        i += 1
    return out


def load(path):
    files = [path]
    if os.path.isdir(path):
        files = [os.path.join(path, f) for f in sorted(os.listdir(path)) if f.endswith('.lua')]
    g = {}
    for f in files:
        with open(f, encoding='latin-1') as fh:
            g.update(LuaParser(fh.read()).globals())
    return g


def un36(s):
    if s.startswith('-'):
        return -int(s[1:], 36)
    return int(s, 36) if s else 0


def unesc(s):
    return re.sub(r'%([0-9A-Fa-f]{2})', lambda m: chr(int(m.group(1), 16)), s)


def log_rows(g):
    rows = []
    core = g.get('PourSocialScoreDB') or {}
    lg = g.get('PSS_LoggingDB') or core
    log = lg.get('blockLog') if isinstance(lg, dict) else None
    if isinstance(log, dict) and log.get('v') == 2:
        for owner, grp in log.items():
            if owner == 'v' or not isinstance(grp, dict):
                continue
            t = 0
            for line in array(grp):
                m = re.match(r'^(.)(\+?)(\d*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$', line, re.S)
                if not m:
                    continue
                t = (t + int(m.group(3) or 0)) if m.group(2) else int(m.group(3) or 0)
                rows.append({'time': t, 'owner': owner, 'type': m.group(1), 'event': m.group(4), 'message': m.group(7)})
    elif isinstance(log, dict):
        for e in array(log):
            if isinstance(e, dict):
                rows.append({'time': e.get('ts', 0), 'owner': e.get('o', ''), 'type': e.get('cat', ''), 'event': e.get('event', ''), 'message': e.get('message', '')})
    for e in array(core.get('outbox')):
        if isinstance(e, dict):
            rows.append({'time': e.get('ts', 0), 'owner': e.get('o', ''), 'type': e.get('cat', ''), 'event': e.get('event', ''), 'message': e.get('message', '')})
    rows.sort(key=lambda r: -(r['time'] or 0))
    return rows


def pss_rows(g):
    rows = []
    core = g.get('PourSocialScoreDB') or {}
    for line in array(core.get('pssHot')):
        parts = line.split('\t')
        r = {'time': int(parts[0] or 0), 'st': parts[1] if len(parts) > 1 else ''}
        for kv in parts[3:]:
            if '=' in kv:
                k, v = kv.split('=', 1)
                r[unesc(k)] = unesc(v)
        rows.append(r)
    lg = g.get('PSS_LoggingDB') or {}
    T = lg.get('pss') if isinstance(lg, dict) else None
    if isinstance(T, dict) and (T.get('v') or 1) <= 1:
        bodies = []
        for _, s in sorted((T.get('seg') or {}).items()):
            m = re.match(r'^([^;]*);([^;]*);([^;]*);([^;]*);([^;]*);(.*)$', s, re.S)
            if m:
                bodies.append((un36(m.group(1)), m.group(6)))
        if array(T.get('open')):
            bodies.append((T.get('openLo') or 0, '\n'.join(array(T.get('open')))))
        for base, body in bodies:
            for line in body.split('\n'):
                parts = line.split('\t')
                if len(parts) >= 2:
                    rows.append({'time': base + un36(parts[0]), 'st': parts[1], 'ent': parts[2] if len(parts) > 2 else '',
                                 'raw': unesc('\t'.join(parts[3:]))})
    rows.sort(key=lambda r: -(r['time'] or 0))
    return rows


def sq_rows(g):
    opts = g.get('PSS_OptionsDB') or {}
    s = opts.get('sqSaved') if isinstance(opts, dict) else None
    rows = []
    if not isinstance(s, str):
        return rows
    m = re.match(r'^(\d+);(\d+)\n?(.*)$', s, re.S)
    if not m or int(m.group(1)) > 1:
        return rows
    for line in m.group(3).split('\n'):
        if not line:
            continue
        f = [unesc(x) for x in line.split('\t')]
        if len(f) == 6:
            rows.append(dict(zip(('id', 'name', 'scope', 'flags', 'query', 'time'), f)))
    return rows


def main(argv):
    if len(argv) >= 2 and argv[0] == '--counts':
        g = load(argv[1])
        print('log %d pss %d sqSaved %d' % (len(log_rows(g)), len(pss_rows(g)), len(sq_rows(g))))
        return 0
    if len(argv) != 2:
        print(__doc__)
        return 2
    g = load(argv[0])
    os.makedirs(argv[1], exist_ok=True)
    for name, rows in (('log', log_rows(g)), ('pss', pss_rows(g)), ('sq', sq_rows(g))):
        cols = []
        for r in rows:
            for k in r:
                if k not in cols:
                    cols.append(k)
        with open(os.path.join(argv[1], name + '.csv'), 'w', newline='', encoding='utf-8') as fh:
            w = csv.DictWriter(fh, fieldnames=cols or ['time'])
            w.writeheader()
            for r in rows:
                w.writerow(r)
        print('%s: %d rows' % (name, len(rows)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
