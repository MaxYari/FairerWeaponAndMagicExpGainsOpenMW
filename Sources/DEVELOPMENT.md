# Fairer Weapon and Magic Experience Gain - technical notes

How the mod works and why its numbers are what they are, for modders and anyone curious. The
user-facing README is at the repository root. Engine references are to OpenMW 0.51's source; paths
are from the repository root. Requires OpenMW 0.51 and Max Yari's Script Services (MSS).

Scripts (`scripts/MaxYari/FairerWeaponAndMagicXP/`):

- `player.lua` - everything the player learns. Arithmetic in `scripts/formulas.lua`, swing lengths in
  `scripts/swing.lua`, settings in `scripts/settings.lua`.
- `combat.lua` (player) - wraps `I.Combat.pickRandomArmor`, to see which piece a hit lands on.
- `actor.lua` (every NPC and creature) - reports the player's attacks on it.

## Nothing per frame

No engine object is fetched per frame, and nothing but one flag is read per frame. Everything hangs off
events: the spellcast text keys, skill uses, hit reports from `actor.lua`, and the player's health
decreases, which MSS reads once per frame for every mod that asks (a health handle made once, one
number read). What has to wait for the rest of a frame's events - whether a release was followed by a
success, what a hit finally taught after every handler - is settled in `onUpdate`, which returns at
once on every frame where nothing happened. The magicka stat handle is made once, at load. Equipment
and active effects come from MSS's caches.

Per event, the costs are: a cast - its cost from its effects, and at release one sound check when the
magicka left is below the cost; a hit - the weapon's record, and while an item worth 0 is involved a
walk of the active spells; a health decrease - three cached effect reads, and with an elemental shield
up a walk of the active spells.

## What the engine does

**Experience.** A use of a skill hands `I.SkillProgression.skillUsed` a gain: the skill record's
`skillGain` for that kind of use (1.0 for every school, weapon and armor skill in vanilla - short blade
0.75), times a scale. The engine's own handler (`files/data-mw/scripts/omw/playerskillhandlers.lua`)
adds `gain / requirement` to the skill's progress, and

```
requirement = (skill + 1) × fMajorSkillBonus 0.75 | fMinorSkillBonus 1.0 | fMiscSkillBonus 1.25
                          × fSpecialSkillBonus 0.8 when the skill is of your specialization
```

So each point costs more than the one before: a major skill in your specialization takes 0.6 ×
(skill + 1) vanilla uses per point - 6.6 at 10, 30.6 at 50, 60.6 at 100.

Skill used handlers run newest first, and the engine's is registered first, so any mod's runs before
it and can change the gain it applies. All of them get the same table.

**A spell's cost** does not change with your skill. It is the record's cost, worked out from the
effects for a record flagged autocalc (`MWMechanics::calcSpellCost`); a player-made spell stores its
exact cost and is not flagged. Skill changes only the chance to cast it
(`calcSpellBaseSuccessChance`):

```
chance = (2 × skill - cost + 0.2 × Willpower + 0.1 × Luck) × fatigue term (1.25 at full fatigue)
```

where the skill is that of the spell's hardest effect for you - which is also the school a cast
trains. Only an enchantment's cost comes down with skill (Enchant).

**A cast** (`CharacterController::updateWeaponState`, `World::startSpellCast`,
`CharacterController::handleTextKey`, `CastSpell::cast`):

1. The spellcast animation starts. The engine checks the magicka (`current < cost` refuses) and
   takes it, then plays the animation, whose `<range> start` key fires at once.
2. At `<range> release` it rolls for success. A success casts and credits the school with a
   `Spellcast_Success` use - for a plain spell that can fail only (`spellIncreasesSkill`). A failure
   plays the school's failure sound and shows `sMagicSkillFail`; nothing reaches any script. Refused
   for magicka, the animation still plays through its release, and nothing is cast.

**A weapon attack** (`CharacterController::updateWeaponState`) plays in three sections, each at the
weapon's speed stat (fists at 1): the wind-up (`<type> start` to `<type> max attack`), the release
(`max attack` to `hit`, a weaker attack skipping a little of it), and the follow-through (`<size>
follow start` to `stop`, large for a strong attack). The next attack can only start once the
follow-through ends. The group played is the weapon type's own (`getWeaponAnimation`) if any loaded
animation has it, and otherwise the two-handed swords' for two-handed melee, the one-handed for the
rest. A successful hit credits the weapon's skill with `Weapon_SuccessfulHit` (`Npc::hit`) - no
strength, no attack type. Those, and every miss, go to the struck actor's scripts only, as the
`I.Combat` onHit `AttackInfo`: `successful`, `strength`, `type`, `weapon`, `sourceType`. A swing that
reaches no one reaches no script.

**Hits taken.** A melee or ranged hit that gets through to the victim's health credits one armor skill
with an `Armor_HitByOpponent` use: that of a piece picked at random (`I.Combat.pickRandomArmor`), or
Unarmored (`I.Combat.applyArmor`, `files/data-mw/scripts/omw/combat/local.lua`). Every step there is
called through `I.Combat`, so a script can override it.

**Shield spells.** Shield adds its magnitude to the armor rating (`getArmorRating`). Fire, Frost and
Lightning Shield add nothing to it: each adds its magnitude to the resistance against its own
element's damage (`getEffectResistanceAttribute`), and burns whoever hits you in melee
(`applyElementalShields`).

**Spells landing** reach no script: `Class::onHit` for a magical hit is C++ only. What a spell leaves
is an active spell on its target, and an instant one stays in the list until the start of the
engine's next `ActiveSpells::update` - after the scripts have run - so it is visible for a frame.

**The Lua event queue.** Text keys, skill uses and hits are queued as they happen and handed to the
scripts in order, before `onUpdate` (`LuaManager::update`). The release key is queued before the
success it causes, in the same frame. An event one script sends another arrives the next frame.

## Costly spells

```
1                                          for cost <= base
min(max, (cost / base) ^ k),  k = ln(max) / ln(top / base)     above it
```

With the defaults (base 15, top 75, max 5) k is exactly 1: the cost / 15, from 1x at 15 to 5x at 75.
Fireball (5), Fire Bite (6), Greater Fireball (10) and Shield (15) teach as in vanilla.

Whether a curve makes leveling speed up as you get better depends on what runs out first. Take the
best spell castable at 75% (Willpower 50, Luck 40, full fatigue: cost = 2 × skill - 46, never below
6), a major skill in your specialization, misses teaching nothing in vanilla and a third here, and a
pool of twice the Intelligence (a Breton with the Mage sign) growing from 60 Intelligence at skill 20
to 100 at 100.

| Skill | Cost | Pool | Bars per point, vanilla | Bars, this mod | Casts per point, vanilla | Casts, this mod |
| --- | --- | --- | --- | --- | --- | --- |
| 20 | 6 | 120 | 0.8 | 0.8 | 16.8 | 15.1 |
| 30 | 14 | 130 | 2.7 | 2.4 | 24.8 | 22.3 |
| 40 | 34 | 140 | 8.0 | 3.2 | 32.8 | 13.0 |
| 50 | 54 | 150 | 14.7 | 3.7 | 40.8 | 10.2 |
| 60 | 74 | 160 | 22.6 | 4.1 | 48.8 | 8.9 |
| 80 | 114 | 180 | 41.0 | 7.4 | 64.8 | 11.7 |
| 100 | 154 | 200 | 62.2 | 11.2 | 80.8 | 14.6 |

**Full bars of magicka per point** is how normal play goes, casting until the magicka is gone. Nothing
speeds up: the requirement grows about 5 times from 20 to 100, the pool about 1.7. Between 15 and 75
magicka every spell teaches the same per point of magicka, so a bar teaches the same whatever it is
spent on. Past 75 a costlier spell teaches less per magicka, which is the slowing down at the top.

**Casts per point** is a caster who rests to refill and casts again, for whom magicka is free. There
the straight line dips in the middle - the castable cost grows twice as fast as the requirement until
the cap - where a square root (k = 0.5) would stay flat. A higher top cost bends the curve that way.

Below the base cost the multiplier stays 1, so a 1-magicka spell teaches what it does in vanilla. That
is vanilla's spam, left as it was on purpose: this mod adds, it does not take away.

The cost is `formulas.spellCost`, a copy of `calcSpellCost` that works out an autocalc record's cost
from its effects and ignores the number stored in it (vanilla's stored numbers match the worked-out
ones but for Hearth Heal, 13 stored and 12 worked out).

## Miscasts

The `start` key's handler notes the selected spell and its cost. The `release` key moves it to
"released", and the skill used handler takes it from there when the success comes. If the frame's
`onUpdate` still finds it there, no success came, and it is settled:

- Magicka at the cost or above at the start key: it was paid - the engine takes it just before - so
  the roll failed. A miscast.
- Below: either never enough, or enough and taken. Only a failed roll plays the school's failure sound
  (`SkillRecord.school.failureSound`), so it is a miscast if that sound is playing on the player. With
  no audio at all, a miscast in this case is taken for running out of magicka.

A miscast teaches the school the engine would have credited (`formulas.castSchool`, a copy of
`calcSpellBaseSuccessChance`'s choice) a third of what the cast would have: the school's gain × the
cost multiplier × the miscast share. A release only counts for the range the cast started with: an
animation can hold all three. A success reported without the animation - a spellcasting mod calling
`skillUsed` itself - is scaled by the selected spell's cost; miscasts made that way are not seen.

## Weapons

**The numbers.** The swing lengths were measured once from ReAnimation's first-person animations, as
loaded (its third-person set is the same), and are stored in `swing.lua` per animation group: nothing
is read from the animations in game. Measured per attack type, from the text keys of the file the engine
plays each one from - the newest to have that type's start key, which is how `Animation::play` picks. The
full-strength swings, in seconds at speed 1, for reference:

| Group | Weapons (ReAnimation has no short blade, one-handed blunt or two-handed blunt groups: they fall back as the engine does) | Chop | Slash | Thrust |
| --- | --- | --- | --- | --- |
| weapononehand | short blades, one-handed long blades, blunt and axes | 1.200 | 1.133 | 1.000 |
| weapontwohand | two-handed long blades, axes and blunt | 1.133 | 1.067 | 1.000 |
| weapontwowide | staves, spears | 0.933 | 0.933 | 0.800 |
| handtohand | fists, katars, knuckledusters | 0.867 | 0.867 | 0.867 |
| bowandarrow / crossbow / throwweapon | shoot | 1.867 / 1.532 / 0.799 | | |

And the keys each weakest swing is made of, from "<type> start":

| Group, type | Min attack | Max attack | Min hit | Hit | Small follow-through | Weakest swing |
| --- | --- | --- | --- | --- | --- | --- |
| weapononehand chop / slash / thrust | 0.133 / 0.233 / 0.133 | 0.400 / 0.467 / 0.267 | 0.567 / 0.533 / 0.400 | 0.733 / 0.600 / 0.533 | 0.467 / 0.533 / 0.467 | **0.777** average |
| weapontwohand chop / slash / thrust | 0.067 / 0.100 / 0.100 | 0.467 | 0.533 / 0.500 / 0.500 | 0.700 / 0.667 / 0.633 | 0.433 / 0.400 / 0.367 | **0.645** |
| weapontwowide chop / slash / thrust | 0.033 | 0.267 | 0.333 / 0.333 / 0.300 | 0.500 / 0.467 / 0.467 | 0.433 / 0.467 / 0.333 | **0.600** |
| handtohand (all three) | 0.100 | 0.267 | 0.300 | 0.400 | 0.200 (medium 0.367, large 0.467) | **0.400** |
| bowandarrow / crossbow / throwweapon | 0.933 / 0.200 / 0.133 | 1.333 / 0.200 / 0.200 | 1.400 / 0.200 / 0.267 | 1.467 / 0.333 / 0.333 | 0.400 / 1.199 / 0.466 | **1.400 / 1.532 / 0.665** |

ReAnimation's tails (`<Type> Tail Start/Stop`, in `<group>extra` groups of their own) play after the
follow-through, are cosmetic, and are not counted. Katars and Knuckledusters' weapons use the
hand-to-hand lengths at their own speed: ReAnimation stretches the engine's one-handed attack to fit
their animations (`retimeParentToOverride`, section by section), and those are ReAnimation's
hand-to-hand ones.

**The weapon's multiplier.** Its weakest swing, averaged over its attack types, at its speed, in step:
`seconds / 0.5` for melee, `seconds / 0.75` for ranged, whose swing holds the draw and the reload. The
weakest swing, as the engine plays it (the `AttackRelease` branch): the wind-up up to "min attack", the
release from "min hit" - the animation jumps there from where it was released - to "hit", and the small
follow-through:

```
weak swing = (min attack - start) + (hit - min hit) + small follow-through
```

**Strength.** A full-strength attack teaches a third more than the weakest (the "Full-strength bonus"),
one in between in step with its strength. The swing's real length grows more than that with the
strength - by 43% for one-handed weapons, 65% for two-handed, 48% for spears and staves, 117% for
hand-to-hand, whose follow-through grows too - but one simple bonus for all is easier to play with.

| Weapon (typical speed) | Weakest swing | Weak hit | Full hit |
| --- | --- | --- | --- |
| Dagger (2.5) | 0.31s | 0.62x | 0.83x |
| Short blade (2.25) | 0.35s | 0.69x | 0.92x |
| Staff (1.75) | 0.34s | 0.69x | 0.92x |
| Bare fists, knuckledusters (1.0) | 0.40s | 0.80x | 1.07x |
| Katar (0.9) | 0.44s | 0.89x | 1.19x |
| Claymore (1.25) | 0.52s | 1.03x | 1.37x |
| Katana 1h (1.5) | 0.52s | 1.04x | 1.39x |
| Long blade 1h (1.35) | 0.58s | 1.15x | 1.53x |
| Mace (1.3) | 0.60s | 1.20x | 1.60x |
| Spear (1.0) | 0.60s | 1.20x | 1.60x |
| Axe 1h (1.25) | 0.62s | 1.24x | 1.65x |
| Axe 2h, warhammer (1.0) | 0.64s | 1.29x | 1.72x |
| Thrown (1.0) | 0.67s | 0.89x | 1.19x |
| Bow (1.0) | 1.40s | 1.87x | 2.49x |
| Crossbow (1.0) | 1.53s | 2.04x | 2.72x |

Two-handed attacks at speed 1 take about as long as one-handed ones, in vanilla's animations as in
ReAnimation's, so claymores (1.25) and longswords (1.35) swing at nearly the same pace: the game makes a
claymore heavy with damage and weight, not time. ReAnimation's one-handed weak attacks are a little
longer than vanilla's, which puts a weak longsword swing just above a weak claymore one.

**How a hit is taught.** The skill use comes at once, with nothing but the skill: the weapon's
multiplier is applied then, and the handler's params table kept. The strength comes a frame later from
`actor.lua`, on the struck actor, and `gain × bonus` is taught on top as a gain of its own
(`"weaponHit"`), `gain` being what the skill was finally taught after every handler. A hit whose report
never comes (half a second) has lost only that.

**Misses.** A report with `successful = false` teaches the weapon's skill a fifth of what the hit would
have: its gain × the weapon's multiplier × the strength's × 0.2.

**No level up from a miss or a miscast.** Their gains are capped in the skill used handler - after every
newer handler has had its say - to leave
the skill 0.001 of the way short of its next level: `(1 - 0.001 - progress) × requirement`, the
requirement from `I.SkillProgression.getSkillProgressRequirement`. A hit or a cast that works is what
takes it over. For Katars and Knuckledusters' weapons it is split between Hand
to Hand and the weapon skill by Katars' own share setting (`SettingsGlobalH2HWeapons.handToHandShare`),
as Katars splits a hit.

The cap alone holds only while the handlers still to run pass the gain on as it is. Those are the older
ones, of the mods loaded before this one, and some scale it: Sun's Dusk's well rested bonus, Perks of
Morrowind's Renaissance Man. The gain is then over the cap again when the engine's handler adds it, and
the skill levels up. So while a miss's or a miscast's gain is with the handlers, a skill level up
handler refuses a `usage` level up of that skill and sets its progress back to 0.999, logging "level up
refused". A level up handler newer than this mod's has already seen the level up that is then refused.

## Conjured gear

A hit with a bound weapon, a hit taken on a piece of bound armor and a block with a bound shield teach
Conjuration 0.33 of what they teach their own skill.

Bound gear is an item worth 0 while an effect with "bound" in its id is active. Vanilla's bound weapons
and armor, Tamriel Data's, Unofficial TR Spells' generated copies of them (made from those as
templates) and Katars' Bound Fist are all worth 0, and all come with such an effect. The school taught
is the bound effect's.

The weapon is the one in the right hand, the shield the one in the left. The armor piece is the one the
hit landed on, and only `I.Combat.applyArmor` knows it: `combat.lua` overrides `pickRandomArmor` - a
shallow copy of the interface it finds, so any other override stays in the chain - and hands the pick
to `player.lua`, which takes it with the armor use that follows in the same call. A pick taken at
another moment is ignored, and so is the one `player.lua` makes itself to price an elemental hit.

## Shield

An armor hit teaches Shield's school (Alteration) 0.33 of it while Shield is up.

For both this and conjured gear, the share is of what the skill was really taught: the handler keeps
the params table, and `onUpdate` reads its `skillGain` when every handler is done with it. This matters
with Katars and Knuckledusters, which splits a hit - it cuts the weapon skill's gain to 30% and credits
Hand to Hand 70% with a use of its own. Read at once, the share would be of 100% + 70% whenever Katars'
handler runs after this one; read afterwards, it is of 30% + 70%, in either order (`test_xp.lua`
checks both).

## Elemental shields

When the player's health drops (MSS's damage listener) with an elemental shield up, the active spells
are looked through. A temporary spell cast by someone else, with the damage effect of a shield that is
up, not there at an earlier look, teaches that shield's school a flat 0.33 (the shield share) - what a
third of a vanilla armor hit would be. Each spell counts once, however long it burns. A spell resisted in full, reflected or absorbed does no
damage and teaches nothing.

## What this mod adds, as others see it

Its own gains go through `I.SkillProgression.skillUsed` with a `skillGain`, no `useType`, and
`fairerWeaponAndMagicXP` set to `"miscast"`, `"weaponHit"`, `"miss"`, `"boundWeapon"`, `"boundArmor"`,
`"boundShield"`, `"shield"` or `"elementalShield"`. No `useType`, because they are not casts, hits or
armor uses: Unofficial TR Spells fires its on-cast effects from a school's `Spellcast_Success`, Katars
charges Mage Fury from it and splits every `Weapon_SuccessfulHit`, PerksOfMorrowind triggers perks on
them - none of which a miscast or a miss should do. A successful cast's or hit's own gain is multiplied
in place, and stays what it was.

`I.FairerWeaponAndMagicXP` (player) has `spellMultiplier(spellRecord)`, `costMultiplier(cost)`,
`spellCost(spellRecord)` and `swingProfile(weapon)`.

## Logging

With "Log experience" on (the default), every gain this mod gives or changes is one `print` - the
console (F10) and openmw.log:

```
[FairerWeaponAndMagicXP] <skill> <gain> | <what happened> | <each multiplier, and why>

[FairerWeaponAndMagicXP] Destruction 1.00 -> 2.27 | cast Lightning Storm | x2.27 for its cost, 34 magicka (1x up to 15, 5x from 75)
[FairerWeaponAndMagicXP] Destruction +0.75 | miscast Lightning Storm | x2.27 for its cost, 34 magicka (1x up to 15, 5x from 75), x0.33 for a miscast
[FairerWeaponAndMagicXP] Long Blade 1.00 -> 1.15 | hit with Steel Longsword | x1.15 for the weapon: its weakest swing takes 0.58s (1x per 0.50s melee); the strength when reported
[FairerWeaponAndMagicXP] Long Blade +0.38 | hit with Steel Longsword, reported | x1.33 for the strength, 1.00 (x1 weakest, x1.33 full), over the 1.15 the hit taught
[FairerWeaponAndMagicXP] Long Blade +0.23 | miss with Steel Longsword | x1.15 for the weapon: its weakest swing takes 0.58s (1x per 0.50s melee), x1.00 for the strength, 0.00 (x1 weakest, x1.33 full), x0.20 for a miss
[FairerWeaponAndMagicXP] Conjuration +0.33 | hit with a bound weapon | x0.33 of Long Blade's 1.00
[FairerWeaponAndMagicXP] Alteration +0.33 | Fire Damage taken under Fire Shield | the shield share, 0.33 of a vanilla use
[FairerWeaponAndMagicXP] Fire Bite | not enough magicka | nothing cast, nothing learned
```

## Performance

See *Nothing per frame* above.

## Tests

```
bash Sources/Tools/tests/run.sh
```

runs `test_xp.lua` against `stubs.lua`, fakes for the openmw API with a copy of the engine's skill
used handler chain. Lua 5.4.

## Building a release

Commits whose message starts with `[nexus]` are packed and uploaded to Nexus by
`.github/workflows/nexus-release.yml` once the tests pass; see the top of that file. The version is
the interface's `version` in `player.lua`. `.githooks/pre-commit` keeps `README.nexus.bbcode` in step
with `README.md` (`git config core.hooksPath .githooks` once per clone).
