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
local defaultBoatSpeed <const> = 4
local boatMinY <const> = 95
local boatMaxY <const> = 225

-- these are essentially "resources"
local mineImagetable = gfx.imagetable.new("images/mine/mine")
assert(mineImagetable)
local skylineImage = gfx.image.new("images/skyline.png")
assert(skylineImage)
local boatImagetable = gfx.imagetable.new("images/boat/boat")
assert(boatImagetable)
local collectibleImage = gfx.image.new("images/collectible.png")
assert(collectibleImage)

-- global-ish variables
local boatSprite = nil
local mineSprites = {}
local mineTimer = nil
local collectibleSprites = {}
local collectibleTimer = nil
local skylineSpriteA = nil
local skylineSpriteB = nil
local scrollSpeed = baseScrollSpeed
local gameOver = false

local function mineTimerCallback()	
	mineSprite = AnimatedSprite.new(mineImagetable)
	mineSprite:addState("float", 1, 4, { tickStep = 3 })
	mineSprite:playAnimation()
	mineSprite:moveTo(math.random(420, 460), math.random(105, 240))
	mineSprite:setCollideRect(6, 2, 32 - 6 * 2, 18)
	mineSprite:setTag(1)
	mineSprite:add()

	if mineSprites[1] == nil then
		mineSprites[1] = mineSprite
	else
		table.insert(mineSprites, mineSprite)
	end
end

local function collectibleTimerCallback()
	collectibleSprite = gfx.sprite.new(collectibleImage)
	collectibleSprite:moveTo(math.random(420, 460), math.random(105, 240))
	collectibleSprite:setCollideRect(0, 0, collectibleSprite:getSize())
	collectibleSprite:add()

	if collectibleSprites[1] == nil then
		collectibleSprites[1] = collectibleSprite
	else
		table.insert(collectibleSprites, collectibleSprite)
	end
end

function cleanUpGameObjects()
	gfx.sprite.removeAll()
	if mineTimer ~= nil then
		mineTimer:remove()
	end
	if collectibleTimer ~= nil then
		collectibleTimer:remove()
	end
end

function resetVariables()
	boatSprite = nil
	mineSprites = {}
	mineTimer = nil
	collectibleTimer = nil
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
	print("initGame")
	math.randomseed(playdate.getSecondsSinceEpoch())
	
	skylineSpriteA = gfx.sprite.new(skylineImage)
	skylineSpriteA:moveTo(0, 52)
	skylineSpriteA:add()

	skylineSpriteB = gfx.sprite.new(skylineImage)
	skylineSpriteB:moveTo(1920, 52)
	skylineSpriteB:add()
	
	boatSprite = AnimatedSprite.new(boatImagetable)
	boatSprite:addState("move", 1, 4, { tickStep = 3 })
	boatSprite:playAnimation()
	boatSprite:moveTo(80, 160)
	boatSprite:setCollideRect(50, 0, 65, 26)
	boatSprite:add()

	mineTimer = playdate.timer.new(1000, mineTimerCallback)
	mineTimer.repeats = true

	collectibleTimer = playdate.timer.new(1000, collectibleTimerCallback)
	collectibleTimer.repeats = true
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
		if playdate.buttonIsPressed( playdate.kButtonUp ) and boatSprite.y > boatMinY then
			boatSprite:moveBy(0, -defaultBoatSpeed)
		end
		if playdate.buttonIsPressed( playdate.kButtonDown ) and boatSprite.y < boatMaxY then
			boatSprite:moveBy(0, defaultBoatSpeed)
		end
	else
		local crankPosition = playdate.getCrankPosition()
		
		boatPositionFraction = nil
		
		if crankPosition <= 180 then
			boatPositionFraction = crankPosition / 180
		else
			boatPositionFraction = 1 - (crankPosition - 180) / 180
		end
		
		boatSprite:moveTo(80, boatMinY + (boatMaxY - boatMinY) * boatPositionFraction)
	end	
	
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
			mineSprites[index] = nil -- TODO: do this a better way
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

	for index, collectibleSprite in pairs(collectibleSprites) do
		collectibleSprite:moveBy(-scrollSpeed, 0)
		
		if collectibleSprite.x < -40 then
			collectibleSprite[index] = nil -- TODO: do this a better way
			collectibleSprite:remove()
		end
	
		sprites_collided_with_collectible = collectibleSprite:overlappingSprites()
		
		for i = 1, #sprites_collided_with_collectible do
			if sprites_collided_with_collectible[i] == boatSprite then
				collectibleSprite:remove()
			end
			
			-- prevent collectibles from overlapping with mines
			if sprites_collided_with_collectible[i]:getTag() == 1 then
				collectibleSprite:remove()
				collectibleTimerCallback() -- TODO: do outside the loop?
			end
		end
	end

	gfx.clear()
	gfx.sprite.update()
	playdate.timer.updateTimers()
end
