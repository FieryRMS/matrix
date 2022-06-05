local gfx <const> = playdate.graphics
local floor <const> = math.floor
local random <const> = math.random

local screenWidth <const> = playdate.display.getWidth()
local screenHeight <const> = playdate.display.getHeight()
local glyphWidth <const> = 20
local numColumns <const> = floor(screenWidth / glyphWidth)
local numRows <const> = floor(screenHeight / glyphWidth)
local numCells <const> = numColumns * numRows

local numGlyphs <const> = 133
local numFades <const> = 32
local glyphs = {}

do
	local glyphSpritesheet = gfx.image.new('images/matrix-glyphs')
	local spritesheetColumns = floor(glyphSpritesheet.width / glyphWidth)
	local fadeGradient = gfx.image.new('images/fade-gradient')
	local glyph = gfx.image.new(glyphWidth, glyphWidth, gfx.kColorBlack)

	for i = 1, numGlyphs do
		local column = (i - 1) % spritesheetColumns
		local row = floor((i - 1) / spritesheetColumns)
		gfx.lockFocus(glyph)
		glyphSpritesheet:draw(-column * glyphWidth, -row * glyphWidth)
		gfx.unlockFocus()
		glyphs[i] = {}
		for j = 1, numFades do
			local fade = (j - 1) / (numFades - 1)
			local variant = glyph:copy()
			glyphs[i][j] = variant
			gfx.lockFocus(variant)
			fadeGradient:draw(fade * (glyphWidth - fadeGradient.width), 0)
			gfx.unlockFocus()
		end
	end
end

local minSpeed <const> = 0.15
local maxSpeed <const> = 1
local time = 0
local speed = maxSpeed

local sineTable = {}
for i = 1,360 do
	sineTable[i] = math.sin(math.pi / 180 * i)
end

-- function fastSin(x)
-- 	x = x / 360 % 1
-- 	local sign
-- 	if x < 0.5 then
-- 		sign = -1
-- 	else
-- 		sign = 1
-- 	end
-- 	x = (x % 0.5) * 2 - 0.5
-- 	return sign * x * x * 4 - 1
-- end

local wobbleA <const> = math.sqrt(2) / 50
local wobbleB <const> = math.sqrt(5) / 50

local cells = {}
for x = 1, numColumns do
	local columnTimeOffset = random() * 1000
	local columnSpeedOffset = random() * 0.5 + 0.5
	for y = 1, numRows do
		local cell = {}
		cell.x = x
		cell.y = y
		cell.glyphCycle = random()
		cell.columnTimeOffset = columnTimeOffset
		cell.columnSpeedOffset = columnSpeedOffset
		cell.glyphIndex = floor(random() * numGlyphs) + 1
		cell.fadeIndex = -1

		cells[#cells + 1] = cell
	end
end

playdate.display.setRefreshRate(0)
playdate.resetElapsedTime()

function playdate.update()
	local delta
	if playdate.isCrankDocked() then
		speed = math.min(maxSpeed, speed + 0.07)
		delta = playdate.getElapsedTime() * speed
	else
		speed = math.max(minSpeed, speed - 0.07)
		delta = playdate.getElapsedTime() * speed + playdate.getCrankChange() * 2 / 360 -- TODO: tune
	end
	playdate.resetElapsedTime()
	time += delta

	for i = 1, numCells do
		local mustDraw = false
		local cell = cells[i]

		local cellTime = cell.y * -0.03 + cell.columnTimeOffset + time * cell.columnSpeedOffset
		local brightness = 4 * (
			(
				cellTime
				+ 0.3 * sineTable[floor((wobbleA * cellTime) % 360) + 1]
				+ 0.2 * sineTable[floor((wobbleB * cellTime) % 360) + 1]
			) % 1
		)
		local fadeIndex = floor(brightness * numFades)
		if fadeIndex < 1 then fadeIndex = 1 end
		if fadeIndex > numFades then fadeIndex = numFades end
		if cell.fadeIndex ~= fadeIndex then
			cell.fadeIndex = fadeIndex
			mustDraw = true
		end

		cell.glyphCycle = cell.glyphCycle + delta * 2
		if cell.glyphCycle > 1 then
			cell.glyphCycle = cell.glyphCycle % 1
			local glyphIndex = (cell.glyphIndex + random(20)) % numGlyphs + 1
			if cell.glyphIndex ~= glyphIndex then
				cell.glyphIndex = glyphIndex
				if fadeIndex < numFades then
					mustDraw = true
				end
			end
		end

		if mustDraw then
			glyphs[cell.glyphIndex][cell.fadeIndex]:draw((cell.x - 1) * glyphWidth, (cell.y - 1) * glyphWidth)
		end
	end
end
