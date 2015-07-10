-- Copyright (C) 2012 Yichun Zhang (agentzh)
-- Copyright (C) 2014 Chang Feng
-- This file is modified version from https://github.com/openresty/lua-resty-mysql
-- The license is under the BSD license.
-- Modified by Cloud Wu (remove bit32 for lua 5.3)

local socketchannel = require "socketchannel"

local sub = string.sub
local strgsub = string.gsub
local strformat = string.format
local strbyte = string.byte
local strchar = string.char
local strrep = string.rep
local strunpack = string.unpack
local strpack = string.pack
local setmetatable = setmetatable


local function _get_byte2(data, i)
	return strunpack("<I2",data,i)
end

local function _get_byte3(data, i)
	return strunpack("<I3",data,i)
end

local function _get_byte4(data, i)
	return strunpack("<I4",data,i)
end

local function _get_byte8(data, i)
	return strunpack("<I8",data,i)
end

local function _set_byte2(n)
    return strpack("<I2", n)
end

local function _set_byte3(n)
    return strpack("<I3", n)
end

local function _set_byte4(n)
    return strpack("<I4", n)
end

local function _from_cstring(data, i)
    return strunpack("z", data, i)
end

local function _dumphex(bytes)
	return strgsub(bytes, ".", function(x) return strformat("%02x ", strbyte(x)) end)
end

local function _compose_query(self, server_id, ver, cmd, seq, uin, subcmd, query)

    local total_len = 2 + 1 + 27 + 8 + 4 + 11 + query.len() + 1
    -- 组包DBPkgHead有27字节长度，共12个参数
    -- typedef struct DBPkgHead {
    --     unsigned short usLen;
    --     unsigned char cCommand;
    --     char sServerID[2];
    --     char sClientAddr[4];
    --     char sClientPort[2];
    --     char sConnAddr[4];
    --     char sConnPort[2];
    --     char sInterfaceAddr[4];
    --     char sInterfacePort[2];
    --     char cProcessSeq;
    --     unsigned char cDbID;
    --     char sPad[2]; // Pad the same length as RelayPkgHead.
    -- }
    local dbpkg = strpack("<I2I4I2I4I2I4I2I1I1I2I2I2", 0, 0, 0, 0, server_id, 0, 0, 0, 0, 0, 0, 0)

    -- 组包RelayPkgHeadEx2有8字节长度，共4个参数
    -- typedef struct RelayPkgHeadEx2 {
    --     unsigned short shExVer;
    --     unsigned short shExLen;
    --     unsigned short shLocaleID;
    --     short shTimeZoneOffsetMin;
    --     char sReserved[0];
    -- } RelayPkgHeadEx2;
    local relaylen = 8 + 4; -- 额外的sessionid信息
    local relaypkg = strpack("<I2I2I2I2", 0, relaylen, 0, 0)

    -- 组包cld_pkg_head有11字节长度，共5个参数
    -- typedef struct cld_pkg_head {
    --     char version[2];
    --     char command[2];
    --     char seq_num[2];
    --     char uin[4];
    --     char subcmd;
    -- } cld_pkg_head;
    local clientpkg = strpack("<I2I2I2I4I1", ver, cmd, seq, uin, subcmd)

    local sessionid = qtserver::genid()
    local querypacket = strpack("<I2I1", total_len, 0x0a) ... dbpkg ... relaypkg ... strpack("<I4", sessionid) ... clientpkg ... query ... strpack("<I1", 0x03)
    return querypacket
end

local function _query_resp(sock)
    local len = sock:read(2)
    local data = sock:read(len)

    if len < 1 + 27 + 8 + 4 then
        return nil, false, nil
    end

    index = 1 + 1
    -- 解包DBPkgHead有27字节长度，共12个参数
    -- typedef struct DBPkgHead {
    --     unsigned short usLen;
    --     unsigned char cCommand;
    --     char sServerID[2];
    --     char sClientAddr[4];
    --     char sClientPort[2];
    --     char sConnAddr[4];
    --     char sConnPort[2];
    --     char sInterfaceAddr[4];
    --     char sInterfacePort[2];
    --     char cProcessSeq;
    --     unsigned char cDbID;
    --     char sPad[2]; // Pad the same length as RelayPkgHead.
    -- }
    -- strunpack("<I2I4I2I4I2I4I2I1I1I2I2I2", data, index)
    index = index + 27

    -- 解包RelayPkgHeadEx2有8字节长度，共4个参数
    -- typedef struct RelayPkgHeadEx2 {
    --     unsigned short shExVer;
    --     unsigned short shExLen;
    --     unsigned short shLocaleID;
    --     short shTimeZoneOffsetMin;
    --     char sReserved[0];
    -- } RelayPkgHeadEx2;
    local sessionid = nil
    local _, _, _, _, sessionid = strunpack("<I2I2I2I2", data, index)
    index = index + 8 + 4

    -- 解包cld_pkg_head有11字节长度，共5个参数
    -- typedef struct cld_pkg_head {
    --     char version[2];
    --     char command[2];
    --     char seq_num[2];
    --     char uin[4];
    --     char subcmd;
    -- } cld_pkg_head;
    -- strunpack("<I2I2I2I2I1", data, index)
    index = index + 11

    -- 解包body
    local body = strunpack(string.format("<c%d", len - index - 1 - 1), data, index)

    return sessionid, true, body
end

function _request(self, server_id, ver, cmd, seq, uin, subcmd, query)
    local querypacket = _compose_packet(server_id, ver, cmd, seq, uin, subcmd, query)
    local sockchannel = self.sockchannel
    if not self.query_resp then
        self.query_resp = _query_resp(self)
    end
    return sockchannel:request(querypacket, self.query_resp)
end

function qtserver:genid()
    local id = self.__id + 1
    self.__id = id
    return id
end

function qtserver:genseqid()
    local id = self.__seqid + 1
    self.__seqid = id
    return id
end

function qtserver:connect( opts)

    local self = setmetatable( {}, mt)

    local max_packet_size = opts.max_packet_size
    if not max_packet_size then
        max_packet_size = 64*1024 -- default 64k
    end
    self._max_packet_size = max_packet_size

    local channel = socketchannel.channel {
        host = opts.host,
        port = opts.port,
    }
    -- try connect first only once
    channel:connect(true)
    self.sockchannel = channel

    return self
end

function qtserver:disconnect(self)
    self.sockchannel:close()
    setmetatable(self, nil)
end

function qtserver:request(self, cmd, uin, subcmd, query)
    return _request(self, 999, 999, cmd, qtserver:genseqid(), uin, subcmd, query)
end

return qtserver
