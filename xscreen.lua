require 'tcp'

XSCREEN_PORT = 12

-- Server, wo gezeichnet wird.
XServer = class(function(p, tcp)
	p.tcp = tcp
	p.clients = {}
	p.onInit = nil -- Muss überschriben werden!
	p.onUpdate = nil -- Für dynamische Inhalte.
end)

-- Client, wo das Bild angezeigt wird.
XClient = class(function(p, tcp, gui)
	p.tcp = tcp
	p.gui = gui
end)

XGui = class(function(p)
	p.buf = ""
end)

function XServer:start(port)
	if self.server ~= nil then error("Server already started.", 2) end
	port = port or XSCREEN_PORT
	self.server = self.tcp:listen(port)
	self.clients = {}
	self.server:accept(function(c)
		print("Client connected", c.rec)
		self.clients[c.tcp.ip] = c
		c.onMessage = function(cmd)
			if cmd == "draw" then
				local gui = XGui()
				self.onInit(gui)
				self.onUpdate(gui, true)
				c:send(gui.buf)
			elseif cmd == "ping" then
				c:send("pong")
			end
		end
		c.onClosed = function()
			table.remove(self.clients, c.tcp.ip)
		end
		c.onMessage("draw")
	end)
end

function XServer:stop()
	if self.server ~= nil then self.server:close() end
	self.server = nil
end

function XGui:flush() end

function XGui:setSize(w,h)
	self.buf = self.buf.."_g:setSize("..w..","..h..")"
	self.w = w
	self.h = h
end

function XGui:setBackground(r,g,b,a)
	self.buf = self.buf..string.format("_g:setBackground(%f,%f,%f,%f)", r, g, b, a)
end

function XGui:setForeground(r,g,b,a)
	self.buf = self.buf..string.format("_g:setForeground(%f,%f,%f,%f)", r, g, b, a)
end

function XGui:fill(x,y,w,h,ch)
	self.buf = self.buf..string.format("_g:fill(%d,%d,%d,%d,\"%s\")", x, y, w, h, ch)
end

function XGui:setText(x,y,txt)
	self.buf = self.buf..string.format("_g:setText(%d,%d,\"%s\")", x, y, txt)
end

function XServer:update()
	local gui = XGui()
	self.onUpdate(gui, false)
	for _,c in pairs(self.clients) do
		c:send(gui.buf)
	end
end

function XClient:connect(ip, port, cb)
	port = port or XSCREEN_PORT
	self.client = self.tcp:connect(ip, port, cb)
	self.client.onMessage = function(buf, ...)
		if buf == "pong" then return end
		--print("update screen")
		if self.gui == nil then return end
		_G['_g'] = self.gui
		load(buf)()
		self.gui:flush()
	end
end

function XClient:ping()
	self.client:send("ping")
end

function XClient:refresh()
	self.client:send("draw")
end