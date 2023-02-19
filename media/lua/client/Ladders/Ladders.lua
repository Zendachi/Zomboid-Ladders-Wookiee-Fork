local Ladders = {}

Ladders.topOfLadder = 'TopOfLadder'

function Ladders.getLadderObject(square)
	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local object = objects:get(i)
		local sprite = object:getSprite()
		if sprite then
			local prop = sprite:getProperties()
			if prop:Is(IsoFlagType.climbSheetN) or prop:Is(IsoFlagType.climbSheetS) or prop:Is(IsoFlagType.climbSheetE) or prop:Is(IsoFlagType.climbSheetW) then
				return object
			end
		end
	end
end

function Ladders.setFlags(square, sprite, flag)
	sprite:getProperties():Set(flag)
	square:getProperties():Set(flag)
end

function Ladders.unsetFlags(square, sprite, flag)
	sprite:getProperties():UnSet(flag)
	square:getProperties():UnSet(flag)
end

function Ladders.setTopOfLadderFlags(square, sprite, north)

	if north then
		Ladders.setFlags(square, sprite, IsoFlagType.climbSheetTopN)
		Ladders.setFlags(square, sprite, IsoFlagType.HoppableN)
	else
		Ladders.setFlags(square, sprite, IsoFlagType.climbSheetTopW)
		Ladders.setFlags(square, sprite, IsoFlagType.HoppableW)
	end
end

function Ladders.addTopOfLadder(square, north)

	local props = square:getProperties()
	if props:Is(IsoFlagType.WallN) or props:Is(IsoFlagType.WallW) or props:Is(IsoFlagType.WallNW) then
		return
	end

	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local object = objects:get(i)
		local name = object:getName()
		if name == Ladders.topOfLadder then
			Ladders.setTopOfLadderFlags(square, object:getSprite(), north)
			return
		end
	end

	local sprite = IsoSprite.new()
	Ladders.setTopOfLadderFlags(square, sprite, north)
	object = IsoObject.new(getCell(), square, sprite)
	object:setName(Ladders.topOfLadder)
	square:transmitAddObjectToSquare(object, -1)
end

function Ladders.removeTopOfLadder(square)

	local x = square:getX()
	local y = square:getY()

	for z = square:getZ() + 1, 8 do
		local aboveSquare = getSquare(x, y, z)
		if not aboveSquare then
			return
		end
		local objects = aboveSquare:getObjects()
		for i = 0, objects:size() - 1 do
			local object = objects:get(i)
			local name = object:getName()
			if name == Ladders.topOfLadder then
				aboveSquare:transmitRemoveItemFromSquare(object)
				return
			end
		end
	end
end

function Ladders.makeLadderClimbable(square, north)

	local x, y = square:getX(), square:getY()

	local topObject = nil
	local topSquare = square
	for z = square:getZ(), 8 do

		local aboveSquare = getSquare(x, y, z + 1)
		if not aboveSquare then
			return
		end
		local object = Ladders.getLadderObject(aboveSquare)
		if not object then
			Ladders.addTopOfLadder(aboveSquare, north)
			break
		end
	end
end

function Ladders.makeLadderClimbableFromTop(square)

	local x = square:getX()
	local y = square:getY()
	local z = square:getZ() - 1

	local belowSquare = getSquare(x, y, z)
	if belowSquare then
		Ladders.makeLadderClimbableFromBottom(getSquare(x - 1, y,     z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x + 1, y,     z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x,     y - 1, z))
		Ladders.makeLadderClimbableFromBottom(getSquare(x,     y + 1, z))
	end
end

function Ladders.makeLadderClimbableFromBottom(square)

	if not square then
		return
	end

	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local object = objects:get(i)
		local sprite = object:getSprite()
		if sprite then
			local prop = sprite:getProperties()
			if prop:Is(IsoFlagType.climbSheetN) then
				Ladders.makeLadderClimbable(square, true)
				break
			elseif prop:Is(IsoFlagType.climbSheetW) then
				Ladders.makeLadderClimbable(square, false)
				break
			end
		end
	end
end

-- The wookiee says to use getCore():getKey("Interact") 
-- because then it respects their vanilla rebindings.
function Ladders.OnKeyPressed(key)
    if key == getCore():getKey("Interact") then
		local square = getPlayer():getSquare()
		Ladders.makeLadderClimbableFromTop(square)
		Ladders.makeLadderClimbableFromBottom(square)
	end
end

Events.OnKeyPressed.Add(Ladders.OnKeyPressed)

-- Gamepad Support via Context-Sensitive Gamepad Prompt Activation

Ladders.validGamepadInput = function(playerIndex, button)
	playerIndex = (playerIndex or 0)
	local player = getSpecificPlayer(playerIndex)
	if not (player and player:isAlive()) then return end
	if button ~= Joypad.BButton then return end
	return player
end

Ladders.triggerGamepadClimbing = function(buttonPromptData, button, square, down)
	local playerIndex = buttonPromptData.player
	local player = Ladders.validGamepadInput(playerIndex, button)
	local location = player:getSquare()

	if (MainScreen.instance and MainScreen.instance:isVisible()) or not (player and location) then return end

	if down then -- Am I serious? Unfortunately . . . Yes.

		local window = location:getWindowTo(square)
		local thumpable = location:getWindowThumpableTo(square)

		if window or thumpable then
			if window and not window:IsOpen() then
				window:ToggleWindow(player)
			end

			-- The 4 below seems hardcoded in Java; its meaning is not obvious to me
			-- because I had to port this algorithm from decompiled Java code. :(
			if window and window:canClimbThrough(player) then
				player:climbThroughWindow(window, 4)
			elseif thumpable and thumpable:canClimbThrough(player) then
				player:climbThroughWindow(thumpable, 4)
			end

			player:climbDownSheetRope()

			return
		end

		local hoppable = location:getHoppableThumpableTo(square)
		local wall = location:getWallHoppableTo(square)

		if hoppable or wall then
			local direction = player:getDir()
			if IsoWindow.canClimbThroughHelper(player, location, square, direction == IsoDirections.N or direction == IsoDirections.S) then
				player:climbOverFence(player:getDir())
			end

			player:climbDownSheetRope()

			return
		end

		local frame = location:getWindowFrameTo(square)

		if frame then
			if (IsoWindowFrame.canClimbThrough(frame, player)) then
				player:climbThroughWindowFrame(frame)
			end

			player:climbDownSheetRope()

			return
		end

		-- Otherwise something is wonky, but we're still getting to that damn rope somehow.
		player:setX(square:getX())
		player:setY(square:getY())
		player:setZ(square:getZ())
		player:climbDownSheetRope()
	else -- Everything is immeasurably easier.
		Ladders.enRoute = true
		-- Walks to AND climbs the rope, rather than sort of teleporting to it
		-- (which is what happens if you use player:climbSheetRope() below).
		ISWorldObjectContextMenu.onClimbSheetRope(nil, square, false, playerIndex)
	end
end

Ladders.patchBestBButtonAction = function()
	
	-- Safe back-up in your module for others who may need this!
	Ladders.ISButtonPrompt = Ladders.ISButtonPrompt or {
		getBestBButtonAction = ISButtonPrompt.getBestBButtonAction 
	}

	function ISButtonPrompt:getBestBButtonAction(direction)
	
		-- Calling getBestBButtonAction back-up in the module created above.
		Ladders.ISButtonPrompt.getBestBButtonAction(self, original)

		if self.bPrompt and self.bPrompt ~= getText("ContextMenu_Climb_through") and self.bPrompt ~= getText("ContextMenu_Climb_over") then return end

		local playerIndex = self.player
		local player = getSpecificPlayer(playerIndex)
		local square = player:getSquare()

		-- This will prevent exceptions when you teleport and either
		--  your target location or its objects have not yet spawned.
		local ladder = (square and square:getObjects() and Ladders.getLadderObject(square))
		
		if ladder then
			Ladders.makeLadderClimbableFromTop(square)
			Ladders.makeLadderClimbableFromBottom(square)
			self:setBPrompt(getText("UI_Ladders_Climb"), Ladders.triggerGamepadClimbing, Joypad.BButton, square, false) 
			return
		end

		local original = direction

		direction = direction or player:getDir()

		if square then 
			if direction == IsoDirections.NE then
				square = square:getAdjacentSquare(IsoDirections.N) or square:getAdjacentSquare(IsoDirections.E)
			elseif direction == IsoDirections.NW then
				square = square:getAdjacentSquare(IsoDirections.N) or square:getAdjacentSquare(IsoDirections.W)
			elseif direction == IsoDirections.SE then
				square = square:getAdjacentSquare(IsoDirections.S) or square:getAdjacentSquare(IsoDirections.E)
			elseif direction == IsoDirections.SW then
				square = square:getAdjacentSquare(IsoDirections.S) or square:getAdjacentSquare(IsoDirections.W)
			else -- Direction is N, S, E, or W
				square = square:getAdjacentSquare(direction)
			end
		end

		below = square and getSquare(math.floor(square:getX()), math.floor(square:getY()), math.floor(square:getZ() - 1))

		-- ladder = (square and square:getObjects() and Ladders.getLadderObject(square))

		ladder = (square and player:canClimbDownSheetRope(square))

		ladderBelow = (below and square:getObjects() and Ladders.getLadderObject(below))

		if ladder then
			self:setBPrompt(getText("UI_Ladders_Climb"), Ladders.triggerGamepadClimbing, Joypad.BButton, square, true) 
			return
		elseif ladderBelow then -- Controller testing suggests need to do this from the bottom of a ladder to work properly.
			Ladders.makeLadderClimbableFromTop(below)
			Ladders.makeLadderClimbableFromBottom(below)
			self:setBPrompt(getText("UI_Ladders_Climb"), Ladders.triggerGamepadClimbing, Joypad.BButton, square, true) 
			return
		end
	
	end

end

Events.OnGameStart.Add(Ladders.patchBestBButtonAction)

-- Hide the progress bar for walking to the ladder because having one is beyond pointless.

Ladders.ISBaseTimedAction = {
	create = ISBaseTimedAction.create
}

function ISBaseTimedAction:create()
	Ladders.ISBaseTimedAction.create(self)
	if Ladders.enRoute then
		self.action:setUseProgressBar(false)
		Ladders.enRoute = nil
	end
end

--
-- Some tiles for ladders are missing the proper flags to
-- make them climbable so we add the missing flags here.
--

Ladders.tileFlags = {}
Ladders.tileFlags.location_sewer_01_32    = IsoFlagType.climbSheetW
Ladders.tileFlags.location_sewer_01_33    = IsoFlagType.climbSheetN
Ladders.tileFlags.industry_railroad_05_20 = IsoFlagType.climbSheetW
Ladders.tileFlags.industry_railroad_05_21 = IsoFlagType.climbSheetN
Ladders.tileFlags.industry_railroad_05_36 = IsoFlagType.climbSheetW
Ladders.tileFlags.industry_railroad_05_37 = IsoFlagType.climbSheetN

Ladders.holeTiles = {}
Ladders.holeTiles.floors_interior_carpet_01_24 = true

Ladders.poleTiles = {}
Ladders.poleTiles.recreational_sports_01_32 = true
Ladders.poleTiles.recreational_sports_01_33 = true

function Ladders.LoadGridsquare(square)

	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do

		local sprite = objects:get(i):getSprite()
		if sprite then
			local name = sprite:getName()
			if Ladders.tileFlags[name] then
				Ladders.setFlags(square, sprite, Ladders.tileFlags[name])
			elseif Ladders.holeTiles[name] then
				Ladders.setFlags(square, sprite, IsoFlagType.HoppableW)
				Ladders.setFlags(square, sprite, IsoFlagType.climbSheetTopW)
				Ladders.unsetFlags(square, sprite, IsoFlagType.solidfloor)
			elseif Ladders.poleTiles[name] and square:getZ() == 0 then
				Ladders.setFlags(square, sprite, IsoFlagType.climbSheetW)
			end
		end
	end
end

Events.LoadGridsquare.Add(Ladders.LoadGridsquare)

--
-- When a player places a crafted ladder, he won't be able to climb it unless:
-- - the ladder sprite has the proper flags set
-- - the player moves to another chunk and comes back
-- - the player quit and load the saved game
-- - the same sprite was already spawned and went through the LoadGridsquare event
--
-- We add the missing flags here to work around the issue.
--

-- Compatibility: Adding a backup for anyone who needs it.

Ladders.ISMoveablesAction = {
	perform = ISMoveablesAction.perform
}

local ISMoveablesAction_perform = ISMoveablesAction.perform

function ISMoveablesAction:perform()
	ISMoveablesAction_perform(self)

	if self.mode == 'pickup' then
		Ladders.removeTopOfLadder(self.square)

	elseif self.mode == 'place' then
		Ladders.LoadGridsquare(self.square)
		Ladders.makeLadderClimbableFromBottom(self.square)
	end
end

return Ladders