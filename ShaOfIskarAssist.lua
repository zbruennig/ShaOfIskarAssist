local _, ShaOfIskarAssist = ...
LibStub("AceAddon-3.0"):NewAddon(ShaOfIskarAssist, "ShaOfIskarAssist", "AceConsole-3.0", "AceEvent-3.0")

ShaOfIskarAssist:SetDefaultModuleLibraries("AceConsole-3.0", "AceEvent-3.0")
-- Local variable to speedup things
local UnitGUID = UnitGUID

local ADDON_NAME = "Sha of Iskar Assist"
local AceConfig3 = LibStub("AceConfig-3.0")
local AceConfigDialog3 = LibStub("AceConfigDialog-3.0")

-- *****************
-- *** Addon Version
-- *** 1.0.4 (Release)
-- *****************
ShaOfIskarAssist.MajorVersion = 1
ShaOfIskarAssist.MinorVersion = 0
-- Stage Number
-- 0 : Alpha
-- 1 : Beta
-- 2 : Release candidate
-- 3 : Final release
ShaOfIskarAssist.StageVersion = 4
ShaOfIskarAssist.RevisionVersion = 0

-- ********************
-- *** Common Data ****
-- ********************

ShaOfIskarAssist.ShaID = 60999
ShaOfIskarAssist.ShaEncounterID = 1431
ShaOfIskarAssist.ShaSubZone = "Dread Expanse"

ShaOfIskarAssist.AuraChampionOfTheLightSpellID = 120268
ShaOfIskarAssist.AuraHuddleInTerrorSpellID = 120629

local Healers = {}
local Tanks = {}
local Dps = {}

local HealerCount = 0
local TankCount = 0
local DpsCount = 0

local Members = {} -- Members[GUID] = raidID

local InEncounterCombat = false

local ModulesAutoEnabled = {}
local autoEnableAllModules = false

-- ****************************
-- *** Local Misc Functions ***
-- ****************************
function ShaOfIskarAssist:GetNumMember()
		local num = GetNumGroupMembers()
		if self.db.profile.showAllRaidMembers then
			return num
		end

		difficulty = GetRaidDifficultyID()

		-- Raid 10, 10H
		if difficulty == 3 or difficulty == 5 then
			maxNumber = 10
		-- Raid 25, 25H
		elseif difficulty == 4 or difficulty == 6 then
			maxNumber = 25
		else
			maxNumber = 40
		end

		if num > maxNumber then
			return maxNumber
		else
			return num
		end
end

local defaults = {
	profile = {
		disabledAll = false,
		showAllRaidMembers = true,
		modulesEnabled = {
			ChampionOfTheLightAssist = true,
		},
	}
}

function ShaOfIskarAssist:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("ShaOfIskarAssistDB", defaults)

	self:SetupOptions()

end

function ShaOfIskarAssist:OnEnable()
  self:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateRaidInfo")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "UpdateRaidInfo")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateRaidInfo")
  self:RegisterEvent("UNIT_NAME_UPDATE", "UpdateRaidInfo")
	self:RegisterEvent("ENCOUNTER_START", "HandleEncounterStart")
	self:RegisterEvent("ENCOUNTER_END", "HandleEncounterStop")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "HandleTargetChanged")
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "HandleMouseoverChanged")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "HandleDelayedAction")


end

function ShaOfIskarAssist:OnDisable()
  self:UnregisterEvent("PARTY_MEMBERS_CHANGED")
  self:UnregisterEvent("GROUP_ROSTER_UPDATE")
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:UnregisterEvent("UNIT_NAME_UPDATE")
	self:UnregisterEvent("ENCOUNTER_START")
	self:UnregisterEvent("ENCOUNTER_END")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")

end

function ShaOfIskarAssist:UpdateRaidInfo()
		self:WipeUnits()

    for i = 1, self:GetNumMember() do
      local unit = string.format("raid%i", i)
      local guid = UnitGUID(unit)
      local name = UnitName(unit)

      if guid and name ~= UNKNOWNOBJECT then
        local role = UnitGroupRolesAssigned(unit)
				self:AddUnit(unit, guid, role)
      end

    end

		self:SendMessage("SIA_RAID_INFO_UPDATED")
end

function ShaOfIskarAssist:WipeUnits()
		wipe(Members)

		wipe(Healers)
		HealerCount = 0

		wipe(Tanks)
		TankCount = 0

		wipe(Dps)
		DpsCount = 0
end

function ShaOfIskarAssist:InEncounterCombat()
	return InEncounterCombat
end

function ShaOfIskarAssist:HandleEncounterStart(event, encounterID, encounterName, difficultyID, raidSize)
	if encounterID == self.ShaEncounterID then
		InEncounterCombat = true
		self:SendMessage("SIA_ISKAR_ENCOUNTER_START", difficultyID, raidSize)
	else
		InEncounterCombat = false
	end
end

function ShaOfIskarAssist:HandleEncounterStop(event, encounterID, encounterName, difficultyID, raidSize, endStatus)
	InEncounterCombat = false

	if encounterID == self.ShaEncounterID then
		if endStatus == 0 then
			self:SendMessage("SIA_ISKAR_WIPE")
		elseif endStatus == 1 then
			self:SendMessage("SIA_ISKAR_KILLED")
		end
		self:SendMessage("SIA_ISKAR_ENCOUNTER_END", difficultyID, raidSize, endStatus)
	end
end

function ShaOfIskarAssist:HandleTargetChanged()
	local npcID = self:GetNpcIDFromUnit("target")
	if tonumber(npcID) == self.ShaID and not UnitIsDead("target") and GetSubZoneText() == self.ShaSubZone then
			if UnitAffectingCombat("player") then
					autoEnableAllModules = true
			else
					self:AutoEnableAllModules()
			end
	end
end

function ShaOfIskarAssist:HandleMouseoverChanged()
  local npcID = self:GetNpcIDFromUnit("mouseover")
	if tonumber(npcID) == self.ShaID and not UnitIsDead("mouseover") and GetSubZoneText() == self.ShaSubZone then
			if UnitAffectingCombat("player") then
					autoEnableAllModules = true
			else
					self:AutoEnableAllModules()
			end
	end
end

function ShaOfIskarAssist:AutoEnableAllModules()
	for module, func in pairs(ModulesAutoEnabled) do
				if module.EnableOnIskar == nil or module.EnableOnIskar == true then
						module:Enable()
						if func then func() end
				end
	end
end

function ShaOfIskarAssist:HandleDelayedAction()
	if autoEnableAllModules then
			self:AutoEnableAllModules()
			autoEnableAllModules = false
	end
end


function ShaOfIskarAssist:AddUnit(unit, guid, role)
  if role == "HEALER" then
    self:AddHealer(unit, guid)
  elseif role == "TANK" then
    self:AddTank(unit, guid)
  elseif role == "DAMAGER" then
    self:AddDps(unit, guid)
  end
end

function ShaOfIskarAssist:AddHealer(unit, guid)
  Members[guid] = unit
  tinsert(Healers, guid)
	HealerCount = HealerCount + 1
end

function ShaOfIskarAssist:AddTank(unit, guid)
  Members[guid] = unit
  tinsert(Tanks, guid)
	TankCount = TankCount + 1
end

function ShaOfIskarAssist:AddDps(unit, guid)
  Members[guid] = unit
  tinsert(Dps, guid)
	DpsCount = DpsCount + 1
end

function ShaOfIskarAssist:GetHealers()
	return Healers, HealerCount
end

function ShaOfIskarAssist:GetTanks()
	return Tanks, TankCount
end

function ShaOfIskarAssist:GetDps()
	return Dps, DpsCount
end


function ShaOfIskarAssist:GetUnit(guid)
  return Members[guid]
end


function ShaOfIskarAssist:GetVersionString()
	local stage = ""
	if self.StageVersion == 0 then
		stage = "Alpha"
	elseif self.StageVersion == 1 then
		stage = "Beta"
	elseif self.StageVersion == 2 then
		stage = "Release Candidate"
	elseif self.StageVersion == 3 then
		stage = "Release"
	end

	local version = string.format("%i.%i.%i.%i (%s)", self.MajorVersion, self.MinorVersion, self.StageVersion, self.RevisionVersion, stage)

	return version
end

function ShaOfIskarAssist:GetNpcID(guid)
	if not guid then return -1 end

	-- local _, _, _, _, _, npcID, _ = strsplit("-", guid)
	local hexNumber = strsub(guid, 7, 10)
	npcID = tonumber(hexNumber, 16)

	return npcID
end


function ShaOfIskarAssist:GetNpcIDFromUnit(unit)
	if not unit then return -1 end

	local guid = UnitGUID(unit)

	return self:GetNpcID(guid)
end

function ShaOfIskarAssist:GetIconText(icon, width, height)
	if not icon then return "" end

	if not width or not height then
		height = 24
		width = 24

	end

	return string.format("|T%s:%i:%i|t", icon, width, height)
end

function ShaOfIskarAssist:GetRoleIconText(role, width, height)
  if not height or not width then
    height = 32
    width = 32
  end

  if not role or role == "NONE" then
        return ""
    elseif role == "HEALER" then
        return string.format("|T%s:%i:%i:0:0:256:256:69:130:2:63|t", "Interface/LFGFRAME/UI-LFG-ICON-ROLES", width, height)
    elseif role == "DAMAGER" then
        return string.format("|T%s:%i:%i:0:0:256:256:69:130:69:130|t", "Interface/LFGFRAME/UI-LFG-ICON-ROLES", width, height)
    elseif role == "TANK" then
        return string.format("|T%s:%i:%i:0:0:256:256:3:64:69:130|t", "Interface/LFGFRAME/UI-LFG-ICON-ROLES", width, height)
    end
end

function ShaOfIskarAssist:GetClassColorText(text, class)

	if not class or not text then return nil end

	local color = RAID_CLASS_COLORS[class]
	return string.format("|c%s%s|r", color.colorStr, text)
end

function ShaOfIskarAssist:AutoEnableModuleOnBoss(module, func)
	ModulesAutoEnabled[module] = func
end

function ShaOfIskarAssist:GenerateModuleOptions()
	for name, module in self:IterateModules() do
			if module.GetOptions then
					AceConfig3:RegisterOptionsTable("SIA" .. ":" .. name, module:GetOptions())
					AceConfigDialog3:AddToBlizOptions("SIA" .. ":" .. name, name, "ShaOfIskarAssist")

					local mlopt = ShaOfIskarAssist.options.args.modulesManagement.args.modules.args
					mlopt[name] = {
						type = "select",
						name = name,
						values = function()
							return {
							[1] = "|cff00ff00" .. "Enabled" .. "|r",
							[0] = "|cffff0000" .. "Disabled" .. "|r",
						}
					end,
					get = function()
							if self.db.profile.modulesEnabled[name] then
								return 1
							else
								return 0
							end
						end,
					set = function(info, value)
							if value == 1 then
								self.db.profile.modulesEnabled[name] = true
								module.EnableOnIskar = nil
								module:Enable()
							else
								self.db.profile.modulesEnabled[name] = false
								module:Disable()
								module.EnableOnIskar = false
							end
					end
					}
			end
	end
end

function ShaOfIskarAssist:GenerateOptions()


	ShaOfIskarAssist.options = {
		type = "group",
		childGroups = "tab",
		args = {
			modulesManagement = {
				type = "group",
				name = "Module Management",
				args = {
					disabledAll = {
						type = "toggle",
						name = "Disable All",
						desc = "Disable Sha of Iskar Assist and all its modules.",
						order = 1,
						descStyle = "tooltip",
						get = function() return self.db.profile.disabledAll end,
						set = function(_, disabledAll)
								if not disabledAll then
									self:Enable()
								else
									self:Disable()
								end
								self.db.profile.disabledAll = disabledAll
						end,
					},
					showAllRaidMembers = {
						type = "toggle",
						name = "Show Entire Raid",
						desc = "Display all raid members regardless of instance size. Useful if your guild keeps benched players in the raid group.",
						order = 2,
						descStyle = "tooltip",
						get = function() return self.db.profile.showAllRaidMembers end,
						set = function(_, showAllRaidMembers)
							self.db.profile.showAllRaidMembers = showAllRaidMembers
							self:UpdateRaidInfo()
						end,
					},
					modules = {
						type = "group",
						name = "",
						order = 3,
						inline = true,
						disabled = function() return self.db.profile.disabledAll end,
						args = {

						}
					}
				},
			},
		},
	}
end

function ShaOfIskarAssist:GetOptions()
	if not ShaOfIskarAssist.options then
		self:GenerateOptions()
	end
	return ShaOfIskarAssist.options
end

function ShaOfIskarAssist:SetupOptions()
	AceConfig3:RegisterOptionsTable("ShaOfIskarAssist", self:GetOptions())
	AceConfigDialog3:AddToBlizOptions("ShaOfIskarAssist", "ShaOfIskarAssist")
	self:GenerateModuleOptions()

	LibStub("LibAboutPanel").new("ShaOfIskarAssist", "ShaOfIskarAssist")


end
