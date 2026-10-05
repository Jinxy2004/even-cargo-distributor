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
eq(legacy.schemaVersion,3,"legacy state migrated")
eq(legacy.active['10'].targetStatus,"legacy_unknown","legacy arrivals are not replayed")
eq(legacy.active['10'].snapshot.meat.arrival,10,"migration keeps original snapshot")
check(legacy.disablePending,"legacy disabled state queues restoration")
local route={{stationGroup=8,station=0,terminal=0,waypoints={{tag=1}},
    alternativeTerminals={{station=0,terminal=1}}}}
eq(core.route(route),core.route(core.copy(route)),"route fingerprint is value-based")
check(core.route({route[1],route[1]})~=core.route(route),"repeated visits are distinct")

local stopsA={{stationGroup=5},{stationGroup=7},{stationGroup=5}}
eq(core.stationKey(stopsA,0),"5#1","first visit key")
eq(core.stationKey(stopsA,2),"5#2","second visit to same station is distinct")
eq(core.stopIndexFor({{stationGroup=9},{stationGroup=5},{stationGroup=7},{stationGroup=5}},"5#2"),3,"key follows station after insertion")
check(core.stopIndexFor({{stationGroup=7}},"5#1")==nil,"removed station has no index")
local norm=core.normalizeRule({percentage=50,filter="selected",goods={meat=true,wool=false},overrides={meat=25},junk=1})
check(norm.goods.meat and norm.goods.wool==nil and norm.junk==nil,"normalized rule keeps only valid fields")
check(core.normalizeRule({percentage=500,filter="automatic"})==nil,"normalize rejects invalid rule")
local v2=core.migrate({schemaVersion=2,lines={["1"]={originals={}}},active={},log={},sequence=0,tick=0,failures=0})
check(v2.rules and v2.legacyLines["1"] and next(v2.lines)==nil,"v2 state keeps legacy records for one-time conversion")

-- The fake native adapter applies commands immediately as the engine docs specify.
-- It does NOT simulate native unloading; these checks must never count as the game gate.
local line={customFilters=false,stops={}}
for i=1,3 do
    line.stops[i]={stationGroup=i,station=0,terminal=0,waypoints={},alternativeTerminals={},
        loadMode="FULL",stopConfig={load={true,true,true},maxLoad={1,1,1},
        forceUnload=false,destroyForConfigChange=false,destroyForRefresh=false}}
end
local originals=core.copy(line)
local function freshVehicles()
    return {
        [10]={line=1,stopIndex=1,lastLineStopDeparture=0,loadState="Arrived",config={capacities={0,100,50},allCaps={0,100,50}}},
        [11]={line=1,stopIndex=1,lastLineStopDeparture=0,loadState="Arrived",config={capacities={0,100,50},allCaps={0,100,50}}},
    }
end
local vehicles=freshVehicles()
local cargoCounts={[10]={[0]=0,[1]=60,[2]=0},[11]={[0]=0,[1]=100,[2]=0}}
local entities={}
local commands={}
local phase="idle"
local state={value={},subscriptions={}}
function state:get() return core.copy(self.value) end
function state:set(v)
    assert(phase~="update", "parallel update must never replace persistent state")
    self.value=core.copy(v)
end
function state:hasEventSubscriptions() return next(self.subscriptions)~=nil end
function state:subscribeToEvent(name) self.subscriptions[name]=true end
local verbose=true -- native-trace mode, so the log can be inspected below
function ug_require(path)
    local m=dofile(source_root.."/"..path:match("([^/]+)$"))
    if path:match("config%.lua$") then m.verbose=verbose end
    return m
end
function getBuildVersion() return "FAKE ENGINE - not a native result" end
api={type={ComponentType={LINE="LINE",TRANSPORT_VEHICLE="TV",SIM_CARGO="CARGO",SIM_ENTITY_AT_VEHICLE="SEAV"},
    Line={new=core.copy,StopConfig={new=function()return{}end},
        LoadMode={LOAD_IF_AVAILABLE="AVAILABLE",FULL_LOAD_ALL="FULL"}}},
    res={cargoTypeRep={getAll=function()return{[0]="passengers",[1]="meat",[2]="grain"}end,
        getPassengerCargoTypeId=function()return 0 end,
        getName=function(id)return ({[0]="passengers",[1]="meat",[2]="grain"})[id]end}},
    engine={entityExists=function(id)return (id==1 and line~=nil) or vehicles[id]~=nil end,
        getComponent=function(id,ct)
            if id==1 and ct=="LINE" then return line and core.copy(line) end
            if ct=="TV" then return vehicles[id] end
            return entities[id] and entities[id][ct]
        end,
        util={getPlayer=function()return 0 end},
        system={simEntityAtVehicleSystem={getVehicleSimEntitiesCountForCargoType=function(v,c)
                return cargoCounts[v][c] or 0 end}}},
    cmd={makeLineUpdateCmd=function(id,value)return{id=id,value=value}end,
        sendCommand=function(cmd,callback)
            assert(phase~="event", "regression: engine mutation attempted from an event callback")
            assert(not (phase=="update" and callback), "Callbacks are currently disallowed")
            assert(phase=="postUpdate", "mod commands belong in postUpdate")
            line=core.copy(cmd.value);commands[#commands+1]=cmd
            if callback then callback({},true,{}) end
        end}}
local function loadRuntime()
    data=nil
    dofile(source_root.."/runtime.script.lua")
    check(type(data)=="function", ".script.lua must expose the native data entry point")
    local resource=data()
    check(type(resource)=="table" and type(resource.update)=="function", "native resource returns script table")
    check(type(resource.postUpdate)=="function", "serial postUpdate entry point exists")
    return resource
end
local runtime=loadRuntime()
local function update(n)
    for _=1,n or 1 do
        phase="update"
        local result=runtime.update({},state,1)
        phase="postUpdate"
        if runtime.postUpdate then runtime.postUpdate({},state,1,result) end
    end
    phase="idle"
end
local function event(name,param,id)
    phase="event"
    runtime.handleEvent({},state,"",id or "TransportVehicleSystem",name,param)
    phase="idle"
end
local function control(param) event("CargoDistributionControl",param,"cargo_distribution_1") end
local function setRule(stopIndex,rule,group)
    control({action="setRule",line=1,stopIndex=stopIndex,stationGroup=group or line.stops[stopIndex+1].stationGroup,rule=rule})
end
local half={percentage=50,filter="automatic",overrides={}}
local function arrival(v,stopIndex) event("OnArriveAtStop",
    {vehicleEntity=v,lineEntity=1,stopIndex=stopIndex or 1,lastStopIndex=0}) end
local function unload(v,n)
    for i=1,n do
        entities[1000+i]={CARGO={cargoType=1},SEAV={vehicle=v}}
        event("OnCargoUnloaded",{[1000+i]={{9,0},false}})
    end
    cargoCounts[v][1]=cargoCounts[v][1]-n
end
local function depart(v,toStop) vehicles[v].stopIndex=toStop or 2;vehicles[v].lastLineStopDeparture=vehicles[v].lastLineStopDeparture+1 end
local function reset()
    state.value={};line=core.copy(originals);vehicles=freshVehicles()
    cargoCounts={[10]={[0]=0,[1]=60,[2]=0},[11]={[0]=0,[1]=100,[2]=0}}
end

-- No rule: the line is never touched.
update(31);arrival(10);update(31)
eq(#commands,0,"lines without rules are untouched")
check(state.value.active["10"]==nil,"no snapshot without a rule")

-- Rules come from the stop window and follow the station.
setRule(1,half)
eq(state.value.rules["1"]["2#1"].percentage,50,"rule stored by station key")
eq(#commands,0,"setting a rule never mutates the line from the event")
setRule(1,half,99)
eq(state.value.log[#state.value.log].kind,"RULE_REJECTED","rule for a changed stop is rejected")
setRule(1,{percentage=200,filter="automatic"})
eq(state.value.rules["1"]["2#1"].percentage,50,"invalid rule does not replace a valid one")

arrival(10)
eq(#commands,0,"arrival event only snapshots; no nested engine mutation")
eq(state.value.active["10"].snapshot.meat.arrival,60,"arrival snapshot persisted before command")
eq(state.value.active["10"].targetStatus,"pending","target pending in saved state")
arrival(10)
eq(state.value.sequence,1,"duplicate pending arrival does not recalculate")
runtime=loadRuntime()
update()
eq(line.stops[2].stopConfig.maxLoad[2],0.3,"60 arriving out of capacity 100 retains 30")
eq(line.stops[2].stopConfig.maxLoad[3],0,"goods absent on arrival have zero pickup target")
check(not line.stops[2].stopConfig.forceUnload,"force destruction disabled")
eq(line.stops[1].loadMode,originals.stops[1].loadMode,"unmanaged stops unchanged")
update()
eq(#commands,1,"already-applied arrival is not replayed")
arrival(11)
update()
eq(line.stops[2].stopConfig.maxLoad[2],0.5,"second vehicle writes a different shared target")
check(state.value.active["10"].overlap and state.value.active["11"].overlap,"both concurrent snapshots flagged")
unload(10,30);depart(10);update()
check(state.value.active["11"]~=nil,"other vehicle remains active")
eq(line.stops[2].stopConfig.maxLoad[2],0.5,"do not restore while second arrival active")
unload(11,50);depart(11);update()
eq(core.describe(line),core.describe(originals),"restore exact original line settings after last departure")
eq(state.value.failures,0,"simulated exact results safe")
check(state.value.lines["1"]==nil or next(state.value.lines["1"].originals)==nil,"no restore owed after restore")

-- Clearing the rule stops further management.
setRule(1,nil)
check(state.value.rules["1"]==nil,"cleared rule removed")
vehicles=freshVehicles();local before=#commands;arrival(10);update()
eq(#commands,before,"cleared rule leaves the stop alone")

-- Route edit: a stop inserted before the managed station; the rule follows the station.
reset();setRule(1,half)
table.insert(line.stops,1,{stationGroup=9,station=0,terminal=0,waypoints={},alternativeTerminals={},
    loadMode="FULL",stopConfig={load={true,true,true},maxLoad={1,1,1},forceUnload=false,destroyForConfigChange=false,destroyForRefresh=false}})
local edited=core.copy(line)
update(31)
eq(state.value.rules["1"]["2#1"].percentage,50,"rule survives an insertion elsewhere")
vehicles[10].stopIndex=2;before=#commands;arrival(10,2);update()
eq(#commands,before+1,"rule applies at the station's new position")
eq(line.stops[3].stopConfig.maxLoad[2],0.3,"target written to the moved stop")
eq(line.stops[2].stopConfig.maxLoad[2],1,"stop now in the old position untouched")
unload(10,30);depart(10,3);update()
eq(core.describe(line),core.describe(edited),"restore lands on the moved stop")

-- Station removed from the line: its rule is dropped, nothing else changes.
reset();setRule(1,half);table.remove(line.stops,2);update(31)
check(state.value.rules["1"]==nil,"rule for a removed station is dropped")

-- Station removed while its target is applied: no restore into another stop.
reset();setRule(1,half);arrival(10);update()
local applied=core.copy(line);table.remove(line.stops,2);local removed=core.copy(line)
depart(10,1);update()
eq(core.describe(line),core.describe(removed),"no restore into a different stop after removal")

-- Player edits the stop while the temporary target is applied: their edit wins.
reset();setRule(1,half);arrival(10);update()
line.stops[2].stopConfig.maxLoad[3]=0.75
local playerEdit=core.copy(line)
unload(10,30);depart(10);update()
eq(core.describe(line),core.describe(playerEdit),"player's mid-unload edit is not overwritten")

-- Passenger vehicle untouched; deletion recorded without inventing a pass.
reset();setRule(1,half);update()
cargoCounts[10][0]=2;before=#commands;arrival(10)
eq(#commands,before,"passengers aboard skip")
cargoCounts[10][0]=0;arrival(10);update()
vehicles[10]=nil;update()
check(state.value.active["10"]==nil,"removed vehicle snapshot cleared")
eq(core.describe(line),core.describe(originals),"deletion restores stop")

-- Two arrivals in one engine transaction; capacity conversion.
reset();setRule(1,half)
vehicles[10]={line=1,stopIndex=1,lastLineStopDeparture=0,loadState="Arrived",config={capacities={0,25,175},allCaps={0,225,225}}}
cargoCounts[10][1]=10;cargoCounts[11][1]=60
update();before=#commands;arrival(11);arrival(10)
eq(#commands,before,"two arrivals in one engine transaction cannot send commands")
update()
eq(#commands,before+2,"both pending targets applied in next update")
eq(commands[before+1].value.stops[2].stopConfig.maxLoad[2],0.3,"pending targets preserve arrival order")
eq(commands[before+2].value.stops[2].stopConfig.maxLoad[2],5/225,"10 meat keeps 5 of 225 compatible capacity")
before=#commands
control({action="disable"})
eq(#commands,before,"disable event cannot mutate engine")
update()
eq(core.describe(line),core.describe(originals),"disable restores from update")
before=#commands;vehicles=freshVehicles();arrival(10);update()
eq(#commands,before,"disabled mod ignores arrivals")
control({action="enable"});check(not state.value.disabled,"enable re-arms")

-- A transfer before the safe update skips this arrival only.
reset();setRule(1,half)
update();before=#commands;arrival(10);unload(10,1);update()
eq(#commands,before,"late target must not be sent after cargo transfer")
eq(state.value.active["10"].targetStatus,"skipped","late target explicitly skipped")
eq(state.value.active["10"].targetError,"cargo_transferred_before_target","timing limitation is logged")
check(state.value.rules["1"]["2#1"]~=nil,"a skipped arrival keeps the rule")

-- Disable while a command is queued cancels it.
reset();setRule(1,half);update();before=#commands;arrival(10)
control({action="disable"});update()
eq(#commands,before,"disabled pending target never runs")

-- Changed quantity without a transfer event still prevents late application.
reset();setRule(1,half);update();before=#commands;arrival(10);cargoCounts[10][1]=8;update()
eq(#commands,before,"quantity recheck blocks late target")

-- A vehicle that left between arrival and update cannot receive a stale command.
reset();setRule(1,half);update();before=#commands;arrival(10);vehicles[10].stopIndex=2;update()
eq(#commands,before,"pending target cancelled when vehicle has already departed")
check(state.value.active["10"]==nil,"departed pending arrival is closed")
local latestResult
for _, entry in ipairs(state.value.log) do if entry.kind=="RESULT" then latestResult=entry.data.result end end
check(latestResult~=nil and not latestResult.exact,"unapplied target cannot count as an exact pass")

-- Descriptor + restricted update + duplicate postUpdate.
data=nil;dofile(source_root.."/cargo_distribution.gs.lua")
eq(data().postUpdateScript.fileName,"runtime.script@postUpdate","native descriptor registers serial phase")
reset();setRule(1,half)
vehicles[10]={line=1,stopIndex=1,lastLineStopDeparture=0,loadState="Arrived",config={capacities={0,25,175},allCaps={0,225,225}}}
cargoCounts[10][1]=16
update();before=#commands;arrival(10)
phase="update"
local step=runtime.update({},state,1)
eq(#commands,before,"restricted update issues no command or callback")
phase="postUpdate"
runtime.postUpdate({},state,1,step)
eq(#commands,before+1,"serial postUpdate applies target once")
eq(line.stops[2].stopConfig.maxLoad[2],8/225,"16 meat retains 8 using 225 compatible capacity")
runtime.postUpdate({},state,1,step)
eq(#commands,before+1,"duplicate serial callback cannot replay the target")
phase="idle"

-- A paused frame leaves pending work intact.
reset();setRule(1,half);update();before=#commands;arrival(10)
phase="update";step=runtime.update({},state,0)
phase="postUpdate";runtime.postUpdate({},state,0,step);phase="idle"
eq(#commands,before,"paused update cannot submit queued commands")
eq(state.value.active["10"].targetStatus,"pending","paused arrival remains pending")

-- Command errors are logged, and a failed restore is retried later.
local normalSend=api.cmd.sendCommand
api.cmd.sendCommand=function()error("simulated command failure")end
update()
eq(state.value.active["10"].targetStatus,"unconfirmed","command exception is not an accepted target")
api.cmd.sendCommand=normalSend
reset();setRule(1,half);arrival(10);update()
api.cmd.sendCommand=function()error("simulated command failure")end
unload(10,30);depart(10);update()
check(state.value.lines["1"].originals["2#1"].applied,"failed restore stays owed")
api.cmd.sendCommand=normalSend
update(31)
eq(core.describe(line),core.describe(originals),"owed restore retried and completed")

-- Parallel update must not write a stale copy of state over arrival/transfer events.
reset();setRule(1,half)
vehicles[10]={line=1,stopIndex=1,lastLineStopDeparture=0,loadState="Arrived",config={capacities={0,25,175},allCaps={0,225,225}}}
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

-- Upgrade from a 0.1.x save with a target still applied at stop 2.
line=core.copy(originals);line.stops[2].stopConfig.maxLoad[2]=0.3
vehicles=freshVehicles()
state.value={schemaVersion=2,tick=5,sequence=4,failures=0,log={},disabled=false,
    lines={["1"]={customFilters=false,suspended=false,route="x",
        originals={["1"]={config=core.copy(originals.stops[2].stopConfig),loadMode="FULL_LOAD_ALL",applied=true}}}},
    active={["10"]={line=1,stop=1,sequence=4,tick=4,snapshot={meat={arrival=60,capacity=100,quota=30,retained=30,target=0.3,loaded=0,unloaded=0,destroyed=0}},
        unknownTransfers=0,targetStatus="applied",departureMarker=0,overlap=false}}}
update()
eq(state.value.active["10"].station,"2#1","legacy arrival mapped to its station")
check(state.value.legacyLines==nil,"legacy records converted once")
unload(10,30);depart(10);update()
eq(core.describe(line),core.describe(originals),"legacy applied target restored after upgrade")
check(state.value.rules["1"]==nil,"no 0.1.x rule carried into the new system")
-- Release mode: routine records are neither printed nor kept; problems still are.
verbose=false;runtime=loadRuntime()
reset();setRule(1,half);arrival(10);update();unload(10,30);depart(10);update()
local kinds={}
for _,e in ipairs(state.value.log) do kinds[e.kind]=true end
check(not kinds.TRANSFER and not kinds.ARRIVAL and not kinds.RESULT,"quiet mode keeps routine records out of the save")
check(kinds.RULE_SET,"quiet mode still records rule changes")
eq(core.describe(line),core.describe(originals),"quiet mode behaves identically")
print("CHECKS_PASSED="..count.." (pure Lua and mocked lifecycle only)")
