local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local snax = require "snax"
local sprotoloader = require "sprotoloader"
local protobuf = require "protobuf"

local WATCHDOG
local host
local send_request

local CMD = {}
local client_fd

local function msg_pack(data)
	local package = string.pack(">s2", data)
	return package
end

local function msg_unpack(msg, sz)
	local data = netpack.tostring(msg, sz, 0) --必须为0,否则这边会直接被free掉,会造成coredump
	-- LOG_INFO(string.format("data: %s", string.dumphex(data)))
	ssheadlen = string.unpack(">H", data, 2)
	-- LOG_INFO("ssheadlen: " .. ssheadlen)
	sshead = string.unpack(">s2", data, 2)
	-- LOG_INFO("sshead: " .. string.dumphex(sshead))

	if not sshead then
		LOG_ERROR("msg_unpack head error")
		error("msg_unpack head error")
	end

	csbodylen = string.unpack(">H", data, 4 + ssheadlen)
	-- LOG_INFO("csbodylen: " .. csbodylen)
	csbody = string.unpack(">s2", data, 4 + ssheadlen)
	-- LOG_INFO("csbody: " .. string.dumphex(csbody))

	if not csbody then
		LOG_ERROR("msg_unpack body error")
		error("msg_unpack body error")
	end

	return sshead, csbody
end

local function msg_dispatch(bytehead, bytebody)
	LOG_INFO("bytehead: " .. string.dumphex(bytehead) .. ", bytebody: " .. string.dumphex(bytebody))
	local sshead = protobuf.decode("SSHead", bytehead)
	local method = "s" .. sshead.command .. "_" .. sshead.subcmd
	-- LOG_INFO("command: %u, subcmd: %u, method: %s, seq: %u, uuid: %s, client_type: %u, head_flag: %u, client_ver: %u, signature: %s",
	-- sshead.command, sshead.subcmd, method, sshead.seq, sshead.uuid, sshead.client_type, sshead.head_flag, sshead.client_ver, sshead.signature)

	begin = skynet.time()

	local ok, cmdroute = pcall(snax.uniqueservice, "cmdroute")
	if not ok then
		LOG_ERROR("uniqueservice cmdroute failed")
	end
	local module = cmdroute.req.query(sshead.command, sshead.subcmd)
	LOG_INFO(string.format("command: %u, subcmd: %u, module %s", sshead.command, sshead.subcmd, module))
	local ok, module_inst = pcall(skynet.uniqueservice, module)
	if not ok then
		LOG_ERROR(string.format("unknown module %s", module))
	else
		-- LOG_INFO("bytehead: " .. string.dumphex(bytehead) .. ", bytebody: " .. string.dumphex(bytebody))
		rsp = skynet.call(module_inst, "lua", method, bytebody)
		if not rsp then
			LOG_ERROR(string.format("pcall module %s failed.", module))
		end
	end

	local rspbytebody = string.pack(">s2", rsp)
	local result = bytehead .. rspbytebody
	LOG_DEBUG("process %s time used %f ms", method, (skynet.time()-begin)*10)
	return string.pack(">s2", result)
end

function CMD.start(conf)
	host = conf.host or "0.0.0.0"
	port = conf.port or 8888
	fd = socket.udp(function(str, from)
		socket.sendto(fd, from, msg_pack(str))
	end, host, port)
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	protobuf.register_file "protocol/SSHead.pb"
end)
