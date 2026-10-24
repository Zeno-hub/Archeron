#!/usr/bin/env python3
"""Cek konsistensi struktur proyek Roblox TANPA Studio:  python3 tests/check_structure.py
Memeriksa: (1) setiap require() menunjuk ke ModuleScript yang ada, (2) tipe skrip mengikuti penamaan file
(.server.lua = Script, .client.lua = LocalScript, .lua = ModuleScript; konvensi Rojo), (3) ModuleScript berakhir
dengan `return` di level atas, (4) Script tidak di-require, (5) tidak ada nama kembar di satu folder.
Exit code 0 = konsisten. Batasan: hanya mengenali pola require yang dipakai proyek ini:
ReplicatedStorage.A.B | script.Parent.X | <Var>:WaitForChild("X") (Var = local hasil WaitForChild/titik dari service)."""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVICES = ("ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterGui")
SUFFIXES = ((".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript"))
TOKEN = re.compile(r'\.(\w+)|:WaitForChild\("(\w+)"\)')
ASSIGN = re.compile(r'^local (\w+) = (\w+(?:\.\w+|:WaitForChild\("\w+"\))*)\s*$', re.M)

problems, nodes = [], {}  # nodes: tuple path -> (class, file)


def classify(filename):
    for suffix, cls in SUFFIXES:
        if filename.endswith(suffix):
            return filename[: -len(suffix)], cls
    return None, None


def strip_comments(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    return re.sub(r"--[^\n]*", "", src)


def resolve(expr, here, env):
    m = re.match(r"\s*(\w+)", expr)
    if not m:
        return None, "ekspresi tidak dikenali: " + expr
    base, pos = m.group(1), m.end()
    if base == "script":
        path = here
    elif base in SERVICES:
        path = (base,)
    elif base in env:
        path = env[base]
    else:
        return None, "identifier tidak dikenal: " + base
    while pos < len(expr):
        t = TOKEN.match(expr, pos)
        if not t:
            return None, "sintaks tidak dikenali di: " + expr[pos:]
        pos = t.end()
        if t.group(1) == "Parent":
            path = path[:-1]
        else:
            path = path + (t.group(1) or t.group(2),)
    return path, None


def require_args(src):
    out, i = [], 0
    while True:
        i = src.find("require(", i)
        if i < 0:
            return out
        j = k = i + len("require(")
        depth = 1
        while k < len(src) and depth:
            depth += {"(": 1, ")": -1}.get(src[k], 0)
            k += 1
        out.append(src[j : k - 1].strip())
        i = k


for svc in SERVICES:
    base = ROOT / svc
    if not base.is_dir():
        continue
    nodes[(svc,)] = ("Service", None)
    for path in sorted(base.rglob("*")):
        rel = path.relative_to(ROOT).parts
        if path.is_dir():
            nodes[rel] = ("Folder", None)
        elif path.suffix == ".lua":
            name, cls = classify(path.name)
            key = rel[:-1] + (name,)
            if key in nodes:
                problems.append("nama kembar di folder yang sama: " + "/".join(key))
            nodes[key] = (cls, path)

required, checked = set(), 0
for key, (cls, path) in sorted(nodes.items()):
    if path is None:
        continue
    src = strip_comments(path.read_text(encoding="utf-8"))
    env = {}
    for m in ASSIGN.finditer(src):
        base = re.match(r"\w+", m.group(2)).group(0)
        if base != "script" and base not in SERVICES and base not in env:
            continue  # bukan path Instance (mis. local cfg = GameConfig.Data)
        target, err = resolve(m.group(2), key, env)
        if err or target not in nodes:
            problems.append("%s: local %s -> %s" % ("/".join(key), m.group(1), err or "TIDAK ADA: " + "/".join(target)))
        else:
            env[m.group(1)] = target
    for expr in require_args(src):
        target, err = resolve(expr, key, env)
        label = "%s: require(%s)" % ("/".join(key), expr)
        if err or target not in nodes:
            problems.append("%s -> %s" % (label, err or "TIDAK ADA: " + "/".join(target)))
            continue
        if nodes[target][0] != "ModuleScript":
            problems.append("%s -> target %s bertipe %s, harus ModuleScript" % (label, "/".join(target), nodes[target][0]))
            continue
        required.add(target)
        checked += 1
        print("  OK  %-45s ->  %s" % ("/".join(key), "/".join(target)))
    if cls == "ModuleScript" and not re.search(r"^return\b", src, re.M):
        problems.append("%s: ModuleScript tanpa `return` di level atas (mungkin seharusnya .server.lua)" % "/".join(key))

for key, (cls, _) in nodes.items():
    if cls in ("Script", "LocalScript") and key in required:
        problems.append("%s bertipe %s tetapi di-require" % ("/".join(key), cls))

print("\nStruktur Studio yang dihasilkan dari susunan file:")
for key in sorted(nodes):
    print("  " * len(key) + "%s  [%s]" % (key[-1], nodes[key][0]))
print("\n%d require() diperiksa, %d masalah" % (checked, len(problems)))
for p in problems:
    print("  MASALAH:", p)
sys.exit(1 if problems else 0)
