local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local snax = require "snax"
local sprotoloader = require "sprotoloader"
local protobuf = require "protobuf"
protobuf.register_file "protocol/CSHead.pb"

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}
local client_fd

function REQUEST:query()
	print("query", self.pbcmd, self.pbsubcmd)
	local r = skynet.call("CMDROUTE", "lua", "query", self.pbcmd, self.pbsubcmd)
	print("result", r)
	return { result = r }
end

function REQUEST:get()
	print("get", self.what)
	local r = skynet.call("SIMPLEDB", "lua", "get", self.what)
	return { result = r }
end

function REQUEST:set()
	print("set", self.what, self.value)
	local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
end

function REQUEST:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

local function request(name, args, response)
	local r = skynet.call("CMDROUTE", "lua", "query", self.pbcmd, self.pbsubcmd)
	local f = assert(REQUEST[name])
	local r = f(args)
	if response then
		return response(r)
	end
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
end

local function msg_unpack(msg, sz)
	local data = netpack.tostring(msg, sz, 0) --必须为0,否则这边会直接被free掉,会造成coredump
	LOG_INFO(string.format("data: %s", string.dumphex(data)))
	csheadlen = string.unpack(">H", data, 2)
	LOG_INFO("csheadlen: " .. csheadlen)
	cshead = string.unpack(">s2", data, 2)
	LOG_INFO("cshead: " .. string.dumphex(cshead))

	if not cshead then
		LOG_ERROR("msg_unpack head error")
		error("msg_unpack head error")
	end

	csbodylen = string.unpack(">H", data, 4 + csheadlen)
	LOG_INFO("csbodylen: " .. csbodylen)
	csbody = string.unpack(">s2", data, 4 + csheadlen)
	LOG_INFO("csbody: " .. string.dumphex(csbody))

	if not csbody then
		LOG_ERROR("msg_unpack body error")
		error("msg_unpack body error")
	end

	return cshead, csbody
end

local function msg_dispatch(bytehead, bytebody)
	-- LOG_INFO("bytehead: " .. string.dumphex(bytehead) .. ", bytebody: " .. string.dumphex(bytebody))
	local cshead = protobuf.decode("app_protos.CSHead", bytehead)
	local method = "s" .. cshead.command .. "_" .. cshead.subcmd
	LOG_INFO("command: %u, subcmd: %u, method: %s, seq: %u, uuid: %s, client_type: %u, head_flag: %u, client_ver: %u, signature: %s",
	cshead.command, cshead.subcmd, method, cshead.seq, cshead.uuid, cshead.client_type, cshead.head_flag, cshead.client_ver, cshead.signature)

	begin = skynet.time()

	local ok, cmdroute = pcall(snax.uniqueservice, "cmdroute")
	if not ok then
		LOG_ERROR("uniqueservice cmdroute failed")
	end
	local module = cmdroute.req.query(cshead.command, cshead.subcmd)
	LOG_INFO(string.format("command: %u, subcmd: %u, module %s", cshead.command, cshead.subcmd, module))
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

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = msg_unpack,
	dispatch = function (_, _, ...)
		-- skynet.ret(msg_dispatch(...))
		local ok, result  = pcall(msg_dispatch, ...)
		if ok then
			if result then
				send_package(result)
			end
		else
			skynet.error(result)
		end
	end
	-- dispatch = function (_, _, type, ...)
		-- LOG_DEBUG("type: " .. type)
		-- if type == "REQUEST" then
			-- local ok, result  = pcall(msg_dispatch, ...)
			-- if ok then
				-- if result then
					-- send_package(result)
				-- end
			-- else
				-- skynet.error(result)
			-- end
		-- else
			-- send_package(...)
			-- -- assert(type == "RESPONSE")
			-- -- error "This example doesn't support request client"
		-- end
	-- end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	send_request = host:attach(sprotoloader.load(2))
	skynet.fork(function()
		while true do
			send_package(send_request "heartbeat")
			skynet.sleep(50000)
		end
	end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

function CMD.publish(data)
	cshead = {}
	cshead.command = 0x2606
	cshead.subcmd = 0
	cshead.head_flag = 8
	local bytehead = protobuf.encode("app_protos.CSHead", cshead)
	local rspbytebody = string.pack(">s2", data)
	local result = bytehead .. rspbytebody
	send_package(result)
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
