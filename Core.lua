local ADDON, ns = ...

local AURA = 1299038
local MAX = 30
local BASE = 7
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local CAL = { -119.5, -78, -42.5, 0, 42.5, 78.25, 120 }
local NEEDLE = 800 / 1254

local sin, rad, min, max, random = math.sin, math.rad, math.min, math.max, math.random

local defaults = { point = "CENTER", x = 0, y = -180, size = 200, locked = false, mode = "auto", sound = true }

local db
local stacks, speed, moving = 0, 0, false
local ang, vel, t, idle, fade = CAL[1], 0, 0, 0, 1
local shown, nextStep, jolt, test = 0, 0, 0, 0

local f = CreateFrame("Frame", "PlainsTachoFrame", UIParent)
f:SetFrameStrata("MEDIUM")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:Hide()

local body = CreateFrame("Frame", nil, f)
body:SetPoint("CENTER")

local dial = body:CreateTexture(nil, "BACKGROUND")
dial:SetTexture(MEDIA .. "Dial")
dial:SetPoint("CENTER")

local glow = body:CreateTexture(nil, "BORDER")
glow:SetTexture("Interface\\Cooldown\\star4")
glow:SetBlendMode("ADD")
glow:SetVertexColor(1, 0.6, 0.1)
glow:SetAlpha(0)

local shadow = body:CreateTexture(nil, "ARTWORK", nil, 1)
shadow:SetTexture(MEDIA .. "Shadow")
shadow:SetAlpha(0.55)

local needle = body:CreateTexture(nil, "ARTWORK", nil, 2)
needle:SetTexture(MEDIA .. "Needle")

local function layout()
  local s = db.size
  f:SetSize(s, s)
  body:SetSize(s, s)
  dial:SetSize(s, s)
  local n = s * NEEDLE
  needle:SetSize(n, n)
  needle:SetPoint("CENTER", body, "CENTER", 0, 0)
  shadow:SetSize(n, n)
  shadow:SetPoint("CENTER", body, "CENTER", s * 0.012, -s * 0.02)
  glow:SetSize(s * 0.5, s * 0.5)
  glow:SetPoint("CENTER", body, "CENTER", s * 0.29, -s * 0.2)
  f:ClearAllPoints()
  f:SetPoint(db.point, UIParent, db.point, db.x, db.y)
end

local function target(n)
  n = max(0, min(MAX, n))
  local i = math.floor(n / 5)
  if i >= 6 then return CAL[7] end
  return CAL[i + 1] + (CAL[i + 2] - CAL[i + 1]) * (n - i * 5) / 5
end

local function readAura()
  if t < test then
    local e = 11 - (test - t)
    if e < 5 then stacks = math.floor(e * 6)
    elseif e < 6.5 then stacks = MAX
    else stacks = max(0, 24 - math.floor((e - 6.5) * 2)) end
    return
  end
  local a = C_UnitAuras.GetPlayerAuraBySpellID(AURA)
  if not a then
    stacks = 0
  elseif not issecretvalue(a.applications) then
    stacks = max(a.applications or 1, 1)
  end
end

local function readSpeed()
  if t < test then
    moving = 11 - (test - t) < 6.5
    speed = moving and BASE * (1 + stacks * 0.02) or 0
    return
  end
  local cur = GetUnitSpeed("player")
  if issecretvalue(cur) then
    moving = stacks > 0
    speed = moving and BASE * (1 + stacks * 0.02) or 0
  else
    speed = cur or 0
    moving = speed > 0.1
  end
end

local function noise(a, b, c)
  return sin(t * a) * 0.5 + sin(t * b + 1.3) * 0.3 + sin(t * c + 2.1) * 0.2
end

local function clock(dir)
  vel = vel + dir * 160
  jolt = 1
  if db.sound then PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON, "SFX") end
end

local acc = 0
f:SetScript("OnUpdate", function(_, dt)
  dt = min(dt, 0.1)
  t = t + dt
  acc = acc + dt
  if acc > 0.1 then
    acc = 0
    readAura()
    readSpeed()
  end

  local fill = stacks / MAX
  local rush = moving and min(speed / (BASE * 1.6), 1.4) or 0
  local heat = moving and (0.15 + 0.85 * fill) or 0

  if shown ~= stacks and t >= nextStep then
    local dir = stacks > shown and 1 or -1
    shown = shown + dir
    nextStep = t + (dir > 0 and 0.05 or 0.08)
    clock(dir)
  end

  local goal = target(shown)
  vel = vel + ((goal - ang) * 380 - vel * 15) * dt
  ang = ang + vel * dt
  jolt = max(0, jolt - dt * 7)

  local jit = 0.25 + heat * 2.2 + (stacks >= MAX and moving and 1.5 or 0)
  local shiver = noise(37, 53, 71) * jit + (random() - 0.5) * jit * 0.8
  local a = ang + shiver
  needle:SetRotation(-rad(a))
  shadow:SetRotation(-rad(a))

  local amp = db.size * 0.012 * heat * heat * (0.6 + rush * 0.4)
  local bump = (sin(t * 9.5) > 0.85 and 1 or 0) * heat
  local j = jolt * jolt * db.size * 0.012
  local dx = noise(23, 31, 47) * amp + (random() - 0.5) * amp * 0.6 + (random() - 0.5) * j
  local dy = noise(19, 29, 43) * amp + bump * amp * 0.8 + j
  local sway = sin(t * 2.7) * 1.2 * heat + noise(13, 17, 21) * 0.6 * heat
  body:ClearAllPoints()
  body:SetPoint("CENTER", f, "CENTER", dx, dy)
  dial:SetRotation(rad(sway))

  if stacks >= MAX and moving then
    glow:SetAlpha(0.35 + 0.25 * sin(t * 8))
  else
    glow:SetAlpha(max(0, glow:GetAlpha() - dt * 2))
  end

  if db.mode == "auto" then
    if stacks > 0 or moving then idle = 0 else idle = idle + dt end
    local want = idle > 4 and 0 or 1
    fade = fade + (want - fade) * min(dt * 3, 1)
    f:SetAlpha(fade)
  else
    f:SetAlpha(1)
  end
end)

f:SetScript("OnDragStart", function(s)
  if not db.locked then s:StartMoving() end
end)
f:SetScript("OnDragStop", function(s)
  s:StopMovingOrSizing()
  local p, _, _, x, y = s:GetPoint()
  db.point, db.x, db.y = p, x, y
end)

local function apply()
  f:EnableMouse(not db.locked)
  f:SetShown(db.mode ~= "off")
end

local function say(msg)
  print("|cffd9a441PlainsTacho|r " .. msg)
end

local function slash(msg)
  local cmd, arg = strsplit(" ", strtrim(msg or ""):lower(), 2)
  if cmd == "lock" then
    db.locked = not db.locked
    apply()
    say(db.locked and "gesperrt" or "entsperrt, mit Linksklick ziehen")
  elseif cmd == "size" and tonumber(arg) then
    db.size = max(80, min(600, tonumber(arg)))
    layout()
    say("Größe " .. db.size)
  elseif cmd == "auto" or cmd == "on" or cmd == "off" then
    db.mode = cmd
    apply()
    say("Modus " .. cmd)
  elseif cmd == "reset" then
    for k, v in pairs(defaults) do db[k] = v end
    layout()
    apply()
    say("zurückgesetzt")
  elseif cmd == "sound" then
    db.sound = not db.sound
    say("Klick-Sound " .. (db.sound and "an" or "aus"))
  elseif cmd == "test" then
    test = t + 11
    idle = 0
    say("Probelauf: hochlaufen, Treffer, stehenbleiben")
  else
    say(format("Stacks %d/%d, Tempo %.1f, Modus %s", stacks, MAX, speed, db.mode))
    say("/tacho lock | size <px> | auto | on | off | sound | reset | test")
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, e, arg)
  if e == "ADDON_LOADED" and arg == ADDON then
    PlainsTachoDB = PlainsTachoDB or {}
    db = PlainsTachoDB
    for k, v in pairs(defaults) do
      if db[k] == nil then db[k] = v end
    end
  elseif e == "PLAYER_LOGIN" then
    ev:UnregisterAllEvents()
    if select(2, UnitRace("player")) ~= "Tauren" then
      C_AddOns.DisableAddOn(ADDON, UnitName("player"))
      return
    end
    SLASH_PLAINSTACHO1 = "/tacho"
    SlashCmdList.PLAINSTACHO = slash
    layout()
    apply()
  end
end)

ns.frame = f
