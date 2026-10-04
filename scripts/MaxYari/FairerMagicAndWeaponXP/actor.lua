-- Tells the player how each of their attacks on this actor went. The engine hands a hit - its
-- strength, its attack type, and whether it landed at all - only to the struck actor's own scripts
-- (I.Combat onHit), and the player hears of nothing but the experience of a hit that landed. So this
-- runs on every NPC and creature, and does nothing but this: one check per hit taken, no per-frame
-- work. A swing at the air reaches no one, and is not reported.
local I = require('openmw.interfaces')
local types = require('openmw.types')

local SOURCE = I.Combat.ATTACK_SOURCE_TYPES

-- The weapon, or its record id once the engine has let go of it. A thrown weapon comes as a copy made
-- for the throw, gone by the time a script sees it - asking it anything throws - and so does an arrow
-- whose bow was put away while it flew. The projectile's record id comes along as the ammunition.
local function weaponOf(attack)
    local weapon = attack.weapon
    if weapon == nil or weapon:isValid() then return weapon end
    return attack.ammo
end

I.Combat.addOnHitHandler(function(attack)
    local attacker = attack.attacker
    if not attacker or attacker.type ~= types.Player then return end
    if attack.sourceType ~= SOURCE.Melee and attack.sourceType ~= SOURCE.Ranged then return end
    attacker:sendEvent("FairerMagicAndWeaponXP_Attack", {
        successful = attack.successful == true,
        strength = attack.strength or 0,
        type = attack.type,
        weapon = weaponOf(attack),
    })
end)

return {}
