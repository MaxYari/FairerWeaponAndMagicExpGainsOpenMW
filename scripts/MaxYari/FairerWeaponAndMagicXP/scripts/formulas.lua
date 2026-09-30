-- The arithmetic: what a spell costs, which school a cast of it trains, and how much more a costly
-- spell teaches than a cheap one. No state, and nothing read from the engine but records and game
-- settings, so the tests drive it directly.
local core = require('openmw.core')

local M = {}

local TARGET = core.magic.RANGE.Target

--- How many times over a cast of this cost teaches what a vanilla cast does.
-- 1 up to `base`. Past it, a power of the cost that reaches `max` at `top` and stays there. The power
-- is whatever joins those two points: with 6 -> 1x and 150 -> 5x it is exactly 0.5, so four times
-- the cost teaches twice as much. Why a square root and not a straight line is in DEVELOPMENT.md.
function M.costMultiplier(cost, base, top, max)
    base = math.max(1, base)
    if cost <= base or max <= 1 then return 1 end
    if top <= base then return max end
    local power = math.log(max) / math.log(top / base)
    return math.min(max, (cost / base) ^ power)
end

--- How many times over a weapon hit teaches what a vanilla one does: in step with how long its swing
-- took, `perVanilla` seconds of swing teaching as much as one vanilla hit.
function M.swingMultiplier(seconds, perVanilla)
    if perVanilla <= 0 then return 1 end
    return seconds / perVanilla
end

--- What the game charges for a spell (MWMechanics::calcSpellCost), which is also what the spell
-- menu shows. A record flagged autocalc - most vanilla ones - has its cost worked out from its
-- effects, and the number stored in it is ignored: a mod that changes an effect's base cost leaves
-- it stale. Player-made spells are not flagged, and store the exact cost.
function M.spellCost(spell)
    if not spell.isAutocalc then return spell.cost end
    local costMult = core.getGMST("fEffectCostMult")
    local total = 0
    local effects = spell.effects
    for i = 1, #effects do
        local params = effects[i]
        local effect = params.effect
        local minMagnitude, maxMagnitude = 1, 1
        if effect.hasMagnitude then
            minMagnitude = math.max(1, params.magnitudeMin)
            maxMagnitude = math.max(1, params.magnitudeMax)
        end
        local duration = effect.hasDuration and params.duration or 1
        if not effect.isAppliedOnce then duration = math.max(1, duration) end
        local cost = 0.5 * (minMagnitude + maxMagnitude) * 0.1 * effect.baseCost * duration
            + 0.05 * math.max(0, params.area) * effect.baseCost
        cost = math.max(0, cost * costMult)
        if params.range == TARGET then cost = cost * 1.5 end
        total = total + cost
    end
    return math.floor(total + 0.5)
end

--- The school a cast of this spell trains: that of its hardest effect for this caster, picked the
-- way the engine picks it (MWMechanics::calcSpellBaseSuccessChance) - twice the school's skill less
-- the effect's share of the cost, lowest wins. The engine's sum here is not quite the cost's - the
-- magnitudes and the area go in as they are, with no floor - and is copied as it is.
-- `skill(school)` is the caster's current skill in that school.
function M.castSchool(spell, skill)
    local costMult = core.getGMST("fEffectCostMult")
    local lowest, school = math.huge, nil
    local effects = spell.effects
    for i = 1, #effects do
        local params = effects[i]
        local effect = params.effect
        local x = params.duration
        if not effect.isAppliedOnce then x = math.max(1, x) end
        x = x * 0.1 * effect.baseCost * 0.5 * (params.magnitudeMin + params.magnitudeMax)
        x = x + params.area * 0.05 * effect.baseCost
        if params.range == TARGET then x = x * 1.5 end
        x = x * costMult
        local s = 2 * skill(effect.school) - x
        if s < lowest then lowest, school = s, effect.school end
    end
    return school
end

return M
