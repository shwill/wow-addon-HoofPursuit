local ADDON, ns = ...

local AURA = 1299038
local MAX = 30
local HIT = 4
local BASE = 7
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local CAL = { -119.5, -78, -42.5, 0, 42.5, 78.25, 120 }
local NEEDLE = 800 / 1254

local sin, rad, min, max, random = math.sin, math.rad, math.min, math.max, math.random

local defaults = { point = "CENTER", x = 0, y = -180, size = 200, locked = false, mode = "auto", sound = true }

local db
local stacks, speed, moving, blind, gray = 0, 0, false, false, 0
local ang, vel, t, idle, vis, on, drop, landed, ticked = CAL[1], 0, 0, 0, 0, false, nil, false, 0
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
dial:SetTexture(MEDIA .. "Dial60")
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

local SHARDS = {
  { 256, -10.5, 7.0 }, { 256, -82.0, 94.5 }, { 256, 40.5, 110.0 }, { 256, 104.5, 9.5 },
  { 256, 74.0, -85.5 }, { 256, -31.0, -122.5 }, { 256, -103.0, -10.5 }, { 256, 19.0, -202.5 },
  { 256, -125.0, -158.5 }, { 256, -184.0, -29.0 }, { 256, -184.5, 92.0 }, { 256, -111.5, 170.0 },
  { 256, 16.0, 199.5 }, { 256, 148.0, 147.5 }, { 256, 197.5, -3.5 }, { 256, 147.5, -137.0 },
}

local bits = CreateFrame("Frame", nil, f)
bits:SetAllPoints()
bits:SetFrameLevel(body:GetFrameLevel() + 5)
bits:Hide()

local parts = {}
for i, d in ipairs(SHARDS) do
  local tx = bits:CreateTexture(nil, "ARTWORK", nil, 1)
  tx:SetTexture(MEDIA .. "Shard" .. i)
  parts[i] = { tx = tx, d = d }
end
do
  local tx = bits:CreateTexture(nil, "ARTWORK", nil, 3)
  tx:SetTexture(MEDIA .. "Needle")
  parts[#parts + 1] = { tx = tx, needle = true }
end

local function layout()
  local s = db.size
  f:SetSize(s, s)
  body:SetSize(s, s)
  dial:SetSize(s, s)
  needle:SetSize(s * NEEDLE, s * NEEDLE)
  needle:SetPoint("CENTER", body, "CENTER", 0, 0)
  shadow:SetSize(s * NEEDLE, s * NEEDLE)
  shadow:SetPoint("CENTER", body, "CENTER", s * 0.012, -s * 0.02)
  glow:SetSize(s * 0.5, s * 0.5)
  glow:SetPoint("CENTER", body, "CENTER", s * 0.29, -s * 0.2)
  for _, p in ipairs(parts) do
    local n = p.needle and s * NEEDLE or s * p.d[1] / 512
    p.tx:SetSize(n, n)
  end
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
    local e = 15 - (test - t)
    if e < 2 then stacks = 1
    elseif e < 7 then stacks = math.floor(1 + (e - 2) * 5.8)
    elseif e < 8.5 then stacks = MAX
    else stacks = max(0, 24 - math.floor((e - 8.5) * 4)) end
    return
  end
  blind = InCombatLockdown()
  local a = C_UnitAuras.GetPlayerAuraBySpellID(AURA)
  if not a then
    if not blind then stacks = 0 end
  elseif not issecretvalue(a.applications) then
    stacks = max(a.applications or 1, 1)
  end
end

local function readSpeed()
  if t < test then
    moving = 15 - (test - t) < 8.5
    speed = moving and BASE * (1 + stacks * 0.02) or 0
    return
  end
  local cur = GetUnitSpeed("player")
  if issecretvalue(cur) then
    moving, speed = false, 0
  else
    speed = cur or 0
    moving = speed > 0.1
  end
end

local function noise(a, b, c)
  return sin(t * a) * 0.5 + sin(t * b + 1.3) * 0.3 + sin(t * c + 2.1) * 0.2
end

local function click()
  if db.sound and t - ticked > 0.03 then
    ticked = t
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON, "SFX")
  end
end

local function clock(dir)
  vel = vel + dir * 160
  jolt = 1
  click()
end

local DROP, BIG, BREAK = 0.15, 2.6, 1.4
local burst, pop

local function rev(e)
  if e < 0.85 then return 0 end
  if e < 1 then return (e - 0.85) / 0.15 end
  if e < 1.15 then return 1 end
  if e < 1.6 then local x = (e - 1.15) / 0.45 return 1 - x * x end
  return 0
end

local function shatter(a, ox, oy)
  local s = db.size
  local sc = s / 200
  for _, p in ipairs(parts) do
    if p.needle then
      p.x, p.y, p.r = ox, oy, -rad(a)
      p.vx, p.vy, p.spin = (random() - 0.5) * 160 * sc, (220 + random() * 120) * sc, (random() - 0.5) * 24
      p.wait = 0
    else
      local x, y = p.d[2] * s / 512, p.d[3] * s / 512
      local r = math.sqrt(x * x + y * y) + 1
      local push = (70 + random() * 110) * sc
      p.x, p.y, p.r = x + ox, y + oy, 0
      p.vx = x / r * push + (random() - 0.5) * 50 * sc
      p.vy = y / r * push * 0.6 + (90 + random() * 140) * sc
      p.spin = (random() - 0.5) * 9
      p.wait = random() * 0.05
    end
  end
  burst = t
  bits:Show()
  body:SetAlpha(0)
  jolt = 0
  if db.sound then PlaySoundFile(MEDIA .. "Shatter.mp3", "SFX") end
end

local function sweep()
  burst = nil
  bits:Hide()
  body:SetAlpha(1)
end

local function setOn(v)
  if v == on then return end
  on = v
  if v then
    drop, landed, shown, idle = t, false, 0, 0
    sweep()
    if db.sound then PlaySoundFile(MEDIA .. "Engine.mp3", "SFX") end
  else
    drop = nil
    shatter(ang, 0, 0)
    vis = 0
  end
  f:EnableMouse(v and not db.locked)
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

  if pop then
    local p = t - pop
    setOn(p < 2)
    if p > 2 + BREAK then pop = nil end
  elseif db.mode == "on" then
    setOn(true)
  else
    if stacks > 0 or moving or blind then idle = 0 else idle = idle + dt end
    if not on and stacks > 0 then setOn(true) elseif on and idle > 4 then setOn(false) end
  end
  local e = drop and t - drop
  local k, rattle, r, crank = 1, 0, 0, 0
  if e and e < DROP then
    k = BIG - (BIG - 1) * e / DROP
    vis = e / DROP
  elseif e then
    if not landed then
      landed = true
      jolt = 1.8
      vel = vel + 420
      click()
    end
    local x = e - DROP
    k = 1 - 0.07 * math.exp(-12 * x) * math.cos(32 * x)
    if x > 0.28 then
      local y = x - 0.28
      k = k + 0.018 * math.exp(-7 * y) * sin(17 * y)
    end
    rattle = math.exp(-9 * x)
    vis = 1
    r = rev(e)
    if e > 0.2 and e < 0.8 then crank = math.abs(sin(e * 44)) end
    if e > 1.7 then drop = nil end
  elseif on then
    vis = min(1, vis + dt * 3.5)
  end
  body:SetScale(k)
  local want = blind and 0.75 or 0
  if gray ~= want then
    gray = want > gray and min(want, gray + dt * 3) or max(want, gray - dt * 1.5)
    dial:SetDesaturation(gray)
    needle:SetDesaturation(gray)
  end
  if burst then
    local b = t - burst
    if b > BREAK then
      sweep()
    else
      local g = 1500 * db.size / 200
      local fade = min(1, max(0, (BREAK - b) / 0.5))
      for _, p in ipairs(parts) do
        if b >= p.wait then
          p.vy = p.vy - g * dt
          p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
          p.r = p.r + p.spin * dt
        end
        p.tx:SetPoint("CENTER", f, "CENTER", p.x, p.y)
        p.tx:SetRotation(p.r)
        p.tx:SetAlpha(fade)
      end
    end
  end
  f:SetAlpha(burst and 1 or vis)

  if (not e or landed) and shown ~= stacks and t >= nextStep then
    local dir = stacks > shown and 1 or -1
    shown = shown + dir
    nextStep = t + (dir > 0 and 0.05 or 0.08)
    clock(dir)
  end

  local goal = max(target(shown), target(r * 20)) + crank * 3
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
  amp = amp + db.size * (0.03 * rattle + 0.005 * crank + 0.016 * r)
  local dx = noise(23, 31, 47) * amp + (random() - 0.5) * amp * 0.6 + (random() - 0.5) * j
  local dy = noise(19, 29, 43) * amp + bump * amp * 0.8 + j
  local sway = sin(t * 2.7) * 1.2 * heat + noise(13, 17, 21) * 0.6 * heat
  sway = sway + (random() - 0.5) * (4 * rattle + 2.5 * r)
  body:ClearAllPoints()
  body:SetPoint("CENTER", f, "CENTER", dx, dy)
  dial:SetRotation(rad(sway))

  if stacks >= MAX and moving then
    glow:SetAlpha(0.35 + 0.25 * sin(t * 8))
  else
    glow:SetAlpha(max(0, glow:GetAlpha() - dt * 2))
  end
end)

f:SetScript("OnEvent", function(_, _, unit, kind)
  if unit ~= "player" or not blind or issecretvalue(kind) or kind ~= "WOUND" then return end
  stacks = max(0, stacks - HIT)
  jolt = 1.4
  if stacks == 0 and on and db.mode == "auto" then setOn(false) end
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
  f:EnableMouse(on and not db.locked)
  f:SetShown(db.mode ~= "off")
  if db.mode == "off" then setOn(false) vis = 0 end
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
  elseif cmd == "pop" then
    sweep()
    on, vis, pop = false, 0, t
  elseif cmd == "test" then
    test = t + 15
    sweep()
    on, vis = false, 0
    say("Probelauf: reinknallen, hochlaufen, Treffer, stehenbleiben, ausblenden")
  else
    say(format("Stacks %d/%d, Tempo %.1f, Modus %s", stacks, MAX, speed, db.mode))
    say("/tacho lock | size <px> | auto | on | off | sound | reset | test | pop")
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
    f:RegisterUnitEvent("UNIT_COMBAT", "player")
    layout()
    apply()
  end
end)

ns.frame = f
