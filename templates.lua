require 'class'
require 'strings-lite'

Template = class(function(p, filename)
	p.content = str.split(readFile(filename), "\n")
	p.meta = str.split(p.content[1], "|")
	p.content[1] = nil

	p.width = tonumber(p.meta[1])
	p.height = tonumber(p.meta[2])
	if #p.meta > 2 then
		p.fg = load(p.meta[3])
		p.bg = load(p.meta[4])
	else
		p.fg = {1, 1, 1, 1}
		p.bg = {0, 0, 0, 1}
	end
end)

function Template:draw(gpu)
	local w = self.width
	local h = self.height

	gpu:setSize(w, h)
	gpu:setForeground(1, 1, 1, 1)
	gpu:setBackground(0, 0, 0, 1)
	gpu:fill(0, 0, w, h, " ")
	for y=0,#self.content-2 do
		gpu:setText(0, y, self.content[y+2])
	end
end