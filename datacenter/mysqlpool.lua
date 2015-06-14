local skynet = require "skynet"
local mysql = require "mysql"
local snax = require "snax"

local pool = {}

local maxconn
local index = 2
local function getconn(sync)
	local db
	if sync then
		db = pool[1]
	else
		db = pool[index]
		assert(db)
		index = index + 1
		if index > maxconn then
			index = 2
		end
	end
	return db
end

function response.start()
	maxconn = tonumber(skynet.getenv("mysql_maxconn")) or 10
	assert(maxconn >= 2)
	for i = 1, maxconn do
		local db = mysql.connect{
			host = skynet.getenv("mysql_host"),
			port = tonumber(skynet.getenv("mysql_port")),
			database = skynet.getenv("mysql_db"),
			user = skynet.getenv("mysql_user"),
			password = skynet.getenv("mysql_pwd"),
			max_packet_size = 1024 * 1024
		}
		if db then
			table.insert(pool, db)
			db:query("set names utf8")
		else
			skynet.error("mysql connect error")
		end
	end
end

-- sync为false或者nil，sql为读操作，如果sync为true用于数据变动时同步数据到mysql，sql为写操作
-- 写操作取连接池中的第一个连接进行操作
function response.execute(sql, sync)
	local db = getconn(sync)
	return db:query(sql)
end

function response.stop()
	for _, db in pairs(pool) do
		db:disconnect()
	end
	pool = {}
end

function init( ... )
	snax.enablecluster()	-- enable cluster call
end

function exit(...)
end
