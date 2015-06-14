local skynet = require "skynet"
local snax = require "snax"

local cmd2service = {
	["101_1"] = "profile",
	["101_4"] = "profile",
	["100"] = "matching"
}

function response.query(pbcmd, pbsubcmd)
	-- LOG_INFO(string.format("cmdroute query. pbcmd: %s, pbsubcmd: %s", tostring(pbcmd), tostring(pbsubcmd)))
	key  = tostring(pbcmd) .. "_" .. tostring(pbsubcmd)
	return cmd2service[key];
end

function init( ... )
	snax.enablecluster()
end

function exit(...)
end
