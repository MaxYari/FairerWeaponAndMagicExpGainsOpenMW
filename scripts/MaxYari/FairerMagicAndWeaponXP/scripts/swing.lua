-- How long a weapon's weakest swing takes: the length the engine plays it for, wind-up to the end of the
-- follow-through, at the weapon's speed stat - fists at 1.
--
-- The lengths at speed 1 were measured once from ReAnimation's animations, the average of each group's
-- chop, slash and thrust (Sources/DEVELOPMENT.md has how, and every key). Its third person set is the
-- same. Nothing is read from the animations in game.
local I = require('openmw.interfaces')
local types = require('openmw.types')

local M = {}

local WT = types.Weapon.TYPE

-- Seconds at speed 1 of the weakest swing, as the engine plays it (the AttackRelease branch of
-- CharacterController::updateWeaponState): the wind-up to "min attack", the release from "min hit" -
-- the animation jumps there for the weakest attack - to "hit", and the small follow-through.
M.WEAK_SWING = {
    weapononehand = 0.777,
    weapontwohand = 0.645,
    weapontwowide = 0.600,
    handtohand = 0.400,
    bowandarrow = 1.400,
    crossbow = 1.532,
    throwweapon = 0.665,
}

-- The group each weapon type attacks with. ReAnimation has no short blade, one-handed blunt or
-- two-handed blunt groups, so those fall back as the engine falls back (getWeaponAnimation): two-handed
-- melee to the two-handed swords', the rest to the one-handed.
local GROUP = {
    [WT.ShortBladeOneHand] = "weapononehand",
    [WT.LongBladeOneHand] = "weapononehand",
    [WT.BluntOneHand] = "weapononehand",
    [WT.AxeOneHand] = "weapononehand",
    [WT.LongBladeTwoHand] = "weapontwohand",
    [WT.AxeTwoHand] = "weapontwohand",
    [WT.BluntTwoClose] = "weapontwohand",
    [WT.BluntTwoWide] = "weapontwowide",
    [WT.SpearTwoWide] = "weapontwowide",
    [WT.MarksmanBow] = "bowandarrow",
    [WT.MarksmanCrossbow] = "crossbow",
    [WT.MarksmanThrown] = "throwweapon",
}

local RANGED = { [WT.MarksmanBow] = true, [WT.MarksmanCrossbow] = true, [WT.MarksmanThrown] = true }

-- The skill each weapon type trains.
M.SKILL = {
    [WT.ShortBladeOneHand] = "shortblade",
    [WT.LongBladeOneHand] = "longblade", [WT.LongBladeTwoHand] = "longblade",
    [WT.BluntOneHand] = "bluntweapon", [WT.BluntTwoClose] = "bluntweapon", [WT.BluntTwoWide] = "bluntweapon",
    [WT.AxeOneHand] = "axe", [WT.AxeTwoHand] = "axe",
    [WT.SpearTwoWide] = "spear",
    [WT.MarksmanBow] = "marksman", [WT.MarksmanCrossbow] = "marksman", [WT.MarksmanThrown] = "marksman",
}

-- Katars and Knuckledusters' weapons swing with the hand-to-hand animations, whatever the engine
-- thinks they are: ReAnimation stretches the one-handed attack underneath to fit them.
-- A record id is never one: only a weapon that has left the hand comes as one.
local function isKatarsWeapon(weapon)
    local h2h = I.H2HWeapons
    return weapon ~= nil and type(weapon) ~= "string" and h2h ~= nil and h2h.kindOfItem ~= nil
        and h2h.kindOfItem(weapon) and true or false
end
M.isKatarsWeapon = isKatarsWeapon

--- A weapon's swing, or bare fists' for nil: { group, speed, skill, ranged, weak }, weak being the
--- seconds of its weakest swing at its speed. Nil for something that is no weapon. `weapon` is the
--- item, or its record id for one that has left the hand (actor.lua).
function M.profile(weapon)
    if not weapon then
        return { group = "handtohand", speed = 1, skill = "handtohand", ranged = false, weak = M.WEAK_SWING.handtohand }
    end
    local record = nil
    if type(weapon) == "string" then
        local ok, found = pcall(types.Weapon.record, weapon)
        record = ok and found or nil
    elseif weapon.type == types.Weapon then
        record = types.Weapon.record(weapon)
    end
    if not record then return nil end
    local speed = record.speed
    if not speed or speed <= 0 then return nil end
    local group = isKatarsWeapon(weapon) and "handtohand" or GROUP[record.type]
    if not group then return nil end
    return { group = group, speed = speed, skill = M.SKILL[record.type], ranged = RANGED[record.type] or false,
        weak = M.WEAK_SWING[group] / speed }
end

return M
