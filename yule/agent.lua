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

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
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

local function err_and_exit(errmsg)
	LOG_ERROR(errmsg)
	skynet.error(errmsg)
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
		err_and_exit("uniqueservice cmdroute failed")
	end

	local module, method, reqname, rspname = cmdroute.req.query(sshead.command, sshead.subcmd)
	if not module or not method or not reqname or not rspname then
		local errmsg = "query module failed. cmd: " .. sshead.command .. ", subcmd: " .. sshead.subcmd
		err_and_exit(errmsg)
	end

	LOG_INFO(string.format("command: 0x%x, subcmd: 0x%x, module: %s, method: %s, req: %s, rsp: %s",
		sshead.command, sshead.subcmd, module, method, reqname, rspname))

	local ok, module_inst = pcall(skynet.uniqueservice, module)
	if not ok then
		local errmsg = "uniqueservice module failed. module: " .. module
		err_and_exit(errmsg)
	end

	-- LOG_INFO("bytehead: " .. string.dumphex(bytehead) .. ", bytebody: " .. string.dumphex(bytebody))
	local obj = cmdroute.req.pbdecode(reqname, bytebody)
	rsp = skynet.call(module_inst, "lua", method, obj)
	if not rsp then
		local errmsg = string.format("pcall module %s failed.", module)
		err_and_exit(errmsg)
	end

	local rspbyte = cmdroute.req.pbencode(rspname, rsp)
	local rspbytebody = string.pack(">s2", rspbyte)
	local result = bytehead .. rspbytebody
	LOG_DEBUG("process %s time used %f ms", method, (skynet.time()-begin)*10)
	return string.pack(">s2", result)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = msg_unpack,
	dispatch = function (_, _, ...)
		local ok, result  = pcall(msg_dispatch, ...)
		if ok then
			if result then
				send_package(result)
			end
		else
			skynet.error(result)
		end
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	-- host = sprotoloader.load(1):host "package"
	-- send_request = host:attach(sprotoloader.load(2))
	-- skynet.fork(function()
		-- while true do
			-- send_package(send_request "heartbeat")
			-- skynet.sleep(50000)
		-- end
	-- end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	protobuf.register_file "protocol/SSHead.pb"
end)
