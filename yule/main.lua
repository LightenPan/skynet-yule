local skynet = require "skynet"
local snax = require "snax"
local sprotoloader = require "sprotoloader"

local max_client = 64

skynet.start(function()
	print("Server start")
	local log = skynet.uniqueservice("log")
	skynet.call(log, "lua", "start")
	skynet.uniqueservice("protoloader")
	local console = skynet.newservice("console")
	skynet.newservice("debug_console",8000)
	snax.newservice("cmdroute")
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	print("watchdog listen on ", 8888)

	skynet.exit()
end)
