-- Experience that follows what you actually do. README.md has the player's side of it, and
-- Sources/DEVELOPMENT.md the engine's, with the numbers.
--
-- - A successful cast teaches more the more the spell costs: as vanilla up to 15 magicka, then in
--   step with the cost, to 5x at 75 magicka and no more past that.
-- - A miscast teaches a third of what the cast would have - never past the skill's next level.
-- - Conjured gear teaches Conjuration a third of what it teaches its own skill: a hit with a bound
--   weapon, a hit taken on a piece of bound armor, a block with a bound shield.
-- - A hit taken under a shield spell teaches the spell's school: a physical hit under Shield a third of
--   what it teaches your armor, fire under Fire Shield, frost under Frost Shield and shock under
--   Lightning Shield a flat third of a vanilla use.
-- - A weapon hit teaches in step with how long the weapon's weakest swing takes - wind-up, release and
--   follow-through at its speed (scripts/swing.lua): half a second of it, or 0.75 for ranged, teaches
--   one vanilla hit. A full-strength attack teaches a third more, one in between in between. A swing
--   that reaches its target and misses teaches a fifth of what it would have had it hit - never past the
--   skill's next level.
--   The attack's type, strength and whether it landed are known only to the one struck: actor.lua, on
--   every NPC and creature, reports them here a frame later.
--
-- Everything goes through I.SkillProgression, so whatever else scales or redirects experience sees
-- these as any other gain. The gains this script adds carry no useType: they are not casts, hits or
-- armor uses, and a mod that reacts to those (a perk on every cast, say) must not take them for one.
-- They are marked instead with a `fairerWeaponAndMagicXP` field naming where they came from.
--
-- With "Log experience" on (the default), every gain this mod gives or changes is one line in the
-- console and openmw.log: "[FairerWeaponAndMagicXP] <skill> <gain> | <what happened> | <multipliers, and why>".
--
-- No engine object is fetched per frame, and nothing but a flag is read per frame. Everything hangs off
-- events: text keys, skill uses, hit reports and health decreases (Max Yari's Script Services, which
-- reads health once per frame for every mod that asks, and is required). What has to wait for the rest
-- of a frame's events is settled in onUpdate, which returns at once on any frame where nothing happened.
local core = require('openmw.core')
local I = require('openmw.interfaces')
local omwself = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local ui = require('openmw.ui')

-- Max Yari's Script Services answers the equipment and effect reads, and reports the player's health
-- decreases, from caches it shares with every mod asking. Required: say so once rather than fail.
if not core.contentFiles.has("MaxYariScriptServices.omwscripts") then
    print("[FairerWeaponAndMagicXP] ERROR: Max Yari's Script Services (MSS) is missing. It is required.")
    ui.showMessage("Fairer Weapon and Magic Experience Gain: Max Yari's Script Services (MSS) is missing, please install it.")
    return {}
end

local mp = "scripts/MaxYari/FairerWeaponAndMagicXP/"
local formulas = require(mp .. "scripts/formulas")
local settings = require(mp .. "scripts/settings")
local swing = require(mp .. "scripts/swing")

local cfg = settings.values
local Actor = types.Actor
local Skill = core.stats.Skill
local EFFECT = core.magic.EFFECT_TYPE
local USE = I.SkillProgression.SKILL_USE_TYPES
local SPELL = core.magic.SPELL_TYPE.Spell
local CARRIED_RIGHT = Actor.EQUIPMENT_SLOT.CarriedRight
local CARRIED_LEFT = Actor.EQUIPMENT_SLOT.CarriedLeft

-- Every skill below has only the one use its group shares, and it is 0 for all of them: a school's
-- is Spellcast_Success, a weapon skill's Weapon_SuccessfulHit, an armor skill's Armor_HitByOpponent,
-- Block's Block_Success.
local SCHOOLS = {
    alteration = true, conjuration = true, destruction = true,
    illusion = true, mysticism = true, restoration = true,
}
local WEAPON_SKILLS = {
    axe = true, bluntweapon = true, longblade = true, shortblade = true,
    spear = true, marksman = true, handtohand = true,
}
local ARMOR_SKILLS = { lightarmor = true, mediumarmor = true, heavyarmor = true, unarmored = true }

-- What each elemental shield wards off: the element it adds its magnitude to the resistance of
-- (MWMechanics::getEffectResistanceAttribute). Unlike Shield they add nothing to the armor rating,
-- so a physical hit is no business of theirs. Ids are looked up as the engine names them and
-- compared lowercased.
local ELEMENTAL_SHIELDS = {
    { shield = EFFECT.FireShield, element = string.lower(EFFECT.FireDamage) },
    { shield = EFFECT.FrostShield, element = string.lower(EFFECT.FrostDamage) },
    { shield = EFFECT.LightningShield, element = string.lower(EFFECT.ShockDamage) },
}

--- Settings page ----------------------------------------------------------------------------------
local D = settings.DEFAULTS
I.Settings.registerPage {
    key = "FairerWeaponAndMagicXP",
    l10n = "FairerWeaponAndMagicXP",
    name = "page_name",
    description = "page_description",
}
I.Settings.registerGroup {
    key = settings.GROUP,
    page = "FairerWeaponAndMagicXP",
    l10n = "FairerWeaponAndMagicXP",
    name = "settings_group",
    description = "settings_group_description",
    permanentStorage = true,
    order = 0,
    settings = {
        {
            key = "baseCost", name = "base_cost", description = "base_cost_description",
            default = D.baseCost, renderer = "number", argument = { integer = true, min = 1, max = 1000 },
        },
        {
            key = "topCost", name = "top_cost", description = "top_cost_description",
            default = D.topCost, renderer = "number", argument = { integer = true, min = 2, max = 10000 },
        },
        {
            key = "maxMultiplier", name = "max_multiplier", description = "max_multiplier_description",
            default = D.maxMultiplier, renderer = "number", argument = { min = 1, max = 20 },
        },
        {
            key = "miscastShare", name = "miscast_share", description = "miscast_share_description",
            default = D.miscastShare, renderer = "number", argument = { min = 0, max = 1 },
        },
        {
            key = "boundShare", name = "bound_share", description = "bound_share_description",
            default = D.boundShare, renderer = "number", argument = { min = 0, max = 1 },
        },
        {
            key = "shieldShare", name = "shield_share", description = "shield_share_description",
            default = D.shieldShare, renderer = "number", argument = { min = 0, max = 1 },
        },
        {
            key = "logging", name = "logging", description = "logging_description",
            default = D.logging, renderer = "checkbox",
        },
    },
}
I.Settings.registerGroup {
    key = settings.WEAPONS_GROUP,
    page = "FairerWeaponAndMagicXP",
    l10n = "FairerWeaponAndMagicXP",
    name = "weapons_group",
    description = "weapons_group_description",
    permanentStorage = true,
    order = 1,
    settings = {
        {
            key = "meleeSwing", name = "melee_swing", description = "melee_swing_description",
            default = D.meleeSwing, renderer = "number", argument = { min = 0.05, max = 5 },
        },
        {
            key = "rangedSwing", name = "ranged_swing", description = "ranged_swing_description",
            default = D.rangedSwing, renderer = "number", argument = { min = 0.05, max = 5 },
        },
        {
            key = "strongAttackBonus", name = "strong_attack_bonus", description = "strong_attack_bonus_description",
            default = D.strongAttackBonus, renderer = "number", argument = { min = 0, max = 5 },
        },
        {
            key = "missShare", name = "miss_share", description = "miss_share_description",
            default = D.missShare, renderer = "number", argument = { min = 0, max = 1 },
        },
    },
}

--- Helpers ----------------------------------------------------------------------------------------
local function costMultiplier(cost)
    return formulas.costMultiplier(cost, cfg.baseCost, cfg.topCost, cfg.maxMultiplier)
end

local function swingMultiplier(seconds, ranged)
    return formulas.swingMultiplier(seconds, ranged and cfg.rangedSwing or cfg.meleeSwing)
end

local function gainOf(skillId, useType)
    local record = Skill.record(skillId)
    return record and record.skillGain[useType + 1] or 0
end

local function schoolOf(effectId)
    local record = core.magic.effects.records[effectId]
    return record and record.school
end

local function effectName(effectId)
    local record = core.magic.effects.records[effectId]
    return record and record.name or effectId
end

local function skillValue(skillId)
    return types.NPC.stats.skills[skillId](omwself).modified
end

local function skillName(skillId)
    local record = Skill.record(skillId)
    return record and record.name or skillId
end

local function weaponName(weapon)
    if not weapon then return "bare fists" end
    local ok, record = pcall(types.Weapon.record, weapon)
    return ok and record and record.name or weapon.recordId
end

-- From MSS's caches. Looked up on use, as its README asks: an interface appears only once its script
-- has loaded.
local function magnitude(effectId)
    return I.MSS.getActiveEffect(effectId) or 0
end

local function equipped(slot)
    return I.MSS.getEquipment(slot)
end

-- Made once: a stat handle is a live view of the stat, and fetching one is an engine call that makes a
-- new object each time.
local magickaStat = Actor.stats.dynamic.magicka(omwself)

--- Settling -----------------------------------------------------------------------------------------
-- Some things are known only once all of a frame's events are in: whether a cast's release was
-- followed by a success, and what a hit finally taught its skill after every handler had its say. The
-- engine hands a frame's events to the scripts before their onUpdate, so onUpdate settles them - and
-- on every other frame does nothing but read this flag.
local settleNeeded = false
local function scheduleSettle()
    settleNeeded = true
end

--- Logging ----------------------------------------------------------------------------------------
-- One line per gain given or changed, when "Log experience" is on:
--   [FairerWeaponAndMagicXP] <skill> <gain> | <what happened> | <each multiplier, and why>
-- A gain this mod changes shows as "<before> -> <after>", one it adds as "+<gain>".
local function log(skillId, change, event, multipliers)
    if not cfg.logging then return end
    print(string.format("[FairerWeaponAndMagicXP] %s %s | %s | %s", skillName(skillId), change, event, multipliers))
end

local function logChange(skillId, before, after, event, multipliers)
    log(skillId, string.format("%.2f -> %.2f", before, after), event, multipliers)
end

-- The skill used handler sits in the chain every skill's experience goes through, and the engine
-- calls it unguarded: an error in it would lose the player that experience, whatever the skill. So
-- the hooks below report an error once and let the event through untouched.
local reported = false
local function guarded(fn)
    return function(...)
        local ok, result = pcall(fn, ...)
        if ok then return result end
        if not reported then
            reported = true
            print("[FairerWeaponAndMagicXP] ERROR (later ones are not printed): " .. tostring(result))
        end
    end
end

--- No level up from a miss ------------------------------------------------------------------------
-- A miss or a miscast brings a skill up to its next level, never over it: that takes a hit or a cast
-- that works. Capped in the skill used handler, after every newer handler has had its say. The older
-- ones - of the mods loaded before this one - run after it, and one that scales the gain (Sun's Dusk's
-- well rested bonus, Perks of Morrowind's Renaissance Man) takes it back over the cap: so the level up
-- the engine's own handler then asks for is refused too, and the skill put back just short of it.
local NO_LEVEL_UP = { miss = true, miscast = true }
local LEVEL_UP_MARGIN = 0.001 -- of the way to the next level, left for a success to cross
local held = nil -- the skill a miss or a miscast is teaching, while its gain is with the handlers

local function capBelowLevelUp(skillid, params)
    local stat = types.NPC.stats.skills[skillid](omwself)
    local room = (1 - LEVEL_UP_MARGIN - stat.progress) * I.SkillProgression.getSkillProgressRequirement(skillid)
    local gain = params.skillGain or 0
    if gain <= room then return end
    local capped = math.max(0, room)
    logChange(skillid, gain, capped, "capped at the next level",
        "a " .. params.fairerWeaponAndMagicXP .. " cannot raise the skill: that takes a hit or a cast that works")
    params.skillGain = capped
end

I.SkillProgression.addSkillLevelUpHandler(guarded(function(skillid, source)
    if skillid ~= held or source ~= I.SkillProgression.SKILL_INCREASE_SOURCES.Usage then return end
    types.NPC.stats.skills[skillid](omwself).progress = 1 - LEVEL_UP_MARGIN
    log(skillid, "level up refused", "held at the next level",
        "a handler after this mod's raised the capped gain")
    return false
end))

-- Experience that is not a cast, a hit or an armor use (see the top of this file).
local function teach(skillId, gain, source, event, multipliers)
    if not skillId or gain <= 0 then return end
    log(skillId, string.format("+%.2f", gain), event, multipliers)
    -- Let go of the skill whatever happens: an error in someone's handler must not leave it held.
    held = NO_LEVEL_UP[source] and skillId or nil
    local ok, err = pcall(I.SkillProgression.skillUsed, skillId, { skillGain = gain, fairerWeaponAndMagicXP = source })
    held = nil
    if not ok then error(err, 0) end
end

--- Casts ------------------------------------------------------------------------------------------
-- A cast goes: the spellcast animation's "<range> start" key, where the engine has just taken the
-- magicka (World::startSpellCast), then its "<range> release" key, where it rolls for success and
-- casts (CastSpell::cast). A success reaches the skill handlers as a Spellcast_Success use. A failure
-- reaches no script at all - it is a sound and a message - so a failure is a release that no success
-- follows. The release key and the success are queued in the same frame, in that order, and the
-- queue is emptied in that frame: a release still waiting for its success when it is settled, the
-- next frame, failed.
--
-- Too little magicka plays the whole animation as well, release and all, but nothing is cast, and
-- that is not a miscast. The engine takes the magicka just before the start key, when there is enough,
-- so magicka still at the cost or above then was certainly paid. Below it, it was either never enough,
-- or enough and taken: then only a failed roll plays the school's failure sound, and that settles it.
local casting = nil -- from the start key to the release: { spell, range, cost, paid }
local released = nil -- the cast whose release went by, until its success comes or it is settled

I.AnimationController.addTextKeyHandler("spellcast", guarded(function(_, key)
    local range = key:match("^(%a+) start$")
    if range then
        casting = nil
        local spell = Actor.getSelectedSpell(omwself)
        -- Only a plain spell that can fail teaches anything (MWMechanics::spellIncreasesSkill). An
        -- enchanted item leaves no spell selected.
        if spell and spell.type == SPELL and not spell.alwaysSucceedFlag then
            local cost = formulas.spellCost(spell)
            casting = { spell = spell, range = range, cost = cost, paid = cost <= 0 or magickaStat.current >= cost }
        end
        return
    end
    range = key:match("^(%a+) release$")
    -- An animation can hold every range's release at the same time; only the cast's own counts.
    if range and casting and casting.range == range then
        released, casting = casting, nil
        scheduleSettle()
    end
end))

local function costReason(cost, multiplier)
    return string.format("x%.2f for its cost, %d magicka (1x up to %d, %gx from %d)", multiplier, cost,
        cfg.baseCost, cfg.maxMultiplier, cfg.topCost)
end

local function castSucceeded(skillid, params)
    local cast = released
    released = nil
    if not params.skillGain then return end
    -- A cast some mod made without the animation has no release to go by: the selected spell is
    -- the best guess at what it was.
    local spell = cast and cast.spell or Actor.getSelectedSpell(omwself)
    if not spell then return end
    local cost = cast and cast.cost or formulas.spellCost(spell)
    local multiplier = costMultiplier(cost)
    logChange(skillid, params.skillGain, params.skillGain * multiplier, "cast " .. spell.name,
        costReason(cost, multiplier))
    params.skillGain = params.skillGain * multiplier
end

-- A third of what the cast would have taught.
local function miscast(cast)
    local school = formulas.castSchool(cast.spell, skillValue)
    if not school then return end
    if not cast.paid then
        local record = Skill.record(school)
        local sound = record and record.school and record.school.failureSound
        if not (sound and core.sound.isSoundPlaying(sound, omwself.object)) then
            if cfg.logging then
                print(string.format("[FairerWeaponAndMagicXP] %s | not enough magicka | nothing cast, nothing learned",
                    cast.spell.name))
            end
            return
        end
    end
    local multiplier = costMultiplier(cast.cost)
    teach(school, gainOf(school, USE.Spellcast_Success) * multiplier * cfg.miscastShare, "miscast",
        "miscast " .. cast.spell.name,
        string.format("%s, x%.2f for a miscast", costReason(cast.cost, multiplier), cfg.miscastShare))
end

--- Conjured gear ----------------------------------------------------------------------------------
-- Bound gear is worth nothing - vanilla's weapons and armor, Tamriel Data's, Unofficial TR Spells'
-- scaled copies, Katars' Bound Fist - and is only there while a bound effect is. The two together
-- tell it apart without any mod's list of its bound items. Returns the bound effect's school, the one
-- taught.
local function boundSchool(item)
    if not item then return nil end
    local itemType = item.type
    if itemType ~= types.Weapon and itemType ~= types.Armor then return nil end
    if itemType.record(item).value ~= 0 then return nil end
    for _, spell in pairs(Actor.activeSpells(omwself)) do
        for _, effect in pairs(spell.effects) do
            local id = string.lower(effect.id)
            if id:find("bound", 1, true) then return schoolOf(id) end
        end
    end
    return nil
end

-- The piece of armor the hit being handled landed on: I.Combat.applyArmor picks it at random and
-- passes on only its skill, so combat.lua wraps the pick and hands it over here, just before the
-- armor use it leads to.
local struckArmor = nil
local struckAt = nil -- the simulation time of that pick: the armor use comes in the same call

--- Shares of another skill's gain -----------------------------------------------------------------
-- What a hit teaches its weapon or armor skill is settled only once every handler has had its say:
-- Katars and Knuckledusters, for one, splits a hit between Hand to Hand and the weapon skill, cutting
-- the one gain and adding another. So the handler's table is kept and its gain read when the frame is
-- settled, when they are all done with it: the share is of what the skill was really taught, whichever
-- order the mods load in.
local shares = {} -- { params, from, skill, share, source }

local SHARE_EVENTS = {
    boundWeapon = "hit with a bound weapon",
    boundShield = "block with a bound shield",
    boundArmor = "hit taken on bound armor",
    shield = "hit taken under Shield",
}

local function addShare(params, from, school, share, source)
    if school and share > 0 then
        shares[#shares + 1] = { params = params, from = from, skill = school, share = share, source = source }
        scheduleSettle()
    end
end

--- Weapons ----------------------------------------------------------------------------------------
-- A hit's experience reaches this script at once, with the weapon's multiplier known: it is applied
-- there. The attack's strength and every miss reach only the one struck: actor.lua reports them here, a
-- frame later, and what the strength adds is taught on top then, as a gain of its own. A hit whose report
-- never comes has lost only that. A miss is taught from its report alone.
local awaiting = {} -- hits waiting for their report: { params, skill, time }
local REPORT_WITHIN = 0.5 -- seconds: a report comes the frame after its hit, or never

local function recentHits()
    local now, kept = core.getSimulationTime(), {}
    for i = 1, #awaiting do
        if now - awaiting[i].time <= REPORT_WITHIN then kept[#kept + 1] = awaiting[i] end
    end
    return kept
end

local function weaponReason(profile, multiplier)
    return string.format("x%.2f for the weapon: its weakest swing takes %.2fs (1x per %.2fs %s)", multiplier,
        profile.weak, profile.ranged and cfg.rangedSwing or cfg.meleeSwing, profile.ranged and "ranged" or "melee")
end

-- What the strength adds, over the weakest attack: 0 for it, strongAttackBonus for a full one.
local function strengthBonus(strength)
    return cfg.strongAttackBonus * math.min(1, math.max(0, strength or 0))
end

local function weaponHit(skillid, params)
    if not params.skillGain then return end
    local weapon = equipped(CARRIED_RIGHT)
    local profile = swing.profile(weapon)
    -- The last of a stack of thrown weapons leaves the hand before it lands.
    if not profile or (skillid == "marksman" and not profile.ranged) then return end
    local multiplier = swingMultiplier(profile.weak, profile.ranged)
    logChange(skillid, params.skillGain, params.skillGain * multiplier, "hit with " .. weaponName(weapon),
        weaponReason(profile, multiplier) .. "; the strength when reported")
    params.skillGain = params.skillGain * multiplier
    if #awaiting > 0 then awaiting = recentHits() end
    awaiting[#awaiting + 1] = { params = params, skill = skillid, time = core.getSimulationTime() }
end

-- Katars and Knuckledusters splits a hit between Hand to Hand and the weapon skill by a setting of its
-- own; a miss, which it never hears of, is split the same way here.
local function katarsShare()
    local ok, share = pcall(function()
        return storage.globalSection("SettingsGlobalH2HWeapons"):get("handToHandShare")
    end)
    return ok and type(share) == "number" and share or 0.7
end

-- An attack of the player's that reached someone: { successful, strength, weapon } (actor.lua).
local function onAttack(e)
    local bonus = strengthBonus(e.strength)
    local strengthReason = string.format("x%.2f for the strength, %.2f (x1 weakest, x%.2f full)", 1 + bonus,
        e.strength or 0, 1 + cfg.strongAttackBonus)

    if e.successful then
        local pending = recentHits()
        awaiting = {}
        if bonus <= 0 then return end
        for i = 1, #pending do
            local entry = pending[i]
            local gain = entry.params.skillGain or 0
            teach(entry.skill, gain * bonus, "weaponHit", "hit with " .. weaponName(e.weapon) .. ", reported",
                string.format("%s, over the %.2f the hit taught", strengthReason, gain))
        end
        return
    end

    if cfg.missShare <= 0 then return end
    local profile = swing.profile(e.weapon)
    if not profile then return end
    local multiplier = swingMultiplier(profile.weak, profile.ranged)
    local event = "miss with " .. weaponName(e.weapon)
    local why = string.format("%s, %s, x%.2f for a miss", weaponReason(profile, multiplier), strengthReason,
        cfg.missShare)
    local base = multiplier * (1 + bonus) * cfg.missShare
    if swing.isKatarsWeapon(e.weapon) then
        local share = katarsShare()
        teach("handtohand", gainOf("handtohand", USE.Weapon_SuccessfulHit) * share * base, "miss", event,
            string.format("%s, x%.2f Katars' Hand to Hand share", why, share))
        teach(profile.skill, gainOf(profile.skill, USE.Weapon_SuccessfulHit) * (1 - share) * base, "miss",
            event, string.format("%s, x%.2f Katars' weapon skill share", why, 1 - share))
    else
        teach(profile.skill, gainOf(profile.skill, USE.Weapon_SuccessfulHit) * base, "miss", event, why)
    end
end

--- The skill used handler -------------------------------------------------------------------------
-- Handlers run newest first, so this runs before the engine's own, which is the one that applies the
-- gain.
I.SkillProgression.addSkillUsedHandler(guarded(function(skillid, params)
    if params.fairerWeaponAndMagicXP then
        if NO_LEVEL_UP[params.fairerWeaponAndMagicXP] then capBelowLevelUp(skillid, params) end
        return
    end
    if params.useType ~= 0 then return end
    if SCHOOLS[skillid] then
        castSucceeded(skillid, params)
    elseif WEAPON_SKILLS[skillid] then
        weaponHit(skillid, params)
        addShare(params, skillid, boundSchool(equipped(CARRIED_RIGHT)), cfg.boundShare, "boundWeapon")
    elseif skillid == "block" then
        addShare(params, skillid, boundSchool(equipped(CARRIED_LEFT)), cfg.boundShare, "boundShield")
    elseif ARMOR_SKILLS[skillid] then
        -- The engine credits armor only for a hit that got through to your health (I.Combat.applyArmor).
        local item = struckAt == core.getSimulationTime() and struckArmor or nil
        struckArmor, struckAt = nil, nil
        addShare(params, skillid, boundSchool(item), cfg.boundShare, "boundArmor")
        if magnitude(EFFECT.Shield) > 0 then
            addShare(params, skillid, schoolOf(EFFECT.Shield), cfg.shieldShare, "shield")
        end
    end
end))

--- Elemental shields ------------------------------------------------------------------------------
-- A spell reaches no script when it lands. What it leaves is an active spell on its target, and even
-- an instant one is there for a frame: the engine clears spent effects at the start of its next
-- update, after the scripts have seen them. So when the player's health drops (MSS's damage listener)
-- with an elemental shield up, the active spells are looked through for one of that shield's element,
-- cast by someone else and not seen in an earlier look: each counts once, however long it burns, and one
-- that was already there when its shield was not does not count. Nothing is looked at otherwise.
local seen = {} -- [activeSpellId] = true for the spells there at the last look

local function onDamaged()
    if cfg.shieldShare <= 0 then return end
    local warded = nil
    for _, pair in ipairs(ELEMENTAL_SHIELDS) do
        if magnitude(pair.shield) > 0 then
            warded = warded or {}
            warded[pair.element] = pair.shield
        end
    end
    if not warded then return end
    local present = {}
    for _, spell in pairs(Actor.activeSpells(omwself)) do
        local id = spell.activeSpellId
        present[id] = true
        if not seen[id] and spell.temporary and spell.caster ~= omwself.object then
            for _, effect in pairs(spell.effects) do
                local shield = warded[string.lower(effect.id)]
                if shield then
                    teach(schoolOf(shield), cfg.shieldShare, "elementalShield",
                        string.format("%s taken under %s", effect.name or effect.id, effectName(shield)),
                        string.format("the shield share, %.2f of a vanilla use", cfg.shieldShare))
                    break
                end
            end
        end
    end
    seen = present
end

--- Settle -----------------------------------------------------------------------------------------
local function onUpdate()
    if not settleNeeded then return end
    settleNeeded = false
    if released then
        -- Its success would have come in the frame of its release.
        miscast(released)
        released = nil
    end
    if #shares > 0 then
        local pending = shares
        shares = {}
        for i = 1, #pending do
            local entry = pending[i]
            local gain = entry.params.skillGain or 0
            teach(entry.skill, gain * entry.share, entry.source, SHARE_EVENTS[entry.source],
                string.format("x%.2f of %s's %.2f", entry.share, skillName(entry.from), gain))
        end
    end
end

-- MSS's listener is added once the player is active, when every script's interface is there.
local listening = false
local function onActive()
    if listening then return end
    listening = true
    I.MSS.addDamageListener(guarded(onDamaged))
end

return {
    interfaceName = "FairerWeaponAndMagicXP",
    interface = {
        version = 1.0,
        --- What a successful cast of this spell record is multiplied by, with the current settings.
        spellMultiplier = function(spell) return costMultiplier(formulas.spellCost(spell)) end,
        --- The multiplier for a spell of this cost.
        costMultiplier = costMultiplier,
        --- What the game charges for a spell record: the cost the spell menu shows.
        spellCost = formulas.spellCost,
        --- A weapon's attacks, nil for bare fists: { group, speed, skill, ranged, keys, weak }.
        swingProfile = swing.profile,
        --- For combat.lua: the piece of armor a hit is about to be credited to.
        _armorStruck = guarded(function(item) struckArmor, struckAt = item, core.getSimulationTime() end),
    },
    engineHandlers = {
        onActive = onActive,
        onUpdate = onUpdate,
    },
    eventHandlers = {
        FairerWeaponAndMagicXP_Attack = guarded(onAttack),
    },
}
