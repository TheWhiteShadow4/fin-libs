--[[
Event System 

-- Beispiele:
callback = function(evt, ...)
Events:add(component, "EventName", callback, context)
-- "context" ist optional und bezeichnet entweder das self Objekt im Callback, oder falls nicht angegeben die Komponente.

Events:remove(component, "EventName", callback)
-- oder
Events:removeAll(component)

-- Statt event.pull wird im Event interrups verwendet.
interrups()
--]]
require 'queue'
_G.Events = {
	queue = Queue(),
	handlers = {}
}
_event_listen = event.listen
_event_ignore = event.ignore

if error_handler == nil then 
	error_handler = function(e)
		print(debug.traceback(e, 2))
	end
end

function Events:add(component, ev, func, context)
	if (component == nil) then error("component is nil", 2) end
	xpcall(function()
		local chash = component.hash
		context = context or component
		local eventHandle = {context=context, f=func}
		if (ev == nil) then ev = '.' end
		if (self.handlers[chash] == nil) then
			map = {}
			map[ev] = {}
			map[ev][func] = eventHandle
			self.handlers[chash] = map
			_event_listen(component)
		elseif (self.handlers[chash][ev] == nil) then
			map = {}
			map[func] = eventHandle
			self.handlers[chash][ev] = map
		else
			self.handlers[chash][ev][func] = eventHandle
		end
	end, error_handler)
end

function Events:remove(component, ev, func)
	if (component == nil) then error("component is nil", 2) end
	xpcall(function()
		local chash = component.hash
		if (ev == nil) then ev = '.' end
		if (self.handlers[chash] ~= nil) then
			if (self.handlers[chash][ev] ~= nil) then
				self.handlers[chash][ev][func] = nil
				if (#self.handlers[chash][ev] == 0) then
					self.handlers[chash][ev] = nil
				end
				if (#self.handlers[chash] == 0) then
					_event_ignore(component)
					self.handlers[chash] = nil
				end
			end
		end
	end, error_handler)
end

function Events:removeAll(component)
	if (component == nil) then error("component is nil", 2) end
	xpcall(function()
		local chash = component.hash
		if (self.handlers[chash] ~= nil) then
			self.handlers[chash] = nil
		end
	end, error_handler)
end

function event.listen(c, f)
	if (f) then
		Events:add(c, '.', f)
	else
		error("Unsupported operation.")
	end
end

function event.ignore(c, f)
	if (f) then
		Events:remove(c, '.', f)
	else
		error("Unsupported operation.")
	end
end

function event.ignoreAll()
	error("Unsupported operation.")
end

function Events.emit(e, s, ...)
	if (e and s) then
		Events.queue:push({ev=e, src=s, args={...}})
	end
end

function Events:pull(e, s, ...)
	if (e and s) then
		Events.queue:push({ev=e, src=s, args={...}})
		return true
	else
		return false
	end
end

function fireEvent(h, entry)
	h.f(h.context, entry.ev, table.unpack(entry.args))
	--xpcall(h.f, error_handler, h.context, entry.ev, table.unpack(entry.args))
end

function interrups(timeout)
	timeout = timeout or 0.0
	while (Events:pull(event.pull(timeout))) do end

	while Events.queue:size() > 0 do
		local entry = Events.queue:pop()
		local src = Events.handlers[entry.src.hash]
		
		if (src ~= nil) then
			if (src[entry.ev] ~= nil) then
				for i,h in pairs(src[entry.ev]) do
					fireEvent(h, entry)
				end
			end
			if (src['.'] ~= nil) then
				for i,h in pairs(src['.']) do
					fireEvent(h, entry)
				end
			end
		end
	end
end
