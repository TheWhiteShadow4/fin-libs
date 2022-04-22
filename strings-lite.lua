-- Utils functions for string (lite)
str = {}

function str.split(src, sep)
	if (sep == nil) then error("missing separator", 2) end
	local arr= {}
	for s in src:gmatch("[^"..sep.."]+") do
		table.insert(arr, s)
	end
	return arr
end

function len(s)
	if type(s) == 'string' then
		return __len_utf8(s)
	elseif type(s) == 'table' then
		return #s
	else
		return nil
	end
end

function __len_utf8(s)
	local len = 0
	local i = 1
	while s:byte(i) do
		if (s:byte(i) & 0xc0) ~= 0x80 then len = len+1 end
		i = i+1
	end
	return len
end