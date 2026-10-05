-- Pure Lua: no engine access. Integer quantities, persistent resource names.
local M = {}
M.schemaVersion = 3

function M.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = M.copy(v) end
    return result
end

local function percentage(p)
    return type(p) == "number" and p == p and p >= 0 and p <= 100
end

function M.validateRule(rule)
    if type(rule) ~= "table" or not percentage(rule.percentage) then
        return false, "percentage must be between 0 and 100"
    end
    if rule.filter ~= "automatic" and rule.filter ~= "selected" then
        return false, "filter must be automatic or selected"
    end
    if rule.filter == "selected" and type(rule.goods) ~= "table" then
        return false, "selected filter requires a goods allowlist"
    end
    for name, p in pairs(rule.overrides or {}) do
        if type(name) ~= "string" or not percentage(p) then
            return false, "overrides require cargo resource names and percentages"
        end
    end
    return true
end

-- Copy only the fields a rule may carry; rejects anything validateRule rejects.
function M.normalizeRule(rule)
    local valid, reason = M.validateRule(rule)
    if not valid then return nil, reason end
    local result = { percentage = rule.percentage, filter = rule.filter, overrides = {} }
    if rule.filter == "selected" then
        result.goods = {}
        for name, on in pairs(rule.goods) do
            if type(name) == "string" and on == true then result.goods[name] = true end
        end
    end
    for name, p in pairs(rule.overrides or {}) do result.overrides[name] = p end
    return result
end

-- Rules follow their station, not the stop number. The key is the station group plus
-- which visit to that group it is (a line may call at the same station twice).
-- stopIndex is zero-based, as in native events.
function M.stationKey(stops, stopIndex)
    local stop = stops and stops[stopIndex + 1]
    if not stop then return nil end
    local visit = 0
    for i = 1, stopIndex + 1 do
        if stops[i].stationGroup == stop.stationGroup then visit = visit + 1 end
    end
    return tostring(stop.stationGroup) .. "#" .. visit
end

function M.stopIndexFor(stops, key)
    for i = 1, #(stops or {}) do
        if M.stationKey(stops, i - 1) == key then return i - 1 end
    end
    return nil
end

function M.quota(quantity, p)
    assert(type(quantity) == "number" and quantity >= 0 and quantity % 1 == 0,
        "quantity must be a nonnegative integer")
    assert(percentage(p), "invalid percentage")
    return math.floor(quantity * p / 100 + 0.5)
end

function M.snapshot(arrival, capacities, rule)
    local valid, reason = M.validateRule(rule)
    assert(valid, reason)
    local result = {}
    for name, quantity in pairs(arrival) do
        local allowed = rule.filter == "automatic" or rule.goods[name] == true
        local p = allowed and (rule.overrides or {})[name] or nil
        if p == nil then p = allowed and rule.percentage or 0 end
        local unload = M.quota(quantity, p)
        local capacity = capacities[name] or 0
        assert(quantity == 0 or capacity >= quantity, "invalid capacity for " .. name)
        result[name] = {
            arrival = quantity, percentage = p, quota = unload,
            retained = quantity - unload, capacity = capacity,
            target = capacity > 0 and (quantity - unload) / capacity or 0,
            loaded = 0, unloaded = 0, destroyed = 0,
        }
    end
    return result
end

function M.evaluate(snapshot, departure, unknownTransfers)
    local failures = {}
    if (unknownTransfers or 0) > 0 then failures[#failures + 1] = "unattributed transfers" end
    for name, item in pairs(snapshot) do
        if item.loaded > 0 then failures[#failures + 1] = "picked up " .. name end
        if item.destroyed > 0 then failures[#failures + 1] = "destroyed " .. name end
        if item.unloaded > item.quota then failures[#failures + 1] = "over-unloaded " .. name end
        if (departure[name] or 0) < item.retained then
            failures[#failures + 1] = "retained below target " .. name
        end
        if (departure[name] or 0) ~= item.arrival + item.loaded - item.unloaded then
            failures[#failures + 1] = "cargo conservation mismatch " .. name
        end
    end
    -- Under-delivery may mean a full/incompatible warehouse. It is not an exact-pass result.
    local exact = #failures == 0
    for name, item in pairs(snapshot) do
        if item.unloaded ~= item.quota or (departure[name] or 0) ~= item.retained then
            exact = false
        end
    end
    return { safe = #failures == 0, exact = exact, failures = failures }
end

function M.route(stops)
    local parts = {}
    for i, stop in ipairs(stops) do
        local via = {}
        for _, waypoint in ipairs(stop.waypoints or {}) do
            local ep, pos = waypoint.edgePos, waypoint.pos
            via[#via + 1] = table.concat({tostring(waypoint.tag),
                ep and tostring(ep.edgeId.entity) or "", ep and tostring(ep.edgeId.index) or "",
                ep and tostring(ep.param) or "", pos and tostring(pos.x) or "",
                pos and tostring(pos.y) or "", pos and tostring(pos.z) or ""}, "/")
        end
        local alt = {}
        for _, terminal in ipairs(stop.alternativeTerminals or {}) do
            alt[#alt + 1] = tostring(terminal.station) .. "/" .. tostring(terminal.terminal)
        end
        parts[i] = table.concat({ tostring(stop.stationGroup), tostring(stop.station),
            tostring(stop.terminal), table.concat(alt, ","), table.concat(via, ",") }, ":")
    end
    return table.concat(parts, "|")
end

-- Deliberately deterministic, compact log encoding; does not depend on a JSON library.
function M.describe(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. M.describe(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

function M.newState()
    return { schemaVersion = M.schemaVersion, tick = 0, sequence = 0,
        lines = {}, rules = {}, active = {}, log = {}, disabled = false, failures = 0 }
end

function M.migrate(saved)
    if not saved or not saved.schemaVersion then return M.newState() end
    if saved.schemaVersion == 1 then
        -- Never recalculate or replay a pre-upgrade arrival: its command status is unknown.
        for _, active in pairs(saved.active or {}) do active.targetStatus = "legacy_unknown" end
        saved.disablePending = saved.disabled
        saved.schemaVersion = 2
    end
    if saved.schemaVersion == 2 then
        -- 0.1.x opted lines in by name with stop-number rules from config.lua. Rules now
        -- come from the stop window. Old records are kept only so the runtime can map any
        -- still-applied target to its station and restore it; no old rule is carried over.
        saved.legacyLines = saved.lines or {}
        saved.lines = {}
        saved.rules = {}
        for _, active in pairs(saved.active or {}) do active.legacy = true end
        saved.schemaVersion = 3
    end
    assert(saved.schemaVersion == M.schemaVersion, "unsupported saved-state version")
    return saved
end

return M
