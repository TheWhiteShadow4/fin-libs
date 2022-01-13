lfs = require "lfs"
ffi = require("ffi")
ffi.cdef[[
void Sleep(int ms);
]]

-- Lookup Tables
local classes = {}
local structs = {}
local items = {}

function typeof(t, c)
	return t ~= nil and t.__index == c
end

local function hash()
	return math.random(1, 4294967295)
end

local Class = {
	__tostring = function(self) return "Class" end
}
function Class:getType() return self end
Class.__index = Class

--- Definiert ein Klassen Objekt für einen Typen und fügt dieses zur Lookuptable hinzu.
function defineClass(spec, init)
	local c = {}
	local base = spec.base
	if type(base) == 'table' then
		for i,v in pairs(base) do c[i] = v end
		c._base = base
	end
	c.__index = c
	local cls = {}
	setmetatable(cls, Class)
	-- Konstruktor setzen
	c.init = init
	cls.displayName = spec.displayName
	-- Instanzierungs Funktion für neue Objekte
	cls.instantiate = function(...)
		local obj = {}
		obj.hash = hash()
		setmetatable(obj,c)
		--print("instantiate", dump(c, 1))
		
		if base then
			print("has base", base)
			local parent = base
			if parent and parent.init then
				parent.init(obj, ...)
			end
		end
		if c.init then c.init(obj,...) end
		return obj
	end
	-- Basis Funktionen jeder Klasse
	c.getHash = function() return c.hash end
	c.getType = function() return cls end
	if type(spec.aliase) == 'table' then
		cls.name = spec.aliase[1]
		-- in Lookup Tabelle eintragen
		for _,n in pairs(spec.aliase) do
			classes[n] = cls
		end
	end
	return c
end

function defineStruct(name, struct)
	structs[name] = struct
end

function defineItem(name, item)
	items[name] = item
end

local table_keys = function(t)
	local keys={}
	local n=0
	for k,_ in pairs(t) do
		n=n+1
		keys[n]=k
	end
	return keys
end

-- Lazy Array. Erstellt bei jeder neuen Indizierung ein neues Objekt
-- mittels einer Factory Funktion.
-- Die Factory Funktion kann mit 'next' kaskadiert werden.
function lazyArray(func, ...)
	local a = {}
	local args = {...}
	setmetatable(a, {
		__index = function(a, i)
			if type(i) == 'number' and i > 0 then
				local obj = func(table.unpack(args))
				if type(a.next) == 'function' then
					obj = a.next(obj)
				end
				a[i] = obj
				return obj
			else
				return nil
			end
		end
	})
	return a
end

function findClass(str)
	return classes[str]
end

function findStruct(str)
	return structs[str]
end

function findItem(str)
	return items[str]
end

Network = Network or {}
ALIASES = {}

function addNetworkComponent(comp)
	if comp == nil then error("componment is nil") end
	if Network[comp.id] == nil then
		Network[comp.id] = comp
	end
end

local function newUID()
	local id = ""
	for i = 1,16 do
		r = math.random(0, 15)
		id = id..(r > 9 and string.char(r + 55) or r)
	end
	return id
end

_Component = defineClass({}, function(p)
	p.id = newUID()
end)

function _Component:__tostring()
	if self:getType() ~= nil then
		return self:getType().name..' '..self.id
	else
		return self.id
	end
end

--- Erstellt ein Array mit einer neuen virtuellen Netzwerk Komponente mit zufällig generierter Id.
--- Die so erstellte Komponente wird dem Netzwerk hinzugefügt.
function componentFactory(cls, nick)
	-- Komponente erstellen und ins Netzwerk einfügen.
	local comp = cls:instantiate()

	if comp == nil then error("Component instance can not created.") end
	if comp.id ~= nil then
		Network[comp.id] = comp
		comp.nick = nick
		if nick ~= nil then
			if ALIASES[nick] == nil then ALIASES[nick] = {} end
			table.insert(ALIASES[nick], comp)
		end
	end
	return comp
end

computer = {
	beep = function(pitch) end,
	stop = function() os.exit() end,
	panic = function(error)
		print(error)
		computer.stop()
	end,
	reset = function() end,
	skip = function() end,
	getEEPROM = function() end,
	setEEPROM = function(code) end,
	time = function() return 0 end,
	millis = function() return os.clock()*1000.0 end,
	getPCIDevices = function(type)
		if not typeof(type, Class) then error("Instance is invalid", 2) end
		cls = classes[type.name]
		if cls == nil then error("Instance is invalid", 2) end
		return lazyArray(componentFactory, cls, nil)
	end
}

component = {
	proxy = function(ids)
		if type(ids) == 'table' then
			-- Kaskadiere Lazy Arrays
			if getmetatable(ids) ~= nil then
				ids.next = component.proxy
				return ids
			end
			ret = {}
			for _,id in pairs(ids) do
				table.insert(ret, component.proxy(id))
			end
			return ret
		else
			if type(ids) ~= "string" then error("id is not a string", 2) end
			return Network[ids]
		end
	end,
	findComponent = function(query)
		if query == nil then return {} end
		
		if Network[query] ~= nil then
			return Network[query].id
		elseif ALIASES[query] ~= nil then
			ids = {}
			for k,v in pairs(ALIASES[query]) do
				table.insert(ids, v.id)
			end
			return ids
		elseif query == "" then
			return table_keys(Network)
		elseif getmetatable(query) == Class then
			return lazyArray(function(...)
					return componentFactory(...).id
				end, query, nil)
		else
			print("findComponent {}")
			return {}
		end
	end
}

local LISTENING = {}
local EVENT_QUEUE = {}

function queueEvent(evt)
	table.insert(EVENT_QUEUE, evt)
end

event = {
	listen = function(comp)
		if comp.id == nil then error("Invalid component") end
		comp._fire = function(self, evt, ...)
			print("fire", self, evt, ...)
			if type(evt) ~= "string" then error("Event type must be a string!") end
			queueEvent({evt, self, ...})
		end
		LISTENING[comp.id] = comp
	end,
	
	listening = function()
		l = {}
		for _,c in pairs(LISTENING) do
			table.insert(l, c)
		end
		return l
	end,
	
	ignore = function(comp)
		if comp.id == nil then error("Invalid component") end
		-- Leere Funktion statt nil ist stabiler.
		LISTENING[comp.id]._fire = function() end
		LISTENING[comp.id] = nil
	end,
	
	ignoreAll = function()
		for _,c in pairs(LISTENING) do
			event.ignore(c)
		end
	end,
	
	clear = function() EVENT_QUEUE = {} end,
	
	pull = function(n)
		if #EVENT_QUEUE > 0 then
			return table.unpack(table.remove(EVENT_QUEUE))
		else
			if n ~= nil and n > 0 then ffi.C.Sleep(n*1000.0) end
		end
	end
}

FS_ROOT = "drives/"
local ROOT_DEVICE = nil
local DRIVES = {}

local function startsWith(str, c)
	if (#str < #c) then return false end
    return string.sub(str, 1, #c) == c
end

local function stripPath(path)
	if path == "" or path == "/" then return "/" end
	path = string.gsub(path..'/', '/+$', '/')
	path = string.gsub(path, '^/+', '')
	return path
end

local function findFile(name)
	for k,v in pairs(DRIVES) do
		if startsWith(name, k) then
			local path = '/'..v..string.sub(name, #k+1, #name)
			return string.gsub(lfs.currentdir(), "\\", "/")..path
		end
	end
	return nil
end

filesystem = {
	initFileSystem = function(path)
		if ROOT_DEVICE ~= nil then return false end
		path = stripPath(path)
		if path == "/" then error("Empty device is not allowed.", 2) end
		ROOT_DEVICE = path
	end,
	makeFileSystem = function(type, name) end,
	removeFileSystem = function(name) end,
	mount = function(device, mountPoint)
		device = stripPath(device)
		if startsWith(device, ROOT_DEVICE) then
			local drive = string.sub(device, #ROOT_DEVICE+1, #device)
			if drive ~= nil then
				drive = FS_ROOT..drive
				mountPoint = string.gsub(mountPoint, '^/', '')
				DRIVES[mountPoint] = drive
				return os.rename(drive, drive) and true or false
			end
			return false
		end
	end,
	open = function(path, mode)
		path = string.gsub(path, '^//', '/')
		local file = findFile(path)
		return io.open(file, mode)
	end,
	createDir = function(path) end,
	remove = function(path) end,
	move = function(from, to) end,
	rename = function(path, name) end,
	childs = function(path)
		if ROOT_DEVICE == nil then error("no device at path found", 2) end
		local list = {}
		local entry
		for entry in lfs.dir(FS_ROOT) do
			if entry ~= "." and entry ~= ".." then
				table.insert(list, '/'..entry)
			end
		end
		return list
	end,
	exists = function(path) end,
	isFile = function(path) end,
	isDir = function(path) end,
	doFile = function(path) end,
	loadFile = function(path) end,
}

_Actor = defineClass({base = _Component}, function(p)
	print("init _Actor")
	p.location = {0, 0, 0}
	p.scale = {1, 1, 1}
	p.rotation = {0, 0, 0}
end)

function _Actor:getPowerConnectors()
	return {}
end

function _Actor:getFactoryConnectors()
	return {}
end

function _Actor:getPipeConnectors()
	return {}
end

function _Actor:getInventories()
	return {}
end

function _Actor:getNetworkConnectors()
	return {}
end

GPUT1Buffer = {}

function GPUT1Buffer:setSize(w, h)
	self.width = w
	self.height = h
end

function GPUT1Buffer:getSize()
	return self.width, self.height
end

function GPUT1Buffer:get(x, y, c, fg, bg) end
function GPUT1Buffer:set(x, y, c, fg, bg) end
function GPUT1Buffer:setText(x, y, txt, fg, bg) end
function GPUT1Buffer:fill(x, y, w, h, c, fg, bg) end
function GPUT1Buffer:setRaw(x, y, c, fg, bg) end
function GPUT1Buffer:copy(x, y, buffer, textMode, fgMode, bgMode) end
function GPUT1Buffer:clone()
	return GPUT1Buffer:new({width=self.width, height=self.height})
end

function GPUT1Buffer:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

FINComputerGPU = defineClass({
	aliase = {"GPU_T1_C", "GPUT1"},
	displayName = "Computer GPU T1"
}, function(p)
	p._width=120
	p._height=40
	p.screen=nil
	p.buffer=GPUT1Buffer:new({width=p._width, height=p._height})
	p.fg = {r=1.0,g=1.0,b=1.0,a=1.0}
	p.bg = {r=0.0,g=0.0,b=0.0,a=1.0}
end)

function FINComputerGPU:bindScreen(screen)
	self.screen = screen
end
function FINComputerGPU:setSize(w, h)
	local oldW, oldH = self.buffer:getSize()
	self.buffer:setSize(w, h)
	queueEvent(ScreenSizeChanged, self, oldW, oldH)
end
function FINComputerGPU:getSize()
	return self.buffer:getSize()
end
function FINComputerGPU:setForeground(r, g, b, a)
	self.fg.r = r
	self.fg.g = g
	self.fg.b = b
	self.fg.a = a
end
function FINComputerGPU:setBackground(r, g, b, a)
	self.bg.r = r
	self.bg.g = g
	self.bg.b = b
	self.bg.a = a
end
function FINComputerGPU:setBuffer(buffer)
	if typeof(buffer, GPUT1Buffer) then
		self.buffer = GPUT1Buffer:new({width=0,height=0})
	else
		self.buffer = buffer
	end
end

function FINComputerGPU:getScreen() return self.screen end
function FINComputerGPU:getBuffer() return self.buffer end
function FINComputerGPU:flush() end
function FINComputerGPU:fill(x, y, w, h, str) self.buffer:fill(x, y, w, h, str) end
function FINComputerGPU:setText(x, y, str) self.buffer:setText(x, y, str) end

FINComputerScreen = defineClass({
	base = _Component,
	aliase = {"Build_Screen_C", "Screen"},
	displayName = "Large Screen"
})

NetworkCard = defineClass({
	base = _Component,
	aliase = {"NetworkCard_C", "NetworkCard"},
	displayName = "NetworkCard"
}, function (p)
	addNetworkComponent(p)
end)

function NetworkCard:open(port)

end

function NetworkCard:close(port)

end

function NetworkCard:closeAll()

end

function NetworkCard:send(rec, port, ...)
	if rec == nil then error("reciever is nil", 2) end
	if port > 10000 then print("Warning! unsafe port number", 2) end
	-- Erstelle direkt ein Event beim Empfänger.
	if LISTENING[rec] ~= nil then
		queueEvent({"NetworkMessage", Network[rec], self.id, port, ...})
	end
end

function NetworkCard:broadcast(port, ...)
	if port > 10000 then print("Warning! unsafe port number", 2) end
	for id,c in pairs(Network) do
		if c:getType().name == "NetworkCard_C" then
			if LISTENING[id] ~= nil then
				queueEvent({"NetworkMessage", c, self.id, port, ...})
			end
		end
	end
end

Powerpol = defineClass({
	base = _Actor,
	aliase = {"Build_PowerPoleMk1_C"}
})

function Powerpol:getPowerConnectors()
	return {PowerConnection:new({owner=self})}
end

PowerConnection = {
	owner = nil,
	connections = 0,
	maxConnections = 4
}
function PowerConnection:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function PowerConnection:getPower()
	return nil
end