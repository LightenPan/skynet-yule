local skynet = require "skynet"
local snax = require "snax"

local CMD = {}
local own_uuid
local group_id
local user_list = {}

local function next_user(uuid)
	--将列表扩大两倍
	local luser_list = user_list

	for key, user in pairs(user_list) do
		table.insert(luser_list, user)
	end

	--查找下一个玩家
	for key, user in pairs(user_list) do
		if user.uuid == uuid then

		end
	end
end

function response.new(uuid, group_id, uuid_list)
	own_uuid = uuid
	group_id = group_id
	for uuid in pairs(uuid_list) do
		user = {}
		user.uuid = uuid
		user.dead = false
		table.insert(user_list, user)
	end
end

function response.clearflat(uuid, row, col)
	
end

function init(...)
end

function exit(...)
end
