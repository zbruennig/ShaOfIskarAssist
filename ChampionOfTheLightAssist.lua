local _, SIA = ...

local ChampionOfTheLightAssist = SIA:NewModule("ChampionOfTheLightAssist")
SIA:AutoEnableModuleOnBoss(ChampionOfTheLightAssist, function() ChampionOfTheLightAssist:ShowFrames() end)

-- **************
-- *** Frames ***
-- **************
local MainFrame = nil
local EyeOfAnzuFrame = nil

local HealerData = {}
local TankData = {}
local DpsData = {}

local needUpdate = false
local needEnable = false
local needDisable = false



-- *************
-- *** Media ***
-- *************
local SKAM_BAR = [[Interface\Addons\ShaOfIskarAssist\Media\skam_bar]]

-- ********************
-- *** Macro Format ***
-- ********************
local MacroEyeOfAnzu = "/tar %s\n/run if UnitDebuff('player', 'Champion of the Light') and UnitInRange(%s) then SendChatMessage('Ball to '..UnitName(%s), 'YELL') end\n/cancelaura Ice Block\n/stopcasting\n/stopcasting\n/click ExtraActionButton1\n/targetlasttarget"

-- ************
-- *** Data ***
-- ************
local PLAYER_FRAME_WIDTH, PLAYER_FRAME_HEIGHT = 100, 25
local DPS_PLAYER_FRAME_WIDTH, DPS_PLAYER_FRAME_HEIGHT = 75, 25

local Ticker = nil

local _, MyClass = UnitClass("player")


local Huddles = {}
local Dead = {}
local EyeOfAnzu = nil

local PreviousHealerCount = 0
local PreviousTankCount =  0
local PreviousDpsCount = 0


-- ****************************
-- *** Localized spell name ***
-- ****************************
local AURA_CHAMPION_OF_THE_LIGHT, _, AURA_CHAMPION_OF_THE_LIGHT_ICON = GetSpellInfo(SIA.AuraChampionOfTheLightSpellID)
local AURA_HUDDLE_IN_TERROR, _, AURA_HUDDLE_IN_TERROR_ICON = GetSpellInfo(SIA.AuraHuddleInTerrorSpellID)

local DebuffsDB = nil

local defaults = {
  profile = {
    showOnIskar = true,
    lock = false,
    scale = 1.0,
    xPos = 100,
    yPos = 100,
    voiceAlerts = true,
    hideSelf = false,
    frameStrata = "BACKGROUND",
    rangeIndicator = {
      enable = true,
      alpha = 0.3,
      updateFrequency = 0.25,
    },
    font = {
      color = {
        r = 0,
        g = 0,
        b = 0
      },
      useClassColor = true,
    },
    debuffs = {
      huddles = {
        show = true,
        color = {
          r = 1,
          g = 0,
          b = 0
        },
        priority = 1, -- currently unused
      }
    },
    eyeOfAnzu = {
      show = true,
    }
  }
}
local scale = 1.0
local function HandleFrameDragStart(frame)
  frame:StartMoving()
end

local function HandleFrameDragStop(frame)
  frame:StopMovingOrSizing()

  x = frame:GetLeft()
  y = frame:GetBottom()

  ChampionOfTheLightAssist.db.profile.xPos = x
  ChampionOfTheLightAssist.db.profile.yPos = y
end

ChampionOfTheLightAssist.EnableOnIskar = true
function ChampionOfTheLightAssist:OnInitialize()

  self.db = SIA.db:GetNamespace("ChampionOfTheLightAssist", true) or SIA.db:RegisterNamespace("ChampionOfTheLightAssist", defaults)
  self.EnableOnIskar = self.db.profile.showOnIskar
  scale = self.db.profile.scale
  DebuffsDB = self.db.profile.debuffs


  self:RegisterChatCommand("iskar", "HandleChatCommands")
  self:RegisterChatCommand("eia", "HandleChatCommands")
  self:RegisterChatCommand("sha", "HandleChatCommands")
  self:RegisterChatCommand("sia", "HandleChatCommands")

  if not SIA.db.profile.modulesEnabled[self:GetName()] then
    self.EnableOnIskar = false
  end

  if self.EnableOnIskar or not SIA.db.profile.modulesEnabled[self:GetName()] then
    self:SetEnabledState(false)
  end
end

function ChampionOfTheLightAssist:OnEnable()

  self.EnableOnIskar = self.db.profile.showOnIskar
  self:RegisterMessage("SIA_RAID_INFO_UPDATED", "HandleRaidInfoUpdate")
  self:RegisterMessage("SIA_ISKAR_WIPE", "HandleWipeActions")
  self:RegisterMessage("SIA_ISKAR_KILLED", "HandleKillActions")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "HandleDelayedAction")

  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "HandleCombatLog")

  HealerData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  TankData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  DpsData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }

  Huddles = {}
  EyeOfAnzu = {}

  PreviousHealerCount = 0
  PreviousTankCount =  0
  PreviousDpsCount = 0

  local xPos = self.db.profile.xPos
  local yPos = self.db.profile.yPos
  local show = self.db.profile.show
  local lock = self.db.profile.lock

  MainFrame = CreateFrame("frame", nil, UIParent)
  MainFrame:SetFrameStrata(self.db.profile.frameStrata)
  MainFrame:SetWidth(400 * scale)
  MainFrame:SetHeight(400 * scale)
  MainFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", xPos, yPos)

  self:CreateTankCategoryFrame()
  self:CreateHealerCategoryFrame()
  self:CreateDpsCategoryFrame()
  self:CreateEyeOfAnzuFrame()

  if lock then
    self:LockFrames()
  else
    self:UnlockFrames()
  end

  MainFrame:Hide()

  MainFrame:RegisterForDrag("LeftButton")
  MainFrame:SetScript("OnDragStart", HandleFrameDragStart)
  MainFrame:SetScript("OnDragStop", HandleFrameDragStop)

  self:HandleRaidInfoUpdate()

  if self.db.profile.rangeIndicator.enable then
    self:EnableAndUpdateRangeTicker()
  end

end

function ChampionOfTheLightAssist:OnDisable()

  self:UnregisterMessage("SIA_RAID_INFO_UPDATED")
  self:UnregisterMessage("SIA_ISKAR_WIPE")
  self:UnregisterMessage("SIA_ISKAR_KILLED")
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")

  self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

  MainFrame:Hide()
  self:DisableRangeTicker()

  MainFrame = nil
  EyeOfAnzuFrame = nil

  HealerData = nil
  TankData = nil
  DpsData = nil

  Huddles = nil
  Dead = nil
  EyeOfAnzu = nil

  PreviousHealerCount = nil
  PreviousTankCount =  nil
  PreviousDpsCount = nil

  self.EnableOnIskar = false


end

function ChampionOfTheLightAssist:LockFrames()
  MainFrame:EnableMouse(false)
  MainFrame:SetMovable(false)
  self:Print("The raid frame has been locked")
end

function ChampionOfTheLightAssist:UnlockFrames()
  MainFrame:EnableMouse(true)
  MainFrame:SetMovable(true)
  self:Print("The raid frame has been unlocked\nHint: Drag on the role icons")
end

function ChampionOfTheLightAssist:HandleChatCommands(rawInput)
  input = string.lower(rawInput)
  if input == "lock" then
    self:LockFrames()
    self.db.profile.lock = true
  elseif input == "unlock" then
    self:UnlockFrames()
    self.db.profile.lock = false
  elseif input == "show" then
    self:ShowFrames()
  elseif input == "hide" then
    self:HideFrames()
  elseif input == "reload" or input == "refresh" then
    self:ShowFrames()
    self:HandleRaidInfoUpdate()
    self:Print("The raid frame has been reloaded")
  elseif input == "clear" then
    self:ShowFrames()
    self:HandleWipeActions() -- clear all the debuffs and reset the player frame color
    self:Print("The raid frame has been cleared")
  elseif input == "version" or input == "ver" or input == "v" then
    self:DisplayVersionInfo()
  elseif input == "ping" then
    SIA:UpdateRaidInfo()
  else
    self:Print("\nValid arguments:\nshow - Display the frame.\nhide - Hide the frame.\nlock - Lock the frame in place.\nunlock - Unlock the frame for moving.\nreload - Reload the frame.\nclear - Clear all debuffs.\nversion - Version check")
  end
end

function ChampionOfTheLightAssist:EnableAndUpdateRangeTicker()

  self:DisableRangeTicker()
  Ticker = C_Timer.NewTicker(self.db.profile.rangeIndicator.updateFrequency, function() ChampionOfTheLightAssist:UpdateRangePlayers() end)
end

function ChampionOfTheLightAssist:DisableRangeTicker()
  if Ticker then
    Ticker:Cancel()
    Ticker = nil
  end
end




function ChampionOfTheLightAssist:UpdateRoleFrame(role)
  local roleData = nil
  local rolePlayers = nil
  local currentRoleCount = 0

  if role == "HEALER" then
    rolePlayers, currentRoleCount = SIA:GetHealers()
    roleData = HealerData
  elseif role == "TANK" then
    rolePlayers, currentRoleCount = SIA:GetTanks()
    roleData = TankData
  elseif role == "DAMAGER" then
    rolePlayers, currentRoleCount = SIA:GetDps()
    roleData = DpsData
  end

  if roleData.previousCount > currentRoleCount then
    local hiddenFrameCount = roleData.previousCount - currentRoleCount
    for y = 0, hiddenFrameCount - 1 do
      local frame = roleData.frames[currentRoleCount + y]
      frame:Hide()
      frame.button:Hide()
      frame.texture:Hide()
      frame.name:Hide()
    end
  elseif currentRoleCount > PreviousHealerCount then
    local addedFrameCount = currentRoleCount - roleData.previousCount
    for i = 0, addedFrameCount - 1 do
      if not roleData.frames[roleData.previousCount + i] then
        local frame = self:CreatePlayerFrame(role, roleData.previousCount + i)
        frame:SetParent(roleData.groupFrame)
        if role == "DAMAGER" then
          local yRatio = math.floor((roleData.previousCount + i) / 2)
          if ((roleData.previousCount + i) % 2) == 0 then
            frame:SetPoint("TOP", roleData.groupFrame, "TOP", 0,  -30 * scale - yRatio * DPS_PLAYER_FRAME_HEIGHT * scale)
          else
            frame:SetPoint("TOP", roleData.groupFrame, "TOP", DPS_PLAYER_FRAME_WIDTH * scale  + 5 * scale, -30 * scale - yRatio * DPS_PLAYER_FRAME_HEIGHT * scale)
          end

          frame:SetSize(DPS_PLAYER_FRAME_WIDTH * scale, DPS_PLAYER_FRAME_HEIGHT * scale)
        else
        frame:SetPoint("TOP", roleData.groupFrame, "TOP", 0, -30 * scale - (roleData.previousCount + i) * PLAYER_FRAME_HEIGHT * scale)
        end
        roleData.frames[roleData.previousCount + i] = frame
      end
    end
  end

  if role == "DAMAGER" then
    roleData.groupFrame:SetSize(150 * scale, 45 * scale + PLAYER_FRAME_HEIGHT * currentRoleCount * scale)
  else
    roleData.groupFrame:SetSize(100 * scale, 45 * scale  + PLAYER_FRAME_HEIGHT * currentRoleCount * scale)
  end

  for index, guid in pairs(rolePlayers) do
     local unit = SIA:GetUnit(guid)
     local frame = roleData.frames[index - 1]

     self:UpdatePlayerFrame(frame, unit)
     roleData.indexesFrame[guid] = index - 1
  end

  roleData.previousCount = currentRoleCount


end

function ChampionOfTheLightAssist:UpdateRangePlayer(frame, unit)

    if not unit then return end

    if not UnitInRange(unit) then
        frame:SetAlpha(self.db.profile.rangeIndicator.alpha)
    else
        frame:SetAlpha(1)
    end
end

function ChampionOfTheLightAssist:UpdateRangePlayers()
  --HealerData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  --TankData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  --DpsData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  --HealerData.indexesFrame[guid]

  for guid, index in pairs(HealerData.indexesFrame) do
      local unit = SIA:GetUnit(guid)
      local frame = HealerData.frames[index]
      self:UpdateRangePlayer(frame, unit)
  end

  for guid, index in pairs(TankData.indexesFrame) do
      local unit = SIA:GetUnit(guid)
      local frame = TankData.frames[index]
      self:UpdateRangePlayer(frame, unit)
  end

  for guid, index in pairs(DpsData.indexesFrame) do
      local unit = SIA:GetUnit(guid)
      local frame = DpsData.frames[index]
      self:UpdateRangePlayer(frame, unit)
  end
end

function ChampionOfTheLightAssist:DisplayVersionInfo()
  if not IsInRaid() then
    print("You need to be in a raid to do that!")
    return
  end
  local versionInfo = SIA.RaidAddonSettings
  print("|cadadad00" .. "===== Sha of Iskar Assist Tattle =====" .. "|r")
  for i = 1, GetNumGroupMembers() do
    local unit = string.format("raid%i", i)
    local name = SIA:RemoveServerTag(UnitName(unit))
    local info = versionInfo[name]
    if info ~= nil then
      print(string.format("|cdd00dd00" .. "%s: %s" .. "|r", name, info))
    else
      print(string.format("|c00eeee00" .. "%s: NO VERSION FOUND!".. "|r", name))
    end
  end
end

function ChampionOfTheLightAssist:AddDebuff(guid, debuffName)
    if self:HasDebuff(guid, debuffName) then return end

    if debuffName == AURA_HUDDLE_IN_TERROR then
      tinsert(Huddles, guid)
      local playerGUID = UnitGUID("player")
      if EyeOfAnzu == playerGUID and self.db.profile.voiceAlerts then
        PlaySoundFile("Interface\\Addons\\ShaOfIskarAssist\\Media\\huddle.ogg", "Master")
      end
    end
end

function ChampionOfTheLightAssist:RemoveDebuff(guid, debuffName)
    local hasDebuff, index = self:HasDebuff(guid, debuffName)

    if not hasDebuff then return end

    if debuffName == AURA_HUDDLE_IN_TERROR then
      tremove(Huddles, index)
    end
end

function ChampionOfTheLightAssist:HasDebuff(guid, debuffName)
    if debuffName == AURA_HUDDLE_IN_TERROR then
  		for index, playerGUID in ipairs(Huddles) do
  			if guid == playerGUID then return true, index end
  		end
  	end

  	return false, nil
end

function ChampionOfTheLightAssist:IsDead(guid)
  for index, playerGUID in ipairs(Dead) do
    if guid == playerGUID then return true, index end
  end
  return false, nil
end

function ChampionOfTheLightAssist:SetEyeOfAnzu(guid)
  if not guid and not EyeOfAnzu then return end

  if guid then
    local unit = SIA:GetUnit(guid)

    local name = UnitName(unit)
    local role = UnitGroupRolesAssigned(unit)
    local _, class = UnitClass(unit)

    local color = RAID_CLASS_COLORS[class]
    if name == UnitName("player") and self.db.profile.voiceAlerts then
      if next(Huddles) then
        PlaySoundFile("Interface\\Addons\\ShaOfIskarAssist\\Media\\huddle.ogg", "Master")
      else
        PlaySoundFile("Interface\\Addons\\ShaOfIskarAssist\\Media\\heyyouhavetheball.ogg", "Master")
      end
    end

    EyeOfAnzuFrame.name:SetText(string.format("|c%s%s|r", color.colorStr, name))
    if role then
      EyeOfAnzuFrame.role:SetText(SIA:GetRoleIconText(role, 22 * scale, 22 * scale))
    end
  else
    EyeOfAnzuFrame.name:SetText("")
    EyeOfAnzuFrame.role:SetText("")
  end

  EyeOfAnzu = guid
end

function ChampionOfTheLightAssist:AddWind(guid)
  -- if the user doesn't want show this debuff, don't continue

	if not DebuffsDB.huddles.show then return end

  local role = UnitGroupRolesAssigned(SIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end


  self:AddDebuff(guid, AURA_HUDDLE_IN_TERROR)

  if true then
    local color = DebuffsDB.huddles.color
    frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
  end
end

function ChampionOfTheLightAssist:RemoveWind(guid)
  -- if the user doesn't want show this debuff, don't continue
  if not DebuffsDB.huddles.show then return end

  local role = UnitGroupRolesAssigned(SIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  self:RemoveDebuff(guid, AURA_HUDDLE_IN_TERROR)

  frame.texture:SetVertexColor(1, 1, 1, 1)
end

function ChampionOfTheLightAssist:CheckAndUpdateIfUnitIsDead(guid)
  unit = SIA:GetUnit(guid)
  local isDead = UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit)
  if isDead then
    local role = UnitGroupRolesAssigned(unit)
    local frame = self:GetPlayerFrame(guid, role)
    tinsert(Dead, guid)
    if not frame then return end
    self:RemoveDebuff(guid, AURA_HUDDLE_IN_TERROR)
    frame.texture:SetVertexColor(0.1, 0.1, 0.1, 1)
  end
end

function ChampionOfTheLightAssist:CheckAndUpdateIfUnitIsAlive(guid)
  unit = SIA:GetUnit(guid)
  local isDead = UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit)
  local _, index = self:IsDead(guid)
  if not isDead then
    local role = UnitGroupRolesAssigned(unit)
    local frame = self:GetPlayerFrame(guid, role)
    tremove(Dead, index)
    if not frame then return end
    if self:HasDebuff(guid, AURA_HUDDLE_IN_TERROR) then
      frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
    else
      frame.texture:SetVertexColor(1, 1, 1, 1)
    end
  end
end

-- **********************
-- *** Event Handlers ***
-- **********************
function ChampionOfTheLightAssist:HandleCombatLog(event, timestamp, message, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, destFlags2, ...)
	local isPlayer = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
  local isFriendly = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) > 0
	local isInRaid = bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_MINE) > 0

    -- check if it's a friendly player who is in the raid
  if isPlayer and isFriendly and isInRaid then
		--local destName, _ = strsplit("-", destName)
		if message == "SPELL_AURA_APPLIED" or message  == "SPELL_AURA_REFRESH" or message == "SPELL_AURA_APPLIED_DOSE" then
			local spellID, spellName = ...
			if spellName == AURA_CHAMPION_OF_THE_LIGHT then -- or spellID == 41635 test
				self:SetEyeOfAnzu(destGUID)
			elseif spellName == AURA_HUDDLE_IN_TERROR then -- spellID == 17
				self:AddWind(destGUID)
			end
    elseif message == "SPELL_CAST_START" or message == "SPELL_CAST_SUCCESS" then
      self:CheckAndUpdateIfUnitIsAlive(destGUID)
		elseif message == "SPELL_AURA_REMOVED" or message == "SPELL_AURA_REMOVED_DOSE" then
			local spellID, spellName = ...
			if spellName == AURA_CHAMPION_OF_THE_LIGHT then -- or spellID == 41635 test pom
				self:SetEyeOfAnzu(nil)
			elseif spellName == AURA_HUDDLE_IN_TERROR then
				self:RemoveWind(destGUID)
      elseif spellID == 21562 or spellID == 109773 or spellID == 1126 or spellID == 20217
      or spellID == 115921 or spellID == 19740 or spellID == 1459 or spellID == 109773 or spellID == 116781 then
        -- check if applied buff spell is gone
        self:CheckAndUpdateIfUnitIsDead(destGUID)
			end
    elseif message == "UNIT_DIED" then
      self:CheckAndUpdateIfUnitIsDead(destGUID)
		end

	elseif message == "UNIT_DIED" then
			--if tonumber(GetNpcID(destGUID)) == IskarID then
				--needHide = true
			--end
	end
end

function ChampionOfTheLightAssist:HandleWipeActions()

    -- Clear all player frames
    for index, frame in pairs(HealerData.frames) do
      frame.texture:SetVertexColor(1, 1, 1, 1)
    end
    for index, frame in pairs(TankData.frames) do
      frame.texture:SetVertexColor(1, 1, 1, 1)
    end
    for index, frame in pairs(DpsData.frames) do
      frame.texture:SetVertexColor(1, 1, 1, 1)
    end
    -- Clear the Eye of Anzu frame
    EyeOfAnzuFrame.name:SetText("")
    EyeOfAnzuFrame.role:SetText("")

    -- Clear all the debuff tables and variables
    wipe(Huddles)
    wipe(Dead)
    EyeOfAnzu = nil
end

function ChampionOfTheLightAssist:HandleKillActions()
    if UnitAffectingCombat("player") then
      needDisable = true
    else
      self:Disable()
    end
end

function ChampionOfTheLightAssist:HandleRaidInfoUpdate()

  if UnitAffectingCombat("player") then
    needUpdate = true
    return
  end

  self:UpdateRoleFrame("HEALER")
  self:UpdateRoleFrame("TANK")
  self:UpdateRoleFrame("DAMAGER")

end

function ChampionOfTheLightAssist:HandleDelayedAction()
  if needUpdate then
    self:HandleRaidInfoUpdate()
    needUpdate = false
  end

  if needEnable then
    self:Enable()
    needEnable = false
  end

  if needDisable then
    self:Disable()
    needDisable = false
  end
end

-- **********************
-- *** Frames Methods ***
-- **********************
function ChampionOfTheLightAssist:ShowFrames()
  if not self:IsEnabled() then
    self:Enable()
    MainFrame:Show()
  else
    MainFrame:Show()
    self:EnableAndUpdateRangeTicker()
  end
end

function ChampionOfTheLightAssist:HideFrames()
  if self:IsEnabled() then
    MainFrame:Hide()
    self:DisableRangeTicker()
  end
end

function ChampionOfTheLightAssist:ToggleFrames()
  if self:IsEnabled() then
    if MainFrame:IsShown() then
      MainFrame:Hide()
      self:DisableRangeTicker()
    else
      MainFrame:Show()
      self:EnableAndUpdateRangeTicker()
    end
  else
    self:Enable()
    MainFrame:Show()
    self:EnableAndUpdateRangeTicker()
  end
end

function ChampionOfTheLightAssist:UpdateScaleFrames()
  MainFrame:SetSize(400 * scale, 400 * scale)

  -- Update the player frames scale
  for index, frame in pairs(HealerData.frames) do
    frame:SetPoint("TOP", HealerData.groupFrame, "TOP", 0, -30 * scale - index * PLAYER_FRAME_HEIGHT * scale)
    frame:SetSize(PLAYER_FRAME_WIDTH * scale, PLAYER_FRAME_HEIGHT * scale)
    frame.texture:SetAllPoints()
  end

  for index, frame in pairs(TankData.frames) do
    frame:SetPoint("TOP", TankData.groupFrame, "TOP", 0, -30 * scale - index * PLAYER_FRAME_HEIGHT * scale)
    frame:SetSize(PLAYER_FRAME_WIDTH * scale, PLAYER_FRAME_HEIGHT * scale)
  end

  for index, frame in pairs(DpsData.frames) do
    local yRatio = math.floor(index / 2)
    if (index % 2) == 0 then
      frame:SetPoint("TOP", DpsData.groupFrame, "TOP", 0,  -30 * scale - yRatio * DPS_PLAYER_FRAME_HEIGHT * scale)
    else
      frame:SetPoint("TOP", DpsData.groupFrame, "TOP", DPS_PLAYER_FRAME_WIDTH * scale  + 5 * scale, -30 * scale - yRatio * DPS_PLAYER_FRAME_HEIGHT * scale)
    end
    frame:SetSize(DPS_PLAYER_FRAME_WIDTH * scale, DPS_PLAYER_FRAME_HEIGHT * scale)
    frame.texture:SetAllPoints()
  end

  -- Update the parent role frame
    local _, dpsCount = SIA:GetDps()
    DpsData.groupFrame:SetSize(150 * scale, 45 * scale + PLAYER_FRAME_HEIGHT * dpsCount * scale)
    DpsData.groupFrame.text:SetText(string.format("%s %s", SIA:GetRoleIconText("DAMAGER", 32 * scale, 32 * scale), "Dps"))
    DpsData.groupFrame:SetPoint("TOPLEFT", 	TankData.groupFrame, "TOPRIGHT", 5 * scale, 0)

    local _, healerCount = SIA:GetHealers()
    HealerData.groupFrame:SetSize(100 * scale, 45 * scale  + PLAYER_FRAME_HEIGHT * healerCount * scale)
    HealerData.groupFrame.text:SetText(string.format("%s %s", SIA:GetRoleIconText("HEALER", 32 * scale, 32 * scale), "Healers"))
    HealerData.groupFrame:SetPoint("TOP", TankData.groupFrame, "BOTTOM", 0, -5 * scale)

    local _, tankCount = SIA:GetTanks()
    TankData.groupFrame:SetSize(100 * scale, 45 * scale  + PLAYER_FRAME_HEIGHT * tankCount * scale)
    TankData.groupFrame.text:SetText(string.format("%s %s", SIA:GetRoleIconText("TANK", 32 * scale, 32 * scale), "Tanks"))

    -- Update the eye of Anzu
    EyeOfAnzuFrame:SetSize(200 * scale, 50 * scale)
    EyeOfAnzuFrame.texture:SetSize(24 * scale, 24 * scale)
    EyeOfAnzuFrame.texture:SetPoint("LEFT", EyeOfAnzuFrame, "LEFT", 10 * scale, 0)
    EyeOfAnzuFrame.role:SetPoint("LEFT", texture, "RIGHT", 10 * scale, 0)
    EyeOfAnzuFrame.name:SetPoint("LEFT", role, "RIGHT", 2 * scale, 0)
    EyeOfAnzuFrame.stack:SetPoint("LEFT", name, "RIGHT", 2 * scale, 0)
    EyeOfAnzuFrame:SetPoint("BOTTOM", MainFrame, "TOP", -50 * scale, 5 * scale)

end

function ChampionOfTheLightAssist:GetPlayerFrame(guid, role)

  local frame = nil

  if role == "HEALER" then
    frame = HealerData.frames[HealerData.indexesFrame[guid]]
  elseif role == "TANK" then
    frame = TankData.frames[TankData.indexesFrame[guid]]
  elseif role == "DAMAGER" then
    frame = DpsData.frames[DpsData.indexesFrame[guid]]
  end
  return frame
end

function ChampionOfTheLightAssist:UpdatePlayerFrame(frame, unit)
  frame:Show()
  frame.button:Show()
  frame.texture:Show()
  frame.name:Show()

  frame.name:SetText(UnitName(unit))

  local color = nil

  if self.db.profile.font.useClassColor then
    local _, class, _ = UnitClass(unit)
    color = RAID_CLASS_COLORS[class]
  else
    color = self.db.profile.font.color
  end

  frame.name:SetTextColor(color.r, color.g, color.b, 1)
  frame.button:SetAttribute("macrotext", string.format(MacroEyeOfAnzu, unit, '"'..unit..'"', '"'..unit..'"'))
  frame.button:SetAttribute("unit", unit)
end

function ChampionOfTheLightAssist:CreatePlayerFrame(categoryName, index)

  local frame = CreateFrame("frame")
  frame:SetSize(PLAYER_FRAME_WIDTH * scale, PLAYER_FRAME_HEIGHT * scale)

  local texture = frame:CreateTexture(nil, "artwork")
  texture:SetTexture(SKAM_BAR)

  texture:SetVertexColor(1, 1, 1, 1)
  texture:SetAllPoints()
  frame.texture = texture

  local button = CreateFrame("button", string.format("%s-%s", categoryName, index), frame, "SecureActionButtonTemplate")
  button:SetAttribute("type1", "macro")
  button:SetAttribute("type2", "spell")
  button:RegisterForClicks("AnyUp")

  button:SetAllPoints()

  -- for heal
  if MyClass == "PRIEST" then
    local spellName = GetSpellInfo(2061) -- Flash Heal
    button:SetAttribute("spell2", spellName)
  elseif MyClass == "PALADIN" then
    local spellName = GetSpellInfo(19750) -- Flash of Light
    button:SetAttribute("spell2", spellName)
  elseif MyClass == "MONK" then
    local spellName = GetSpellInfo(116694) -- Surging Mist
    button:SetAttribute("spell2", spellName)
  elseif MyClass == "SHAMAN" then
    local spellName = GetSpellInfo(8004) -- Healing Surge
    button:SetAttribute("spell2", spellName)
  elseif MyClass == "DRUID" then
    local spellName = GetSpellInfo(8936) -- Regrowth
    button:SetAttribute("spell2", spellName)
  end

  frame.button = button

  local name = frame:CreateFontString(nil, "overlay", "GameFontNormal")
  name:SetAllPoints(frame)

  frame.name = name

  -- Fill unit information if given

  return frame

end


function ChampionOfTheLightAssist:CreateTankCategoryFrame()
  TankData.groupFrame = CreateFrame("frame")
  TankData.groupFrame:SetSize(100 * scale, 45 * scale)

  local text = TankData.groupFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  text:SetText(string.format("%s %s", SIA:GetRoleIconText("TANK", 32 * scale, 32 * scale), "Tanks"))
  text:SetPoint("TOP")
  TankData.groupFrame.text = text

  TankData.groupFrame:SetParent(MainFrame)
  TankData.groupFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 0, 0)

  TankData.groupFrame:Show()
end

function ChampionOfTheLightAssist:CreateHealerCategoryFrame()

  HealerData.groupFrame = CreateFrame("frame")
  HealerData.groupFrame:SetSize(100 * scale, 45 * scale)

  local text = HealerData.groupFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  text:SetText(string.format("%s %s", SIA:GetRoleIconText("HEALER", 32 * scale, 32 * scale), "Healers"))
  text:SetPoint("TOP")
	HealerData.groupFrame.text = text

  HealerData.groupFrame:SetParent(MainFrame)
  HealerData.groupFrame:SetPoint("TOP", TankData.groupFrame, "BOTTOM", 0, -5 * scale)

  HealerData.groupFrame:Show()
end

function ChampionOfTheLightAssist:CreateDpsCategoryFrame()
    DpsData.groupFrame = CreateFrame("frame")
  	DpsData.groupFrame:SetSize(150 * scale, 45 * scale)

  	local text = DpsData.groupFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  	text:SetText(string.format("%s %s", SIA:GetRoleIconText("DAMAGER", 32 * scale, 32 * scale), "Dps"))
  	text:SetPoint("TOP")
  	DpsData.groupFrame.text = text

  	DpsData.groupFrame:SetParent(MainFrame)
  	DpsData.groupFrame:SetPoint("TOPLEFT", 	TankData.groupFrame, "TOPRIGHT", 5 * scale, 0)

  	DpsData.groupFrame:Show()
end

function ChampionOfTheLightAssist:CreateEyeOfAnzuFrame()
  local show = true

  EyeOfAnzuFrame = CreateFrame("frame")
  EyeOfAnzuFrame:SetSize(200 * scale, 50 * scale)

  local texture = EyeOfAnzuFrame:CreateTexture(nil, "OVERLAY")
  texture:SetTexture(AURA_CHAMPION_OF_THE_LIGHT_ICON)
  texture:SetSize(24 * scale, 24 * scale)
  texture:SetPoint("LEFT", EyeOfAnzuFrame, "LEFT", 10 * scale, 0)

  EyeOfAnzuFrame.texture = texture

  role = EyeOfAnzuFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  role:SetText("")
  role:SetPoint("LEFT", texture, "RIGHT", 10 * scale, 0)

  EyeOfAnzuFrame.role = role

  local name = EyeOfAnzuFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  name:SetText("")
  name:SetPoint("LEFT", role, "RIGHT", 2 * scale, 0)

  EyeOfAnzuFrame.name = name

  local stack = EyeOfAnzuFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  stack:SetText("")
  stack:SetPoint("LEFT", name, "RIGHT", 2 * scale, 0)

  EyeOfAnzuFrame.stack = stack

  EyeOfAnzuFrame:SetParent(MainFrame)
  EyeOfAnzuFrame:SetPoint("BOTTOM", MainFrame, "TOP", -50 * scale, 5 * scale)

  if show then
    EyeOfAnzuFrame:Show()
  else
    EyeOfAnzuFrame:Hide()
  end
end


function ChampionOfTheLightAssist:GetOptions()
   ChampionOfTheLightAssist.options = {
    type = "group",
    name = "Champion of the Light Assist",
    order = 2,
    childGroups = "tab",
    disabled = function() return not SIA.db.profile.modulesEnabled[self:GetName()] end,
    args = {
      general = {
        type = "group",
        name = "General",
        order = 1,
        args = {
          enable = {
            type = "toggle",
            name = "Show on Phase 2",
            desc = "Show automatically when entering the Dread Expanse.",
            descStyle = "tooltip",
            order = 1,
            get = function() return self.db.profile.showOnIskar end,
            set = function(_, showOnIskar)
                self.db.profile.showOnIskar = showOnIskar
                self.EnableOnIskar = showOnIskar
            end
          },
          lock = {
            type = "toggle",
            name = "Lock",
            order = 2,
            get = function() return self.db.profile.lock end,
            set = function(_, locked)
              if locked then
                self:LockFrames()
              else
                self:UnlockFrames()
              end
              self.db.profile.lock = locked
            end
          },
          show = {
            type = "execute",
            name = "Show/Hide",
            order = 3,
            func = function() self:ToggleFrames() end,
          },
          scale = {
            type = "range",
            name = "Scale",
            order = 4,
            min = 0.1,
            max = 5.0,
            step = 0.05,
            get = function() return self.db.profile.scale end,
            set = function(_, value) self.db.profile.scale = value;  scale = value; self:UpdateScaleFrames() end,
          },
          frameStrata = {
            type = "select",
            name = "Frame strata",
            desc = [[
FrameStrata is a frame property that determines the coarse order in which UI frames are composited onto the screen.
The following stratas are ordered in ascending order (a frame in the HIGH Strata will always be composited on top of a frame in
the MEDIUM strata) :
  1. BACKGROUND (the lowest stata)
  2. LOW
  3. MEDIUM
  4. HIGH
  5. DIALOG
  6. FULLSCREEN
  7. FULLSCREEN_DIALOG
  8. TOOLTIP (the highest stata)]],
						values = {['BACKGROUND'] = 'BACKGROUND', ['LOW'] = 'LOW', ['MEDIUM'] = 'MEDIUM',
											['HIGH'] = 'HIGH', ['DIALOG'] = 'DIALOG', ['FULLSCREEN'] = 'FULLSCREEN',
											['FULLSCREEN_DIALOG'] = 'FULLSCREEN_DIALOG', ['TOOLTIP'] = 'TOOLTIP'},
						order = 4,
						get = function() return self.db.profile.frameStrata end,
						set = function(_, strata) self.db.profile.frameStrata = strata; MainFrame:SetFrameStrata(strata) end,
          },
          rangeIndicator = {
            type = "group",
            name = "Range indicator",
            inline = true,
            args = {
              enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable the range indicator",
                order = 1,
                get = function() return self.db.profile.rangeIndicator.enable end,
                set = function(_, enable) self.db.profile.rangeIndicator.enable = enable
                    if enable then
                      self:EnableAndUpdateRangeTicker()
                    else
                      self:DisableRangeTicker()
                    end
                end,
              },
              alpha = {
                type = "range",
                name = "Out of range alpha",
                disabled = function() return not self.db.profile.rangeIndicator.enable end,
                min = 0,
                max = 1,
                step = 0.01,
                order = 2,
                get = function() return self.db.profile.rangeIndicator.alpha end,
                set = function(_, alpha) self.db.profile.rangeIndicator.alpha = alpha end,
              },
              updateFrequency = {
                type = "range",
                name = "Update frequency",
                disabled = function() return not self.db.profile.rangeIndicator.enable end,
                min = 0,
                max = 5,
                step = 0.1,
                order = 3,
                get = function() return self.db.profile.rangeIndicator.updateFrequency end,
                set = function(_, frequency)
                  self.db.profile.rangeIndicator.updateFrequency = frequency
                  self:EnableAndUpdateRangeTicker()
                end,
              }
            }
          },
          font = {
            type = "group",
            name = "Font",
            inline = true,
            args = {
              color = {
                type = "color",
                name = "Color",
                desc = "Set the name font color",
                order = 1,
                disabled = function() return self.db.profile.font.useClassColor end,
                get = function()
                  local color = self.db.profile.font.color
                  return color.r, color.g, color.b
                end,
                set = function(_, r, g, b, a)
                  local color = self.db.profile.font.color
                  color.r, color.g, color.b = r, g, b
                end,
              },
              classColor ={
                type = "toggle",
								name = "Use class color",
								desc = "If set, the name will be colored by the class color.",
								order = 2,
								get = function() return self.db.profile.font.useClassColor end,
								set = function(_, value)
									self.db.profile.font.useClassColor = value
									self:UpdateAllFrames()
								end,
              }
            }
          },
          eyeOfAnzu = {
            type = "group",
            name = string.format("%s %s", SIA:GetIconText(AURA_CHAMPION_OF_THE_LIGHT_ICON, 18, 18), AURA_CHAMPION_OF_THE_LIGHT),
            inline = true,
            args ={
              show = {
                type = "toggle",
                name = "Show",
                desc = "Show the Champion of the Light frame which displays the holder.",
                order = 1,
                get = function() return self.db.profile.eyeOfAnzu.show end,
                set = function(_, value)
                  if value then
                    EyeOfAnzuFrame:Show()
                  else
                    EyeOfAnzuFrame:Hide()
                  end

                  self.db.profile.eyeOfAnzu.show = value
                end,

              }
            }
          },
          extraFeatures = {
            type= "group",
            name = "Extra Features",
            inline = true,
            args = {
              voiceAlerts = {
                type = "toggle",
                name = "Voice Alerts",
                desc = "Play voice lines when you get Champion of the Light.",
                order = 1,
                get = function() return self.db.profile.voiceAlerts end,
                set = function(_, value) self.db.profile.voiceAlerts = value end,
              }
            }
          }
        }
      },
      debuffs = {
        type = "group",
        name = "Debuffs",
        order = 2,
        args = {
          header = {
						type = "description",
						name = string.format("The debuff priority is : %s",
										AURA_HUDDLE_IN_TERROR),
						order = 0,

					},
					huddles = {
						type = "group",
						name = string.format("%s %s", SIA:GetIconText(AURA_HUDDLE_IN_TERROR_ICON, 18, 18), AURA_HUDDLE_IN_TERROR),
						inline = true,
						order = 1,
						args = {
							show = {
								type = "toggle",
								name = "Show debuff",
								order = 1,
								get = function() return DebuffsDB.huddles.show end,
								set = function(_, value) DebuffsDB.huddles.show = value end,

							},
							color = {
								type = "color",
								name = "Debuff color",
								order = 2,
                get = function()
                    local color = DebuffsDB.huddles.color
                    return color.r, color.g, color.b
                  end,
								set = function(_, r, g, b, a)
                  local color = DebuffsDB.huddles.color
                  color.r, color.g, color.b = r, g, b
								end,

							}
						}
					}
        }
      }
    }
  }

  return ChampionOfTheLightAssist.options
end
