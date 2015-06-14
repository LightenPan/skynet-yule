local skynet = require "skynet"
local mc = require "multicast"
local dc = require "datacenter"

local agent_address {}
local channel = {}

local function CMD.join(address, channel)
	local c = mc.new {
		channel = channel ,
		dispatch = function (channel, source, ...)
			skynet.call(agent_address, "lua", "publish", ...)
		end
	}

	agent_address = address
	channel = c
	channel:subscribe()
end

local function CMD.leave()
	channel:unsubscribe()
	channel.delete()
end

skynet.start(function()
	skynet.dispatch("lua", function (_,_, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			LOG_ERROR("unknown cmd: " .. cmd)
		end
	end)
end)
