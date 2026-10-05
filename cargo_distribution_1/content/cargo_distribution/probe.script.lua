-- Experimental adapter. Do not promote this to a release without the native gate.
local core = ug_require "cargo_distribution_1::/cargo_distribution/core.lua"
local config = ug_require "cargo_distribution_1::/cargo_distribution/config.lua"
local M = {}
local CT = api.type.ComponentType

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
    print("[CargoDistribution] " .. core.describe(item))
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
    local native = allConfigurations and component.config.allCaps or component.config.capacities
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

local function lineComponent(id)
    if not api.engine.entityExists(id) then return nil end
    return api.engine.getComponent(id, CT.LINE)
end

local function replaceStop(saved, lineId, stopIndex, cfg, loadMode, customFilters)
    local current = lineComponent(lineId)
    if not current then return false end
    local record = saved.lines[tostring(lineId)]
    if record.route ~= core.route(current.stops) then
        record.suspended = true
        emit(saved, "RESTORE_BLOCKED_ROUTE_CHANGED", { line = lineId, stop = stopIndex + 1 })
        return false
    end
    local copy = api.type.Line.new(current)
    local stops = copy.stops
    local stop = stops[stopIndex + 1]
    stop.stopConfig = nativeConfig(cfg)
    stop.loadMode = loadMode
    stops[stopIndex + 1] = stop
    copy.stops = stops
    copy.customFilters = customFilters
    -- Only called from postUpdate. Arrival events are inside a native transaction;
    -- update runs in a restricted parallel context that explicitly rejects callbacks.
    local accepted = nil
    local ok, reason = pcall(api.cmd.sendCommand, api.cmd.makeLineUpdateCmd(lineId, copy), function(_, success)
        accepted = success
    end)
    if not ok then
        emit(saved, "COMMAND_ERROR", { line = lineId, stop = stopIndex + 1, reason = tostring(reason) })
        return false
    end
    if accepted ~= true then
        emit(saved, "COMMAND_NOT_CONFIRMED", { line = lineId, stop = stopIndex + 1,
            callback = tostring(accepted) })
    end
    return accepted == true
end

local function restoreStop(saved, lineId, stopIndex)
    local record = saved.lines[tostring(lineId)]
    local original = record and record.originals[tostring(stopIndex)]
    if not original or not original.applied then return true end
    local otherApplied = false
    for key, v in pairs(record.originals) do
        if key ~= tostring(stopIndex) and v.applied then otherApplied = true end
    end
    local ok = replaceStop(saved, lineId, stopIndex, original.config,
        api.type.Line.LoadMode[original.loadMode], otherApplied or record.customFilters)
    if ok then
        original.applied = false
        emit(saved, "RESTORED", { line = lineId, stop = stopIndex + 1 })
    end
    return ok
end

local function restoreLine(saved, lineId)
    local record = saved.lines[tostring(lineId)]
    if not record then return end
    for index in pairs(record.originals) do restoreStop(saved, lineId, tonumber(index)) end
    record.suspended = true
end

local function anotherActive(saved, lineId, stopIndex, except)
    for vehicle, active in pairs(saved.active) do
        if vehicle ~= except and active.line == lineId and active.stop == stopIndex then return true end
    end
    return false
end

local function watchLines(saved)
    for _, lineId in ipairs(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer())) do
        local name = api.engine.util.getEntityName(lineId)
        local key = tostring(lineId)
        local record = saved.lines[key]
        local current = lineComponent(lineId)
        if record and (name ~= config.lineName or saved.disabled) then
            restoreLine(saved, lineId)
        elseif record and core.route(current.stops) ~= record.route then
            if not record.suspended then emit(saved, "SUSPENDED_ROUTE_CHANGED", { line = lineId }) end
            record.suspended = true
        elseif not record and name == config.lineName and not saved.disabled then
            saved.lines[key] = { route = core.route(current.stops),
                customFilters = current.customFilters, originals = {}, suspended = false }
            emit(saved, "ARMED", { line = lineId, name = name, rules = config.rules })
        end
    end
end

local function arrive(saved, param)
    local vehicle, lineId, stopIndex = param.vehicleEntity, param.lineEntity, param.stopIndex
    local record = saved.lines[tostring(lineId)]
    local rule = config.rules[stopIndex + 1]
    if saved.disabled or not record or record.suspended or not rule then return end
    if api.engine.util.getEntityName(lineId) ~= config.lineName then return end
    local current = lineComponent(lineId)
    if not current or core.route(current.stops) ~= record.route then record.suspended = true; return end
    local key = tostring(vehicle)
    if saved.active[key] then
        emit(saved, "DUPLICATE_OR_OVERLAPPING_ARRIVAL", { vehicle = vehicle, stop = stopIndex + 1 })
        return
    end
    local component = api.engine.getComponent(vehicle, CT.TRANSPORT_VEHICLE)
    local quantities = amounts(vehicle)
    if (api.engine.system.simEntityAtVehicleSystem.getVehicleSimEntitiesCountForCargoType(vehicle,
        api.res.cargoTypeRep.getPassengerCargoTypeId()) or 0) > 0 then
        emit(saved, "SKIPPED_PASSENGERS", { vehicle = vehicle }); return
    end
    local ok, snapshot = pcall(core.snapshot, quantities, capacities(vehicle), rule)
    if not ok then
        record.suspended = true
        emit(saved, "PROBE_ERROR", { reason = tostring(snapshot), vehicle = vehicle })
        return
    end
    saved.sequence = saved.sequence + 1
    local active = { line = lineId, stop = stopIndex, sequence = saved.sequence,
        tick = saved.tick, snapshot = snapshot, unknownTransfers = 0,
        targetStatus = "pending",
        departureMarker = component.lastLineStopDeparture,
        overlap = anotherActive(saved, lineId, stopIndex, key) }
    if active.overlap then
        for _, other in pairs(saved.active) do
            if other.line == lineId and other.stop == stopIndex then other.overlap = true end
        end
    end
    saved.active[key] = active
    local original = record.originals[tostring(stopIndex)]
    if not original then
        local stop = current.stops[stopIndex + 1]
        original = { config = plainConfig(stop.stopConfig), loadMode = loadModeName(stop.loadMode), applied = false }
        record.originals[tostring(stopIndex)] = original
    end
    emit(saved, "ARRIVAL", { vehicle = vehicle, line = lineId, stop = stopIndex + 1,
        sequence = active.sequence, overlap = active.overlap, cargo = snapshot,
        loadState = tostring(component.loadState), targetStatus = "pending",
        allCapacities = capacities(vehicle, true) })
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
        local current = lineComponent(active.line)
        local reason = nil
        if saved.disabled or not record or record.suspended then reason = "disabled_or_suspended"
        elseif not current or record.route ~= core.route(current.stops) then reason = "route_changed"
        elseif api.engine.util.getEntityName(active.line) ~= config.lineName then reason = "line_renamed"
        else
            local now, caps = amounts(vehicle), capacities(vehicle)
            if active.unknownTransfers > 0 then reason = "unattributed_transfer_before_target" end
            for name, item in pairs(active.snapshot) do
                if item.loaded > 0 or item.unloaded > 0 or (now[name] or 0) ~= item.arrival then
                    reason = "cargo_transferred_before_target"
                elseif (caps[name] or 0) ~= item.capacity then reason = "capacity_changed_before_target" end
            end
        end
        if reason then
            active.targetStatus = "skipped"
            active.targetError = reason
            if record then record.suspended = true end
            emit(saved, "TARGET_SKIPPED", { vehicle = vehicle, sequence = active.sequence,
                line = active.line, stop = active.stop + 1, reason = reason })
        else
            local original = record.originals[tostring(active.stop)]
            local candidate = core.copy(original.config)
            candidate.forceUnload, candidate.destroyForConfigChange, candidate.destroyForRefresh = false, false, false
            for id, name in pairs(catalog()) do
                local item = active.snapshot[name]
                candidate.load[id + 1] = item ~= nil and item.retained > 0
                candidate.maxLoad[id + 1] = item and item.target or 0
            end
            -- Keep restoration owed even if the callback is unexpectedly absent.
            original.applied = true
            local accepted = replaceStop(saved, active.line, active.stop, candidate,
                api.type.Line.LoadMode.LOAD_IF_AVAILABLE, true)
            active.targetStatus = accepted and "applied" or "unconfirmed"
            active.appliedTick = saved.tick
            if not accepted then record.suspended = true end
            emit(saved, "TARGET_WRITTEN", { vehicle = vehicle, line = active.line, stop = active.stop + 1,
                sequence = active.sequence, arrivalTick = active.tick, applyTick = saved.tick,
                target = candidate, applied = accepted, commandPhase = "postUpdate" })
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
                    line = active.line, stop = active.stop + 1, overlap = active.overlap,
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
        if not anotherActive(saved, active.line, active.stop) then restoreStop(saved, active.line, active.stop) end
    end
end

function M.update(_, state, dt)
    if not state:hasEventSubscriptions() then
        state:subscribeToEvent("OnArriveAtStop")
        state:subscribeToEvent("OnCargoLoaded")
        state:subscribeToEvent("OnCargoUnloaded")
        state:subscribeToEvent("CargoDistributionControl")
    end
    local saved = core.migrate(state:get())
    if saved.version ~= config.version then
        saved.started = true
        saved.version = config.version
        emit(saved, "STARTUP", { version = config.version, build = getBuildVersion(), catalog = catalog() })
    end
    if dt > 0 then
        saved.tick = saved.tick + 1
    end
    state:set(saved)
    return { tick = saved.tick, advance = dt > 0 }
end

function M.postUpdate(_, state, dt, updateResult)
    if dt <= 0 or not updateResult or not updateResult.advance then return end
    local saved = core.migrate(state:get())
    -- postUpdate is the serial command phase used by the game's own scripts.
    -- An extra callback for the same tick must not issue a second line command.
    if saved.lastPostUpdateTick == updateResult.tick then return end
    saved.lastPostUpdateTick = updateResult.tick
    if saved.disablePending then
        for line in pairs(saved.lines) do restoreLine(saved, tonumber(line)) end
        saved.disablePending = false
        emit(saved, "DISABLED", { active = saved.active })
    end
    finishDepartures(saved)
    if saved.tick % 30 == 1 then watchLines(saved) end
    applyPending(saved)
    state:set(saved)
end

function M.handleEvent(_, state, _, id, name, param)
    local saved = core.migrate(state:get())
    if name == "CargoDistributionControl" and id == "cargo_distribution_1" then
        if param.action == "disable" then
            saved.disabled = true
            saved.disablePending = true
            emit(saved, "DISABLE_QUEUED", { active = saved.active })
        elseif param.action == "status" then emit(saved, "STATUS", saved.lines) end
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
