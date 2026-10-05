-- Smoke test for unload_gui.script.lua with a fake React. It checks the module loads,
-- registers the replacement, wraps only the stop window, and that the card's controls
-- send well-formed setRule requests. It does NOT prove the real game GUI renders.
local core = dofile(source_root .. "/core.lua")
local count = 0
local function check(v, m) assert(v, m); count = count + 1 end
local names, sent, replaced = {}, {}, nil
local function widget(kind) return function(p) return { kind = kind, p = p } end end
local builtin = setmetatable({ type = { Orientation = { Vertical = "V", Horizontal = "H" }, ScrollBarPolicy = {} } },
    { __index = function(t, k) local w = widget(k); rawset(t, k, w); return w end })
local react = {}
local LAYOUTS = { BoxLayout = true, FloatingLayout = true, FlowLayout = true }
function react.RegisterRecipe(name, fn)
    local recipe = function(p)
        local out = fn(p)
        -- Native rule (build 40408): "Recipe child must be a layout".
        if name:match("^CargoDistribution") then
            assert(type(out) == "table" and LAYOUTS[out.kind], name .. " must return a builtin layout")
            count = count + 1
        end
        return { recipe = name, out = out }
    end
    names[recipe] = name
    return recipe
end
function react.GetRecipeName(r) return names[r] end
local viewStore = {}
function react.useState(initial)
    viewStore.value = viewStore.value or initial
    return { old = function() return viewStore.value end, set = function(_, v) viewStore.value = v end }
end
function react.CallOriginalRecipe(r, p) return r(p) end
local popover = { PopoverWindowContent = react.RegisterRecipe("PopoverWindowContent", function(p)
    return builtin.BoxLayout{ child = p.recipe(p.params), meta = p.meta } end) }
local committed
local engine_react_util = { useStepState = function(get, make)
    local value = get()
    return { old = function() return value end }, function(v) committed = v; sent[#sent + 1] = make(v) end
end }
local modules = {
    ["::/gui/main/react.lua"] = react, ["::/gui/main/builtin.lua"] = builtin,
    ["::/gui/main/popover_react_util.tl"] = popover,
    ["::/gui/main/content_card.tl"] = { ContentCard = widget("ContentCard") },
    ["::/gui/main/engine_react_util.tl"] = engine_react_util,
    ["::/gui/main/gui_react_util.tl"] = { IconLabelIndicator = widget("IconLabelIndicator") },
    ["cargo_distribution_1::/cargo_distribution/core.lua"] = core,
}
function ug_require(path) return assert(modules[path], "unexpected require " .. path) end
local scriptState = { rules = { ["1"] = { ["2#1"] = { percentage = 40, filter = "automatic", overrides = {} } } } }
api = { type = { ComponentType = { LINE = "LINE", TRANSPORT_VEHICLE = "TV", GAME_SCRIPT = "GS" } },
    res = { cargoTypeRep = {
        getAll = function() return { [0] = "pax", [1] = "::/cargos/meat/meat.cargo", [2] = "::/cargos/wool/wool.cargo" } end,
        getPassengerCargoTypeId = function() return 0 end,
        get = function(id) return ({ [1] = { name = "Meat", icon = "m.tga" }, [2] = { name = "Wool", icon = "w.tga" } })[id] end } },
    engine = { entityExists = function(id) return id == 1 end,
        getComponent = function(id, ct)
            if ct == "LINE" then return { stops = { { stationGroup = 1 }, { stationGroup = 2 }, { stationGroup = 3 } } } end
            if ct == "TV" then return { config = { allCaps = { 0, 50, 50 } } } end
            if ct == "GS" then return { state = scriptState } end
        end,
        system = { gameScriptSystem = { getEntityForGameScript = function(n)
                check(n == "cargo_distribution_1::/cargo_distribution/probe.gs", "script name"); return 77 end },
            transportVehicleSystem = { getLineVehicles = function() return { 500 } end } } },
    cmd = { makeScriptingSendEventCmd = function(src, id, name, p) return { id = id, name = name, p = p } end } }
data = nil
dofile(source_root .. "/unload_gui.script.lua")
local M = data()
M.doReplace({ ReplaceRecipe = function(orig, rep) replaced = { orig = orig, rep = rep } end })
check(replaced and replaced.orig == popover.PopoverWindowContent, "replaces the stock popover content")
-- Other popovers pass straight through.
local other = react.RegisterRecipe("SomethingElse", function(p) return "other" end)
local out = replaced.rep({ recipe = other, params = 1 })
check(out.out.p.children[1].out.p.child.recipe == "SomethingElse", "non-stop popovers unchanged")
check(out.out.p.children[1].out.p.meta.forceFocusable, "focus meta forwarded")
-- The stop window gets the card.
local stopContent = react.RegisterRecipe("CargoFilterContent", function(p) return "stock" end)
local params = { lineEntity = 1, stopIndex = 1 }
out = replaced.rep({ recipe = stopContent, params = params })
local box = out.out.p.children[1].out.p.child.out
local kids = box.p.children
check(kids[1].recipe == "CargoFilterContent", "stock content first")
check(kids[2].recipe == "CargoDistributionUnloadCard", "unload card below")
check(kids[2].out.kind == "BoxLayout", "card recipe returns a layout")
local card = kids[2].out.p.children[1].p
check(card.title == "Unload", "card title")
local items = card.extraChildrenPermanent
check(items[1].kind == "CheckBox" and items[1].p.value == 1, "existing rule shown as on")
local function render()
    local o = replaced.rep({ recipe = stopContent, params = params })
    return o.out.p.children[1].out.p.child.out.p.children[2].out.p.children[1].p.extraChildrenPermanent
end
local function find(list, kind) for _, it in ipairs(list) do if it.kind == kind then return it end end end
local function icons(list)
    local area = find(list, "ScrollArea"); local out = {}
    for _, row in ipairs(area.p.content.p.layout.p.children) do
        for _, b in ipairs(row.p.layout.p.children) do out[#out + 1] = b end
    end
    return out
end
-- View: "All cargo" level row.
local level = items[2].p.children[2]
check(level.kind == "Slider" and level.p.value == 40, "all-cargo slider shows saved level")
level.p.onValueChange(65)
check(sent[#sent].p.action == "setRule" and sent[#sent].p.rule.percentage == 65 and sent[#sent].p.stationGroup == 2, "slider sends rule")
check(core.normalizeRule(sent[#sent].p.rule) ~= nil, "sent rule is valid")
-- No overrides yet: only the + button.
local ic = icons(items)
check(#ic == 1 and ic[1].p.content.kind == "ImageView", "only the add button")
-- Add: + -> edit mode -> pick wool at 30%.
ic[1].p.onClick()
items = render()
check(items[1].p.children[1].p.text == "Unload Level", "edit mode shows level")
items[1].p.children[2].p.onValueChange(30)
items = render()
ic = icons(items)
check(#ic == 2, "picker lists every cargo type except passengers")
ic[2].p.onClick() -- Wool (sorted Meat, Wool)
check(sent[#sent].p.rule.overrides["::/cargos/wool/wool.cargo"] == 30, "wool gets its own level")
check(core.normalizeRule(sent[#sent].p.rule) ~= nil, "override rule is valid")
check(viewStore.value.mode == "View", "back to view after picking")
-- Saved override shows as an icon with its level; clicking edits, trash removes.
scriptState.rules["1"]["2#1"] = sent[#sent].p.rule
items = render(); ic = icons(items)
check(#ic == 2 and ic[1].p.content.p.label == "30%", "override icon labelled with level")
ic[1].p.onClick()
items = render()
check(items[1].p.children[2].p.value == 30, "editing shows that cargo's level")
items[1].p.children[2].p.onValueChange(45)
check(sent[#sent].p.rule.overrides["::/cargos/wool/wool.cargo"] == 45, "editing updates level")
find(items, "Button").p.onClick()
check(sent[#sent].p.rule.overrides["::/cargos/wool/wool.cargo"] == nil, "trash removes the override")
-- Turn off.
items = render()
items[1].p.onValueChange(0)
check(sent[#sent].p.rule == nil, "unchecking clears the rule")
-- No rule yet: only the checkbox, turning it on sends a default rule.
scriptState.rules = {}
items = render()
check(#items == 1 and items[1].p.value == 0, "off by default")
items[1].p.onValueChange(1)
check(sent[#sent].p.rule.percentage == 50 and core.normalizeRule(sent[#sent].p.rule), "default rule sent")
-- An older "selected cargo" rule is shown as levels: others 0%, meat 50%.
scriptState.rules = { ["1"] = { ["2#1"] = { percentage = 50, filter = "selected", goods = { ["::/cargos/meat/meat.cargo"] = true }, overrides = {} } } }
items = render()
check(items[2].p.children[2].p.value == 0, "legacy selected rule: other cargo 0%")
ic = icons(items)
check(ic[1].p.content.p.label == "50%", "legacy selected cargo shown with its level")
-- Script missing: friendly message, no crash.
api.engine.system.gameScriptSystem.getEntityForGameScript = function() return -1 end
items = render()
check(#items == 1 and items[1].kind == "TextView", "missing script handled")
print("GUI_SMOKE_PASSED=" .. count .. " (fake React only)")
