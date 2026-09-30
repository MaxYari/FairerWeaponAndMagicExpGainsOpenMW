-- Everything the mod does, end to end through the faked engine: the cost curve and the cost itself,
-- casts that work, miscasts and casts refused for magicka, conjured gear (with and without another
-- mod splitting the hit, in either load order), hits taken under each kind of shield, weapon swings,
-- strengths and misses, the reports actor.lua sends, and MSS being required.
package.path = arg[0]:gsub("[^/]*$", "") .. "?.lua;" .. package.path
local stubs = require("stubs")
local T = stubs.RANGE
local WT = stubs.WT
local st = stubs.state

local fails, checks = 0, 0
local function check(ok, msg, extra)
    checks = checks + 1
    if not ok then fails = fails + 1; print("FAIL: " .. msg .. (extra and ("  [" .. tostring(extra) .. "]") or "")) end
end
local function near(a, b) return a ~= nil and math.abs(a - b) < 1e-4 end
local function about(a, b) return a ~= nil and math.abs(a - b) < 0.002 end -- to the table's rounding

--- The magic curve ---------------------------------------------------------------------------------
stubs.load()
local F = stubs.formulas()
local function mult(cost) return F.costMultiplier(cost, 15, 75, 5) end
check(mult(1) == 1 and mult(10) == 1 and mult(15) == 1, "up to 15 magicka, as vanilla")
check(near(mult(30), 2) and near(mult(45), 3), "then the cost / 15", mult(45))
check(near(mult(75), 5), "5x at 75", mult(75))
check(mult(750) == 5, "and nothing costs more than that", mult(750))
check(near(F.costMultiplier(24, 6, 150, 5), 2), "other anchors bend it: 6 -> 150 is a square root")
check(F.costMultiplier(100, 6, 6, 5) == 5, "a top no higher than the base: a step, not a division by 0")
check(F.costMultiplier(100, 6, 150, 1) == 1, "a most of 1 turns it off")

--- The swing curve -------------------------------------------------------------------------------
check(near(F.swingMultiplier(0.5, 0.5), 1) and near(F.swingMultiplier(1.07, 0.5), 2.14)
      and near(F.swingMultiplier(0.31, 0.5), 0.62), "in step with the swing: 0.5s teaches 1x")

--- The cost -----------------------------------------------------------------------------------------
local fireBite = stubs.spell { id = "fire bite", autocalc = true, cost = 99,
    effects = { { id = "FireDamage", range = T.Touch, duration = 1, min = 15, max = 30 } } }
local fireball = stubs.spell { id = "fireball", autocalc = true, cost = 99,
    effects = { { id = "FireDamage", range = T.Target, area = 5, duration = 1, min = 2, max = 20 } } }
local godsFire = stubs.spell { id = "god's fire", autocalc = true,
    effects = { { id = "FireDamage", range = T.Target, area = 10, duration = 10, min = 11, max = 60 } } }
local thirty = stubs.spell { id = "thirty", autocalc = true,
    effects = { { id = "FireDamage", range = T.Touch, duration = 1, min = 120, max = 120 } } }
check(F.spellCost(fireBite) == 6, "Fire Bite: 6, worked out, the stored number ignored", F.spellCost(fireBite))
check(F.spellCost(fireball) == 5, "Fireball: 5", F.spellCost(fireball))
check(F.spellCost(godsFire) == 135, "God's Fire: 135", F.spellCost(godsFire))
check(F.spellCost(thirty) == 30, "and one of 30 for the tests", F.spellCost(thirty))
local made = stubs.spell { cost = 77, effects = { { id = "FireDamage", min = 100, max = 100 } } }
check(F.spellCost(made) == 77, "a player-made spell keeps the cost it was made with")

local mixed = stubs.spell { effects = {
    { id = "RestoreHealth", min = 10, max = 10, duration = 1 },
    { id = "FireDamage", range = T.Target, min = 20, max = 40 } } }
local function skills(t) return function(school) return t[school] or 0 end end
check(F.castSchool(mixed, skills { restoration = 50, destruction = 50 }) == "destruction",
      "the costlier effect, at equal skill")
check(F.castSchool(mixed, skills { restoration = 10, destruction = 80 }) == "restoration",
      "the weaker school, when the gap in skill outweighs the cost")

--- Casts --------------------------------------------------------------------------------------------
stubs.load()
stubs.cast(fireBite, true)
check(near(stubs.taughtTo("destruction"), 1), "Fire Bite teaches as in vanilla", stubs.taughtTo("destruction"))

stubs.load()
stubs.cast(thirty, true)
check(near(stubs.taughtTo("destruction"), 2), "a 30 magicka spell teaches 2x", stubs.taughtTo("destruction"))

stubs.load()
stubs.cast(godsFire, true)
check(near(stubs.taughtTo("destruction"), 5), "God's Fire teaches 5x", stubs.taughtTo("destruction"))
check(st.taught[1].params.useType == 0, "and stays a Spellcast_Success for everyone after")

stubs.load()
stubs.cast(thirty, false)
check(near(stubs.taughtTo("destruction"), 0.66), "a miscast of 30 magicka teaches a third of 2x",
      stubs.taughtTo("destruction"))
check(st.taught[1] and st.taught[1].params.useType == nil and st.taught[1].params.fairerWeaponAndMagicXP == "miscast",
      "as a use of no type, so nothing takes it for a cast")
stubs.update()
check(#st.taught == 1, "once")

stubs.load()
stubs.cast(godsFire, false)
check(near(stubs.taughtTo("destruction"), 1.65), "a miscast of God's Fire teaches a third of 5x",
      stubs.taughtTo("destruction"))

-- Too little magicka: the animation plays, nothing is cast, no failure sound, nothing learned.
stubs.load()
st.magicka = 100
stubs.cast(godsFire, false)
check(#st.taught == 0, "no magicka, no miscast", #st.taught)

-- Enough, and what is left after paying is below the cost: the failure sound tells it was paid.
stubs.load()
st.magicka = 150
stubs.cast(godsFire, false)
check(near(stubs.taughtTo("destruction"), 1.65), "paid with little left over: still a miscast",
      stubs.taughtTo("destruction"))

stubs.load()
stubs.cast(stubs.spell { type = 5, effects = { { id = "FireDamage", min = 50 } } }, false)
stubs.cast(stubs.spell { always = true, effects = { { id = "FireDamage", min = 50 } } }, false)
check(#st.taught == 0, "powers and sure-fire spells have no miscast")

stubs.load()
st.selectedSpell = godsFire
stubs.textKey("spellcast", "target start")
stubs.textKey("spellcast", "self release")
stubs.update()
check(#st.taught == 0, "only the cast's own release counts")

stubs.load()
st.selectedSpell = godsFire
stubs.skillUse("destruction", 0)
check(near(stubs.taughtTo("destruction"), 5), "a cast with no animation still scales")

stubs.load()
stubs.skillUsed("alteration", { skillGain = 1, fairerWeaponAndMagicXP = "test" })
check(near(stubs.taughtTo("alteration"), 1), "its own gains pass through untouched")

--- Conjured gear ------------------------------------------------------------------------------------
local function bind(effect)
    st.activeSpells = { { activeSpellId = "1", caster = stubs.player, temporary = true,
        effects = { { id = effect or "BoundLongsword" } } } }
end

stubs.load()
bind()
st.right = stubs.item("weapon", "bound_longsword")
stubs.skillUse("longblade", 0)
stubs.update()
check(near(stubs.taughtTo("conjuration"), 0.33 * stubs.taughtTo("longblade")),
      "a bound weapon's hit teaches Conjuration a third of what it taught Long Blade", stubs.taughtTo("conjuration"))

stubs.load()
bind()
st.right = stubs.item("weapon", "steel_longsword", 12)
stubs.skillUse("longblade", 0)
stubs.update()
check(stubs.taughtTo("conjuration") == 0, "a weapon with a value is not bound")

stubs.load()
st.right = stubs.item("weapon", "bound_longsword")
stubs.skillUse("longblade", 0)
stubs.update()
check(stubs.taughtTo("conjuration") == 0, "nor is a worthless one with no bound effect up")

-- Katars and Knuckledusters splits a hit: the weapon skill keeps 30%, Hand to Hand gets 70% as a
-- use of its own. The share is of what was really taught, whichever handler runs first.
local function katarSplit(skillid, options)
    if skillid == "handtohand" or options.useType ~= 0 then return end
    options.skillGain = options.skillGain * 0.3
    stubs.skillUsed("handtohand", { useType = 0, scale = 0.7 })
end
for _, order in ipairs({ "Katars loaded before", "Katars loaded after" }) do
    if order == "Katars loaded before" then
        stubs.load(function() stubs.interfaces.SkillProgression.addSkillUsedHandler(katarSplit) end)
    else
        stubs.load()
        stubs.interfaces.SkillProgression.addSkillUsedHandler(katarSplit)
    end
    bind()
    st.right = stubs.item("weapon", "h2h_bound_katar", 0, { type = WT.ShortBladeOneHand })
    stubs.skillUse("shortblade", 0)
    stubs.update()
    local whole = stubs.taughtTo("shortblade") + stubs.taughtTo("handtohand")
    check(near(stubs.taughtTo("handtohand"), 0.7 * whole), order .. ": the split holds")
    check(near(stubs.taughtTo("conjuration"), 0.33 * whole), order .. ": Conjuration a third of the whole, once",
          stubs.taughtTo("conjuration"))
end

local cuirass = stubs.item("armor", "bound_cuirass")
stubs.load()
bind("BoundCuirass")
st.pick = cuirass
stubs.armorHit("lightarmor")
stubs.update()
check(near(stubs.taughtTo("conjuration"), 0.33), "a hit on bound armor teaches Conjuration a third",
      stubs.taughtTo("conjuration"))

stubs.load()
bind("BoundCuirass")
st.pick = stubs.item("armor", "glass_cuirass", 14000)
stubs.armorHit("lightarmor")
stubs.update()
check(stubs.taughtTo("conjuration") == 0, "a hit on real armor, under a bound effect, does not")

stubs.load()
bind("BoundCuirass")
st.pick = cuirass
stubs.interfaces.Combat.pickRandomArmor() -- someone asking, with no armor use after it
stubs.update()
stubs.skillUse("lightarmor", 0)            -- an armor use with no pick before it
stubs.update()
check(stubs.taughtTo("conjuration") == 0, "a pick is only good for the armor use right after it")

stubs.load()
bind("BoundCuirass")
st.left = stubs.item("armor", "bound_shield")
stubs.skillUse("block", 0)
stubs.update()
check(near(stubs.taughtTo("conjuration"), 0.33), "a block with a bound shield teaches Conjuration a third")

--- Shield -------------------------------------------------------------------------------------------
stubs.load()
st.effects.shield = 10
stubs.skillUse("mediumarmor", 0)
stubs.update()
check(near(stubs.taughtTo("alteration"), 0.33), "a hit under Shield teaches Alteration a third of the armor's")

stubs.load()
stubs.skillUse("mediumarmor", 0)
stubs.skillUse("block", 0)
stubs.update()
check(stubs.taughtTo("alteration") == 0, "no Shield, nothing - and a block is not a hit")

stubs.load()
st.effects.fireshield = 10
stubs.skillUse("unarmored", 0)
stubs.update()
check(stubs.taughtTo("alteration") == 0, "an elemental shield wards no physical hit")

--- Elemental shields --------------------------------------------------------------------------------
local function landed(id, effect, caster)
    table.insert(st.activeSpells, { activeSpellId = id, caster = caster or stubs.enemy, temporary = true,
        effects = { { id = effect } } })
end

stubs.load()
check(#st.damageListeners == 1, "listening to MSS for health decreases, from onActive")
st.effects.fireshield = 20
landed("bolt", "FireDamage")
stubs.update()
check(stubs.taughtTo("alteration") == 0, "nothing looked at until the health drops")
stubs.damaged()
check(near(stubs.taughtTo("alteration"), 0.33), "a fire bolt under Fire Shield teaches Alteration",
      stubs.taughtTo("alteration"))
stubs.damaged()
check(near(stubs.taughtTo("alteration"), 0.33), "once, however long it burns")
landed("frost", "FrostDamage")
landed("mine", "FireDamage", stubs.player)
stubs.damaged()
check(near(stubs.taughtTo("alteration"), 0.33), "frost is Frost Shield's, and your own fire is not a hit")
st.effects.frostshield = 5
landed("frost2", "FrostDamage")
stubs.damaged()
check(near(stubs.taughtTo("alteration"), 0.66), "with both up, each wards its own")

-- The piece picked to price an elemental hit is not a hit on that piece.
stubs.load()
bind("BoundCuirass")
st.pick = cuirass
st.effects.lightningshield = 20
landed("spark", "ShockDamage")
stubs.damaged()
stubs.skillUse("heavyarmor", 0)
stubs.update()
check(near(stubs.taughtTo("alteration"), 0.33), "shock under Lightning Shield: a flat 0.33")
check(stubs.taughtTo("conjuration") == 0, "and no armor piece is picked for it")

--- Weapons ------------------------------------------------------------------------------------------
-- A weapon teaches in step with its weakest swing, measured once from ReAnimation per group (swing.lua):
-- 0.5s of melee, 0.75s of ranged, is one vanilla hit. A full-strength attack a third more.
local dagger = stubs.item("weapon", "iron dagger", 10, { type = WT.ShortBladeOneHand, speed = 2.5 })
local longsword = stubs.item("weapon", "steel longsword", 60, { type = WT.LongBladeOneHand, speed = 1.35 })
local axe = stubs.item("weapon", "steel battle axe", 50, { type = WT.AxeTwoHand, speed = 1 })
local staff = stubs.item("weapon", "wooden staff", 5, { type = WT.BluntTwoWide, speed = 1.75 })
local katar = stubs.item("weapon", "katar_steel", 40, { type = WT.ShortBladeOneHand, speed = 0.9 })
local bow = stubs.item("weapon", "long bow", 50, { type = WT.MarksmanBow, speed = 1 })
local S = stubs.swing()
local function weak(group) return S.WEAK_SWING[group] end

stubs.load()
st.right = dagger
stubs.skillUse("shortblade", 0)
local daggerX = weak("weapononehand") / 2.5 / 0.5
check(near(stubs.taughtTo("shortblade"), daggerX) and about(daggerX, 0.622), "a dagger: 0.62x, at once",
      stubs.taughtTo("shortblade"))
stubs.report { strength = 1, weapon = dagger }
check(near(stubs.taughtTo("shortblade"), daggerX * 1.33), "a full-strength one: a third more, when reported",
      stubs.taughtTo("shortblade"))
check(st.taught[2].params.fairerWeaponAndMagicXP == "weaponHit" and st.taught[2].params.useType == nil,
      "the third as a gain of its own")

stubs.load()
st.right = longsword
stubs.skillUse("longblade", 0)
local swordX = weak("weapononehand") / 1.35 / 0.5
check(near(stubs.taughtTo("longblade"), swordX) and about(swordX, 1.151), "a longsword: 1.15x", stubs.taughtTo("longblade"))
stubs.report { strength = 0.5, weapon = longsword }
check(near(stubs.taughtTo("longblade"), swordX * (1 + 0.165)), "half strength: a sixth more", stubs.taughtTo("longblade"))

-- Two-handed axes swing with the two-handed swords' animations, staves with the spears'.
stubs.load()
st.right = axe
stubs.skillUse("axe", 0)
check(about(stubs.taughtTo("axe"), 1.29), "a battle axe: 1.29x", stubs.taughtTo("axe"))
st.right = staff
stubs.skillUse("bluntweapon", 0)
check(about(stubs.taughtTo("bluntweapon"), 0.686), "a staff: 0.69x", stubs.taughtTo("bluntweapon"))

stubs.load()
stubs.skillUse("handtohand", 0)
check(near(stubs.taughtTo("handtohand"), 0.8), "bare fists: a jab, 0.40s: 0.8x")
stubs.report { strength = 1, weapon = nil }
check(near(stubs.taughtTo("handtohand"), 0.8 * 1.33), "a full punch a third more", stubs.taughtTo("handtohand"))

-- Katars and Knuckledusters' weapons swing with the hand-to-hand animations, at their own speed.
local function katars()
    stubs.interfaces.H2HWeapons = { kindOfItem = function(item) return item.recordId:find("katar") and "katar" end }
end
stubs.load(katars)
st.right = katar
stubs.skillUse("shortblade", 0)
stubs.report { strength = 0, weapon = katar }
check(near(stubs.taughtTo("shortblade"), 0.4 / 0.9 / 0.5), "a katar: hand-to-hand timing at 0.9, 0.89x",
      stubs.taughtTo("shortblade"))
check(#st.taught == 1, "and nothing on top for the weakest attack")

-- Ranged: 0.75s is a vanilla hit, the draw counted.
stubs.load()
st.right = bow
stubs.skillUse("marksman", 0)
check(near(stubs.taughtTo("marksman"), 1.4 / 0.75), "a bow: 1.87x", stubs.taughtTo("marksman"))

-- Misses: a fifth of what the hit would have taught.
stubs.load()
stubs.report { successful = false, strength = 0, weapon = longsword }
check(near(stubs.taughtTo("longblade"), 0.2 * swordX), "a missed weak swing teaches a fifth", stubs.taughtTo("longblade"))
check(st.taught[1].params.fairerWeaponAndMagicXP == "miss", "as a miss")

stubs.load(katars)
st.sections.SettingsGlobalH2HWeapons = { handToHandShare = 0.7 }
stubs.report { successful = false, strength = 1, weapon = katar }
local whole = 0.2 * (0.4 / 0.9 / 0.5) * 1.33
check(near(stubs.taughtTo("handtohand"), 0.7 * whole) and near(stubs.taughtTo("shortblade"), 0.3 * whole),
      "a missed katar: split as Katars splits a hit", stubs.taughtTo("handtohand"))

stubs.load()
st.right = longsword
stubs.skillUse("longblade", 0)
st.time = st.time + 1
stubs.report { strength = 1, weapon = longsword }
check(near(stubs.taughtTo("longblade"), swordX), "a report long after its hit is not for it")

stubs.load()
stubs.report { strength = 1, weapon = longsword }
check(#st.taught == 0, "a hit report with no hit to it teaches nothing")

stubs.load()
stubs.skillUse("marksman", 0) -- the last throwing knife left the hand before it landed
check(near(stubs.taughtTo("marksman"), 1), "marksman with an empty hand: left alone")

--- No level up from a miss -------------------------------------------------------------------------
-- A miss or a miscast fills the skill up to just short of its next level; a success is what crosses it.
stubs.load()
st.skills.longblade = { base = 50, modified = 50, progress = 0.998 } -- 0.102 of 51 left
stubs.report { successful = false, strength = 1, weapon = longsword }
check(near(stubs.taughtTo("longblade"), (0.999 - 0.998) * 51), "a miss stops just short of the level",
      stubs.taughtTo("longblade"))
st.skills.longblade.progress = 0.5
stubs.report { successful = false, strength = 0, weapon = longsword }
check(near(stubs.taughtTo("longblade", 2), 0.2 * swordX), "and is not capped with room to spare")
st.skills.longblade.progress = 0.9995
st.right = longsword
stubs.skillUse("longblade", 0)
check(near(stubs.taughtTo("longblade", 3), swordX), "a hit is never capped")

stubs.load()
st.skills.destruction = { base = 50, modified = 50, progress = 0.999 }
stubs.cast(thirty, false)
check(near(stubs.taughtTo("destruction"), 0), "a miscast at the edge of a level teaches nothing more",
      stubs.taughtTo("destruction"))

-- A mod loaded before this one scales the gain after the cap (Sun's Dusk's well rested bonus): the
-- level up it would bring is refused, and the skill left where the cap meant it to be.
stubs.load(function()
    stubs.interfaces.SkillProgression.addSkillUsedHandler(function(_, params) params.skillGain = params.skillGain * 1.25 end)
end)
st.skills.destruction = { base = 50, modified = 50, progress = 0.99 }
stubs.cast(thirty, false)
check(st.skills.destruction.base == 50 and near(st.skills.destruction.progress, 0.999),
      "a miscast scaled up after its cap still raises no level", st.skills.destruction.progress)
st.skills.longblade = { base = 50, modified = 50, progress = 0.994 }
stubs.report { successful = false, strength = 1, weapon = longsword }
check(st.skills.longblade.base == 50 and near(st.skills.longblade.progress, 0.999), "nor does a miss",
      st.skills.longblade.progress)
stubs.cast(thirty, true)
check(st.skills.destruction.base == 51 and st.skills.destruction.progress == 0, "the cast that works does")

-- A handler that breaks under a miscast does not leave the skill held for the casts after it.
local breaks = true
stubs.load(function()
    stubs.interfaces.SkillProgression.addSkillUsedHandler(function() if breaks then error("broken") end end)
end)
st.skills.destruction = { base = 50, modified = 50, progress = 0.999 }
check(not pcall(stubs.cast, thirty, false), "someone else's error under a miscast is passed on")
breaks = false
stubs.cast(thirty, true)
check(st.skills.destruction.base == 51, "and the next cast that works still raises the skill")

--- actor.lua ----------------------------------------------------------------------------------------
stubs.load()
local onHit = stubs.loadActor()
onHit({ attacker = stubs.player, successful = false, strength = 0.4, type = 2, weapon = longsword, sourceType = "melee" })
onHit({ attacker = stubs.enemy, successful = true, strength = 1, type = 0, sourceType = "melee" })
onHit({ attacker = stubs.player, successful = true, sourceType = "magic" })
check(#st.sent == 1 and st.sent[1].name == "FairerWeaponAndMagicXP_Attack", "reports the player's attacks only, not spells",
      #st.sent)
local sent = st.sent[1] and st.sent[1].data or {}
check(sent.successful == false and sent.strength == 0.4 and sent.type == 2 and sent.weapon == longsword,
      "with whether it landed, its strength, its type and the weapon")

--- Logging ----------------------------------------------------------------------------------------
local function capture(fn)
    local lines, print_ = {}, print
    print = function(s) lines[#lines + 1] = s end
    fn()
    print = print_
    return table.concat(lines, "\n"), #lines
end

stubs.load(function() st.settings.logging = true end)
local out = capture(function()
    stubs.cast(thirty, true)
    stubs.cast(thirty, false)
    st.right = longsword
    stubs.skillUse("longblade", 0)
    stubs.report { type = 0, strength = 1, weapon = longsword }
    stubs.report { successful = false, type = 2, strength = 0, weapon = longsword }
end)
local function has(text) return out:find(text, 1, true) ~= nil end
check(has("[FairerWeaponAndMagicXP] destruction 1.00 -> 2.00 | cast thirty | x2.00 for its cost, 30 magicka"), "a cast", out)
check(has("[FairerWeaponAndMagicXP] destruction +0.66 | miscast thirty | x2.00 for its cost, 30 magicka")
      and has("x0.33 for a miscast"), "a miscast")
check(has("longblade 1.00 -> 1.15 | hit with steel longsword | x1.15 for the weapon: its weakest swing takes 0.58s (1x per 0.50s melee); the strength when reported"),
      "a hit, at once", out)
check(has("longblade +0.38 | hit with steel longsword, reported | x1.33 for the strength, 1.00 (x1 weakest, x1.33 full), over the 1.15 the hit taught"),
      "and its report")
check(has("longblade +0.23 | miss with steel longsword | x1.15 for the weapon: its weakest swing takes 0.58s (1x per 0.50s melee), x1.00 for the strength, 0.00 (x1 weakest, x1.33 full), x0.20 for a miss"),
      "a miss")

stubs.load()
local _, lines = capture(function() stubs.cast(thirty, false) end)
check(lines == 0, "and nothing with logging off", lines)

--- Errors -----------------------------------------------------------------------------------------
-- Something in the handler breaks: the hit still teaches its armor what it would have.
stubs.load()
stubs.interfaces.MSS.getActiveEffect = function() error("broken") end
local printed, count = capture(function()
    stubs.skillUse("heavyarmor", 0)
    stubs.skillUse("heavyarmor", 0)
end)
check(near(stubs.taughtTo("heavyarmor"), 2), "an error in this mod never costs a skill its experience")
check(count == 1 and printed:find("FairerWeaponAndMagicXP", 1, true), "and is reported once", count)

-- MSS is required: without it, say so and do nothing.
stubs.load(function() st.contentFiles["MaxYariScriptServices.omwscripts"] = nil end)
check(stubs.script.engineHandlers == nil and #st.messages == 1, "without MSS: a message, and nothing else")

--- Settings ---------------------------------------------------------------------------------------
stubs.load(function()
    st.settings.miscastShare, st.settings.boundShare, st.settings.shieldShare = 0, 0, 0
    st.weaponSettings.missShare = 0
end)
stubs.cast(godsFire, false)
bind()
st.right = stubs.item("weapon", "bound_longsword")
st.effects.shield = 10
stubs.skillUse("heavyarmor", 0)
stubs.report { successful = false, type = 0, weapon = longsword }
stubs.update()
check(stubs.taughtTo("destruction") + stubs.taughtTo("conjuration") + stubs.taughtTo("alteration")
      + stubs.taughtTo("longblade") == 0, "every share at 0 turns its part off")

print(string.format("\n%d checks, %d failures", checks, fails))
os.exit(fails == 0 and 0 or 1)
