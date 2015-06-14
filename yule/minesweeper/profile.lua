local skynet = require "skynet"
local snax = require "snax"
local protobuf = require "protobuf"

local cmd2name = {
	["s101_1"] = {reqname = "profilesvr_protos.GetUserInfoReq", rspname = "profilesvr_protos.GetUserInfoRsp"}
}

local command = {}
local PBCMD = {}

function PBCMD.s101_1(req)
	oUserInfo = {user_id = "test", nick = "test_nick", level = 0, edge = 0}
	rsp = {result = 0, user_info = oUserInfo}
	LOG_INFO(tostring(oUserInfo))
	return rsp
end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, cmd, data)
		local name = cmd2name[cmd]
		local req = protobuf.decode(name.reqname, data)
		if not req then
			LOG_INFO(string.format("protobuf.decode failed. cmd: %s, reqname: %s", cmd, name.reqname))
			error(string.format("protobuf.decode failed. cmd: %s, reqname: %s", cmd, name.reqname))
		end

		local f = PBCMD[cmd]
		if f then
			local rsp = f(cshead, req)
			local rspbody = protobuf.encode(name.rspname, rsp)
			skynet.ret(skynet.pack(rspbody))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)

	protobuf.register_file "protocol/profilesvr.pb"
end)
