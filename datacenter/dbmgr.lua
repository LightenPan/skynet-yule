local skynet = require "skynet"
local snax = require "snax"

function CMD.start(config, user, common)
	local mysqlpool = skynet.uniqueservice("mysqlpool")
	mysqlpool.req.start()

	local redispool = skynet.uniqueservice("redispool")
	redispool.req.start()
end

function CMD.stop()
	mysqlpool.req.stop()
	redispool.req.stop()
end

function init( ... )
	snax.enablecluster()	-- enable cluster call
end

function exit(...)
end
