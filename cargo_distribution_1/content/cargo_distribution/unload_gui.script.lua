-- Adds an "Unload" card to the bottom of the game's stop window (the window that
-- opens from a stop in the line manager). Uses the game's documented recipe
-- replacement hook (react-replacement-config, see unload_gui.res.lua): the stock
-- popover content is wrapped, and only the stop window gets the extra card.
local react = ug_require "::/gui/main/react.lua"
local builtin = ug_require "::/gui/main/builtin.lua"
local popover = ug_require "::/gui/main/popover_react_util.tl"
local content_card = ug_require "::/gui/main/content_card.tl"
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl"
local gui_react_util = ug_require "::/gui/main/gui_react_util.tl"
local entity_window_util = ug_require "::/gui/entity_window/entity_window_util.tl"
local core = ug_require "cargo_distribution_1::/cargo_distribution/core.lua"

local M = {}
local SCRIPT = "cargo_distribution_1::/cargo_distribution/cargo_distribution.gs"
local STOP_WINDOW_CONTENT = "CargoFilterContent" -- the game's stop window content recipe
local DEFAULT_PERCENT = 50

local function T(text)
    if type(_) == "function" then return _(text) end
    return text
end

local function body(text)
    return builtin.TextView{ meta = { class = "font-scale-body" }, text = text }
end

local function horizontal(children)
    return builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = children }
end

local function vertical(children)
    return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = children }
end

local function readScriptState()
    local ok, entity = pcall(api.engine.system.gameScriptSystem.getEntityForGameScript, SCRIPT)
    if not ok or not entity or entity < 0 then return nil end
    local component = api.engine.getComponent(entity, api.type.ComponentType.GAME_SCRIPT)
    return component and component.state or nil
end

-- Every cargo type in the game (passengers excluded), sorted by name.
local function cargoList()
    local passenger = api.res.cargoTypeRep.getPassengerCargoTypeId()
    local list = {}
    for id, name in pairs(api.res.cargoTypeRep.getAll(true)) do
        if id ~= passenger then
            local cargoType = api.res.cargoTypeRep.get(id)
            list[#list + 1] = { name = name, label = cargoType and cargoType.name or name,
                icon = cargoType and cargoType.icon or nil }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function makeData(params)
    if not params.lineEntity or not api.engine.entityExists(params.lineEntity) then return nil end
    local line = api.engine.getComponent(params.lineEntity, api.type.ComponentType.LINE)
    local stop = line and line.stops[params.stopIndex + 1]
    if not stop then return nil end
    local station = core.stationKey(line.stops, params.stopIndex)
    local state = readScriptState()
    local stations = state and state.rules and state.rules[tostring(params.lineEntity)]
    local rule = stations and stations[station] and core.copy(stations[station]) or nil
    return {
        available = state ~= nil,
        disabled = state ~= nil and state.disabled == true,
        stationGroup = stop.stationGroup,
        rule = rule,
        cargo = cargoList(),
    }
end

local function makeCommand(params, data)
    return api.cmd.makeScriptingSendEventCmd("cargo_distribution_gui", "cargo_distribution_1",
        "CargoDistributionControl", {
            action = "setRule",
            line = params.lineEntity,
            stopIndex = params.stopIndex,
            stationGroup = data.stationGroup,
            rule = data.rule,
        })
end

local ICON_ADD = "::/gui/line_vehicle_mgmt/icons/metadata_add.tga"
local ICON_TRASH = "::/gui/line_vehicle_mgmt/icons/trash_bin.tga"
local ICON_CANCEL = "::/gui/line_vehicle_mgmt/icons/symbol_trash_bin.tga"

local function percentText(value)
    return tostring(math.floor((value or 0) + 0.5)) .. "%"
end

-- Older rules may use the "selected cargo" filter. The card shows everything as one
-- level for all cargo plus per-cargo levels, which expresses the same rule:
-- cargo not selected = 0%.
local function asLevels(rule)
    if not rule or rule.filter ~= "selected" then return rule end
    local overrides = {}
    for name, on in pairs(rule.goods or {}) do
        if on then overrides[name] = (rule.overrides or {})[name] or rule.percentage end
    end
    return { percentage = 0, filter = "automatic", overrides = overrides }
end

local function slider(value, onChange)
    return builtin.Slider{ min = 0, max = 100, step = 1, value = value, onValueChange = onChange }
end

local function levelRow(label, value, onChange)
    return horizontal({ body(label), slider(value, onChange), body(percentText(value)) })
end

-- Rows of six icons, as in the game's Load card.
local function iconTable(icons)
    local rows, row = {}, {}
    for _, icon in ipairs(icons) do
        row[#row + 1] = icon
        if #row == 6 then
            rows[#rows + 1] = builtin.Component{ layout = horizontal(row) }
            row = {}
        end
    end
    if #row > 0 then rows[#rows + 1] = builtin.Component{ layout = horizontal(row) } end
    return builtin.ScrollArea{
        content = builtin.Component{ layout = vertical(rows) },
        horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
        verticalPolicy = builtin.type.ScrollBarPolicy.AsNeededButAlwaysReserveSpace,
    }
end

local function cargoIcon(cargo, label, classes, tooltip, onClick)
    return builtin.Button{
        meta = { class = classes, tooltip = tooltip or cargo.label, localKey = cargo.name },
        content = gui_react_util.IconLabelIndicator{ iconPath = cargo.icon, label = label },
        onClick = onClick,
    }
end

local UnloadCard = react.RegisterRecipe("CargoDistributionUnloadCard", function(params)
    local stateData, commit = engine_react_util.useStepState(
        function() return makeData(params) end,
        function(data) return makeCommand(params, data) end)
    -- View: the card. Edit: picking a cargo / setting its own level (like the Load card).
    local view = react.useState({ mode = "View", cargo = nil, value = 100 })
    local data = stateData:old()
    if not data then return vertical({}) end
    local v = view:old()

    local function setRule(rule)
        local nextData = core.copy(data)
        nextData.rule = rule
        commit(nextData)
    end
    local rule = asLevels(data.rule)
    local function edit(fn)
        local r = core.copy(rule)
        r.overrides = r.overrides or {}
        fn(r)
        setRule(r)
    end
    local function setView(mode, cargo, value)
        view:set({ mode = mode, cargo = cargo, value = value or 100 })
    end

    local children = {}
    if not data.available then
        children[#children + 1] = body(T("Cargo Distribution is not running in this game yet. Unpause for a moment, then reopen this window."))
    elseif rule and v.mode == "Edit" then
        local editing = v.cargo
        local value = editing and (rule.overrides or {})[editing] or v.value
        children[#children + 1] = levelRow(T("Unload Level"), value, function(newValue)
            if editing then
                edit(function(r) r.overrides[editing] = newValue end)
            else
                setView("Edit", nil, newValue)
            end
        end)
        local icons = {}
        for _, cargo in ipairs(data.cargo) do
            local has = (rule.overrides or {})[cargo.name] ~= nil
            if not has or cargo.name == editing then
                local classes = cargo.name == editing and "cargo-button, selected" or "cargo-button"
                icons[#icons + 1] = cargoIcon(cargo, nil, classes, cargo.label, function()
                    edit(function(r)
                        if editing and editing ~= cargo.name then r.overrides[editing] = nil end
                        r.overrides[cargo.name] = value
                    end)
                    setView("View")
                end)
            end
        end
        if #icons == 0 then
            children[#children + 1] = body(T("Every cargo already has its own level."))
        else
            children[#children + 1] = iconTable(icons)
        end
        children[#children + 1] = builtin.Button{
            meta = { class = "cargo-button-small, right-align",
                tooltip = editing and T("Remove") or T("Cancel") },
            content = builtin.ImageView{ path = editing and ICON_TRASH or ICON_CANCEL },
            onClick = function()
                if editing then edit(function(r) r.overrides[editing] = nil end) end
                setView("View")
            end,
        }
    else
        children[#children + 1] = builtin.CheckBox{
            value = rule and 1 or 0,
            label = T("Custom unloading at this stop"),
            onValueChange = function(value)
                setView("View")
                if value == 1 then
                    setRule({ percentage = DEFAULT_PERCENT, filter = "automatic", overrides = {} })
                else
                    setRule(nil)
                end
            end,
        }
        if data.disabled then
            children[#children + 1] = body(T("Cargo Distribution is currently switched off for this game."))
        end
        if rule then
            children[#children + 1] = levelRow(T("All cargo"), rule.percentage, function(value)
                edit(function(r) r.percentage = value end)
            end)
            local icons = {}
            for _, cargo in ipairs(data.cargo) do
                local level = (rule.overrides or {})[cargo.name]
                if level ~= nil then
                    local tooltip = level == 0 and (cargo.label .. " - " .. T("stays aboard")) or cargo.label
                    icons[#icons + 1] = cargoIcon(cargo, percentText(level),
                        level == 0 and "cargo-button, kept" or "cargo-button", tooltip, function()
                            setView("Edit", cargo.name)
                        end)
                end
            end
            icons[#icons + 1] = builtin.Button{
                meta = { class = "cargo-button", tooltip = T("Give a cargo its own unload level") },
                content = builtin.ImageView{ path = ICON_ADD },
                onClick = function() setView("Edit", nil, rule.percentage) end,
            }
            children[#children + 1] = iconTable(icons)
            children[#children + 1] = body(T("Levels apply to the cargo each vehicle carries when it arrives. 0% keeps that cargo aboard. Vehicles won't pick up cargo here while this is on."))
            children[#children + 1] = body(T("If two vehicles on this line unload here at the same time, both follow the most recent arrival."))
        end
    end

    -- A recipe placed inside a layout must itself return a builtin layout
    -- ("Recipe child must be a layout"), so the card is wrapped.
    return vertical({
        content_card.ContentCard{
            title = T("Unload"),
            extraChildrenPermanent = children,
        },
    })
end)

-- The stop window is a popover; this remembers the params of the one being shown.
-- The popover closes when clicking outside it, so only one stop window exists at a time,
-- and its content always renders after this (the popover content is its ancestor).
local activeStopParams = nil

local OriginalPopoverContent = popover.PopoverWindowContent

local PopoverContentReplacement = react.RegisterRecipe("CargoDistributionPopoverWindowContent", function(params)
    -- meta is stripped before a recipe body runs; every game caller passes this one.
    local forwarded = { meta = { forceFocusable = true } }
    for k, v in pairs(params or {}) do forwarded[k] = v end
    local recipe = forwarded.recipe
    if recipe and react.GetRecipeName(recipe) == STOP_WINDOW_CONTENT then
        activeStopParams = params.params
    end
    -- Like every recipe placed in a window/layout, return a builtin layout around the
    -- original node rather than the node itself ("Recipe child must be a layout").
    return vertical({ react.CallOriginalRecipe(OriginalPopoverContent, forwarded) })
end)

-- The card goes inside the stock content's own scroll list, after its cards. The stock
-- content handles gamepad up/down itself and never lets it leave its own subtree, so a
-- card placed beside it could not be reached with a controller. Its last call is
-- ContentWidgetScrollContainer(children, first), made synchronously inside its body, so
-- a plain-function replacement can tell (getCurrentRecipeName) that it was called from
-- the stop window and add the card to the list. Other windows are left as is.
local OriginalScrollContainer = entity_window_util.ContentWidgetScrollContainer

local function scrollContainerWithUnload(children, ...)
    if activeStopParams and react.getCurrentRecipeName() == STOP_WINDOW_CONTENT then
        local withCard = {}
        for i, child in ipairs(children or {}) do withCard[i] = child end
        withCard[#withCard + 1] = UnloadCard(activeStopParams)
        children = withCard
    end
    return react.CallOriginalRecipe(OriginalScrollContainer, children, ...)
end

function M.doReplace(replacementApi)
    replacementApi.ReplaceRecipe(OriginalPopoverContent, PopoverContentReplacement)
    replacementApi.ReplaceRecipe(OriginalScrollContainer, scrollContainerWithUnload)
end

function data()
    return M
end
