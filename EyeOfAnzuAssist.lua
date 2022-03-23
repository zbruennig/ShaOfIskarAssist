local _, EIA = ...

local EyeOfAnzuAssist = EIA:NewModule("EyeOfAnzuAssist")
EIA:AutoEnableModuleOnBoss(EyeOfAnzuAssist, function() EyeOfAnzuAssist:ShowFrames() end)

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
local SKAM_BAR = [[Interface\Addons\EpsiIskarAssist\Media\skam_bar]]

-- ********************
-- *** Macro Format ***
-- ********************
local MacroEyeOfAnzu = "/target %s\n/click ExtraActionButton1\n/targetlasttarget"

-- ************
-- *** Data ***
-- ************
local PLAYER_FRAME_WIDTH, PLAYER_FRAME_HEIGHT = 100, 25
local DPS_PLAYER_FRAME_WIDTH, DPS_PLAYER_FRAME_HEIGHT = 75, 25

local Ticker = nil

local _, MyClass = UnitClass("player")


local Winds = {}
local Wounds = {}
local DarkBindings = {}
local Corruptions = {}
local FelBomb = nil
local EyeOfAnzu = nil

local PreviousHealerCount = 0
local PreviousTankCount =  0
local PreviousDpsCount = 0


-- ****************************
-- *** Localized spell name ***
-- ****************************
local AURA_EYE_OF_ANZU, _, AURA_EYE_OF_ANZU_ICON = GetSpellInfo(EIA.AuraEyeOfAnzuSpellID)
local AURA_PHANTASMAL_WINDS, _, AURA_PHANTASMAL_WINDS_ICON = GetSpellInfo(EIA.AuraPhantasmalWindsSpellID)
local AURA_PHANTASMAL_WOUNDS, _, AURA_PHANTASMAL_WOUNDS_ICON = GetSpellInfo(EIA.AuraPhantasmalWoundsSpellID)
local AURA_PHANTASMAL_FEL_BOMB = GetSpellInfo(EIA.AuraPhantasmalFelBombSpellID)
local AURA_FEL_BOMB, _, AURA_FEL_BOMB_ICON = GetSpellInfo(EIA.AuraFelBombSpellID)
local AURA_PHANTASMAL_CORRUPTION, _, AURA_PHANTASMAL_CORRUPTION_ICON = GetSpellInfo(EIA.AuraPhantasmalCorruptionSpellID)
local AURA_DARK_BINDINGS, _, AURA_DARK_BINDINGS_ICON = GetSpellInfo(EIA.AuraDarkBindingsSpellID)
local AURA_RADIANCE_OF_ANZU, _, AURA_RADIANCE_OF_ANZU_ICON = GetSpellInfo(EIA.AuraRadianceOfAnzuSpellID)

local DebuffsDB = nil

local defaults = {
  profile = {
    showOnIskar = true,
    lock = false,
    scale = 1.0,
    xPos = 100,
    yPos = 100,
    frameStrata = "HIGH",
    rangeIndicator = {
      enable = true,
      alpha = 0.5,
      updateFrequency = 0.5,
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
      winds = {
        show = true,
        color = {
          r = 1,
          g = 0,
          b = 0
        },
        priority = 1, -- currently unused
      },
      wounds = {
        show = true,
        color = {
          r = 1,
          g = 0,
          b = 1
        },
        priority = 4, -- currently unused
      },
      felBomb = {
        show = true,
        color = {
          r = 0,
          g = 1,
          b = 0,
        },
        priority = 0,
      },
      corruption = {
        show = true,
        color = {
          r = 1,
          g = 0.85,
          b = 0,
        },
        priority = 3,
      },
      darkBindings = {
        show = true,
        color = {
          r = 0.49,
          g = 0.29,
          b = 0.09,
        },
        priority = 2,
      }
    },
    eyeOfAnzu = {
      show = true,
      showRadianceOfAnzu = true,
    },
    radianceOfAnzu = {
      show = true,
      showIcon = false,
      stack = {
        low = {
          threshold = 10,
          color = {
            r = 0,
            g = 1,
            b = 0,
          }
        },
        medium = {
          threshold = 20,
          color = {
            r = 1,
            g = 0.5,
            b = 0,
          }
        },
        high = {
          color = {
            r = 1,
            g = 0,
            b = 0,
          }
        }
      }
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

  EyeOfAnzuAssist.db.profile.xPos = x
  EyeOfAnzuAssist.db.profile.yPos = y
end

EyeOfAnzuAssist.EnableOnIskar = true
function EyeOfAnzuAssist:OnInitialize()

  self.db = EIA.db:GetNamespace("EyeOfAnzuAssist", true) or EIA.db:RegisterNamespace("EyeOfAnzuAssist", defaults)
  self.EnableOnIskar = self.db.profile.showOnIskar
  scale = self.db.profile.scale
  DebuffsDB = self.db.profile.debuffs


  self:RegisterChatCommand("iskar", "HandleChatCommands")
  self:RegisterChatCommand("eia", "HandleChatCommands")


  if not EIA.db.profile.modulesEnabled[self:GetName()] then
    self.EnableOnIskar = false
  end

  if self.EnableOnIskar or not EIA.db.profile.modulesEnabled[self:GetName()] then
    self:SetEnabledState(false)
  end
end

function EyeOfAnzuAssist:OnEnable()

  self.EnableOnIskar = self.db.profile.showOnIskar
  self:RegisterMessage("EIA_RAID_INFO_UPDATED", "HandleRaidInfoUpdate")
  self:RegisterMessage("EIA_ISKAR_WIPE", "HandleWipeActions")
  self:RegisterMessage("EIA_ISKAR_KILLED", "HandleKillActions")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "HandleDelayedAction")

  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "HandleCombatLog")

  HealerData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  TankData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  DpsData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }

  Winds = {}
  Wounds = {}
  DarkBindings = {}
  Corruptions = {}
  FelBomb = {}
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

function EyeOfAnzuAssist:OnDisable()

  self:UnregisterMessage("EIA_RAID_INFO_UPDATED")
  self:UnregisterMessage("EIA_ISKAR_WIPE")
  self:UnregisterMessage("EIA_ISKAR_KILLED")
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")

  self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

  MainFrame:Hide()
  self:DisableRangeTicker()

  MainFrame = nil
  EyeOfAnzuFrame = nil

  HealerData = nil
  TankData = nil
  DpsData = nil

  Winds = nil
  Wounds = nil
  DarkBindings = nil
  Corruptions = nil
  FelBomb = nil
  EyeOfAnzu = nil

  PreviousHealerCount = nil
  PreviousTankCount =  nil
  PreviousDpsCount = nil

  self.EnableOnIskar = false


end

function EyeOfAnzuAssist:LockFrames()
  MainFrame:EnableMouse(false)
  MainFrame:SetMovable(false)
  self:Print("The raid frame has been locked")
end

function EyeOfAnzuAssist:UnlockFrames()
  MainFrame:EnableMouse(true)
  MainFrame:SetMovable(true)
  self:Print("The raid frame has been unlocked")
end

function EyeOfAnzuAssist:HandleChatCommands(input)
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
    self:HandleRaidInfoUpdate()
    self:Print("The raid frame has been reloaded")
  elseif input == "clear" then
    self:HandleWipeActions() -- clear all the debuffs and reset the player frame color
    self:Print("The raid frame has been cleared")
  end
end

function EyeOfAnzuAssist:EnableAndUpdateRangeTicker()

  self:DisableRangeTicker()
  Ticker = C_Timer.NewTicker(self.db.profile.rangeIndicator.updateFrequency, function() EyeOfAnzuAssist:UpdateRangePlayers() end)
end

function EyeOfAnzuAssist:DisableRangeTicker()
  if Ticker then
    Ticker:Cancel()
    Ticker = nil
  end
end




function EyeOfAnzuAssist:UpdateRoleFrame(role)
  local roleData = nil
  local rolePlayers = nil
  local currentRoleCount = 0

  if role == "HEALER" then
    rolePlayers, currentRoleCount = EIA:GetHealers()
    roleData = HealerData
  elseif role == "TANK" then
    rolePlayers, currentRoleCount = EIA:GetTanks()
    roleData = TankData
  elseif role == "DAMAGER" then
    rolePlayers, currentRoleCount = EIA:GetDps()
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
      frame.radianceOfAnzuIcon:Hide()
      frame.radianceOfAnzuStack:Hide()
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
            frame.radianceOfAnzuIcon:SetPoint("RIGHT", frame, "LEFT", 0, 0)
          else
            frame:SetPoint("TOP", roleData.groupFrame, "TOP", DPS_PLAYER_FRAME_WIDTH * scale  + 5 * scale, -30 * scale - yRatio * DPS_PLAYER_FRAME_HEIGHT * scale)
            frame.radianceOfAnzuIcon:SetPoint("LEFT", frame, "RIGHT", 0, 0)
          end

          frame:SetSize(DPS_PLAYER_FRAME_WIDTH * scale, DPS_PLAYER_FRAME_HEIGHT * scale)
        else
        frame.radianceOfAnzuIcon:SetPoint("RIGHT", frame, "LEFT", 0, 0)
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
     local unit = EIA:GetUnit(guid)
     local frame = roleData.frames[index - 1]

     self:UpdatePlayerFrame(frame, unit)
     roleData.indexesFrame[guid] = index - 1
  end

  roleData.previousCount = currentRoleCount


end

function EyeOfAnzuAssist:UpdateRangePlayer(frame, unit)

    if not unit then return end

    local range = math.floor(UnitDistanceSquared(unit) ^ 0.5)
    if range > 40 then
        frame:SetAlpha(self.db.profile.rangeIndicator.alpha)
    else
        frame:SetAlpha(1)
    end
end

function EyeOfAnzuAssist:UpdateRangePlayers()
  --HealerData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  --TankData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  --DpsData = { previousCount = 0, frames = {}, indexesFrame = {}, groupFrame = nil }
  --HealerData.indexesFrame[guid]

  for guid, index in pairs(HealerData.indexesFrame) do
      local unit = EIA:GetUnit(guid)
      local frame = HealerData.frames[index]
      self:UpdateRangePlayer(frame, unit)
  end

  for guid, index in pairs(TankData.indexesFrame) do
      local unit = EIA:GetUnit(guid)
      local frame = TankData.frames[index]
      self:UpdateRangePlayer(frame, unit)
  end

  for guid, index in pairs(DpsData.indexesFrame) do
      local unit = EIA:GetUnit(guid)
      local frame = DpsData.frames[index]
      self:UpdateRangePlayer(frame, unit)
  end
end

function EyeOfAnzuAssist:AddDebuff(guid, debuffName)
    if self:HasDebuff(guid, debuffName) then return end

    if debuffName == AURA_PHANTASMAL_WINDS then
      tinsert(Winds, guid)
    elseif debuffName == AURA_PHANTASMAL_WOUNDS then
      tinsert(Wounds, guid)
    elseif debuffName == AURA_DARK_BINDINGS then
      tinsert(DarkBindings, guid)
    elseif debuffName == AURA_PHANTASMAL_CORRUPTION then
      tinsert(Corruptions, guid)
    end
end

function EyeOfAnzuAssist:RemoveDebuff(guid, debuffName)
    local hasDebuff, index = self:HasDebuff(guid, debuffName)

    if not hasDebuff then return end

    if debuffName == AURA_PHANTASMAL_WINDS then
      tremove(Winds, index)
    elseif debuffName == AURA_PHANTASMAL_WOUNDS then
      tremove(Wounds, index)
    elseif debuffName == AURA_DARK_BINDINGS then
      tremove(DarkBindings, index)
    elseif debuffName == AURA_PHANTASMAL_CORRUPTION then
      tremove(Corruptions, index)
    end
end

function EyeOfAnzuAssist:HasDebuff(guid, debuffName)
    if debuffName == AURA_FEL_BOMB then
      if FelBomb and FelBomb == guid then return true, nil end
    elseif debuffName == AURA_PHANTASMAL_WINDS then
  		for index, playerGUID in ipairs(Winds) do
  			if guid == playerGUID then return true, index end
  		end
  	elseif debuffName == AURA_PHANTASMAL_WOUNDS then
  		for index, playerGUID in ipairs(Wounds) do
  			if guid == playerGUID then return true, index end
  		end
  	elseif debuffName == AURA_DARK_BINDINGS then
  		for index, playerGUID in ipairs(DarkBindings) do
  			if guid == playerGUID then return true, index end
  		end
  	elseif debuffName == AURA_PHANTASMAL_CORRUPTION then
  		for index, playerGUID in ipairs(Corruptions) do
  			if guid == playerGUID then return true, index end
  		end
  	end

  	return false, nil
end

function EyeOfAnzuAssist:SetFelBomb(guid)
  -- if the user doesn't want show this debuff, don't continue
	if not DebuffsDB.felBomb.show then return end

  if not FelBomb and not guid then return end

  local g = nil

  if guid then
    g = guid
    FelBomb = guid
  else
    g = FelBomb
    FelBomb = nil
  end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(g))

  local frame = self:GetPlayerFrame(g, role)

  if not frame then return end

  local color = nil
  -- If Felbomb is ~= nil, Felbomb is added
  if FelBomb then
    color = DebuffsDB.felBomb.color
  else
    if self:HasDebuff(g, AURA_PHANTASMAL_WINDS) then
      color = DebuffsDB.winds.color
    elseif self:HasDebuff(g, AURA_DARK_BINDINGS) then
      color = DebuffsDB.darkBindings.color
    elseif self:HasDebuff(g, AURA_PHANTASMAL_CORRUPTION) then
      color = DebuffsDB.corruption.color
    elseif self:HasDebuff(g, AURA_PHANTASMAL_WOUNDS) then
      color = DebuffsDB.wounds.color
    end
  end

  if color then
    frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
  else
    frame.texture:SetVertexColor(1, 1, 1, 1)
  end

end

function EyeOfAnzuAssist:SetEyeOfAnzu(guid)
  if not guid and not EyeOfAnzu then return end

  if guid then
    local unit = EIA:GetUnit(guid)

    local name = UnitName(unit)
    local role = UnitGroupRolesAssigned(unit)
    local _, class = UnitClass(unit)

    local color = RAID_CLASS_COLORS[class]

    EyeOfAnzuFrame.name:SetText(string.format("|c%s%s|r", color.colorStr, name))
    if role then
      EyeOfAnzuFrame.role:SetText(EIA:GetRoleIconText(role, 22 * scale, 22 * scale))
    end
  else
    EyeOfAnzuFrame.name:SetText("")
    EyeOfAnzuFrame.role:SetText("")
  end

  EyeOfAnzu = guid
end

function EyeOfAnzuAssist:AddWind(guid)
  -- if the user doesn't want show this debuff, don't continue

	if not DebuffsDB.winds.show then return end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end


  self:AddDebuff(guid, AURA_PHANTASMAL_WINDS)

  -- Color Priority ( FelBomb > Winds > DarkBindings > Corruption > Wound)
  if not self:HasDebuff(guid, AURA_FEL_BOMB) then
    local color = DebuffsDB.winds.color
    frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
  end
end

function EyeOfAnzuAssist:RemoveWind(guid)
  -- if the user doesn't want show this debuff, don't continue
  if not DebuffsDB.winds.show then return end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  self:RemoveDebuff(guid, AURA_PHANTASMAL_WINDS)

  -- Color Priority ( FelBomb > Winds > DarkBindings > Corruption > Wound)
  local color = nil
  if self:HasDebuff(guid, AURA_FEL_BOMB) then
    return
  elseif self:HasDebuff(guid, AURA_DARK_BINDINGS) then
    color = DebuffsDB.darkBindings.color
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_CORRUPTION) then
    color = DebuffsDB.corruption.color
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_WOUNDS) then
    color = DebuffsDB.wounds.color
  end

  if color then
    frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
  else
    frame.texture:SetVertexColor(1, 1, 1, 1)
  end
end

function EyeOfAnzuAssist:AddWound(guid)
  -- if the user doesn't want show this debuff, don't continue
  if not DebuffsDB.wounds.show then return end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  self:AddDebuff(guid, AURA_PHANTASMAL_WOUNDS)

  -- Color Priority ( FelBomb > Winds > DarkBindings > Corruption > Wound)
  if not self:HasDebuff(guid, AURA_FEL_BOMB) and not self:HasDebuff(guid, AURA_PHANTASMAL_WINDS) and not self:HasDebuff(guid, AURA_DARK_BINDINGS) and not self:HasDebuff(guid, AURA_PHANTASMAL_CORRUPTION) then
    local color = DebuffsDB.wounds.color
    frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
  end

end

function EyeOfAnzuAssist:RemoveWound(guid)
  -- if the user doesn't want show this debuff, don't continue
  if not DebuffsDB.wounds.show then return end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  self:RemoveDebuff(guid, AURA_PHANTASMAL_WOUNDS)

  -- Color Priority ( FelBomb > Winds > DarkBindings > Corruption > Wound)
  if self:HasDebuff(guid, AURA_FEL_BOMB) then
    return
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_WINDS) then
    return
  elseif self:HasDebuff(guid, AURA_DARK_BINDINGS) then
    return
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_CORRUPTION) then
    return
  else
    frame.texture:SetVertexColor(1, 1, 1, 1)
  end

end

function EyeOfAnzuAssist:AddDarkBinding(guid)
  -- if the user doesn't want show this debuff, don't continue
	if not DebuffsDB.darkBindings.show then return end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  self:AddDebuff(guid, AURA_DARK_BINDINGS)

  -- Color Priority ( FelBomb > Winds > DarkBindings > Corruption > Wound)
  if not self:HasDebuff(guid, AURA_FEL_BOMB) and not self:HasDebuff(guid, AURA_PHANTASMAL_WINDS) then
    --frame.texture:SetVertexColor(1, 0, 1, 1)
    local color = DebuffsDB.darkBindings.color
    frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
  end
end

function EyeOfAnzuAssist:RemoveDarkBinding(guid)
  -- if the user doesn't want show this debuff, don't continue
  if not DebuffsDB.darkBindings.show then return end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  self:RemoveDebuff(guid, AURA_DARK_BINDINGS)

  -- Color Priority ( FelBomb > Winds > DarkBindings > Corruption > Wound)
  local color = nil
  if self:HasDebuff(guid, AURA_FEL_BOMB) then
    return
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_WINDS) then
    return
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_CORRUPTION) then
    color = DebuffsDB.corruption.color
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_WOUNDS) then
    color = DebuffsDB.wounds.color
  end

  if color then
    frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
  else
    frame.texture:SetVertexColor(1, 1, 1, 1)
  end

end

function EyeOfAnzuAssist:AddCorruption(guid)
  -- if the user doesn't want show this debuff, don't continue
  if not DebuffsDB.corruption.show then return end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  self:AddDebuff(guid, AURA_PHANTASMAL_CORRUPTION)

  -- Color Priority ( FelBomb > Winds > DarkBindings > Corruption > Wound)
  if not self:HasDebuff(guid, AURA_FEL_BOMB) and not self:HasDebuff(guid, AURA_PHANTASMAL_WINDS) and not self:HasDebuff(guid, AURA_DARK_BINDINGS) then
    local color = DebuffsDB.corruption.color
		frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
	end
end

function EyeOfAnzuAssist:RemoveCorruption(guid)
  -- if the user doesn't want show this debuff, don't continue
  if not DebuffsDB.corruption.show then return end

  local role = UnitGroupRolesAssigned(EIA:GetUnit(guid))
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  self:RemoveDebuff(guid, AURA_PHANTASMAL_CORRUPTION)

  -- Color Priority ( FelBomb > Winds > DarkBindings > Corruption > Wound)
  local color = nil
  if self:HasDebuff(guid, AURA_FEL_BOMB) then
    return
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_WINDS) then
    return
  elseif self:HasDebuff(guid, AURA_DARK_BINDINGS) then
    return
  elseif self:HasDebuff(guid, AURA_PHANTASMAL_WOUNDS) then
    color = DebuffsDB.wounds.color
  end

  if color then
    frame.texture:SetVertexColor(color.r, color.g, color.b, 1)
  else
    frame.texture:SetVertexColor(1, 1, 1, 1)
  end

end

function EyeOfAnzuAssist:UpdateRadianceOfAnzu(guid)
	if not self.db.profile.radianceOfAnzu.show and not self.db.profile.eyeOfAnzu.showRadianceOfAnzu then return end

  local unit = EIA:GetUnit(guid)
  local role = UnitGroupRolesAssigned(unit)
  local frame = self:GetPlayerFrame(guid, role)

  if not frame then return end

  local _, _, _, stack = UnitDebuff(unit, AURA_RADIANCE_OF_ANZU)

  if stack and stack > 0 then
    if self.db.profile.radianceOfAnzu.showIcon then
      frame.radianceOfAnzuIcon:Show()
    end
    -- color
    local color = nil
    if stack < self.db.profile.radianceOfAnzu.stack.low.threshold then
      color = self.db.profile.radianceOfAnzu.stack.low.color
    elseif stack < self.db.profile.radianceOfAnzu.stack.medium.threshold then
      color = self.db.profile.radianceOfAnzu.stack.medium.color
    else
      color = self.db.profile.radianceOfAnzu.stack.high.color
    end

    if self.db.profile.radianceOfAnzu.show then
      frame.radianceOfAnzuStack:SetTextColor(color.r, color.g, color.b)
      frame.radianceOfAnzuStack:Show()
      frame.radianceOfAnzuStack:SetText(stack)
    end

    if self.db.profile.eyeOfAnzu.show and self.db.profile.eyeOfAnzu.showRadianceOfAnzu then
      EyeOfAnzuFrame.stack:Show()
      EyeOfAnzuFrame.stack:SetText(string.format("(%i)", stack))
      EyeOfAnzuFrame.stack:SetTextColor(color.r, color.g, color.b)
    end
  else
      frame.radianceOfAnzuStack:Hide()
      frame.radianceOfAnzuIcon:Hide()
      EyeOfAnzuFrame.stack:Hide()
  end
end




-- **********************
-- *** Event Handlers ***
-- **********************
function EyeOfAnzuAssist:HandleCombatLog(event, timestamp, message, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, destFlags2, ...)
	local isPlayer = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
  local isFriendly = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) > 0
	 local isInRaid = bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_MINE) > 0

    -- check if it's a friendly player who is in the raid
    if isPlayer and isFriendly and isInRaid then
		--local destName, _ = strsplit("-", destName)
		if message == "SPELL_AURA_APPLIED" or message  == "SPELL_AURA_REFRESH" or message == "SPELL_AURA_APPLIED_DOSE" then
			local spellID, spellName = ...

			if spellName == AURA_EYE_OF_ANZU then -- or spellID == 41635 test
				self:SetEyeOfAnzu(destGUID)
			elseif spellName == AURA_PHANTASMAL_WINDS then -- spellID == 17
				self:AddWind(destGUID)
			elseif spellName == AURA_FEL_BOMB then -- or spellID == 111759
				self:SetFelBomb(destGUID)
			elseif spellName == AURA_PHANTASMAL_WOUNDS then -- or spellID == 121557
				self:AddWound(destGUID)
			elseif spellName == AURA_DARK_BINDINGS then -- or spellID == 152118
				self:AddDarkBinding(destGUID)
			elseif spellName == AURA_PHANTASMAL_CORRUPTION then -- or spellID == 586
				self:AddCorruption(destGUID)
			elseif spellName == AURA_RADIANCE_OF_ANZU then -- or spellID == 155274
				self:UpdateRadianceOfAnzu(destGUID)
			end
		elseif message == "SPELL_AURA_REMOVED" or message == "SPELL_AURA_REMOVED_DOSE" then
			local spellID, spellName = ...

			if spellName == AURA_EYE_OF_ANZU then -- or spellID == 41635 test pom
				self:SetEyeOfAnzu(nil)
			elseif spellName == AURA_PHANTASMAL_WINDS then
				self:RemoveWind(destGUID)
			elseif spellName == AURA_FEL_BOMB then
				self:SetFelBomb(nil)
			elseif spellName == AURA_PHANTASMAL_WOUNDS then
				self:RemoveWound(destGUID)
			elseif spellName == AURA_DARK_BINDINGS then
				self:RemoveDarkBinding(destGUID)
			elseif spellName == AURA_PHANTASMAL_CORRUPTION then
				self:RemoveCorruption(destGUID)
			elseif spellName == AURA_RADIANCE_OF_ANZU then
				self:UpdateRadianceOfAnzu(destGUID)
			end
		end

	elseif message == "UNIT_DIED" then
			--if tonumber(GetNpcID(destGUID)) == IskarID then
				--needHide = true
			--end
	end
end

function EyeOfAnzuAssist:HandleWipeActions()

    -- Clear all player frames
    for index, frame in pairs(HealerData.frames) do
      frame.texture:SetVertexColor(1, 1, 1, 1)
      frame.radianceOfAnzuStack:SetText("")
    end
    for index, frame in pairs(TankData.frames) do
      frame.texture:SetVertexColor(1, 1, 1, 1)
      frame.radianceOfAnzuStack:SetText("")
    end
    for index, frame in pairs(DpsData.frames) do
      frame.texture:SetVertexColor(1, 1, 1, 1)
      frame.radianceOfAnzuStack:SetText("")
    end
    -- Clear the Eye of Anzu frame
    EyeOfAnzuFrame.name:SetText("")
    EyeOfAnzuFrame.role:SetText("")

    -- Clear all the debuff tables and variables
    wipe(Winds)
    wipe(Wounds)
    wipe(Corruptions)
    wipe(DarkBindings)
    FelBomb = nil
    EyeOfAnzu = nil
end

function EyeOfAnzuAssist:HandleKillActions()
    if UnitAffectingCombat("player") then
      needDisable = true
    else
      self:Disable()
    end
end

function EyeOfAnzuAssist:HandleRaidInfoUpdate()

  if UnitAffectingCombat("player") then
    needUpdate = true
    return
  end

  self:UpdateRoleFrame("HEALER")
  self:UpdateRoleFrame("TANK")
  self:UpdateRoleFrame("DAMAGER")

end

function EyeOfAnzuAssist:HandleDelayedAction()
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
function EyeOfAnzuAssist:ShowFrames()
  if not self:IsEnabled() then
    self:Enable()
    MainFrame:Show()
  else
    MainFrame:Show()
    self:EnableAndUpdateRangeTicker()
  end
end

function EyeOfAnzuAssist:HideFrames()
  if self:IsEnabled() then
    MainFrame:Hide()
    self:DisableRangeTicker()
  end
end

function EyeOfAnzuAssist:ToggleFrames()
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

function EyeOfAnzuAssist:UpdateScaleFrames()
  MainFrame:SetSize(400 * scale, 400 * scale)

  -- Update the player frames scale
  for index, frame in pairs(HealerData.frames) do
    frame:SetPoint("TOP", HealerData.groupFrame, "TOP", 0, -30 * scale - index * PLAYER_FRAME_HEIGHT * scale)
    frame:SetSize(PLAYER_FRAME_WIDTH * scale, PLAYER_FRAME_HEIGHT * scale)
    frame.radianceOfAnzuIcon:SetSize(PLAYER_FRAME_HEIGHT * scale, PLAYER_FRAME_HEIGHT * scale)
    frame.texture:SetAllPoints()
  end

  for index, frame in pairs(TankData.frames) do
    frame:SetPoint("TOP", TankData.groupFrame, "TOP", 0, -30 * scale - index * PLAYER_FRAME_HEIGHT * scale)
    frame:SetSize(PLAYER_FRAME_WIDTH * scale, PLAYER_FRAME_HEIGHT * scale)
    frame.radianceOfAnzuIcon:SetSize(PLAYER_FRAME_HEIGHT * scale, PLAYER_FRAME_HEIGHT * scale)
  end

  for index, frame in pairs(DpsData.frames) do
    local yRatio = math.floor(index / 2)
    if (index % 2) == 0 then
      frame:SetPoint("TOP", DpsData.groupFrame, "TOP", 0,  -30 * scale - yRatio * DPS_PLAYER_FRAME_HEIGHT * scale)
      frame.radianceOfAnzuIcon:SetPoint("RIGHT", frame, "LEFT", 0, 0)
    else
      frame:SetPoint("TOP", DpsData.groupFrame, "TOP", DPS_PLAYER_FRAME_WIDTH * scale  + 5 * scale, -30 * scale - yRatio * DPS_PLAYER_FRAME_HEIGHT * scale)
      frame.radianceOfAnzuIcon:SetPoint("LEFT", frame, "RIGHT", 0, 0)
    end
    frame:SetSize(DPS_PLAYER_FRAME_WIDTH * scale, DPS_PLAYER_FRAME_HEIGHT * scale)
    frame.radianceOfAnzuIcon:SetSize(PLAYER_FRAME_HEIGHT * scale, PLAYER_FRAME_HEIGHT * scale)
    frame.texture:SetAllPoints()
  end

  -- Update the parent role frame
    local _, dpsCount = EIA:GetDps()
    DpsData.groupFrame:SetSize(150 * scale, 45 * scale + PLAYER_FRAME_HEIGHT * dpsCount * scale)
    DpsData.groupFrame.text:SetText(string.format("%s %s", EIA:GetRoleIconText("DAMAGER", 32 * scale, 32 * scale), "Dps"))
    DpsData.groupFrame:SetPoint("TOPLEFT", 	TankData.groupFrame, "TOPRIGHT", 5 * scale, 0)

    local _, healerCount = EIA:GetHealers()
    HealerData.groupFrame:SetSize(100 * scale, 45 * scale  + PLAYER_FRAME_HEIGHT * healerCount * scale)
    HealerData.groupFrame.text:SetText(string.format("%s %s", EIA:GetRoleIconText("HEALER", 32 * scale, 32 * scale), "Healers"))
    HealerData.groupFrame:SetPoint("TOP", TankData.groupFrame, "BOTTOM", 0, -5 * scale)

    local _, tankCount = EIA:GetTanks()
    TankData.groupFrame:SetSize(100 * scale, 45 * scale  + PLAYER_FRAME_HEIGHT * tankCount * scale)
    TankData.groupFrame.text:SetText(string.format("%s %s", EIA:GetRoleIconText("TANK", 32 * scale, 32 * scale), "Tanks"))

    -- Update the eye of Anzu
    EyeOfAnzuFrame:SetSize(200 * scale, 50 * scale)
    EyeOfAnzuFrame.texture:SetSize(24 * scale, 24 * scale)
    EyeOfAnzuFrame.texture:SetPoint("LEFT", EyeOfAnzuFrame, "LEFT", 10 * scale, 0)
    EyeOfAnzuFrame.role:SetPoint("LEFT", texture, "RIGHT", 10 * scale, 0)
    EyeOfAnzuFrame.name:SetPoint("LEFT", role, "RIGHT", 2 * scale, 0)
    EyeOfAnzuFrame.stack:SetPoint("LEFT", name, "RIGHT", 2 * scale, 0)
    EyeOfAnzuFrame:SetPoint("BOTTOM", MainFrame, "TOP", -50 * scale, 5 * scale)

end

function EyeOfAnzuAssist:GetPlayerFrame(guid, role)

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

function EyeOfAnzuAssist:UpdatePlayerFrame(frame, unit)
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

  frame.button:SetAttribute("macrotext", string.format(MacroEyeOfAnzu, unit))
  frame.button:SetAttribute("unit", unit)
end

function EyeOfAnzuAssist:CreatePlayerFrame(categoryName, index)

  local frame = CreateFrame("frame")
  frame:SetSize(PLAYER_FRAME_WIDTH * scale, PLAYER_FRAME_HEIGHT * scale)

  local texture = frame:CreateTexture(nil, "artwork")
  texture:SetTexture(SKAM_BAR)

  texture:SetVertexColor(1, 1, 1, 1)
  texture:SetAllPoints()
  frame.texture = texture

  local radianceOfAnzuIcon = frame:CreateTexture(nil, "OVERLAY")
  radianceOfAnzuIcon:SetTexture(AURA_RADIANCE_OF_ANZU)
  radianceOfAnzuIcon:SetSize(PLAYER_FRAME_HEIGHT * scale, PLAYER_FRAME_HEIGHT * scale)
  radianceOfAnzuIcon:Hide()
  frame.radianceOfAnzuIcon = radianceOfAnzuIcon

  local radianceOfAnzuStack = frame:CreateFontString(nil, "overlay", "GameFontNormal")
  radianceOfAnzuStack:SetText("")
  radianceOfAnzuStack:SetTextColor(1, 0, 0, 1)
  radianceOfAnzuStack:SetAllPoints(radianceOfAnzuIcon)
  radianceOfAnzuStack:Hide()
  frame.radianceOfAnzuStack = radianceOfAnzuStack

  local button = CreateFrame("button", string.format("%s-%s", categoryName, index), frame, "SecureActionButtonTemplate")
  button:SetAttribute("type1", "macro")
  button:SetAttribute("type2", "spell")
  button:RegisterForClicks("AnyUp")

  button:SetAllPoints()

  -- for heal
  if MyClass == "PRIEST" then
    local spellName = GetSpellInfo(527)
    button:SetAttribute("spell2", spellName)
  elseif MyClass == "PALADIN" then
    local spellName = GetSpellInfo(4987)
    button:SetAttribute("spell2", spellName)
  elseif MyClass == "MONK" then
    local spellName = GetSpellInfo(115450)
    button:SetAttribute("spell2", spellName)
  elseif MyClass == "SHAMAN" then
    local spellName = GetSpellInfo(77130)
    button:SetAttribute("spell2", spellName)
  elseif MyClass == "DRUID" then
    local spellName = GetSpellInfo(88423)
    button:SetAttribute("spell2", spellName)
  end

  frame.button = button

  local name = frame:CreateFontString(nil, "overlay", "GameFontNormal")
  name:SetAllPoints(frame)

  frame.name = name

  -- Fill unit information if given

  return frame

end


function EyeOfAnzuAssist:CreateTankCategoryFrame()
  TankData.groupFrame = CreateFrame("frame")
  TankData.groupFrame:SetSize(100 * scale, 45 * scale)

  local text = TankData.groupFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  text:SetText(string.format("%s %s", EIA:GetRoleIconText("TANK", 32 * scale, 32 * scale), "Tanks"))
  text:SetPoint("TOP")
  TankData.groupFrame.text = text

  TankData.groupFrame:SetParent(MainFrame)
  TankData.groupFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 0, 0)

  TankData.groupFrame:Show()
end

function EyeOfAnzuAssist:CreateHealerCategoryFrame()

  HealerData.groupFrame = CreateFrame("frame")
  HealerData.groupFrame:SetSize(100 * scale, 45 * scale)

  local text = HealerData.groupFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  text:SetText(string.format("%s %s", EIA:GetRoleIconText("HEALER", 32 * scale, 32 * scale), "Healers"))
  text:SetPoint("TOP")
	HealerData.groupFrame.text = text

  HealerData.groupFrame:SetParent(MainFrame)
  HealerData.groupFrame:SetPoint("TOP", TankData.groupFrame, "BOTTOM", 0, -5 * scale)

  HealerData.groupFrame:Show()
end

function EyeOfAnzuAssist:CreateDpsCategoryFrame()
    DpsData.groupFrame = CreateFrame("frame")
  	DpsData.groupFrame:SetSize(150 * scale, 45 * scale)

  	local text = DpsData.groupFrame:CreateFontString(nil, "overlay", "GameFontNormal")
  	text:SetText(string.format("%s %s", EIA:GetRoleIconText("DAMAGER", 32 * scale, 32 * scale), "Dps"))
  	text:SetPoint("TOP")
  	DpsData.groupFrame.text = text

  	DpsData.groupFrame:SetParent(MainFrame)
  	DpsData.groupFrame:SetPoint("TOPLEFT", 	TankData.groupFrame, "TOPRIGHT", 5 * scale, 0)
  	--DpsGroupFrame:SetPoint("TOP", EpsiIskarFrame, "TOP")

  	DpsData.groupFrame:Show()
end

function EyeOfAnzuAssist:CreateEyeOfAnzuFrame()
  local show = true

  EyeOfAnzuFrame = CreateFrame("frame")
  EyeOfAnzuFrame:SetSize(200 * scale, 50 * scale)

  local texture = EyeOfAnzuFrame:CreateTexture(nil, "OVERLAY")
  texture:SetTexture(AURA_EYE_OF_ANZU_ICON)
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


function EyeOfAnzuAssist:GetOptions()
   EyeOfAnzuAssist.options = {
    type = "group",
    name = "Eye of Anzu Assist",
    order = 2,
    childGroups = "tab",
    disabled = function() return not EIA.db.profile.modulesEnabled[self:GetName()] end,
    args = {
      general = {
        type = "group",
        name = "General",
        order = 1,
        args = {
          enable = {
            type = "toggle",
            name = "Show on Iskar",
            desc = "Show automacaly when Iskar is targeted or you have him on mouseover.",
            descStyle = "inline",
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
            name = string.format("%s %s", EIA:GetIconText(AURA_EYE_OF_ANZU_ICON, 18, 18), AURA_EYE_OF_ANZU),
            inline = true,
            args ={
              show = {
                type = "toggle",
                name = "Show",
                desc = "Show the eye of Anzu frame which displays the holder.",
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

              },
              showRadianceOfAnzu = {
                type = "toggle",
                name = "Show radiance of Anzu",
                desc = "Display the radiance of Anzu stack of the holder.",
                order = 2,
                get = function() return self.db.profile.eyeOfAnzu.showRadianceOfAnzu end,
                set = function(_, value) self.db.profile.eyeOfAnzu.showRadianceOfAnzu = value end,

              }

            }
          },
          radianceOfAnzu = {
            type = "group",
            name = string.format("%s %s", EIA:GetIconText(AURA_RADIANCE_OF_ANZU_ICON, 18, 18), AURA_RADIANCE_OF_ANZU),
						inline = true,
            args = {
              show = {
								type = "toggle",
								name = "Show",
								desc = "Tell if the radiance of Anzu must be shown next to the player frames.",
								order = 1,
								get = function() return self.db.profile.radianceOfAnzu.show end,
								set = function(_, value) self.db.profile.radianceOfAnzu.show = value end,

							},
              showIcon = {
								type = "toggle",
								name = "Show icon",
								desc = "Show the radiance of Anzu icon. If not toggled, only the text is displayed.",
								order = 2,
								get = function() return self.db.profile.radianceOfAnzu.showIcon end,
								set = function(_, value) self.db.profile.radianceOfAnzu.showIcon = value end,
								disabled = function() return not self.db.profile.radianceOfAnzu.show end,

							},
              font = {
								type = "group",
								name = "Font Color Stacks",
								disabled = function() return not self.db.profile.radianceOfAnzu.show end,
                args = {
                  colors = {
                    type = "group",
                    name = "",
                    inline = true,
                    args = {
                      lowColor = {
                        type = "color",
                        name = "Low",
                        desc = "The color used when the radiance of Anzu stack is low.",
                        order = 1,
                        get = function()
                          local color = self.db.profile.radianceOfAnzu.stack.low.color
                          return color.r, color.g, color.b
                        end,
                        set = function(_, r, g, b, a)
                          local color = self.db.profile.radianceOfAnzu.stack.low.color
                          color.r, color.g, color.b = r, g, b
                        end,
                      },
                      mediumColor = {
                        type = "color",
                        name = "Medium",
                        desc = "The color used when the radiance Of Anzu stack is medium",
                        order = 2,
                        get = function()
                          local color = self.db.profile.radianceOfAnzu.stack.medium.color
                          return color.r, color.g, color.b
                        end,
                        set = function(_, r, g, b, a)
                          local color = self.db.profile.radianceOfAnzu.stack.medium.color
                          color.r, color.g, color.b = r, g, b
                        end,
                      },
                      HighColor = {
                        type = "color",
                        name = "High",
                        desc = "The color used when the radiance of Anzu stack is neither low nor medium.",
                        order = 3,
                        get = function()
                          local color = self.db.profile.radianceOfAnzu.stack.high.color
                          return color.r, color.g, color.b
                        end,
                        set = function(_, r, g, b, a)
                          local color = self.db.profile.radianceOfAnzu.stack.high.color
                          color.r, color.g, color.b = r, g, b
                        end,
                      },
                      thresholds = {
                        type = "group",
                        name = "",
                        inline = true,
                        args = {
                          lowThreshold = {
                            type = "range",
                            name = "Low Threshold",
                            desc = "The value below which a radiance of Anzu stack is considered low.",
                            min = 0,
                            max = 50,
                            step = 1,
                            get = function() return self.db.profile.radianceOfAnzu.stack.low.threshold end,
                            set = function(_, value) self.db.profile.radianceOfAnzu.stack.low.threshold = value end,

                          },
                          mediumThreshold = {
                            type = "range",
                            name = "Medium Threshold",
                            desc = "The value below which a radiance of Anzu stack is considered medium.",
                            min  = 0,
                            max = 50,
                            step = 1,
                            get = function() return self.db.profile.radianceOfAnzu.stack.medium.threshold end,
                            set = function(_, value) self.db.profile.radianceOfAnzu.stack.medium.threshold = value end,
                          }
                        }
                      }
                    }
                  },
                }
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
						name = string.format("The debuff priority is :\n %s > %s > %s (mythic) > %s > %s",
											AURA_FEL_BOMB, AURA_PHANTASMAL_WINDS, AURA_DARK_BINDINGS, AURA_PHANTASMAL_WOUNDS, AURA_PHANTASMAL_CORRUPTION),
						order = 0,

					},
					winds = {
						type = "group",
						name = string.format("%s %s", EIA:GetIconText(AURA_PHANTASMAL_WINDS_ICON, 18, 18), AURA_PHANTASMAL_WINDS),
						inline = true,
						order = 1,
						args = {
							show = {
								type = "toggle",
								name = "Show debuff",
								order = 1,
								get = function() return DebuffsDB.winds.show end,
								set = function(_, value) DebuffsDB.winds.show = value end,

							},
							color = {
								type = "color",
								name = "Debuff color",
								order = 2,
                get = function()
                    local color = DebuffsDB.winds.color
                    return color.r, color.g, color.b
                  end,
								set = function(_, r, g, b, a)
                  local color = DebuffsDB.winds.color
                  color.r, color.g, color.b = r, g, b
								end,

							},
						}
					},

					wounds = {
						type = "group",
						name = string.format("%s %s", EIA:GetIconText(AURA_PHANTASMAL_WOUNDS_ICON, 18, 18), AURA_PHANTASMAL_WOUNDS),
						inline = true,
						order = 2,
						args = {
							show = {
								type = "toggle",
								name = "Show debuff",
								order = 1,
								get = function() return DebuffsDB.wounds.show end,
								set = function(_, value) DebuffsDB.wounds.show = value end,

							},
							color = {
								type = "color",
								name = "Debuff color",
								order = 2,
                get = function()
                    local color = DebuffsDB.wounds.color
                    return color.r, color.g, color.b
                  end,
								set = function(_, r, g, b, a)
                  local color = DebuffsDB.wounds.color
                  color.r, color.g, color.b = r, g, b
								end,

							},

						}
					},
					felBomb = {
						type = "group",
						name = string.format("%s %s", EIA:GetIconText(AURA_FEL_BOMB_ICON, 18, 18), AURA_FEL_BOMB),
						inline = true,
						order = 3,
						args = {
							show = {
								type = "toggle",
								name = "Show debuff",
								order = 1,
								get = function() return DebuffsDB.felBomb.show end,
								set = function(_, value) DebuffsDB.felBomb.show = value end,

							},
							color = {
								type = "color",
								name = "Debuff color",
								order = 2,
								get = function()
                    local color = DebuffsDB.felBomb.color
                    return color.r, color.g, color.b
                  end,
								set = function(_, r, g, b, a)
                  local color = DebuffsDB.felBomb.color
                  color.r, color.g, color.b = r, g, b
								end,
							},
						}
					},
					corruption = {
						type = "group",
						name = string.format("%s%s", EIA:GetIconText(AURA_PHANTASMAL_CORRUPTION_ICON, 18, 18), AURA_PHANTASMAL_CORRUPTION),
						inline = true,
						order = 4,
						args = {
							show = {
								type = "toggle",
								name = "Show debuff",
								order = 1,
								get = function() return DebuffsDB.corruption.show end,
								set = function(_, value) DebuffsDB.corruption.show = value end,
							},
							color = {
								type = "color",
								name = "Debuff color",
								order = 2,
                get = function()
                    local color = DebuffsDB.corruption.color
                    return color.r, color.g, color.b
                  end,
								set = function(_, r, g, b, a)
                  local color = DebuffsDB.corruption.color
                  color.r, color.g, color.b = r, g, b
								end,
							},
						}
					},
					darkBindings = {
						type = "group",
						name = string.format("%s%s", EIA:GetIconText(AURA_DARK_BINDINGS_ICON, 18, 18), AURA_DARK_BINDINGS),
						inline = true,
						order = 5,
						args = {
							show = {
								type = "toggle",
								name = "Show debuff",
								order = 1,
								get = function() return DebuffsDB.darkBindings.show end,
								set = function(_, value) DebuffsDB.darkBindings.show = value end,
							},
							color = {
								type = "color",
								name = "Debuff color",
								order = 2,
                get = function()
                    local color = DebuffsDB.darkBindings.color
                    return color.r, color.g, color.b
                  end,
								set = function(_, r, g, b, a)
                  local color = DebuffsDB.darkBindings.color
                  color.r, color.g, color.b = r, g, b
								end,

							},
						}
					}
        }
      }
    }
  }

  return EyeOfAnzuAssist.options
end
