local skynet = require "skynet"
local redis = require "redis"
local snax = require "snax"

local pool = {}

local maxconn
local function getconn(uid)
	local db
	if not uid or maxconn == 1 then
		db = pool[1]
	else
		db = pool[uid % (maxconn - 1) + 2]
	end

	return db
end

function response.start()
	maxconn = tonumber(skynet.getenv("redis_maxinst")) or 2
	for i = 1, maxconn do
		local db = redis.connect{
			host = skynet.getenv("redis_host" .. i),
			port = skynet.getenv("redis_port" .. i),
			db = 0,
			auth = skynet.getenv("redis_auth" .. i),
		}

		if db then
			db:flushdb() --测试期，清理redis数据
			table.insert(pool, db)
		else
			skynet.error("mysql connect error")
		end
	end
end

function response.set(uid, key, value)
	local db = getconn(uid)
	local retsult = db:set(key,value)

	return retsult
end

function response.get(uid, key)
	local db = getconn(uid)
	local retsult = db:get(key)

	return retsult
end

function response.hmset(uid, key, t)
	local data = {}
	for k, v in pairs(t) do
		table.insert(data, k)
		table.insert(data, v)
	end

	local db = getconn(uid)
	local result = db:hmset(key, table.unpack(data))

	return result
end

function response.hmget(uid, key, ...)
	if not key then return end

	local db = getconn(uid)
	local result = db:hmget(key, ...)

	return result
end

function response.hset(uid, key, filed, value)
	local db = getconn(uid)
	local result = db:hset(key,filed,value)

	return result
end

function response.hget(uid, key, filed)
	local db = getconn(uid)
	local result = db:hget(key, filed)

	return result
end

function response.hgetall(uid, key)
	local db = getconn(uid)
	local result = db:hgetall(key)

	return result
end

function response.zadd(uid, key, score, member)
	local db = getconn(uid)
	local result = db:zadd(key, score, member)

	return result
end

function response.keys(uid, key)
	local db = getconn(uid)
	local result = db:keys(key)

	return result

end

function response.zrange(uid, key, from, to)
	local db = getconn(uid)
	local result = db:zrange(key, from, to)

	return result
end

function response.zrevrange(uid, key, from, to ,scores)
	local result
	local db = getconn(uid)
	if not scores then
		result = db:zrevrange(key,from,to)
	else
		result = db:zrevrange(key,from,to,scores)
	end

	return result
end

function response.zrank(uid, key, member)
	local db = getconn(uid)
	local result = db:zrank(key,member)

	return result
end

function response.zrevrank(uid, key, member)
	local db = getconn(uid)
	local result = db:zrevrank(key,member)

	return result
end

function response.zscore(uid, key, score)
	local db = getconn(uid)
	local result = db:zscore(key,score)

	return result
end

function response.zcount(uid, key, from, to)
	local db = getconn(uid)
	local result = db:zcount(key,from,to)

	return result
end

function response.zcard(uid, key)
	local db = getconn(uid)
	local result = db:zcard(key)

	return result
end

function response.incr(uid, key)
	local db = getconn(uid)
	local result = db:incr(key)

	return result
end

function response.del(uid, key)
	local db = getconn(uid)
	local result = db:del(key)

	return result
end

function init( ... )
	snax.enablecluster()	-- enable cluster call
end

function exit(...)
end
