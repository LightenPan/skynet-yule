local skynet = require "skynet"
local snax = require "snax"
local protobuf = require "protobuf"

local cmd2name = {
	["s206_1"] = {reqname = "groupsvr_protos.GroupHelloReq", rspname = "groupsvr_protos.GroupHelloRsp"}
	["s206_2"] = {reqname = "groupsvr_protos.GroupJoinReq", rspname = "groupsvr_protos.GroupJoinRsp"}
	["s206_3"] = {reqname = "groupsvr_protos.GroupLeaveReq", rspname = "groupsvr_protos.GroupLeaveRsp"}
	["s206_4"] = {reqname = "groupsvr_protos.GroupBroadcastReq", rspname = "groupsvr_protos.GroupBroadcastRsp"}
	["s206_5"] = {reqname = "groupsvr_protos.GetUserNumReq", rspname = "groupsvr_protos.GetUserNumRsp"}
}

local group_user_set = {}
local user_info_set = {}

function remove_group_user(uuid, group_id)
	local user_chan = {}
	if user_info_set[uuid] then
		-- 删除通道
		user_chan = user_info_set[uuid].chan
		skynet.call(user_chan, "lua", "leave")

		--删除在线
		table.remove(user_info_set, uuid)

		--删除分组关系
		table.remove(user_info_set, uuid)
		group_user = group_user_set[group_id]
		if group_user then
			group_user.uuid = false
			group_user.count = group_user.count - 1
			if group_user.count == 0 then
				table.remove(group_user_set, group_user)
			end
		end
	end
end



local PBCMD = {}

function PBCMD.s206_1(req)
	user_num = group_set[req.group_id]
	rsp = {result = 0, user_num = user_num}
	return rsp
end

function PBCMD.s206_2(source, req)
	local uuid = req.uuid
	local group_id = req.group_id
	remove_group_user(uuid, group_id)

	group_user = group_user_set[group_id]
	if not group_user then
		-- 创建通道
		local channel = mc.new()
		group_user.count = 0
		group_user.channel = channel
		table.insert(group_user_set, group_user)
	end

	group_user = group_user_set[group_id]

	user_chan = skynet.newservice("user_chan")
	skynet.call(user_chan, "lua", "join", group_user.channel)

	user = {}
	user.uuid = req.uuid;
	user.group_id = req.group_id
	user.room_sig = req.room_sig
	user.connsvr_ip = req.connsvr_ip
	user.chan = user_chan
	user.agent = source
	table.insert(user_info_set, user)

	group_user.uuid = true
	group_user.group_id = group_id
	group_user.count = group_user.count + 1

	rsp = {result = 0}
	return rsp
end

function PBCMD.s206_3(req)
	local uuid = req.uuid
	local group_id = req.group_id
	remove_group_user(uuid, group_id)

	rsp = {result = 0}
	return rsp
end

function PBCMD.s206_4(req)
	if group_set[req.group_id] then
		table.remove(group_set, req.group_id)
	end

	rsp = {result = 0}
	return rsp
end

function PBCMD.s206_5(req)
	if group_set[req.group_id] then
		table.remove(group_set, req.group_id)
	end

	rsp = {result = 0}
	return rsp
end


skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, data)
		local name = cmd2name[cmd]
		local req = protobuf.decode(name.reqname, data)
		if not req then
			LOG_INFO(string.format("protobuf.decode failed. cmd: %s, reqname: %s", cmd, name.reqname))
			error(string.format("protobuf.decode failed. cmd: %s, reqname: %s", cmd, name.reqname))
		end

		local f = PBCMD[cmd]
		if f then
			if s206_2 == cmd then
				local rsp = f(source, req)
			else
				local rsp = f(req)
			end
			local rspbody = protobuf.encode(name.rspname, rsp)
			skynet.ret(skynet.pack(rspbody))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)

	protobuf.register_file "protocol/GroupSvr.pb"
end)
