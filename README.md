# ✦ Fairer Magic and Weapon Experience Gains for Sane People

A friendly adjustment of the way Magic and Weapon experience gains work. Doesnt aim to be an overhaul, but rather to simply illiminate some points of contention and unfairness, as well as reduce the dark-side pull of a common ways of exploiting the morrowind xp system for "effecient" skill leveling (quick attack spam, cheap "practice" spells). At the same time it's not an anti-cheese mod, previously "efficient" tactics are either slightly less efficient or as eficcient as before, BUT this mod makes normal skill use in combat more appealing and effective as a means of natural experience gain. The changes are quite succinct and are listed below:

- **Magic XP scales with spell cost.** Casting a spell that costs 15 or less magica grants 1x XP, while a spell costing 75 or more magica grants 5x XP.
- **Slow weapons grant more XP per hit, fast ones less.** A dagger hit teaches about 0.6x, a long sword
  1.15x, a two-handed axe 1.3x, a bow 1.9x. The exact multiplier depends on a true weapon speed, which is different from the speed displayed in the game since different weapons have different actual speed at 1.0 speed value due to differences in their animation durations.
- **Miscasts and misses still bring a little XP** You do learn from your failures! Only 1/3 of xp that you would've gotten otherwise and, additionally this exp can not actually level up the skill, you still need to succeed atleast once to get over the level up threshold.
- **Conjuration XP from bound gear and Alteration XP from shields**, being hit while under an Alteration shield or actively using a Conjured equipment - grants extra XP of the appropriate magic school.

Adjustible in setting: Options -> Scripts -> Fairer Magic and Weapon XP.

<p><a href="https://ko-fi.com/maxyari"><img src="imgs/morrowind_kofi_banner_left_half_bright124.gif" width="25.72%" align="top" alt="Support me on Ko-fi"></a><a href="https://ko-fi.com/maxyari"><img src="imgs/banner_right.png" width="73.88%" align="top" alt="Support me on Ko-fi"></a><br><a href="https://ko-fi.com/maxyari"><img src="imgs/banner_glow.png" width="99.6%" align="top" alt=""></a></p>

## ✦ How to install

- **Requires OpenMW 0.51 or newer.**
- Install and enable [Max Yari's Script Services (MSS)](https://www.nexusmods.com/morrowind/mods/60256), it's a required dependency.
- Install this mod **with a mod organiser**: download the archive (or this repository as an archive) and drag and drop it into your mod organiser of choice (e.g [Mod Organizer 2](https://github.com/ModOrganizer2/modorganizer/releases) on Windows or [Nerevarine Organizer](https://github.com/grazelandsnomad/nerevarine_organizer/releases/tag/v0.70) on Linux). **Or** [read this tutorial](https://modding-openmw.com/tips/installing-mods/) on how to install mods using the launcher or completely manually (it's also very easy).
- Enable `FairerMagicAndWeaponXP.omwscripts` in the "Content Files" tab of the OpenMW launcher, after `MaxYariScriptServices.omwscripts`.

Safe to add to or remove from a game in progress.

## ✦ Mod compatibility

Don't combine it with other mods that scale magic or weapon experience (MBSP, Skill Uses Scaled,
NCGDMW's magicka-based progression) - both would scale the same experience. Skill uncappers and
level-up overhauls are fine.

Modders: how it works, and its interface, is in the [technical notes](Sources/DEVELOPMENT.md).

## ✦ AI disclaimer

This mod is 95% AI slop, this kind of minor rebalance sounded like a great idea to me, especially in a context of my current playthough and I was not satisfied with the existing solutions (they are either too overloaded or just dont do what this mod does). I also had a paid slopmachine subscription at the time, so slopping this out was fairly straightforward. I am still using this in my playthrough and am quite satisfied with how sublte yet fair the changes are, so I think the mod deserved a right to not just be considered a mere slop. Cheers!
