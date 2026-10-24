#!/usr/bin/env python3
"""Jalankan seluruh tes memakai Luau CLI standalone -- BUKAN di Roblox Studio.

  LUAU_BIN=/path/ke/luau python3 tests/run_tests.py      (default: 'luau' di PATH)

Cara kerja: modul Roblox digabung ke satu file Luau; pola require(...) diganti __req("Nama");
global Roblox (game/task/os/warn/Instance) disuplai tests/mock_roblox.lua (Roblox palsu + penjadwal virtual).
Diuji: semua ModuleScript (config, logika murni, ProfileStore, DataService, PlayerStatsService, migrasi).
TIDAK diuji: Main, DevTools (butuh Roblox sungguhan). Exit code 0 = semua lulus."""
import os, pathlib, re, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
LUAU = os.environ.get("LUAU_BIN", "luau")
MODULES = {
    "GameConfig": "ReplicatedStorage/Configurations/GameConfig.lua",
    "StatFormulas": "ReplicatedStorage/SharedModules/StatFormulas.lua",
    "ProfileStore": "ServerScriptService/Services/ProfileStore.lua",
    "DataTemplate": "ServerScriptService/Services/DataTemplate.lua",
    "DataService": "ServerScriptService/Services/DataService.lua",
    "PlayerStatsService": "ServerScriptService/Services/PlayerStatsService.lua",
    "DataMigrations": "ServerScriptService/Services/DataMigrations.lua",
    "WorldConfig": "ReplicatedStorage/Configurations/WorldConfig.lua",
    "EnemyConfig": "ReplicatedStorage/Configurations/EnemyConfig.lua",
    "QuestConfig": "ReplicatedStorage/Configurations/QuestConfig.lua",
    "GachaConfig": "ReplicatedStorage/Configurations/GachaConfig.lua",
    "QuestLogic": "ReplicatedStorage/SharedModules/QuestLogic.lua",
    "GachaLogic": "ReplicatedStorage/SharedModules/GachaLogic.lua",
}
TEST_FILES = ["test_core.lua", "test_integration.lua", "test_gameplay.lua"]
REQUIRE = re.compile(r"require\(\s*(?:\w+\.)*(\w+)\s*\)")


def read(path):
    return pathlib.Path(path).read_text(encoding="utf-8")


parts = ["local __sources = {}", "local H = (function()\n" + read(HERE / "mock_roblox.lua") + "\nend)()"]
for name, rel in MODULES.items():
    source = REQUIRE.sub(lambda m: '__req("%s")' % m.group(1), read(ROOT / rel))
    parts.append('__sources["%s"] = function(game, task, os, warn, Instance, workspace, __req)\n%s\nend' % (name, source))
parts.append('local __pure = H.newServer("PURE", H.newStore())\nlocal function __req(name) return __pure.require(name) end')
parts.append("local __passed, __failed = 0, 0")
for fname in TEST_FILES:
    parts.append(
        'do\n  local p, f = (function(__req, H)\n%s\n  end)(__req, H)\n  __passed += p; __failed += f\n'
        '  print("%s: " .. p .. " passed, " .. f .. " failed")\nend' % (read(HERE / fname), fname)
    )
parts.append('print("TOTAL: " .. __passed .. " passed, " .. __failed .. " failed")\n'
             'if __failed > 0 then error("ADA TEST GAGAL") end')

combined = pathlib.Path(tempfile.gettempdir()) / "ar_combined_test.lua"
combined.write_text("\n".join(parts), encoding="utf-8")
try:
    sys.exit(subprocess.call([LUAU, str(combined)]))
except FileNotFoundError:
    print("Luau CLI tidak ditemukan. Unduh dari https://github.com/luau-lang/luau/releases (luau-<os>.zip),")
    print("lalu jalankan: LUAU_BIN=/path/ke/luau python3 tests/run_tests.py")
    sys.exit(127)
