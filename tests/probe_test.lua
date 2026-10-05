local core = dofile(source_root .. "/core.lua")
local count = 0
local function check(value, message)
    assert(value, message)
    count = count + 1
end
local function eq(actual, expected, message)
    check(actual == expected, (message or "mismatch") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local auto = { percentage = 50, filter = "automatic" }
for _, case in ipairs({{100,50,50},{60,50,30},{0,50,0},{1,50,1},{3,50,2},
    {99,0,0},{99,100,99},{99,33,33}}) do
    eq(core.quota(case[1],case[2]),case[3], "quota")
end
check(not core.validateRule({percentage=-1,filter="automatic"}), "reject negative")
check(not core.validateRule({percentage=101,filter="automatic"}), "reject over 100")
check(not core.validateRule({percentage=0/0,filter="automatic"}), "reject NaN")
check(not core.validateRule({percentage=50,filter="selected"}), "reject missing allowlist")
local s = core.snapshot({meat=60,grain=15},{meat=100,grain=20},
    {percentage=50,filter="selected",goods={meat=true},overrides={meat=25,grain=100}})
eq(s.meat.quota,15,"override")
eq(s.meat.retained,45,"partial arrival retained")
eq(s.meat.target,0.45,"native capacity translation")
eq(s.grain.quota,0,"excluded override cannot bypass filter")
eq(s.grain.retained,15,"excluded goods retained")
s.meat.unloaded=15
check(core.evaluate(s,{meat=45,grain=15}).exact,"exact complete transfer")
check(not core.evaluate(s,{meat=45,grain=15},1).exact,"unknown transfer blocks pass")
s.meat.loaded=1
check(not core.evaluate(s,{meat=46,grain=15}).safe,"pickup forbidden even if net amount matches")
s.meat.loaded=0; s.meat.destroyed=1
check(not core.evaluate(s,{meat=45,grain=15}).safe,"destruction forbidden")
s.meat.destroyed=0;s.meat.unloaded=0
local full=core.evaluate(s,{meat=60,grain=15})
check(full.safe and not full.exact,"warehouse refusal is safe but not an exact pass")
s.meat.unloaded=16
check(not core.evaluate(s,{meat=44,grain=15}).safe,"over-unloading detected")
check(not pcall(core.snapshot,{meat=100},{meat=60},auto),"invalid capacity fails before mutation")
check(not pcall(core.migrate,{schemaVersion=99}),"future saved state is rejected")
local legacy=core.migrate({schemaVersion=1,active={['10']={snapshot={meat={arrival=10}}}},disabled=true})
eq(legacy.schemaVersion,2,"legacy state migrated")
eq(legacy.active['10'].targetStatus,"legacy_unknown","legacy arrivals are not replayed")
eq(legacy.active['10'].snapshot.meat.arrival,10,"migration keeps original snapshot")
check(legacy.disablePending,"legacy disabled state queues restoration")
local route={{stationGroup=8,station=0,terminal=0,waypoints={{tag=1}},
    alternativeTerminals={{station=0,terminal=1}}}}
eq(core.route(route),core.route(core.copy(route)),"route fingerprint is value-based")
check(core.route({route[1],route[1]})~=core.route(route),"repeated visits are distinct")

-- The fake native adapter applies commands immediately as the engine docs specify.
-- It does NOT simulate native unloading; these checks must never count as the game gate.
local cfg=dofile(source_root.."/config.lua")
local line={customFilters=false,stops={}}
for i=1,3 do
    line.stops[i]={stationGroup=i,station=0,terminal=0,waypoints={},alternativeTerminals={},
        loadMode="FULL",stopConfig={load={true,true,true},maxLoad={1,1,1},
        forceUnload=false,destroyForConfigChange=false,destroyForRefresh=false}}
end
local originals=core.copy(line)
local vehicles={
    [10]={line=1,stopIndex=1,lastLineStopDeparture=0,loadState="Arrived",config={capacities={0,100,50},allCaps={0,100,50}}},
    [11]={line=1,stopIndex=1,lastLineStopDeparture=0,loadState="Arrived",config={capacities={0,100,50},allCaps={0,100,50}}},
}
local cargoCounts={[10]={[0]=0,[1]=60,[2]=0},[11]={[0]=0,[1]=100,[2]=0}}
local entities={}
local commands={}
local phase="idle"
local lineName=cfg.lineName
local state={value={},subscriptions={}}
function state:get() return core.copy(self.value) end
function state:set(v)
    assert(phase~="update", "parallel update must never replace persistent state")
    self.value=core.copy(v)
end
function state:hasEventSubscriptions() return next(self.subscriptions)~=nil end
function state:subscribeToEvent(name) self.subscriptions[name]=true end
function ug_require(path) return dofile(source_root.."/"..path:match("([^/]+)$")) end
function getBuildVersion() return "FAKE ENGINE - not a native result" end
api={type={ComponentType={LINE="LINE",TRANSPORT_VEHICLE="TV",SIM_CARGO="CARGO",SIM_ENTITY_AT_VEHICLE="SEAV"},
    Line={new=core.copy,StopConfig={new=function()return{}end},
        LoadMode={LOAD_IF_AVAILABLE="AVAILABLE",FULL_LOAD_ALL="FULL"}}},
    res={cargoTypeRep={getAll=function()return{[0]="passengers",[1]="meat",[2]="grain"}end,
        getPassengerCargoTypeId=function()return 0 end,
        getName=function(id)return ({[0]="passengers",[1]="meat",[2]="grain"})[id]end}},
    engine={entityExists=function(id)return id==1 or vehicles[id]~=nil end,
        getComponent=function(id,ct)
            if id==1 and ct=="LINE" then return core.copy(line) end
            if ct=="TV" then return vehicles[id] end
            return entities[id] and entities[id][ct]
        end,
        util={getPlayer=function()return 0 end,getEntityName=function()return lineName end},
        system={lineSystem={getLinesForPlayer=function()return{1}end},
            simEntityAtVehicleSystem={getVehicleSimEntitiesCountForCargoType=function(v,c)
                return cargoCounts[v][c] or 0 end}}},
    cmd={makeLineUpdateCmd=function(id,value)return{id=id,value=value}end,
        sendCommand=function(cmd,callback)
            assert(phase~="event", "regression: engine mutation attempted from an event callback")
            assert(not (phase=="update" and callback), "Callbacks are currently disallowed")
            assert(phase=="postUpdate", "mod commands belong in postUpdate")
            line=core.copy(cmd.value);commands[#commands+1]=cmd
            if callback then callback({},true,{}) end
        end}}
local function loadProbe()
    data=nil
    dofile(source_root.."/probe.script.lua")
    check(type(data)=="function", ".script.lua must expose the native data entry point")
    local resource=data()
    check(type(resource)=="table" and type(resource.update)=="function", "native resource returns script table")
    check(type(resource.postUpdate)=="function", "serial postUpdate entry point exists")
    return resource
end
local probe=loadProbe()
local function update(n)
    for _=1,n or 1 do
        phase="update"
        local result=probe.update({},state,1)
        phase="postUpdate"
        if probe.postUpdate then probe.postUpdate({},state,1,result) end
    end
    phase="idle"
end
local function event(name,param,id)
    phase="event"
    probe.handleEvent({},state,"",id or "TransportVehicleSystem",name,param)
    phase="idle"
end
local function arrival(v) event("OnArriveAtStop",
    {vehicleEntity=v,lineEntity=1,stopIndex=1,lastStopIndex=0}) end
local function unload(v,n)
    for i=1,n do
        entities[1000+i]={CARGO={cargoType=1},SEAV={vehicle=v}}
        event("OnCargoUnloaded",{[1000+i]={{9,0},false}})
    end
    cargoCounts[v][1]=cargoCounts[v][1]-n
end
update()
eq(#commands,0,"arming must not mutate any stop")
arrival(10)
eq(#commands,0,"arrival event only snapshots; no nested engine mutation")
eq(state.value.active["10"].snapshot.meat.arrival,60,"arrival snapshot persisted before command")
eq(state.value.active["10"].targetStatus,"pending","target pending in saved state")
arrival(10)
eq(state.value.sequence,1,"duplicate pending arrival does not recalculate")
local reloaded=loadProbe()
probe=reloaded
update()
eq(line.stops[2].stopConfig.maxLoad[2],0.3,"60 arriving out of capacity 100 retains 30")
eq(line.stops[2].stopConfig.maxLoad[3],0,"goods absent on arrival have zero pickup target")
check(not line.stops[2].stopConfig.forceUnload,"force destruction disabled")
eq(line.stops[1].loadMode,originals.stops[1].loadMode,"unmanaged stops unchanged")
arrival(10)
eq(state.value.sequence,1,"duplicate arrival does not recalculate")
update()
eq(state.value.active["10"].snapshot.meat.arrival,60,"save/reload keeps original snapshot")
eq(#commands,1,"already-applied arrival is not replayed")
arrival(11)
eq(#commands,1,"concurrent arrival also defers its command")
update()
eq(line.stops[2].stopConfig.maxLoad[2],0.5,"second vehicle writes a different shared target")
check(state.value.active["10"].overlap and state.value.active["11"].overlap,"both concurrent snapshots flagged")
eq(state.value.active["10"].snapshot.meat.target,0.3,"first snapshot remains independent")
unload(10,30)
vehicles[10].stopIndex=2;vehicles[10].lastLineStopDeparture=1
update()
check(state.value.active["11"]~=nil,"other vehicle remains active")
eq(line.stops[2].stopConfig.maxLoad[2],0.5,"do not restore while second arrival active")
unload(11,50)
vehicles[11].stopIndex=2;vehicles[11].lastLineStopDeparture=1
update()
eq(core.describe(line),core.describe(originals),"restore exact original line settings after last departure")
eq(state.value.failures,0,"simulated exact results safe")
vehicles[10].stopIndex=1
arrival(10)
lineName=cfg.resetName
update(30)
eq(core.describe(line),core.describe(originals),"rename resets settings")
check(state.value.lines["1"].suspended,"reset prevents further arrivals")
local before=#commands
arrival(11)
eq(#commands,before,"suspended rules do not mutate line")

-- Fresh state: route edits suspend without assigning old settings to a new stop.
state.value={}; line=core.copy(originals); lineName=cfg.lineName
update(); arrival(10)
line.stops[2].stationGroup=99
update(30)
check(state.value.lines["1"].suspended,"route edits suspend rules")
before=#commands
arrival(11)
eq(#commands,before,"route edit cannot redirect a rule")
event("CargoDistributionControl",{action="disable"},"cargo_distribution_1")
check(state.value.disabled,"explicit disable persists")
update()
eq(#commands,before,"disable never restores into a changed route")

-- Fresh state: passenger vehicle untouched; deletion recorded without inventing a pass.
state.value={}; line=core.copy(originals); lineName=cfg.lineName
update(); cargoCounts[10][0]=2
before=#commands;arrival(10)
eq(#commands,before,"passengers aboard skip probe")
cargoCounts[10][0]=0;arrival(10);update()
vehicles[10]=nil;update()
check(state.value.active["10"]==nil,"removed vehicle snapshot cleared")
eq(core.describe(line),core.describe(originals),"deletion restores stop")

-- Fresh state: no named line => no command at all.
state.value={};lineName="Ordinary freight";before=#commands
update(60);arrival(11)
eq(#commands,before,"unmanaged lines stay untouched")

-- Native crash regression: snapshots and disable requests cannot issue commands in events.
state.value={};line=core.copy(originals);lineName=cfg.lineName
vehicles[10]={line=1,stopIndex=1,lastLineStopDeparture=0,loadState="Arrived",config={capacities={0,25,175},allCaps={0,225,225}}}
vehicles[11].stopIndex=1
cargoCounts[10][1]=10;cargoCounts[11][1]=60
update();before=#commands;arrival(11);arrival(10)
eq(#commands,before,"two arrivals in one engine transaction cannot send commands")
update()
eq(#commands,before+2,"both pending targets applied in next update")
eq(commands[before+1].value.stops[2].stopConfig.maxLoad[2],0.3,"pending targets preserve arrival order")
eq(commands[before+2].value.stops[2].stopConfig.maxLoad[2],5/225,"10 meat keeps 5 of 225 compatible capacity")
before=#commands
event("CargoDistributionControl",{action="disable"},"cargo_distribution_1")
eq(#commands,before,"disable event cannot mutate engine")
update()
eq(core.describe(line),core.describe(originals),"disable restores from update")

-- A transfer before the safe update invalidates the experiment instead of recalculating.
state.value={};line=core.copy(originals);lineName=cfg.lineName
update();before=#commands;arrival(10);unload(10,1);update()
eq(#commands,before,"late target must not be sent after cargo transfer")
eq(state.value.active["10"].snapshot.meat.arrival,10,"never rebase quota on changed cargo")
eq(state.value.active["10"].targetStatus,"skipped","late target explicitly skipped")
eq(state.value.active["10"].targetError,"cargo_transferred_before_target","timing limitation is logged")
check(state.value.lines["1"].suspended,"timing failure suspends probe")

-- Reset/disable while a command is still queued must cancel it.
state.value={};line=core.copy(originals);lineName=cfg.lineName
update();before=#commands;arrival(10)
event("CargoDistributionControl",{action="disable"},"cargo_distribution_1")
update()
eq(#commands,before,"disabled pending target never runs")

-- Pure quantity recheck catches missing transfer events too.
state.value={};line=core.copy(originals);lineName=cfg.lineName
update();before=#commands;arrival(10);cargoCounts[10][1]=8;update()
eq(#commands,before,"changed quantity without a transfer event still prevents late application")

-- A vehicle that left between arrival and update cannot receive a stale command.
state.value={};line=core.copy(originals);lineName=cfg.lineName
update();before=#commands;arrival(10);vehicles[10].stopIndex=2;update()
eq(#commands,before,"pending target cancelled when vehicle has already departed")
check(state.value.active["10"]==nil,"departed pending arrival is closed")
local latestResult
for _, entry in ipairs(state.value.log) do if entry.kind=="RESULT" then latestResult=entry.data.result end end
check(latestResult~=nil and not latestResult.exact,"unapplied target cannot count as an exact pass")

-- Regression for build 40408's restricted update: descriptor + both lifecycle phases.
data=nil;dofile(source_root.."/probe.gs.lua")
eq(data().postUpdateScript.fileName,"probe.script@postUpdate","native descriptor registers serial phase")
state.value={};line=core.copy(originals);lineName=cfg.lineName;vehicles[10].stopIndex=1
cargoCounts[10][1]=16
update();before=#commands;arrival(10)
phase="update"
local step=probe.update({},state,1)
eq(#commands,before,"restricted update issues no command or callback")
eq(state.value.active["10"].targetStatus,"pending","pending arrival survives restricted update")
phase="postUpdate"
probe.postUpdate({},state,1,step)
eq(#commands,before+1,"serial postUpdate applies target once")
eq(line.stops[2].stopConfig.maxLoad[2],8/225,"16 meat retains 8 using 225 compatible capacity")
eq(state.value.active["10"].snapshot.meat.capacity,225,"snapshot uses compatible capacity, not configured 25")
eq(state.value.active["10"].snapshot.meat.quota,8,"unload quota remains half of 16 on arrival")
eq(state.value.active["10"].targetStatus,"applied","serial callback confirms command")
probe.postUpdate({},state,1,step)
eq(#commands,before+1,"duplicate serial callback cannot replay the target")
phase="idle"

-- A paused frame leaves pending work intact without attempting a native command.
state.value={};line=core.copy(originals);lineName=cfg.lineName
update();before=#commands;arrival(10)
phase="update";step=probe.update({},state,0)
phase="postUpdate";probe.postUpdate({},state,0,step);phase="idle"
eq(#commands,before,"paused update cannot submit queued commands")
eq(state.value.active["10"].targetStatus,"pending","paused arrival remains pending")

-- Recoverable command errors are logged, not rethrown as repeated game error dialogs.
local normalSend=api.cmd.sendCommand
api.cmd.sendCommand=function()error("simulated command failure")end
update()
eq(state.value.active["10"].targetStatus,"unconfirmed","command exception is not an accepted target")
check(state.value.lines["1"].suspended,"command exception suspends rule")
api.cmd.sendCommand=normalSend

-- Parallel update must not write a stale copy of state over arrival/transfer events.
-- Simulate an event arriving after the update has read state but before a stale set.
state.value={};line=core.copy(originals);lineName=cfg.lineName;vehicles[10].stopIndex=1
cargoCounts[10][1]=16
update();arrival(10);update()
local normalGet=state.get
local interleaved=false
function state:get()
    local snapshot=normalGet(self)
    if phase=="update" and not interleaved then
        interleaved=true
        self.value.active["10"].snapshot.meat.unloaded=3
        cargoCounts[10][1]=13
    end
    return snapshot
end
update()
state.get=normalGet
eq(state.value.active["10"].snapshot.meat.unloaded,3,"parallel update must preserve newer event counters")
print("CHECKS_PASSED="..count.." (pure Lua and mocked lifecycle only)")
