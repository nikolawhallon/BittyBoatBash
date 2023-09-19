import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

-- from https://github.com/Whitebrim/AnimatedSprite
import "AnimatedSprite.lua"

-- constants
local gfx <const> = playdate.graphics
gfx.setBackgroundColor(gfx.kColorBlack)
local baseScrollSpeed <const> = 6

-- these are essentially "resources"
local mineImagetable = gfx.imagetable.new("images/mine/mine")
assert(mineImagetable)
local skylineImage = gfx.image.new("images/skyline.png")
assert(skylineImage)
local boatImagetable = gfx.imagetable.new("images/boat/boat")
assert(boatImagetable)

-- global-ish variables
local boatSprite = nil
local mineSprites = {}
local mineTimer = nil
local skylineSpriteA = nil
local skylineSpriteB = nil
local scrollSpeed = baseScrollSpeed
local gameOver = false

local function mineTimerCallback()	
	mineSprite = AnimatedSprite.new(mineImagetable)
	mineSprite:addState("float", 1, 4, { tickStep = 3 })
	mineSprite:playAnimation()
	mineSprite:moveTo( 440, math.random(105, 240) )
	mineSprite:setCollideRect(6, 2, 32 - 6 * 2, 18)
	mineSprite:add()

	if mineSprites[1] == nil then
		mineSprites[1] = mineSprite
	else
		table.insert(mineSprites, mineSprite)
	end
end

function cleanUpGameObjects()
	gfx.sprite.removeAll()
	if mineTimer ~= nil then
		mineTimer:remove()
	end
end

function resetVariables()
	boatSprite = nil
	mineSprites = {}
	mineTimer = nil
	skylineSpriteA = nil
	skylineSpriteB = nil
	scrollSpeed = baseScrollSpeed
	gameOver = false
end

function reInitGame()
	cleanUpGameObjects()
	resetVariables()
	initGame()
end

function initGame()	
	math.randomseed(playdate.getSecondsSinceEpoch())
	
	skylineSpriteA = gfx.sprite.new(skylineImage)
	skylineSpriteA:moveTo(0, 52)
	skylineSpriteA:add()

	skylineSpriteB = gfx.sprite.new(skylineImage)
	skylineSpriteB:moveTo(1920, 52)
	skylineSpriteB:add()
	
	boatSprite = AnimatedSprite.new(boatImagetable)
	boatSprite:addState("move", 1, 4, { tickStep = 3 })
	boatSprite:addState("moveSlow", 1, 4, { tickStep = 4 })
	boatSprite:addState("moveFast", 1, 4, { tickStep = 2 })
	boatSprite:playAnimation()
	boatSprite:moveTo(80, 160)
	boatSprite:setCollideRect(50, 0, 65, 26)
	boatSprite:add()

	mineTimer = playdate.timer.new(1000, mineTimerCallback)
	mineTimer.repeats = true
end

initGame()

function playdate.update()
	if gameOver then
		if playdate.buttonIsPressed( playdate.kButtonA ) then
			reInitGame()
		end
		return
	end
	
	if playdate.isCrankDocked() then
		if playdate.buttonIsPressed( playdate.kButtonUp ) and boatSprite.y > 95 then
			boatSprite:moveBy(0, -4)
		end
		if playdate.buttonIsPressed( playdate.kButtonDown ) and boatSprite.y < 225 then
			boatSprite:moveBy(0, 4)
		end
	else
		-- use crankAcceleratedChange to deal with plane speeds via something like
		-- the commented out scroll speed logic
		local crankChange, crankAcceleratedChange = playdate.getCrankChange()
		--print(crankAcceleratedChange)
		--scrollSpeed = math.max(baseScrollSpeed + crankAcceleratedChange, 1)
		
		local crankPosition = playdate.getCrankPosition()
		
		boatPositionFraction = nil
		
		if crankPosition <= 180 then
			boatPositionFraction = crankPosition / 180
		else
			boatPositionFraction = 1 - (crankPosition - 180) / 180
		end
		
		-- y position range is 95 - 225 (so a range of 130 values)
		boatSprite:moveTo(80, 95 + 130 * boatPositionFraction)
	end	
	
	-- consider whether to include this or not at all - it's useful to show how to switch animations at least
	--[[
	if playdate.buttonIsPressed( playdate.kButtonRight ) or playdate.buttonIsPressed( playdate.kButtonA ) then
		scrollSpeed = baseScrollSpeed + 2
		boatSprite:changeState("moveFast", true)
	elseif playdate.buttonIsPressed( playdate.kButtonLeft ) or playdate.buttonIsPressed( playdate.kButtonB ) then
		scrollSpeed = baseScrollSpeed - 2
		boatSprite:changeState("moveSlow", true)
	else
		scrollSpeed = baseScrollSpeed
		boatSprite:changeState("move", true)
	end
	--]]
	
	skylineSpriteA:moveBy(-scrollSpeed, 0)
	skylineSpriteB:moveBy(-scrollSpeed, 0)
		
	if skylineSpriteA.x <= -1920 then
		skylineSpriteA:moveBy(1920 * 2, 0)
	end

	if skylineSpriteB.x <= -1920 then
		skylineSpriteB:moveBy(1920 * 2, 0)
	end

	for index, mineSprite in pairs(mineSprites) do
		mineSprite:moveBy(-scrollSpeed, 0)
		
		if mineSprite.x < -40 then
			mineSprites[index] = nil -- do this a better way
			mineSprite:remove()
		end

		sprites_collided_with_mine = mineSprite:overlappingSprites()
		
		for i = 1, #sprites_collided_with_mine do
			if sprites_collided_with_mine[i] == boatSprite then
				boatSprite:remove()
				mineSprite:remove()
				gameOver = true
			end
		end
	end

	gfx.clear()
	gfx.sprite.update()
	playdate.timer.updateTimers()
end
