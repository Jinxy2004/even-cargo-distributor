-- Cargo Distribution runtime. Unload rules are set per line stop from the stop window
-- and stored in this script's saved state, keyed by station (see core.stationKey).
-- Commands are only ever sent from serial postUpdate (see reports/CALLBACK-ERROR.md).
local core = ug_require "cargo_distribution_1::/cargo_distribution/core.lua"
local config = ug_require "cargo_distribution_1::/cargo_distribution/config.lua"
local M = {}
local CT = api.type.ComponentType
local EVENT_ID = "cargo_distribution_1"
local CONTROL = "CargoDistributionControl"

local function loadModeName(mode)
    for _, name in ipairs({"LOAD_IF_AVAILABLE", "FULL_LOAD_ANY", "FULL_LOAD_ALL", "LEGACY_UNLOAD_ONLY"}) do
        if mode == api.type.Line.LoadMode[name] then return name end
    end
    error("unknown native loading mode")
end

local function emit(saved, kind, data)
    local item = { tick = saved.tick, kind = kind, data = data }
    saved.log[#saved.log + 1] = item
    while #saved.log > config.maxLogEntries do table.remove(saved.log, 1) end
    if config.verbose or kind ~= "TRANSFER" then
        print("[CargoDistribution] " .. core.describe(item))
    end
end

local function catalog()
    local names, passenger = {}, api.res.cargoTypeRep.getPassengerCargoTypeId()
    for id, name in pairs(api.res.cargoTypeRep.getAll(true)) do
        if id ~= passenger then names[id] = name end
    end
    return names
end

local function amounts(vehicle)
    local values = {}
    for id, name in pairs(catalog()) do
        values[name] = api.engine.system.simEntityAtVehicleSystem
            .getVehicleSimEntitiesCountForCargoType(vehicle, id)
    end
    return values
end

local function capacities(vehicle, allConfigurations)
    local values = {}
    local component = api.engine.getComponent(vehicle, CT.TRANSPORT_VEHICLE)
    local native = component.config.capacities
    if allConfigurations then native = component.config.allCaps end
    for id, name in pairs(catalog()) do values[name] = native and native[id + 1] or 0 end
    return values
end

local function plainConfig(cfg)
    local result = { load = {}, maxLoad = {}, forceUnload = cfg.forceUnload,
        destroyForConfigChange = cfg.destroyForConfigChange, destroyForRefresh = cfg.destroyForRefresh }
    for i, v in ipairs(cfg.load) do result.load[i] = v end
    for i, v in ipairs(cfg.maxLoad) do result.maxLoad[i] = v end
    return result
end

local function nativeConfig(cfg)
    local result = api.type.Line.StopConfig.new()
    result.load = cfg.load
    result.maxLoad = cfg.maxLoad
    result.forceUnload = cfg.forceUnload
    result.destroyForConfigChange = cfg.destroyForConfigChange
    result.destroyForRefresh = cfg.destroyForRefresh
    return result
end

-- Same settings, allowing for float round-off in maxLoad.
local function sameConfig(a, b)
    if not a or not b then return false end
    if (a.forceUnload == true) ~= (b.forceUnload == true)
        or (a.destroyForConfigChange == true) ~= (b.destroyForConfigChange == true)
        or (a.destroyForRefresh == true) ~= (b.destroyForRefresh == true) then return false end
    local n = math.max(#a.load, #b.load, #a.maxLoad, #b.maxLoad)
    for i = 1, n do
        if (a.load[i] == true) ~= (b.load[i] == true) then return false end
        if math.abs((a.maxLoad[i] or 0) - (b.maxLoad[i] or 0)) > 1e-6 then return false end
    end
    return true
end

local function lineComponent(id)
    if not id or not api.engine.entityExists(id) then return nil end
    return api.engine.getComponent(id, CT.LINE)
end

local function lineRecord(saved, lineId)
    local key = tostring(lineId)
    saved.lines[key] = saved.lines[key] or { originals = {} }
    return saved.lines[key]
end

local function anyApplied(record)
    for _, original in pairs(record.originals) do
        if original.applied then return true end
    end
    return false
end

local function ruleFor(saved, lineId, station)
    local stations = saved.rules[tostring(lineId)]
    return stations and stations[station] or nil
end

local function writeStop(saved, lineId, station, cfg, loadMode, customFilters)
    local current = lineComponent(lineId)
    local index = current and core.stopIndexFor(current.stops, station)
    if not index then return false, "station_missing" end
    local copy = api.type.Line.new(current)
    local stops = copy.stops
    local stop = stops[index + 1]
    stop.stopConfig = nativeConfig(cfg)
    stop.loadMode = loadMode
    stops[index + 1] = stop
    copy.stops = stops
    copy.customFilters = customFilters
    local accepted = nil
    local ok, reason = pcall(api.cmd.sendCommand, api.cmd.makeLineUpdateCmd(lineId, copy), function(_, success)
        accepted = success
    end)
    if not ok then
        emit(saved, "COMMAND_ERROR", { line = lineId, station = station, reason = tostring(reason) })
        return false, "command_error"
    end
    if accepted ~= true then
        emit(saved, "COMMAND_NOT_CONFIRMED", { line = lineId, station = station, callback = tostring(accepted) })
    end
    return accepted == true
end

local function restoreStop(saved, lineId, station)
    local record = saved.lines[tostring(lineId)]
    local original = record and record.originals[station]
    if not original or not original.applied then return true end
    local current = lineComponent(lineId)
    local index = current and core.stopIndexFor(current.stops, station)
    if not index then
        record.originals[station] = nil
        emit(saved, "RESTORE_SKIPPED_STATION_REMOVED", { line = lineId, station = station })
        return true
    end
    -- If the player changed this stop while our temporary target was in place,
    -- their change wins; writing the old settings back would silently undo it.
    if original.written and not sameConfig(plainConfig(current.stops[index + 1].stopConfig), original.written) then
        record.originals[station] = nil
        emit(saved, "RESTORE_SKIPPED_PLAYER_EDIT", { line = lineId, station = station, stop = index + 1 })
        return true
    end
    original.applied = false
    local customFilters = anyApplied(record) or record.customFilters
    original.applied = true
    local ok = writeStop(saved, lineId, station, original.config,
        api.type.Line.LoadMode[original.loadMode], customFilters)
    if ok then
        record.originals[station] = nil
        emit(saved, "RESTORED", { line = lineId, station = station, stop = index + 1 })
    end
    return ok
end

local function restoreLine(saved, lineId)
    local record = saved.lines[tostring(lineId)]
    if not record then return end
    local stations = {}
    for station in pairs(record.originals) do stations[#stations + 1] = station end
    table.sort(stations)
    for _, station in ipairs(stations) do restoreStop(saved, lineId, station) end
end

local function anotherActive(saved, lineId, station, except)
    for vehicle, active in pairs(saved.active) do
        if vehicle ~= except and active.line == lineId and active.station == station then return true end
    end
    return false
end

-- 0.1.x state: map any still-applied stop-number record to its station once.
local function convertLegacy(saved)
    if not saved.legacyLines then return end
    for lineKey, record in pairs(saved.legacyLines) do
        local current = lineComponent(tonumber(lineKey))
        if current then
            for index, original in pairs(record.originals or {}) do
                local station = core.stationKey(current.stops, tonumber(index))
                if original.applied and station then
                    local target = lineRecord(saved, tonumber(lineKey))
                    target.customFilters = record.customFilters
                    target.originals[station] = original
                end
            end
        end
    end
    for _, active in pairs(saved.active) do
        if active.legacy and not active.station then
            local current = lineComponent(active.line)
            active.station = current and core.stationKey(current.stops, active.stop) or "legacy"
            active.targetStatus = active.targetStatus == "pending" and "legacy_unknown" or active.targetStatus
        end
    end
    saved.legacyLines = nil
    emit(saved, "MIGRATED_LEGACY_STATE", {})
end

-- Rules follow their station. Drop rules whose station or line no longer exists.
local function watchRules(saved)
    for lineKey, stations in pairs(saved.rules) do
        local current = lineComponent(tonumber(lineKey))
        if not current then
            saved.rules[lineKey] = nil
            emit(saved, "RULES_DROPPED_LINE_REMOVED", { line = tonumber(lineKey) })
        else
            for station in pairs(stations) do
                if not core.stopIndexFor(current.stops, station) then
                    stations[station] = nil
                    emit(saved, "RULE_DROPPED_STATION_REMOVED", { line = tonumber(lineKey), station = station })
                end
            end
            if next(stations) == nil then saved.rules[lineKey] = nil end
        end
    end
end

-- A restore can fail (e.g. a rejected command). Retry any that are still owed.
local function retryRestores(saved)
    for lineKey, record in pairs(saved.lines) do
        local lineId = tonumber(lineKey)
        for station, original in pairs(record.originals) do
            if original.applied and not anotherActive(saved, lineId, station) then
                restoreStop(saved, lineId, station)
            end
        end
        if next(record.originals) == nil then saved.lines[lineKey] = nil end
    end
end

local function arrive(saved, param)
    if saved.disabled then return end
    local vehicle, lineId, stopIndex = param.vehicleEntity, param.lineEntity, param.stopIndex
    local current = lineComponent(lineId)
    if not current then return end
    local station = core.stationKey(current.stops, stopIndex)
    local rule = station and ruleFor(saved, lineId, station)
    if not rule then return end
    local key = tostring(vehicle)
    if saved.active[key] then
        emit(saved, "DUPLICATE_OR_OVERLAPPING_ARRIVAL", { vehicle = vehicle, stop = stopIndex + 1 })
        return
    end
    local component = api.engine.getComponent(vehicle, CT.TRANSPORT_VEHICLE)
    if (api.engine.system.simEntityAtVehicleSystem.getVehicleSimEntitiesCountForCargoType(vehicle,
        api.res.cargoTypeRep.getPassengerCargoTypeId()) or 0) > 0 then
        emit(saved, "SKIPPED_PASSENGERS", { vehicle = vehicle }); return
    end
    -- maxLoad is a fraction of compatible capacity across all configurations, not
    -- just the compartments currently configured for this cargo.
    local ok, snapshot = pcall(core.snapshot, amounts(vehicle), capacities(vehicle, true), rule)
    if not ok then
        emit(saved, "PROBE_ERROR", { reason = tostring(snapshot), vehicle = vehicle })
        return
    end
    saved.sequence = saved.sequence + 1
    local active = { line = lineId, stop = stopIndex, station = station, sequence = saved.sequence,
        tick = saved.tick, snapshot = snapshot, unknownTransfers = 0,
        targetStatus = "pending",
        departureMarker = component.lastLineStopDeparture,
        overlap = anotherActive(saved, lineId, station, key) }
    if active.overlap then
        for _, other in pairs(saved.active) do
            if other.line == lineId and other.station == station then other.overlap = true end
        end
    end
    saved.active[key] = active
    local record = lineRecord(saved, lineId)
    local original = record.originals[station]
    if not original or not original.applied then
        if not anyApplied(record) then record.customFilters = current.customFilters end
        local stop = current.stops[stopIndex + 1]
        record.originals[station] = { config = plainConfig(stop.stopConfig),
            loadMode = loadModeName(stop.loadMode), applied = false }
    end
    emit(saved, "ARRIVAL", { vehicle = vehicle, line = lineId, stop = stopIndex + 1, station = station,
        sequence = active.sequence, overlap = active.overlap, cargo = snapshot,
        loadState = tostring(component.loadState), targetStatus = "pending",
        allCapacities = capacities(vehicle, true), configuredCapacities = capacities(vehicle) })
    -- Only the snapshot and pending status are saved here. postUpdate owns all commands.
end

local function applyPending(saved)
    local queue = {}
    for key, active in pairs(saved.active) do
        if active.targetStatus == "pending" then queue[#queue + 1] = { key = key, active = active } end
    end
    table.sort(queue, function(a, b) return a.active.sequence < b.active.sequence end)
    for _, pending in ipairs(queue) do
        local active, vehicle = pending.active, tonumber(pending.key)
        local record = saved.lines[tostring(active.line)]
        local original = record and record.originals[active.station]
        local current = lineComponent(active.line)
        local reason = nil
        if saved.disabled then reason = "disabled"
        elseif not current or not original or not core.stopIndexFor(current.stops, active.station) then
            reason = "station_removed"
        else
            local now, caps = amounts(vehicle), capacities(vehicle, true)
            if active.unknownTransfers > 0 then reason = "unattributed_transfer_before_target" end
            for name, item in pairs(active.snapshot) do
                if item.loaded > 0 or item.unloaded > 0 or (now[name] or 0) ~= item.arrival then
                    reason = "cargo_transferred_before_target"
                elseif (caps[name] or 0) ~= item.capacity then reason = "capacity_changed_before_target" end
            end
        end
        if reason then
            -- Only this arrival is skipped. The stop keeps its normal settings for it.
            active.targetStatus = "skipped"
            active.targetError = reason
            emit(saved, "TARGET_SKIPPED", { vehicle = vehicle, sequence = active.sequence,
                line = active.line, stop = active.stop + 1, reason = reason })
        else
            local candidate = core.copy(original.config)
            candidate.forceUnload, candidate.destroyForConfigChange, candidate.destroyForRefresh = false, false, false
            for id, name in pairs(catalog()) do
                local item = active.snapshot[name]
                candidate.load[id + 1] = item ~= nil and item.retained > 0
                candidate.maxLoad[id + 1] = item and item.target or 0
            end
            -- Keep restoration owed even if the callback is unexpectedly absent.
            original.applied = true
            original.written = candidate
            local accepted = writeStop(saved, active.line, active.station, candidate,
                api.type.Line.LoadMode.LOAD_IF_AVAILABLE, true)
            active.targetStatus = accepted and "applied" or "unconfirmed"
            active.appliedTick = saved.tick
            emit(saved, "TARGET_WRITTEN", { vehicle = vehicle, line = active.line, stop = active.stop + 1,
                station = active.station, sequence = active.sequence, arrivalTick = active.tick,
                applyTick = saved.tick, target = candidate, applied = accepted, commandPhase = "postUpdate" })
        end
    end
end

local function transfers(saved, name, param)
    for cargoEntity, target in pairs(param) do
        local atVehicle = api.engine.getComponent(cargoEntity, CT.SIM_ENTITY_AT_VEHICLE)
        local cargo = api.engine.getComponent(cargoEntity, CT.SIM_CARGO)
        local vehicle = atVehicle and atVehicle.vehicle or (name == "OnCargoLoaded" and target or nil)
        local active = vehicle and saved.active[tostring(vehicle)]
        if active then
            local resource = cargo and api.res.cargoTypeRep.getName(cargo.cargoType)
            local item = resource and active.snapshot[resource]
            if item then
                if name == "OnCargoLoaded" then item.loaded = item.loaded + 1
                else
                    item.unloaded = item.unloaded + 1
                    if type(target) == "table" and target[2] == true then
                        item.destroyed = item.destroyed + 1
                    end
                end
            else active.unknownTransfers = active.unknownTransfers + 1 end
            emit(saved, "TRANSFER", { sequence = active.sequence, vehicle = vehicle,
                event = name, cargo = resource or "unknown", item = cargoEntity, destination = target })
        elseif not vehicle and next(saved.active) then
            for _, pending in pairs(saved.active) do pending.unknownTransfers = pending.unknownTransfers + 1 end
            emit(saved, "UNATTRIBUTED_TRANSFER", { event = name, cargoEntity = cargoEntity })
        end
    end
end

local function finishDepartures(saved)
    local finished = {}
    for key, active in pairs(saved.active) do
        local vehicle = tonumber(key)
        local component = api.engine.entityExists(vehicle)
            and api.engine.getComponent(vehicle, CT.TRANSPORT_VEHICLE) or nil
        if not component or component.line ~= active.line or component.stopIndex ~= active.stop
            or component.lastLineStopDeparture ~= active.departureMarker then
            if component then
                local departure = amounts(vehicle)
                local result = core.evaluate(active.snapshot, departure, active.unknownTransfers)
                if active.targetStatus ~= "applied" then
                    result.exact = false
                    result.failures[#result.failures + 1] = "target_not_applied:" .. tostring(active.targetStatus)
                end
                if not result.safe then saved.failures = saved.failures + 1 end
                emit(saved, "RESULT", { sequence = active.sequence, vehicle = vehicle,
                    line = active.line, stop = active.stop + 1, station = active.station, overlap = active.overlap,
                    arrivalTick = active.tick, targetStatus = active.targetStatus, targetError = active.targetError,
                    cargo = active.snapshot, departure = departure, result = result })
            else
                emit(saved, "ABORTED_VEHICLE_REMOVED", { sequence = active.sequence, vehicle = vehicle })
            end
            finished[#finished + 1] = key
        end
    end
    for _, key in ipairs(finished) do
        local active = saved.active[key]
        saved.active[key] = nil
        if not anotherActive(saved, active.line, active.station) then
            restoreStop(saved, active.line, active.station)
        end
    end
end

-- Requests from the stop window. Runs inside a native event: state only, no commands.
local function control(saved, param)
    param = param or {}
    if param.action == "setRule" then
        local lineId, stopIndex = tonumber(param.line), tonumber(param.stopIndex)
        local current = lineComponent(lineId)
        local stop = current and stopIndex and current.stops[stopIndex + 1]
        if not stop or stop.stationGroup ~= param.stationGroup then
            emit(saved, "RULE_REJECTED", { line = lineId, stop = stopIndex, reason = "stop_changed" })
            return
        end
        local station = core.stationKey(current.stops, stopIndex)
        local lineKey = tostring(lineId)
        if not param.rule then
            if saved.rules[lineKey] then saved.rules[lineKey][station] = nil end
            if saved.rules[lineKey] and next(saved.rules[lineKey]) == nil then saved.rules[lineKey] = nil end
            emit(saved, "RULE_CLEARED", { line = lineId, station = station, stop = stopIndex + 1 })
            return
        end
        local rule, reason = core.normalizeRule(param.rule)
        if not rule then
            emit(saved, "RULE_REJECTED", { line = lineId, stop = stopIndex + 1, reason = reason })
            return
        end
        saved.rules[lineKey] = saved.rules[lineKey] or {}
        saved.rules[lineKey][station] = rule
        emit(saved, "RULE_SET", { line = lineId, station = station, stop = stopIndex + 1, rule = rule })
    elseif param.action == "disable" then
        saved.disabled = true
        saved.disablePending = true
        emit(saved, "DISABLE_QUEUED", { active = saved.active })
    elseif param.action == "enable" then
        saved.disabled = false
        emit(saved, "ENABLED", {})
    elseif param.action == "status" then
        emit(saved, "STATUS", { rules = saved.rules, lines = saved.lines })
    end
end

function M.update(_, state, dt)
    if not state:hasEventSubscriptions() then
        state:subscribeToEvent("OnArriveAtStop")
        state:subscribeToEvent("OnCargoLoaded")
        state:subscribeToEvent("OnCargoUnloaded")
        state:subscribeToEvent(CONTROL)
    end
    -- Parallel update can read an older snapshot than an intervening cargo event.
    -- Never set script state here: doing so overwrites the event's newer counters.
    local saved = state:get() or {}
    return { tick = (saved.tick or 0) + 1, advance = dt > 0 }
end

function M.postUpdate(_, state, dt, updateResult)
    if dt <= 0 or not updateResult or not updateResult.advance then return end
    local saved = core.migrate(state:get())
    -- An extra callback for the same tick must not issue a second line command.
    if saved.lastPostUpdateTick == updateResult.tick then return end
    saved.lastPostUpdateTick = updateResult.tick
    saved.tick = updateResult.tick
    if saved.version ~= config.version then
        saved.version = config.version
        emit(saved, "STARTUP", { version = config.version, build = getBuildVersion(), catalog = catalog() })
    end
    convertLegacy(saved)
    if saved.disablePending then
        for line in pairs(saved.lines) do restoreLine(saved, tonumber(line)) end
        saved.disablePending = false
        emit(saved, "DISABLED", { active = saved.active })
    end
    finishDepartures(saved)
    if saved.tick % 30 == 1 then
        watchRules(saved)
        retryRestores(saved)
    end
    applyPending(saved)
    state:set(saved)
end

function M.handleEvent(_, state, _, id, name, param)
    local saved = core.migrate(state:get())
    if name == CONTROL and id == EVENT_ID then
        control(saved, param)
    elseif id == "TransportVehicleSystem" then
        if name == "OnArriveAtStop" then arrive(saved, param)
        elseif name == "OnCargoLoaded" or name == "OnCargoUnloaded" then transfers(saved, name, param) end
    end
    state:set(saved)
end

-- .script.lua is a resource: the engine calls data(), unlike a plain Lua module.
function data()
    return M
end
