-- Create addon stuff
local AssistAssistSB = CreateFrame("Button", "AssistAssistSB", UIParent, "SecureActionButtonTemplate")
local AssistAssist = LibStub("AceAddon-3.0"):NewAddon(AssistAssistSB, "AssistAssist", "AceEvent-3.0")
local Config = AssistAssist:NewModule("Config")

-- Name keybindings
BINDING_HEADER_ASSISTASSIST = "AssistAssist"
_G["BINDING_NAME_CLICK AssistAssistSB:LeftButton"] = "Assist tank / mark target if you're the tank"
BINDING_NAME_AASETASSIST = "Set target as assist, mark if none"

-- Slash command

SLASH_ASSISTASSIST1 = "/assistassist"
SlashCmdList["ASSISTASSIST"] = function() InterfaceOptionsFrame_OpenToCategory("AssistAssist") end

-- LDB Button

local ldbObject = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("AssistAssist", {
	type = "data source",
	icon = "Interface\\Icons\\Ability_Hunter_Snipershot",
	text = "initializing"
})

function ldbObject:OnClick(button)
	if button == "LeftButton" then
		AssistAssist:setManualAssistToTarget()
	elseif button == "RightButton" then
		InterfaceOptionsFrame_OpenToCategory("AssistAssist") 
	end
end

ldbObject.OnTooltipShow = function(tooltip)
	if not tooltip or not tooltip.AddLine then return end
	tooltip:AddLine("AssistAssist "..GetAddOnMetadata("AssistAssist", "Version"))
	tooltip:AddLine("Left-click to set target as tank/assist")
	tooltip:AddLine("Left-click targeting self to set to mark")
	tooltip:AddLine("Left-click with no target to return to auto mode")
	tooltip:AddLine("Right-click for options")
	tooltip:AddLine(AssistAssist:getLongStatusText(), 1, 1, 1)
end

-- Utility stuff

local marks = {"star", "circle", "diamond", "triangle", "moon", "square", "X", "skull"}

local function getPlayerName() -- less server querying
	local playerName
	if playerName then
		return playerName
	else
		playerName = UnitName("PLAYER")
		return playerName
	end
end

local function getTank(changedPlayer, newRole)
	-- arguments are supplied if we have data a server query wouldn't give us yet
	-- preferentially return ourselves if we are a tank
	if UnitGroupRolesAssigned("PLAYER") == "TANK"
	or (changedPlayer == getPlayerName() and newRole == "TANK") then 
		return getPlayerName()
	end
	-- otherwise find another tank
	for _, groupType in ipairs({"Raid", "Party"}) do
		for i = 1, _G["GetNum"..groupType.."Members"]() do
			local currentPlayer = UnitName(groupType..i)
			if currentPlayer == getPlayerName() then
				-- ignore since this function is *other* tank
			elseif currentPlayer ~= changedPlayer then
				if UnitGroupRolesAssigned(currentPlayer) == "TANK" then
					return currentPlayer
				end
			else
				if newRole == "TANK" then
					return currentPlayer
				end
			end
		end
	end
end

-- Macro class

local Macro = {}
Macro.__Index = Macro

function Macro.__eq(a, b)
	return a.text == b.text
end

function Macro:newWithContents(text, description)
	local o = { text = text, description = description }
	setmetatable(o, Macro)
	return o
end

function Macro:newEmpty()
	return self:newWithContents("", "doing nothing")
end

function Macro:newToAssist(assist)
	return self:newWithContents("/assist "..assist, "assisting "..assist)
end

function Macro:newToMark()
	local text = [[/script SetRaidTarget("target", "]]..AssistAssist.db.profile.mark..[[")]]
	local description = [[applying ]]..marks[tonumber(AssistAssist.db.profile.mark)].."s"
	return self:newWithContents(text, description)
end

function Macro:newCurrentMacro(changedPlayer, newRole)
	-- is there a manually set assist?
	if AssistAssist.manualAssist then
		if AssistAssist.manualAssist ~= getPlayerName() then -- if it's someone else,
			return self:newToAssist(AssistAssist.manualAssist) -- assist them
		else -- if it's us,
			return self:newToMark() -- mark
		end
	end
	-- get the tank
	local tank = getTank(changedPlayer, newRole)
	-- is that us?
	if tank == getPlayerName() then
		return self:newToMark()
	-- is there another tank?
	elseif tank ~= nil then
		return self:newToAssist(tank)
	-- do we want to mark otherwise?
	elseif AssistAssist.db.profile.noTank == "mark" then
		return self:newToMark()
	-- otherwise nothing
	else
		return self:newEmpty()
	end
end

--  AssistAssist methods
AssistAssist.queuedMacro = Macro:newEmpty() -- store latest update; empty for now to not break ldb
AssistAssist.currentMacro = Macro:newEmpty() -- for info on current macro
AssistAssist.printPrefix = "<AssistAssist> "

function AssistAssist:getWaySet()
	if self.manualAssist ~= nil then
		return "manually"
	else
		return "automatically"
	end
end

function AssistAssist:getUpdateText()
	if self.queuedMacro == self.currentMacro then
		return self.printPrefix.."Your assist key has been "..self:getWaySet().." set for "..self.currentMacro.description
	else
		return self.printPrefix.."Changed "..self:getWaySet().." in combat. Assist key will be set to "..self.queuedMacro.description.." when you leave combat"
	end
end

function AssistAssist:getShortStatusText()
	if self.queuedMacro == self.currentMacro then
		return self.currentMacro.description
	else
		return self.currentMacro.description.." ("..self.queuedMacro.description..")"
	end
end

function AssistAssist:getLongStatusText()
	local text = self.currentMacro.description..": "..self:getWaySet().." set"
	if self.queuedMacro ~= self.currentMacro then
		text = text.."\nWill set for "..self.newMacro.description.." on leaving combat"
	end
	return text
end

function AssistAssist:queueSetMacroText()
	if not UnitAffectingCombat("PLAYER") then -- out of combat, set macro text now
		self:setMacroText()
	else  -- otherwise register event for leaving combat
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "setMacroText") -- yes this is what the leaving combat event is called
		print(self:getUpdateText())
		ldbObject.text = self:getShortStatusText()
	end
end

function AssistAssist:setMacroText()
	-- update stuff
	self:SetAttribute("macrotext", self.queuedMacro.text)
	self.currentMacro = self.queuedMacro
	print(self:getUpdateText())
	ldbObject.text = self:getShortStatusText()
	-- unregister leaving combat event
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "setMacroText")
end

function AssistAssist:setManualAssistToTarget()
	self.manualAssist = UnitName("TARGET")
	self:updateIfNecessary()
end


function AssistAssist:updateIfNecessary(changedPlayer, newRole)
	local currentMacro = Macro:newCurrentMacro(changedPlayer, newRole)
	if currentMacro ~= self.queuedMacro then
		self.queuedMacro = currentMacro
		self:queueSetMacroText()
	end
end

function AssistAssist:roleEvent(event, ...)
	local changedChar, _, oldRole, newRole = ... -- only ROLE_CHANGED_INFORM has the later arguments
	-- seperate cases just in case they add arguments to the other events or I add an event that has them
	if event == "ROLE_CHANGED_INFORM" then 
		self:updateIfNecessary(changedPlayer, newRole)
	else
		self:updateIfNecessary()
	end
end

function AssistAssist:OnEnable()
	print(self.printPrefix..[[addon loaded: type "/assistassist" for keybindings, options, and more information]])
	self:SetAttribute("type", "macro")
	self:RegisterForClicks("AnyUp")
	self:updateIfNecessary()
	ldbObject.text = self:getShortStatusText() -- set the text if we still have the empty macro
	self:RegisterEvent("ROLE_CHANGED_INFORM", "roleEvent") -- this happens when someone manually changes a role
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "roleEvent")
end

