require 'class'

Queue = class(function(p)
	p._first = nil
	p._last = nil
	p.n = 0
end)

function Queue:push(e)
	local item = {e=e,next=nil}
	if (not self._first) then
		self._first = item
	else
		self._last.next = item
	end
	self._last = item
	self.n = self.n + 1
end

function Queue:pop()
	if (not self._first) then return nil end
	local item = self._first
	self._first = item.next
	self.n = self.n - 1
	return item.e
end

function Queue:first()
	return self.n > 0 and self._first.e or nil
end

function Queue:last()
	return self.n > 0 and self._last.e or nil
end

function Queue:size()
	return self.n
end
return Queue