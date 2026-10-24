--!nonstrict
--[[
	Main | Script (server)
	Lokasi Studio: ServerScriptService > Main
	Boot semua service. Aturan urutan: semua Init() dulu (mendaftarkan callback),
	DataService.Start() PALING AKHIR supaya tidak ada pemain yang dimuat sebelum callback terdaftar.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")

local DataService = require(Services:WaitForChild("DataService"))
local PlayerStatsService = require(Services:WaitForChild("PlayerStatsService"))

PlayerStatsService.Init()
-- Service Bagian B dst. ditambahkan di sini, sebelum DataService.Start()

DataService.Start()
