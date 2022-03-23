local _, EpsiIskarAssist = ...
LibStub("AceAddon-3.0"):NewAddon(EpsiIskarAssist, "EpsiIskarAssist", "AceConsole-3.0", "AceEvent-3.0")

EpsiIskarAssist:SetDefaultModuleLibraries("AceConsole-3.0", "AceEvent-3.0")
-- Local variable to speedup things
local UnitGUID = UnitGUID

local ADDON_NAME = "Epsi Iskar Assist"
local AceConfig3 = LibStub("AceConfig-3.0")
local AceConfigDialog3 = LibStub("AceConfigDialog-3.0")

-- *****************
-- *** Addon Version
-- *** 1.0.4 (Release)
-- *****************
EpsiIskarAssist.MajorVersion = 1
EpsiIskarAssist.MinorVersion = 0
-- Stage Number
-- 0 : Alpha
-- 1 : Beta
-- 2 : Release candidate
-- 3 : Final release
EpsiIskarAssist.StageVersion = 4
EpsiIskarAssist.RevisionVersion = 0

-- ********************
-- *** Common Data ****
-- ********************
EpsiIskarAssist.IskarID = 90316 --  73101 (Test) - Iskar => 90316
EpsiIskarAssist.IskarEncounterID = 1788

EpsiIskarAssist.AuraEyeOfAnzuSpellID = 179202
EpsiIskarAssist.AuraPhantasmalWindsSpellID = 181957
EpsiIskarAssist.AuraPhantasmalWoundsSpellID = 182325
EpsiIskarAssist.AuraPhantasmalFelBombSpellID = 179219
EpsiIskarAssist.AuraFelBombSpellID = 181753
EpsiIskarAssist.AuraPhantasmalCorruptionSpellID = 181824
EpsiIskarAssist.AuraDarkBindingsSpellID = 185510
EpsiIskarAssist.AuraRadianceOfAnzuSpellID = 185239
EpsiIskarAssist.ShadowRiposteSpellID = 185345

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
function EpsiIskarAssist:GetNumMember()
		local num = GetNumGroupMembers()

		difficulty = GetRaidDifficultyID()

		-- Raid Normal
		if difficulty == 14 then
			maxNumber = 30
		-- Raid Heroic
		elseif difficulty == 15 then
			maxNumber = 30
		-- Raid Mythic
		elseif difficulty == 16 then
			maxNumber = 20
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
		modulesEnabled = {
			EyeOfAnzuAssist = true,
		},
	}
}

function EpsiIskarAssist:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("EpsiIskarAssistDB", defaults)

	self:SetupOptions()

end

function EpsiIskarAssist:OnEnable()
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

function EpsiIskarAssist:OnDisable()
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

function EpsiIskarAssist:UpdateRaidInfo()
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

		self:SendMessage("EIA_RAID_INFO_UPDATED")
end

function EpsiIskarAssist:WipeUnits()
		wipe(Members)

		wipe(Healers)
		HealerCount = 0

		wipe(Tanks)
		TankCount = 0

		wipe(Dps)
		DpsCount = 0
end

function EpsiIskarAssist:InEncounterCombat()
	return InEncounterCombat
end

function EpsiIskarAssist:HandleEncounterStart(event, encounterID, encounterName, difficultyID, raidSize)
	if encounterID == self.IskarEncounterID then
		InEncounterCombat = true
		self:SendMessage("EIA_ISKAR_ENCOUNTER_START", difficultyID, raidSize)
	else
		InEncounterCombat = false
	end
end

function EpsiIskarAssist:HandleEncounterStop(event, encounterID, encounterName, difficultyID, raidSize, endStatus)
	InEncounterCombat = false

	if encounterID == self.IskarEncounterID then
		if endStatus == 0 then
			self:SendMessage("EIA_ISKAR_WIPE")
		elseif endStatus == 1 then
			self:SendMessage("EIA_ISKAR_KILLED")
		end
		self:SendMessage("EIA_ISKAR_ENCOUNTER_END", difficultyID, raidSize, endStatus)
	end
end

function EpsiIskarAssist:HandleTargetChanged()
	local npcID = self:GetNpcIDFromUnit("target")
	if tonumber(npcID) == self.IskarID and not UnitIsDead("target") then
			if UnitAffectingCombat("player") then
					autoEnableAllModules = true
			else
					self:AutoEnableAllModules()
			end
	end
end

function EpsiIskarAssist:HandleMouseoverChanged()
  local npcID = self:GetNpcIDFromUnit("mouseover")
	if tonumber(npcID) == self.IskarID and not UnitIsDead("mouseover") then
			if UnitAffectingCombat("player") then
					autoEnableAllModules = true
			else
					self:AutoEnableAllModules()
			end
	end
end

function EpsiIskarAssist:AutoEnableAllModules()
	for module, func in pairs(ModulesAutoEnabled) do
				if module.EnableOnIskar == nil or module.EnableOnIskar == true then
						module:Enable()
						if func then func() end
				end
	end
end

function EpsiIskarAssist:HandleDelayedAction()
	if autoEnableAllModules then
			self:AutoEnableAllModules()
			autoEnableAllModules = false
	end
end


function EpsiIskarAssist:AddUnit(unit, guid, role)
  if role == "HEALER" then
    self:AddHealer(unit, guid)
  elseif role == "TANK" then
    self:AddTank(unit, guid)
  elseif role == "DAMAGER" then
    self:AddDps(unit, guid)
  end
end

function EpsiIskarAssist:AddHealer(unit, guid)
  Members[guid] = unit
  tinsert(Healers, guid)
	HealerCount = HealerCount + 1
end

function EpsiIskarAssist:AddTank(unit, guid)
  Members[guid] = unit
  tinsert(Tanks, guid)
	TankCount = TankCount + 1
end

function EpsiIskarAssist:AddDps(unit, guid)
  Members[guid] = unit
  tinsert(Dps, guid)
	DpsCount = DpsCount + 1
end

function EpsiIskarAssist:GetHealers()
	return Healers, HealerCount
end

function EpsiIskarAssist:GetTanks()
	return Tanks, TankCount
end

function EpsiIskarAssist:GetDps()
	return Dps, DpsCount
end


function EpsiIskarAssist:GetUnit(guid)
  return Members[guid]
end


function EpsiIskarAssist:GetVersionString()
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

function EpsiIskarAssist:GetNpcID(guid)
	if not guid then return -1 end

	local _, _, _, _, _, npcID, _ = strsplit("-", guid)

	return npcID
end


function EpsiIskarAssist:GetNpcIDFromUnit(unit)
	if not unit then return -1 end

	local guid = UnitGUID(unit)

	return self:GetNpcID(guid)
end

function EpsiIskarAssist:GetIconText(icon, width, height)
	if not icon then return "" end

	if not width or not height then
		height = 24
		width = 24

	end

	return string.format("|T%s:%i:%i|t", icon, width, height)
end

function EpsiIskarAssist:GetRoleIconText(role, width, height)
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

function EpsiIskarAssist:GetClassColorText(text, class)

	if not class or not text then return nil end

	local color = RAID_CLASS_COLORS[class]
	return string.format("|c%s%s|r", color.colorStr, text)
end

function EpsiIskarAssist:AutoEnableModuleOnBoss(module, func)
	ModulesAutoEnabled[module] = func
end

function EpsiIskarAssist:GenerateModuleOptions()
	for name, module in self:IterateModules() do
			if module.GetOptions then
					AceConfig3:RegisterOptionsTable("EIA" .. ":" .. name, module:GetOptions())
					AceConfigDialog3:AddToBlizOptions("EIA" .. ":" .. name, name, "EpsiIskarAssist")

					local mlopt = EpsiIskarAssist.options.args.modulesManagement.args.modules.args
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

function EpsiIskarAssist:GenerateOptions()


	EpsiIskarAssist.options = {
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
						desc = "Disable Epsi Iskar Assist and all its modules.",
						order = 1,
						descStyle = "inline",
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
					modules = {
						type = "group",
						name = "",
						order = 2,
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

function EpsiIskarAssist:GetOptions()
	if not EpsiIskarAssist.options then
		self:GenerateOptions()
	end
	return EpsiIskarAssist.options
end

function EpsiIskarAssist:SetupOptions()
	AceConfig3:RegisterOptionsTable("EpsiIskarAssist", self:GetOptions())
	AceConfigDialog3:AddToBlizOptions("EpsiIskarAssist", "EpsiIskarAssist")
	self:GenerateModuleOptions()

	LibStub("LibAboutPanel").new("EpsiIskarAssist", "EpsiIskarAssist")


end
