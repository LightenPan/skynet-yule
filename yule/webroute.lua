local skynet = require "skynet"
local snax = require "snax"
local cjson = require "cjson"
local protobuf = require "protobuf"

function getsybidbyqq()

end

function getsybid()
	return "getsybid"
end

route_table={}
route_table.name="hello"
route_table["/getsybid"]=getsybid

function response.query(path, query, body)
	LOG_INFO(string.format("webquery. path: %s, query: %s, body: %s", path, query, body))
	local f = route_table[path]
	if f then
		return f(query, body)
	else
		return "nil path"
	end
end

function init(...)
	protobuf.register_file("protocol/tafproxysvr.pb")
end

function exit(...)
end
