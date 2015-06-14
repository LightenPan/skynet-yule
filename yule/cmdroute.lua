local skynet = require "skynet"
local snax = require "snax"
local cjson = require "cjson"
local protobuf = require "protobuf"

local route_table = {}

function response.query(pbcmd, pbsubcmd)
	cmdhex = string.format("0x%x", pbcmd)
	subcmdhex = string.format("0x%x", pbsubcmd)
	LOG_INFO(string.format("cmdroute query. pbcmd: %s, pbsubcmd: %s", cmdhex, subcmdhex))
	method = string.gsub(route_table[cmdhex][subcmdhex].req, "%.", "_")
	return tostring(route_table[cmdhex].service), tostring(method), route_table[cmdhex][subcmdhex].req, route_table[cmdhex][subcmdhex].rsp
end

function response.pbdecode(name, data)
	return protobuf.decode(name, data)
end

function response.pbencode(name, obj)
	return protobuf.encode(name, obj)
end

function init( ... )
	snax.enablecluster()
	local file = io.input("yule/etc/route.json")
	local content = file:read("*a")
	route_table = cjson.decode(content)
	file:close()

	for i,v in pairs(route_table) do
		local pbfile = v.pbfile
		if pbfile then
			protobuf.register_file("protocol/" .. tostring(pbfile))
		end
	end

	LOG_INFO("dump route table: \n" .. table.dump(route_table))
end

function exit(...)
end
