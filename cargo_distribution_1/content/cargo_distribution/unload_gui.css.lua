-- Styles for the Unload card. The game's stop-window styles are scoped to its own
-- recipe (R::CargoFilterContent), so the card needs its own scope to match the look
-- of the Load card. Uses only the game's colour tables and border image by reference.
local color_util = require "::/gui/main/color_util.tl"
local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
    local result = {}
    local a = ssu.makeAdder(result)
    local colors = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/default_colors.gres")).data
    local border = {
        fileName = "::/gui/entity_window/icons/card_border.tga",
        horizontal = { 0, 8, 9, 17 },
        vertical = { 0, 8, 9, 17 },
    }
    local card = "R::CargoDistributionUnloadCard"

    local function button(selector, color)
        a(card .. " " .. selector, { backgroundImage1 = border, backgroundColor1 = color })
        a(card .. " " .. selector .. ":hover", { borderColor = colors.Invisible,
            backgroundColor1 = color_util.getHoverFromRaw(color) })
        a(card .. " " .. selector .. ":active", { borderColor = colors.Invisible,
            backgroundColor1 = color_util.getActiveFromRaw(color) })
    end

    a(card, { minSize = { 460, -1 }, padding = { 0, 10, 10, 10 } })
    a(card .. " R::ContentCard", { size = { 445, -1 } })
    a(card .. " ScrollArea", { gravity = { -1, -1 }, maxSize = { -1, 240 } })
    a(card .. " TextView", { padding = { 3, 3, 3, 3 }, maxSize = { 420, -1 }, textAutoWrap = true })
    a(card .. " CheckBox", { gravity = { 0, 0 }, margin = { 4, 2, 4, 2 } })
    a(card .. " CheckBox TextView", { maxSize = { 380, -1 }, textAutoWrap = true, textAlignment = { 0, 0.5 } })
    a(card .. " Slider", { gravity = { -1, 0.5 } })

    a(card .. " Button!cargo-button", { gravity = { 0.5, 0.5 }, margin = { 2, 2, 2, 2 }, size = { 50, 50 } })
    button("Button!cargo-button", colors.AccentMedium)
    button("Button!cargo-button!selected", colors.AccentDark)
    button("Button!cargo-button!kept", colors.NeutralMedium)
    a(card .. " Button!cargo-button R::IconLabelIndicator", { gravity = { 0.5, 0.5 }, size = { 50, 50 } })
    a(card .. " Button!cargo-button TextView", { padding = { 3, 0, 3, 0 } })
    a(card .. " Button!cargo-button TextView!font-scale-annotation", { textAlignment = { 0.5, 1 } })
    a(card .. " Button!cargo-button ImageView", { gravity = { -1, -1 } })

    a(card .. " Button!cargo-button-small", { size = { 24, 24 }, padding = { 2, 2, 2, 2 } })
    button("Button!cargo-button-small", colors.AccentDark)
    a(card .. " Button!cargo-button-small ImageView", { padding = { 0, 0, 0, 1 }, gravity = { 0.5, 0.5 } })
    a(card .. " !right-align", { gravity = { 1, -1 } })

    return result
end
