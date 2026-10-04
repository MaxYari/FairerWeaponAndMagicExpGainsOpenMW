-- The banner at the top of the settings page. Setting renderers exist only in the menu, so this one is
-- registered here; player.lua puts it in a group of its own, first on the page.
local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local util = require('openmw.util')

-- Twice the size it is shown at, so it stays sharp with the UI scaled up.
local BANNER = ui.texture { path = "textures/MaxYari/FairerMagicAndWeaponXP/banner.png" }

I.Settings.registerRenderer("FairerMagicAndWeaponXP_banner", function()
    return {
        type = ui.TYPE.Image,
        props = { resource = BANNER, size = util.vector2(420, 120) },
    }
end)

return {}
