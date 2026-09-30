-- Which piece of armor a hit lands on. The engine picks it at random (I.Combat.applyArmor) and hands
-- on only its skill to the experience, so a hit on a piece of bound armor cannot be told from the
-- experience alone. Every step there is called through I.Combat so that a script can override it:
-- this overrides the pick, tells player.lua what was picked, and is otherwise the interface it found,
-- any other mod's overrides included.
local I = require('openmw.interfaces')
local auxUtil = require('openmw_aux.util')

local combat = I.Combat

local interface = auxUtil.shallowCopy(combat)
interface.pickRandomArmor = function(actor)
    local item = combat.pickRandomArmor(actor)
    -- applyArmor asks with no actor, for this one's own; an actor passed in is someone asking about
    -- another.
    local xp = I.FairerWeaponAndMagicXP
    if actor == nil and xp then xp._armorStruck(item) end
    return item
end

return {
    interfaceName = "Combat",
    interface = interface,
}
