local skynet = require "skynet"
local snax = require "snax"

local CMD = {}

function CMD.profilesvr_protos_GetUserInfoReq(req)
	oUserInfo = {user_id = "test", nick = "test_nick", level = 0, edge = 0}
	rsp = {result = 0, user_info = oUserInfo}
	LOG_INFO("dump oUserInfo. \n" .. table.dump(oUserInfo))
	return rsp
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)
end)
