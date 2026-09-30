# ✦ Fairer Weapon and Magic Experience Gain

Experience that follows what you actually do. In vanilla Morrowind every successful cast teaches the
same and every hit teaches the same, so the fastest way to learn is a 1-magicka spell or a dagger
jab, repeated a thousand times, and the big spells and heavy weapons you actually fight with teach no
more than that. Here:

**Magic**

- **Costly spells teach more.** Anything up to 15 magicka teaches exactly as in vanilla; above that a
  cast teaches in step with its cost, up to **5x** for a spell of 75 magicka or more.
- **A miscast still teaches** a third of what the cast would have - up to the skill's next level, never
  over it: that takes a cast that works. Running out of magicka is not a miscast, and teaches nothing.
- **Conjured gear teaches Conjuration.** A hit with a bound weapon, a hit taken on a piece of bound
  armor and a block with a bound shield teach Conjuration a third of what they teach their own skill,
  on top of it.
- **Shield spells teach Alteration.** A hit taken under a shield spell teaches Alteration a third of
  a vanilla hit's worth - as long as it is the kind that shield wards off: a weapon or a claw under
  **Shield** (a third of what it teaches your armor), fire under **Fire Shield**, frost under **Frost
  Shield**, shock under **Lightning Shield**.

**Weapons**

- **Slow weapons teach more per hit.** How long the weapon's weakest swing takes - the attack animation
  the game plays for it, at its speed, wind-up to follow-through - decides it: half a second of it
  teaches one vanilla hit, three quarters of a second for ranged weapons. A dagger teaches less than
  vanilla, a two-handed axe about a third more.
- **Strong attacks teach a third more.** An attack wound up all the way teaches a third more than the
  weakest one, and in between in step with how far you wound it up.
- **A miss still teaches** a fifth of what the hit would have - a real miss, where the swing reached
  its target, and up to the skill's next level, never over it: that takes a hit. A swing at the air
  teaches nothing.

Developed for OpenMW. **Requires OpenMW 0.51+** and
[Max Yari's Script Services](https://www.nexusmods.com/morrowind/mods/60256).

<p><a href="https://ko-fi.com/maxyari"><img src="imgs/morrowind_kofi_banner_left_half_bright124.gif" width="25.72%" align="top" alt="Support me on Ko-fi"></a><a href="https://ko-fi.com/maxyari"><img src="imgs/banner_right.png" width="73.88%" align="top" alt="Support me on Ko-fi"></a><br><a href="https://ko-fi.com/maxyari"><img src="imgs/banner_glow.png" width="99.6%" align="top" alt=""></a></p>

## ✦ How much more

What a successful cast teaches, for some vanilla spells (their cost in brackets):

- **1x**, as vanilla - Fireball (5), Fire Bite (6), Greater Fireball (10), Shield (15), and anything
  cheaper
- **1.7x** - Firebloom (26)
- **2.3x** - Lightning Storm (34)
- **3x** - Fire Shield (45)
- **5x** - God's Fire (135), Tap Energy (180), and anything else from 75 up

What a typical weapon hit teaches, from the weakest attack to one wound up all the way:

- **0.62x - 0.83x** - daggers
- **0.69x - 0.92x** - short swords, staves
- **0.8x - 1.07x** - bare fists, knuckledusters
- **0.89x - 1.19x** - katars (Katars and Knuckledusters), thrown weapons
- **1.03x - 1.37x** - claymores
- **1.15x - 1.53x** - one-handed long swords
- **1.2x - 1.6x** - maces, spears
- **1.24x - 1.65x** - one-handed axes
- **1.29x - 1.72x** - two-handed axes, warhammers
- **1.87x - 2.49x** - bows; **2.04x - 2.72x** - crossbows

The swing lengths were measured from [ReAnimation](https://www.nexusmods.com/morrowind/mods/52596)'s
animations, and the mod uses them whatever animations you have; vanilla's are close.

<details>
<summary>Won't leveling fly by once I can cast the big spells?</summary>

No. Between 15 and 75 magicka, every spell teaches the same for the magicka it costs, so what you
learn from a full bar of magicka is the same whichever spells you spend it on - and each point of a
skill takes a little more experience than the one before it (skill + 1, times your major/minor
multiplier), while your magicka grows much more slowly than that. Casting the best spell you can
reliably cast, a point of a major skill takes about one full bar at skill 20, three at 40, four at 60
and eleven at 100. In vanilla, the same spells would take one, eight, twenty-three and sixty-two.

What changes is that the spells you fight with are no longer the slow way to learn. A 1-magicka spell
cast over and over still teaches as much as it does in vanilla.

</details>

## ✦ How to install

**Requires OpenMW 0.51+**

1) Install [Max Yari's Script Services](https://www.nexusmods.com/morrowind/mods/60256) if you don't
   have it yet.
2) Install this mod **with a mod organiser**: download the archive and drag and drop it into your mod
   organiser of choice (e.g [Mod Organizer 2](https://github.com/ModOrganizer2/modorganizer/releases)
   on Windows or [Nerevarine Organizer](https://github.com/grazelandsnomad/nerevarine_organizer/releases/tag/v0.70)
   on Linux).
   **Or**: [read this tutorial](https://modding-openmw.com/tips/installing-mods/) on how to install
   mods using the launcher or completely manually (it's also very easy).
3) Enable `FairerWeaponAndMagicXP.omwscripts` in the "Content Files" tab of the OpenMW launcher, after
   `MaxYariScriptServices.omwscripts`.

It can be added to or removed from a game in progress at any time. It adds nothing to your save.

## ✦ Settings

Options -> Scripts -> Fairer Weapon and Magic Experience Gain. Every number above is a setting:

- **Magic**: the cost that teaches as vanilla (15), the cost of a top spell (75), the most a cast can
  teach (5x), and the three shares - miscast (0.33), conjured gear (0.33) and shield (0.33).
- **Weapons**: the seconds of a weapon's weakest swing that teach a vanilla hit, melee (0.5) and
  ranged (0.75), the full-strength bonus (0.33), and misses (0.2).

A share of 0 turns that part off. "Log experience" (on) writes a line to the console (F10) and
openmw.log for every bit of experience the mod gives or changes: which skill, how much, what for, and
every multiplier with its reason.

## ✦ Mod compatibility

Fairer Weapon and Magic Experience Gain hands every gain to the game's own skill progression, so mods that change how skills
level up - uncappers, level-up overhauls - see it as they would any other experience. It does no work
per frame beyond reading one flag.

- **Other mods that scale magic or weapon experience** - MBSP, Skill Uses Scaled, NCGDMW's
  magicka-based progression: use one or the other, or both scale the same experience.
- **Other mods that give experience for miscasts** - Failed Spell Progress, FailureXP: set "Miscast
  experience" to 0 here, or turn theirs off.
- **[Katars and Knuckledusters](https://github.com/MaxYari/Katars-KnucklesOpenMW)**: katars and
  knuckledusters swing with the hand-to-hand animations, and are measured that way. Bound Fist teaches
  Conjuration too, and a miss is split between Hand to Hand and the weapon skill as Katars splits a hit.
- **[Unofficial Tamriel Rebuilt Spells](https://www.nexusmods.com/morrowind/mods/58693)** and Tamriel
  Rebuilt: their bound weapons and armor count, scaled ones included.
- **Oblivion-Style Spell Casting / Spell Framework Plus**: not tried. They cast in their own way, so
  miscasts made through them teach nothing here.

## ✦ Credits

- Scripts: Max Yari

## ✦ For modders

`I.FairerWeaponAndMagicXP` (player) has `spellMultiplier(spellRecord)`, `costMultiplier(cost)`,
`spellCost(spellRecord)` and `swingProfile(weapon)`. The experience this mod adds reaches skill used
handlers with no `useType` and a `fairerWeaponAndMagicXP` field saying where it came from (`"miscast"`,
`"weaponHit"`, `"miss"`, `"boundWeapon"`, `"boundArmor"`, `"boundShield"`, `"shield"` or
`"elementalShield"`). It also overrides `I.Combat.pickRandomArmor` on the player, passing everything
through, to see which piece a hit lands on, and puts a small script on every NPC and creature that
reports the player's attacks on them. How all of it works is in the
[technical notes](Sources/DEVELOPMENT.md) in the git repository.
