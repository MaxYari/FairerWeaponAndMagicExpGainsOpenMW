-- Settings, read once and kept in plain Lua variables: the handlers read them on every hit and every
-- cast, and storage:get() is an engine call that builds a value each time. The section is read at
-- load and again only when something changes.
local async = require('openmw.async')
local storage = require('openmw.storage')

local M = {}

-- Two groups on the settings page, magic and weapons, each its own storage section.
M.GROUP = "SettingsPlayerFairerWeaponAndMagicXP"
M.WEAPONS_GROUP = "SettingsPlayerFairerWeaponAndMagicXPWeapons"

-- Defaults, also the registered defaults in player.lua.
M.DEFAULTS = {
    -- A spell costing this much or less teaches as it does in vanilla: Fireball (5), Fire Bite (6),
    -- Greater Fireball (10), Shield (15).
    baseCost = 15,
    -- The cost at which a cast teaches maxMultiplier times as much, and past which it teaches no more.
    -- With 15 and 5x, the multiplier is the cost / 15 in between: experience in step with magicka.
    topCost = 75,
    maxMultiplier = 5,
    -- Of what the cast would have taught had it worked.
    miscastShare = 0.33,
    -- Of what conjured gear teaches its own skill - a bound weapon's hit, a hit on bound armor, a
    -- block with a bound shield - taught to Conjuration as well.
    boundShare = 0.33,
    -- Of what a hit teaches your armor skill, taught to the shield spell's own school as well.
    shieldShare = 0.33,
    -- Weapons. A hit teaches in step with how long the weapon's weakest swing takes, wind-up to the end
    -- of the follow-through: this many seconds of it teach what one vanilla hit does. Ranged attacks
    -- count their draw and reload, so theirs is a longer measure.
    meleeSwing = 0.5,
    rangedSwing = 0.75,
    -- A full-strength attack teaches this much more than the weakest, and one in between, in between.
    strongAttackBonus = 0.33,
    -- A swing that reached its target and missed teaches this share of what it would have had it hit.
    missShare = 0.2,
    -- A line in the console (F10) and openmw.log for every gain this mod gives or changes.
    logging = true,
}

M.values = {}
for key, value in pairs(M.DEFAULTS) do M.values[key] = value end

local sections = { storage.playerSection(M.GROUP), storage.playerSection(M.WEAPONS_GROUP) }

local function refresh()
    local stored = {}
    for _, section in ipairs(sections) do
        for key, value in pairs(section:asTable()) do stored[key] = value end
    end
    for key, default in pairs(M.DEFAULTS) do
        local value = stored[key]
        if type(value) ~= type(default) then value = default end
        M.values[key] = value
    end
end

refresh()
for _, section in ipairs(sections) do section:subscribe(async:callback(refresh)) end

return M
