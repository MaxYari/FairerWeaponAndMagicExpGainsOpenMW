-- Minimal fakes for the openmw API, enough to load the mod's scripts and drive them: casts through
-- their text keys, hits through skill uses and their reports, spells landing through the active spell
-- list and a health decrease.
--
-- I.SkillProgression is a copy of the engine's (files/data/scripts/omw/skillhandlers.lua): the
-- options are copied once and the same table goes to every handler, newest first, and the engine's
-- own handler - the one that applies the gain, and here records it as well - is registered first,
-- so it runs last. It asks for the level up as the engine's does (playerskillhandlers.lua), through
-- the level up handlers.
local M = {}

local here = arg[0]:gsub("[^/]*$", "")
local root = os.getenv("FAIRER_WEAPON_AND_MAGIC_XP_MOD") or (here .. "../../..")

-- OpenMW resolves require("scripts/Foo/bar") against the VFS; plain Lua wants dots.
table.insert(package.searchers or package.loaders, 1, function(name)
    if name:sub(1, 6) == "openmw" then return nil end
    local rel = name:gsub("%.", "/") .. ".lua"
    local f = io.open(root .. "/" .. rel, "r")
    if not f then return nil end
    local src = f:read("a"); f:close()
    return assert(load(src, "@" .. rel))
end)

local function lowerKeys(t)
    return setmetatable({}, { __index = function(_, k) return t[string.lower(k)] end })
end

local Player = { name = "Player" }
M.player = { id = "player", type = Player }
M.enemy = { id = "enemy" }
local S = {}
function M.player:sendEvent(name, data) S.sent[#S.sent + 1] = { name = name, data = data } end

local function skillStat(id)
    S.skills[id] = S.skills[id] or { base = 50, modified = 50, progress = 0 }
    return S.skills[id]
end

--- The world the tests poke at --------------------------------------------------------------------
-- One table, emptied and refilled in place, so a test can keep hold of stubs.state across loads.
M.state = S
function M.reset()
    for k in pairs(S) do S[k] = nil end
    local fresh = {
        time = 0,
        magicka = 1000,
        selectedSpell = nil,
        right = nil,             -- what is in each hand: a M.item
        left = nil,
        effects = {},            -- [lowercase effect id] = magnitude
        activeSpells = {},       -- { activeSpellId, caster, temporary, effects = { { id } } }
        skills = {},             -- [skill id] = { base, modified, progress }
        taught = {},             -- what the engine's own handler was handed: { skill, gain, params }
        textKeyHandlers = {},
        skillUsedHandlers = {},
        skillLevelUpHandlers = {},
        sections = {},           -- [storage section] = { key = value }, player and global alike
        contentFiles = { ["MaxYariScriptServices.omwscripts"] = 1, ["FairerWeaponAndMagicXP.omwscripts"] = 2 },
        messages = {},
        soundsPlaying = {},      -- [sound id] = true, on the player
        textKeys = {},           -- ["group: key"] = time; none, and the measured numbers are used
        groups = {},             -- [group] = true for an animation group that exists
        damageListeners = {},
        sent = {},               -- events sent to the player: { name, data }
        view = 0,                -- camera mode: 0 first person
        gmst = { fEffectCostMult = 0.5 },
    }
    for k, v in pairs(fresh) do S[k] = v end
    S.settings = { logging = false } -- quiet; test_xp.lua turns it on where it checks it
    S.sections.SettingsPlayerFairerWeaponAndMagicXP = S.settings
    S.weaponSettings = {}
    S.sections.SettingsPlayerFairerWeaponAndMagicXPWeapons = S.weaponSettings
    -- The engine's own handlers (playerskillhandlers.lua): first in, last to run.
    table.insert(S.skillUsedHandlers, function(skillid, params)
        S.taught[#S.taught + 1] = { skill = skillid, gain = params.skillGain, params = params }
        local stat = skillStat(skillid)
        stat.progress = stat.progress + params.skillGain / M.interfaces.SkillProgression.getSkillProgressRequirement(skillid)
        if stat.progress >= 1 then M.interfaces.SkillProgression.skillLevelUp(skillid, "usage") end
    end)
    table.insert(S.skillLevelUpHandlers, function(skillid)
        local stat = skillStat(skillid)
        stat.base, stat.modified, stat.progress = stat.base + 1, stat.modified + 1, 0
    end)
    -- The engine's I.Combat (combat/local.lua); combat.lua wraps it. A test sets S.pick for the piece.
    M.interfaces.Combat = {
        ATTACK_TYPES = { Chop = 0, Slash = 1, Thrust = 2 },
        ATTACK_SOURCE_TYPES = { Magic = "magic", Melee = "melee", Ranged = "ranged", Unspecified = "unspecified" },
        pickRandomArmor = function() return S.pick end,
        getArmorSkill = function(item) return item and "heavyarmor" or "unarmored" end,
        addOnHitHandler = function(h) S.onHitHandler = h end,
    }
    M.interfaces.MSS = {
        getActiveEffect = function(id)
            local m = S.effects[string.lower(id)]
            return m and m > 0 and m or nil
        end,
        getEquipment = function(slot) if slot == 16 then return S.right elseif slot == 17 then return S.left end end,
        addDamageListener = function(fn) S.damageListeners[#S.damageListeners + 1] = fn end,
    }
    M.interfaces.FairerWeaponAndMagicXP = nil
    M.interfaces.H2HWeapons = nil
end

-- Magic effects, as vanilla has them (MGEF). Ids keep the engine's case, to check nothing depends on it.
M.EFFECT = {
    FireDamage = { school = "destruction", baseCost = 5, harmful = true },
    FrostDamage = { school = "destruction", baseCost = 5, harmful = true },
    ShockDamage = { school = "destruction", baseCost = 7, harmful = true },
    Shield = { school = "alteration", baseCost = 2 },
    FireShield = { school = "alteration", baseCost = 3 },
    FrostShield = { school = "alteration", baseCost = 3 },
    LightningShield = { school = "alteration", baseCost = 3 },
    BoundLongsword = { school = "conjuration", baseCost = 2, noMagnitude = true },
    BoundCuirass = { school = "conjuration", baseCost = 2, noMagnitude = true },
    RestoreHealth = { school = "restoration", baseCost = 1 },
}
local effectRecords, effectTypes = {}, {}
for name, e in pairs(M.EFFECT) do
    effectTypes[name] = name
    effectRecords[string.lower(name)] = {
        id = name, name = name, school = e.school, baseCost = e.baseCost, harmful = e.harmful or false,
        hasMagnitude = not e.noMagnitude, hasDuration = true, isAppliedOnce = false,
    }
end

M.RANGE = { Self = 0, Touch = 1, Target = 2 }

--- A spell record. effects: { { id, range, area, duration, min, max } }
function M.spell(t)
    local effects = {}
    for i, e in ipairs(t.effects or {}) do
        effects[i] = {
            id = e.id, effect = effectRecords[string.lower(e.id)], range = e.range or 0,
            area = e.area or 0, duration = e.duration or 1,
            magnitudeMin = e.min or 1, magnitudeMax = e.max or e.min or 1,
        }
    end
    return {
        id = t.id or "spell", name = t.id or "spell", type = t.type or 0, cost = t.cost or 0,
        isAutocalc = t.autocalc or false, alwaysSucceedFlag = t.always or false, effects = effects,
    }
end

--- openmw.* --------------------------------------------------------------------------------------
local core = {
    getGMST = function(name) return S.gmst[name] end,
    getSimulationTime = function() return S.time end,
    l10n = function(_) return function(key) return key end end,
    contentFiles = {
        has = function(name) return S.contentFiles[name] ~= nil end,
        indexOf = function(name) return S.contentFiles[name] end,
    },
    sound = {
        isSoundPlaying = function(id, object) return object == M.player and S.soundsPlaying[id] == true end,
    },
    magic = {
        RANGE = M.RANGE,
        SPELL_TYPE = { Spell = 0, Ability = 1, Power = 5 },
        EFFECT_TYPE = effectTypes,
        effects = { records = lowerKeys(effectRecords) },
    },
    stats = {
        Skill = {
            record = function(id)
                return { id = id, name = id, skillGain = { 1, 1, 1, 1 },
                    school = { failureSound = "spell failure " .. id } }
            end,
        },
    },
}

local SKILL_USE_TYPES = {
    Armor_HitByOpponent = 0, Block_Success = 0, Spellcast_Success = 0, Weapon_SuccessfulHit = 0,
}

local function skillUsed(skillid, options)
    local params = {}
    for k, v in pairs(options) do params[k] = v end
    if not params.skillGain then
        params.skillGain = core.stats.Skill.record(skillid).skillGain[params.useType + 1] * (params.scale or 1)
    end
    for i = #S.skillUsedHandlers, 1, -1 do
        if S.skillUsedHandlers[i](skillid, params) == false then return end
    end
end

local function skillLevelUp(skillid, source)
    for i = #S.skillLevelUpHandlers, 1, -1 do
        if S.skillLevelUpHandlers[i](skillid, source, {}) == false then return end
    end
end

local interfaces = {
    SkillProgression = {
        SKILL_USE_TYPES = SKILL_USE_TYPES,
        SKILL_INCREASE_SOURCES = { Book = "book", Usage = "usage", Trainer = "trainer", Jail = "jail" },
        addSkillUsedHandler = function(h) table.insert(S.skillUsedHandlers, h) end,
        addSkillLevelUpHandler = function(h) table.insert(S.skillLevelUpHandlers, h) end,
        skillUsed = skillUsed,
        skillLevelUp = skillLevelUp,
        -- The engine's: (skill + 1), for a misc skill of no specialization it would be x1.25; 1 here.
        getSkillProgressRequirement = function(id) return skillStat(id).base + 1 end,
    },
    AnimationController = {
        addTextKeyHandler = function(group, fn)
            S.textKeyHandlers[group] = S.textKeyHandlers[group] or {}
            table.insert(S.textKeyHandlers[group], fn)
        end,
    },
    Settings = { registerPage = function() end, registerGroup = function() end },
}
M.interfaces = interfaces

-- types.Weapon.TYPE, as the engine numbers them.
local WT = {
    ShortBladeOneHand = 0, LongBladeOneHand = 1, LongBladeTwoHand = 2, BluntOneHand = 3,
    BluntTwoClose = 4, BluntTwoWide = 5, SpearTwoWide = 6, AxeOneHand = 7, AxeTwoHand = 8,
    MarksmanBow = 9, MarksmanCrossbow = 10, MarksmanThrown = 11, Arrow = 12, Bolt = 13,
}
M.WT = WT
local Weapon, Armor = { name = "Weapon", TYPE = WT }, { name = "Armor" }
Weapon.record = function(o) return { id = o.recordId, name = o.name or o.recordId, value = o.value,
    type = o.weaponType, speed = o.speed } end
Armor.record = Weapon.record

--- An item: kind "weapon" or "armor"; for a weapon, t = { type, speed, name }.
function M.item(kind, recordId, value, t)
    t = t or {}
    return { type = kind == "armor" and Armor or Weapon, recordId = recordId, value = value or 0,
        weaponType = t.type or WT.LongBladeOneHand, speed = t.speed or 1, name = t.name }
end

local Actor = {
    EQUIPMENT_SLOT = { CarriedRight = 16, CarriedLeft = 17 },
    getSelectedSpell = function() return S.selectedSpell end,
    activeSpells = function() return S.activeSpells end,
    stats = {
        dynamic = {
            -- A live view, as the engine's: made once, it reads the current value every time.
            magicka = function() return setmetatable({}, { __index = function(_, k)
                if k == "current" then return S.magicka end
            end }) end,
        },
    },
}
local types = {
    Actor = Actor,
    Player = Player,
    Weapon = Weapon,
    Armor = Armor,
    NPC = {
        stats = {
            skills = setmetatable({}, { __index = function(_, id)
                return function() return skillStat(id) end
            end }),
        },
    },
}

local function section(name)
    S.sections[name] = S.sections[name] or {}
    local values = S.sections[name]
    return {
        asTable = function() return values end,
        get = function(_, key) return values[key] end,
        set = function(_, key, value) values[key] = value end,
        subscribe = function() end,
    }
end

-- Nothing may read the animations: the swing lengths are stored.
local animation = setmetatable({}, { __index = function(_, k) error("openmw.animation." .. k .. " was used") end })

package.preload["openmw.core"] = function() return core end
package.preload["openmw.interfaces"] = function() return interfaces end
package.preload["openmw.self"] = function() return { object = M.player } end
package.preload["openmw.types"] = function() return types end
package.preload["openmw.storage"] = function() return { playerSection = section, globalSection = section } end
package.preload["openmw.animation"] = function() return animation end
package.preload["openmw.camera"] = function()
    return { MODE = { FirstPerson = 0, ThirdPerson = 1 }, getMode = function() return S.view or 0 end }
end
package.preload["openmw.ui"] = function()
    return { showMessage = function(text) S.messages[#S.messages + 1] = text end }
end
package.preload["openmw.async"] = function() return { callback = function(_, fn) return fn end } end
package.preload["openmw_aux.util"] = function()
    return { shallowCopy = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end }
end

M.reset()

--- Driving it -------------------------------------------------------------------------------------
--- A fresh world, then the mod's player scripts loaded into it as the engine would: each one's
--- interface put in I, then onActive. `before` runs in between, to register handlers that should be
--- older than this mod's (and so run after it), or to store settings.
function M.load(before)
    M.reset()
    if before then before() end
    -- The scripts require each other by VFS path, slashes and all: that is the name they are cached
    -- under, and every one of them goes, so settings are read again.
    for name in pairs(package.loaded) do
        if name:find("FairerWeaponAndMagicXP", 1, true) then package.loaded[name] = nil end
    end
    M.script = require("scripts/MaxYari/FairerWeaponAndMagicXP/player")
    if M.script.interfaceName then
        interfaces.FairerWeaponAndMagicXP = M.script.interface
        local combat = require("scripts/MaxYari/FairerWeaponAndMagicXP/combat")
        interfaces[combat.interfaceName] = combat.interface
        M.script.engineHandlers.onActive()
    end
    return M.script
end

--- actor.lua, loaded on an NPC: returns the hit handler it gave I.Combat.
function M.loadActor()
    package.loaded["scripts/MaxYari/FairerWeaponAndMagicXP/actor"] = nil
    S.onHitHandler = nil
    require("scripts/MaxYari/FairerWeaponAndMagicXP/actor")
    return S.onHitHandler
end

function M.formulas() return require("scripts/MaxYari/FairerWeaponAndMagicXP/scripts/formulas") end
function M.swing() return require("scripts/MaxYari/FairerWeaponAndMagicXP/scripts/swing") end

function M.textKey(group, key)
    for _, fn in ipairs(S.textKeyHandlers[group] or {}) do fn(group, key) end
end

--- The engine reporting a skill use (_onSkillUse).
function M.skillUse(skillid, useType, scale)
    skillUsed(skillid, { useType = useType, scale = scale or 1 })
end

M.skillUsed = skillUsed

--- The next frame: time moves on, and the player's onUpdate runs after the frame's events.
function M.update(dt)
    S.time = S.time + (dt or 0.016)
    M.script.engineHandlers.onUpdate(dt or 0.016)
end

--- The cast the engine makes from the spellcast animation: the magicka taken if there is enough,
--- the start key, the release, and a success if `succeeds` - or, having paid, the school's failure
--- sound. Then the frame's onUpdate.
function M.cast(spell, succeeds, range)
    range = range or "target"
    S.selectedSpell = spell
    local cost = M.formulas().spellCost(spell)
    local paid = S.magicka >= cost
    if paid then S.magicka = S.magicka - cost end
    M.textKey("spellcast", range .. " start")
    M.textKey("spellcast", range .. " release")
    local school = spell.effects[1].effect.school
    if succeeds and paid then
        M.skillUse(school, 0)
    elseif paid then
        S.soundsPlaying["spell failure " .. school] = true
    end
    M.update()
    S.soundsPlaying = {}
end

--- A hit taken, as I.Combat.applyArmor makes it: the piece struck picked, then its skill credited.
function M.armorHit(skill)
    interfaces.Combat.pickRandomArmor()
    M.skillUse(skill, 0)
end

--- One of the player's attacks reported by the one it reached (actor.lua), the frame after.
function M.report(t)
    M.update()
    M.script.eventHandlers.FairerWeaponAndMagicXP_Attack({
        successful = t.successful ~= false, strength = t.strength or 0, type = t.type, weapon = t.weapon,
    })
end

--- The player's health dropping, as MSS reports it.
function M.damaged()
    for _, fn in ipairs(S.damageListeners) do fn({ actor = M.player }) end
end

--- What the engine's handler was handed for a skill, summed, since `from` (an index into taught).
function M.taughtTo(skill, from)
    local total = 0
    for i = (from or 1), #S.taught do
        if S.taught[i].skill == skill then total = total + S.taught[i].gain end
    end
    return total
end

return M
