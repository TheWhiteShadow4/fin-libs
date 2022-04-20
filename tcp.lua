require 'events'

IP_TABLE = {}
TCP_TIMEOUT = 3000

--
-- Verwendung:
-- tcp = TCP(networkCard, "meineIPoderDNS")
-- server = tcp:listen(80)  Server hört auf http Port.
-- server:accept(function(c)
--     c.onMessage = function(...) end
-- end)
--
-- client = tcp:connect("meineIPoderDNS", 80)  Klient verbindet sich auf http Port.
-- client.onMessage = function(arg1, arg2) end
--

local function localPort(used)
	local p
	repeat
		p = math.random(5000, 10000)
	until used[p] == nil
	return p
end

local function await(f)
	local time = computer.millis()
	repeat
		interrups(0.05)
	until f() or computer.millis() > time + TCP_TIMEOUT	
	if computer.millis() > time + TCP_TIMEOUT then
		error("Connection timeout", 3)
	end
end


local ClientSocket = {}

function ClientSocket:new(o)
	setmetatable(o, self)
	self.__index = self
	return o
end

function ClientSocket:close()
	if self.tcp == nil then return end
	self.tcp:_close(self.rec, self.srcPort, self.port)
	self.rec = nil
	self.port = nil
end

function ClientSocket:send(...)
	if self.rec == nil then error("Not connected", 2) end
	self.tcp.nc:send(self.rec, self.port, ...)
end

--[[
vielleicht später mal
function ClientSocket:sendSync(...)
	if self.rec == nil then error("Not connected", 2) end
	self.tcp.nc:send(self.rec, self.port, "FIN", ...)
end
--]]

local ServerSocket = {}

function ServerSocket:new(o)
	setmetatable(o, self)
	self.__index = self
	return o
end

function ServerSocket:close()
	if self.tcp == nil then return end
	self.tcp:_close(self.rec, self.port)
	self.rec = nil
	self.port = nil
end

function ServerSocket:accept(callback)
	self.open = true
	if callback ~= nil then
		self.accept = callback
		return nil
	else
		local client = nil
		self.accept = function(c) client = c end
		while client == nil and self.open do
			interrups(0.1)
		end
		return client
	end
end

function ServerSocket:sendAll(...)
	if self.open == false then error("Not open", 2) end
	self.tcp.nc:send(self.rec, self.port, ...)
end

TCP = class(function(p, target, ip)
	if type(target) == 'string' then
		target = component.proxy(target)
	end
	if target == nil or target:getType().name ~= 'NetworkCard_C' then error("Invalid target", 3) end
	p.nc = target
	p.ip = ip or target.nick or target.ip
	p.cons = {}
	Events:add(p.nc, "NetworkMessage", TCP.handler, p)
	IP_TABLE[p.ip] = target
end)

function TCP:handler(evt, sender, port, flag, ...)
	--print("Event", sender, port, flag)

	local con = self.cons[port]
	if con == nil then return end
	if flag == "SYN" then
		local args = {...}
		local ip = args[1]
		-- Verwerfe Pakete, die nicht an uns adressiert sind.
		if ip ~= self.ip then return end
		if con.open then
			local dstPort = args[2]
			local srcPort = localPort(self.cons)
			self.nc:open(srcPort)
			self.nc:send(sender, dstPort, "ACK", self.nc.id, srcPort)
			local c = ClientSocket:new({tcp = self, rec = sender, srcPort = srcPort, port = dstPort})
			self.cons[srcPort] = c
			con.accept(c)
		end
	elseif flag == "ACK" then
		local args = {...}
		con.rec = args[1]
		con.port = args[2]
	elseif flag == "RST" then
		self.nc:close(port)
		self.cons[port] = nil
		if con.onClosed ~= nil then con.onClosed(flag, ...) end
	--elseif flag == "FIN" then
	--	self.nc:send("ACK")
	--	if con.onMessage ~= nil then con.onMessage(...) end
	else
		if con.onMessage ~= nil then con.onMessage(flag, ...) end
	end
end

function TCP:listen(port)
	self.nc:open(port)
	local s = ServerSocket:new({tcp = self, port = port})
	self.cons[port] = s
	return s
end

function TCP:connect(ip, port, cb)
	if ip == nil then error("Invalid ip", 2) end
	if ip == "::1" then ip = self.ip end
	local s = ClientSocket:new({tcp = self, ip = ip, port = port})
	s.srcPort = localPort(self.cons)
	self.nc:open(s.srcPort)
	self.cons[s.srcPort] = s
	if IP_TABLE[ip] ~= nil then
		self.nc:send(IP_TABLE[ip].id, port, "SYN", ip, s.srcPort)
	else
		self.nc:broadcast(port, "SYN", ip, s.srcPort)
	end
	
	s._time = computer.millis()
	Events:on({
		canGet = function()
			if computer.millis() > s._time + TCP_TIMEOUT then
				error("Connection timeout", 1)
			end
			return s.rec ~= nil
		end,
		get = function() return s end},
		cb)
	return s
end

function TCP:_close(rec, srcPort, dstPort)
	if rec ~= nil then self.nc:send(rec, dstPort, "RST") end
	self.nc:close(srcPort)
	self.cons[srcPort] = nil
end

function TCP:__tostring()
	return "TCP: "..self.ip
end