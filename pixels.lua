--[[
Buffered Pixel Mapper for mapping Pixels to a screen in three possible modes.

rgb_bitmap = ...
image = pixels.from_rgb(gpu, 150, 100, rgb_bitmap, PIXEL_MODE.SUB)
image:draw(0, 0, gpu)

--]]
PIXEL_MODE = {
	ONE = 0, -- One to one mapping.
	SUB = 1, -- Screen pixels are vertical divided to two logical pixels.
	WIDE = 2 -- Logical pixels are horizontal stretched to two screen pixels.
}


Image = {}
function Image:new(buf)
	local o = {buffer = buf}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Image:draw(x, y, gpu)
	local b = gpu:getBuffer()
	b:copy(x, y, self.buffer, 0, 0, 0)
	gpu:setBuffer(b)
end

local read_color = function(data, idx)
	return {
		string.byte(string.sub(data, idx + 0, idx + 0)) / 255.0,
		string.byte(string.sub(data, idx + 1, idx + 1)) / 255.0,
		string.byte(string.sub(data, idx + 2, idx + 2)) / 255.0,
		1}
end

pixels = {
	from_rgb = function(gpu, width, height, data, pixel_mode)
		local buf = gpu:getBuffer()
		if pixel_mode == PIXEL_MODE.SUB then
			height = height/2
			buf:setSize(width, height)
			local w = width-1
			local h = height-1
			for y = 0,h,1 do
				for x = 0,w,1 do
					local i = (x + y*2 * width)*3
					local c1 = read_color(data, i + 1)
					local c2 = read_color(data, i + 1 + width*3)
					buf:set(x, y, '▀', c1, c2)
				end
			end
		elseif pixel_mode == PIXEL_MODE.ONE then
			buf:setSize(width, height)
			local w = width-1
			local h = height-1
			for y = 0,h,1 do
				for x = 0,w,1 do
					local i = (x + y * width)*3
					local c = read_color(data, i + 1)
					buf:set(x, y, ' ', c, c)
				end
			end
		elseif pixel_mode == PIXEL_MODE.WIDE then
			width = width * 2
			buf:setSize(width, height)
			local w = width-1
			local h = height-1
			for y = 0,h,1 do
				for x = 0,w,1 do
					local i = (x + y * width)*3
					local c = read_color(data, i + 1)
					buf:set(x*2, y, ' ', c, c)
					buf:set(x*2+1, y, ' ', c, c)
				end
			end
		else
			error("Invalid pixel mode", 2)
		end
		return Image:new(buf)
	end
}
