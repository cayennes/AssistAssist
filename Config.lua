local AssistAssist = LibStub("AceAddon-3.0"):GetAddon("AssistAssist")
local Config = AssistAssist:GetModule("Config")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

-- Setters and getters

function Config:setPreference(info, val)
	AssistAssist.db.profile[info[#info]] = val
	AssistAssist:updateIfNecessary()
end

function Config:getPreference(info)
	return AssistAssist.db.profile[info[#info]]
end

local keyNames = {key = "CLICK AssistAssistSB:LeftButton", setkey = "AASETASSIST"}

function Config:setKey(info, val)
	local keyName = keyNames[info[#info]]
	-- unbind old key
	local oldKey = GetBindingKey(keyName)
	if oldKey ~= nil then
		SetBinding(oldKey, nil)
	end
	-- set new one if it wasn't escape which is supposed to just clear
	if key ~= "ESCAPE" then
		if info[#info] == "key" then
			SetBindingClick(val, "AssistAssistSB")
		else
			SetBinding(val, keyName)
		end
	end
	-- save
	SaveBindings(GetCurrentBindingSet())
end

function Config:getKey(info, val)
	local keyName = keyNames[info[#info]]
	return GetBindingKey(keyName)
end

-- Utility function to make it easy to put headers on paragraphs

local textInABox = function(title, text, order) 
	return {
		type = "group",
		name = title,
		inline = true,
		order = order,
		args = {
			text = {
				type = "description",
				fontSize = "medium",
				name = text,
				order = 50
			}
		}
	}
end

-- Ace options table

local options = {
	type = "group",
	name = "AssistAssist",
	handler = Config,
	set = "setPreference",
	get = "getPreference",
	args = {
		keybindings = {
			type = "group",
			name = "Keybindings",
			order = 10,
			inline = true,
			set = "setKey",
			get = "getKey",
			args = {
				key = {
					name = "Assist/mark",
					type = "keybinding",
					desc = "Set the keybinding to "..string.lower(_G["BINDING_NAME_CLICK AssistAssistSB:LeftButton"]),
					order = 10,
				},
				setkey = {
					name = "Manually set",
					type = "keybinding",
					desc = "Set the keybinding to "..string.lower(BINDING_NAME_AASETASSIST),
					order = 11,
				},
			},
		},
		behavior = {
			type = "group",
			name = "Behavior",
			order = 20,
			inline = true,
			args = {
				mark = {
					order = 20,
					name = "Mark to apply as tank",
					desc = "What mark to apply when you're the tank",
					type = "select",
					values = {
						["1"] = "Star",
						["2"] = "Circle",
						["3"] = "Diamond",
						["4"] = "Triangle",
						["5"] = "Moon",
						["6"] = "Square",
						["7"] = "X",
						["8"] = "Skull"
					},
				},
				noTank = {
					order = 21,
					name = "Action with no tank",
					desc = "What to do if there isn't a tank",
					type = "select",
					values = {
						mark = "Apply mark",
						nothing = "Do nothing",
					},
				},
			},
		},
		help = textInABox(
			"Usage",
			[[The "Assist/mark" keybinding will automatically assist the dungeon finder tank or mark the current target if that's you.  If there are multiple tanks, it will always mark if you are one of them and assist one if you aren't; the "Manually set" keybinding allows you to pick which one.

The "Manually set" keybinding will allow you to set your current target as the person to assist; this will result in marking if you use it with yourself targeted.  If you manually set a tank/assist, it will not automatically update (for example if your tank has dropped and the dungeon finder gets you a new one) until you use it again without a target, which returns AssistAssist to auto mode. 

The "Mark to apply as tank" dropdown chooses what mark to apply when you are the tank/person to assist.  The "Action with no tank" lets you choose to apply marks by default when there isn't a tank or to do nothing.

If you have a LibDataBroker display addon, AssistAssist provides a plugin which will let you see what it is currently set to do, click to manually set, and right click to open preferences.]],
			30
		),
		about = textInABox(
			"About", 
			-- this-version added in OnEnable
			[[You can contact me via the AssistAssist page on curse or by emailing me at luacayenne@gmail.com.  Let me know if you find bugs: the way things are, chances are multiple people are experiencing it but no one lets me know.  Also let me know if you'd like additional features:  I like to add them when I know someone would use them.]],
			 31
		)
	},
}

local defaults = {
	profile = {
		mark = "8",
		noTank = "nothing"
	}
}

function Config:OnInitialize()
	-- saved preferences
	AssistAssist.db = LibStub("AceDB-3.0"):New("AssistAssistDB", defaults, true)
	-- main options panel
	options.args.about.args.text.name = 
		"AssistAssist by Cayenne, version "
		..GetAddOnMetadata("AssistAssist", "Version")
		.."\n\n"..options.args.about.args.text.name
	AceConfig:RegisterOptionsTable("AssistAssist", options) 
	AceConfigDialog:AddToBlizOptions("AssistAssist")
end
