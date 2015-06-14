package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;examples/?.lua"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

local socket = require "clientsocket"
local proto = require "proto"
local sproto = require "sproto"
local protobuf = require "protobuf"
protobuf.register_file "protocol/SSHead.pb"
protobuf.register_file "protocol/profilesvr.pb"

local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))

local fd = assert(socket.connect("127.0.0.1", 8888))

function string.fromhex(str)
	return (str:gsub('..', function (cc)
		return string.char(tonumber(cc, 16))
	end))
end

local function dumphex(data)
	return (string.gsub(data, ".", function(x)
		return string.format("%02x ", string.byte(x))
	end))
end

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	print("send_package: ", dumphex(package))
	socket.send(fd, package)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0

local function send_request(name, args)
	session = session + 1
	local str = request(name, args, session)
	send_package(fd, str)
	print("Request:", session)
end

local function send_pbrequest()
	session = session + 1
	sshead = {}
	sshead.command = 0x204
	sshead.subcmd = 1
	sshead.sequence = session
	sshead.uuid = "test"
	sshead.client_ip = 0
	sshead.client_port = 1024
	sshead.objectid = 200
	sshead.appid = 233
	sshead.client_type = 0
	local bytehead = protobuf.encode("SSHead", sshead)

	req = {}
	req.user_id = "test"
	local bytebody = protobuf.encode("profilesvr_protos.GetUserInfoReq", req)

	local packagehead = string.pack(">s2", bytehead)
	local packagebody = string.pack(">s2", bytebody)
	msg = string.pack("B", 0x0a) .. packagehead .. packagebody .. string.pack("B", 0x03)
	print("send_pbrequest: ", dumphex(msg))
	send_package(fd, msg)
end

local last = ""

local function print_request(name, args)
	print("REQUEST", name)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		print(dumphex(last))
		-- print_package(host:dispatch(v))
	end
end

while true do
	dispatch_package()
	local cmd = socket.readstdin()
	if cmd then
		if cmd == "quit" then
			send_request("quit")
		elseif cmd == "pb" then
			send_pbrequest()
		end
	else
		socket.usleep(100)
	end
end
