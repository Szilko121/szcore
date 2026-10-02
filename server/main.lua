SzCore.PendingSaves={}
local function checkpointSaves()
    local rows={};for cid,p in pairs(SzCore.PendingSaves)do rows[cid]={PlayerData=p.PlayerData}end
    SaveResourceFile(GetCurrentResourceName(),'character_recovery.json',json.encode(rows),-1)
end
local function retrySaves()
    for cid,p in pairs(SzCore.PendingSaves)do
        local ok,result=pcall(SzCore.DB.saveCharacter,p)
        if ok and result~=nil and result~=false then SzCore.PendingSaves[cid]=nil end
    end
    checkpointSaves()
end
local charset='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';math.randomseed(os.time()+GetGameTimer())

local function getIdentifiers(source)
    local raw = GetPlayerIdentifiers(source)
    local byType = {}
    local ordered = {}
    local seen = {}

    for i = 1, #raw do
        local identifier = raw[i]
        local kind = identifier:match('^([^:]+):')

        if kind and not byType[kind] then
            byType[kind] = identifier
        end
    end

    for i = 1, #SzCoreConfig.IdentifierPriority do
        local identifier = byType[SzCoreConfig.IdentifierPriority[i]]
        if identifier and not seen[identifier] then
            seen[identifier] = true
            ordered[#ordered + 1] = identifier
        end
    end

    if #ordered == 0 and raw[1] then
        ordered[1] = raw[1]
    end

    return ordered
end

local function getIdentifier(source)
    local identifiers = getIdentifiers(source)
    return identifiers[1]
end
local function validText(v,min,max)return type(v)=='string' and #v>=min and #v<=max and not v:find('[%z\1-\31]')end
local function citizen() for _=1,25 do local t={};for i=1,8 do local p=math.random(1,#charset);t[i]=charset:sub(p,p) end;local id='SZ-'..table.concat(t);if not SzCore.DB.citizenIdTaken(id) then return id end end;error('citizenid generation failed') end
function SzCore.GetIdentifier(source)return getIdentifier(source)end
function SzCore.GetIdentifiers(source)return getIdentifiers(source)end
local function login(source,citizenid)
    source=tonumber(source);if SzCore.GetPlayer(source) then return false,'already_logged_in' end;local identifier=getIdentifier(source);if not identifier then return false,'identifier_missing' end
    local identifiers=getIdentifiers(source);local row=SzCore.DB.loadCharacterAny(identifiers,citizenid);if not row then return false,'character_not_found' end;if SzCore.GetPlayerByCitizenId(citizenid) then return false,'already_online' end
    local p=SzCore.CreateRuntimePlayer(source,row);if not GetPlayerName(source) or getIdentifier(source)~=identifier then return false,'disconnected' end;SzCore.RegisterPlayer(p);local s=Player(source).state;s:set('szcoreLoaded',true,true);s:set('szcoreCitizenId',citizenid,true);s:set('szcoreJob',p.PlayerData.job.name,true);s:set('szcoreDuty',p.PlayerData.job.onduty,true);s:set('szcoreDead',p.PlayerData.metadata.dead==true,true)
    TriggerClientEvent('szcore:client:playerLoaded',source,SzCore.GetClientPlayerData(p));SzCore.Metrics.logins=SzCore.Metrics.logins+1;TriggerEvent('szcore:server:playerLoaded',source,SzCore.ToExportPlayer(p));SzCore.RunHooks('player:loaded',{player=p});return true
end
function SzCore.Login(source,citizenid)
    source=SzCore.Integer(source,1);if not source or type(citizenid)~='string' or #citizenid>24 then return false,'invalid_request' end
    if not SzCore.Ready then return false,'core_not_ready' end
    if SzCore.PendingSaves[citizenid] then return false,'pending_save_retry' end
    return SzCore.WithLocks({'session:'..source,'money:player:'..citizenid,'groups:'..citizenid},function()return login(source,citizenid)end)
end
function SzCore.Logout(source,save)
    source=tonumber(source);local p=SzCore.GetPlayer(source);if not p or p._unloading then return false end;p._unloading=true;if save~=false then local ok=p:save(true);if not ok then SzCore.PendingSaves[p.PlayerData.citizenid]=p;checkpointSaves() end end;SzCore.RunHooks('player:unloading',{player=p});TriggerEvent('szcore:server:playerUnloaded',source,p.PlayerData.citizenid);SzCore.UnregisterPlayer(source);SzCore.Metrics.logouts=SzCore.Metrics.logouts+1;if GetPlayerName(source) then local s=Player(source).state;s:set('szcoreLoaded',false,true);s:set('szcoreCitizenId',nil,true);TriggerClientEvent('szcore:client:playerUnloaded',source) end;return true
end
function SzCore.Save(source,force)local p=SzCore.GetPlayer(source);return p and p:save(force) or false end
function SzCore.SaveAll(force)
    local players,versions,positions={},{},{};local threshold=(tonumber(SzCoreConfig.PositionSaveDistance) or 10)^2
    for _,p in pairs(SzCore.Registry.bySource) do if force then local deadline=GetGameTimer()+10000;while p._saving do if GetGameTimer()>deadline then for _,held in ipairs(players)do held._saving=false end;return false,0 end;Wait(5) end end;if force or not p._saving then local b=p._persistedPosition or p.PlayerData.position;SzCore.UpdatePlayerPosition(p);local a=p.PlayerData.position;local dx=(a.x or 0)-(b.x or 0);local dy=(a.y or 0)-(b.y or 0);local dz=(a.z or 0)-(b.z or 0);if dx*dx+dy*dy+dz*dz>=threshold then p:markDirty('position') end;if force or p:isDirty() then players[#players+1]=p;versions[p]=p._dirtyVersion;positions[p]={x=a.x,y=a.y,z=a.z,w=a.w};p._saving=true end end end
    if #players==0 then return true,0 end;local ok,err=pcall(SzCore.DB.saveCharacters,players);if not ok or err~=true then for i=1,#players do local failed=players[i];failed._saving=false;SzCore.PendingSaves[failed.PlayerData.citizenid]=failed end;checkpointSaves();SzCore.Log('error','Batch save: %s',tostring(err));return false,0 end
    for i=1,#players do local p=players[i];if p._dirtyVersion==versions[p] then p._dirty=false;p._dirtySections={} end;p._persistedPosition=positions[p];p._lastSave=os.time();p._saving=false end;SzCore.Metrics.batchSaves=SzCore.Metrics.batchSaves+1;SzCore.Metrics.saves=SzCore.Metrics.saves+#players;return true,#players
end
SzCore.CreateCallback('szcore:restoreSession',function(source)local p=SzCore.GetPlayer(source);if p then return SzCore.GetClientPlayerData(p) end;local s=Player(source).state;local id=s and s.szcoreCitizenId;if id and SzCore.Login(source,id) then return SzCore.GetClientPlayerData(SzCore.GetPlayer(source)) end end)
SzCore.CreateCallback('szcore:getCharacters',function(source)local ids=getIdentifiers(source);local id=ids[1];if not id then return {} end;SzCore.DB.ensureAccount(id,GetPlayerName(source));return SzCore.DB.listCharactersAny(ids) end)
SzCore.CreateCallback('szcore:createCharacter',function(source,data)
    if SzCore.GetPlayer(source) or type(data)~='table' then return nil,'invalid_request' end;local ids=getIdentifiers(source);local id=ids[1];if not id then return nil,'identifier_missing' end;SzCore.DB.ensureAccount(id,GetPlayerName(source));local slot=tonumber(data.slot);if not slot or slot%1~=0 or slot<1 or slot>SzCoreConfig.MaxCharacters or SzCore.DB.slotTakenAny(ids,slot) then return nil,'invalid_slot' end;if not validText(data.firstname,2,32) or not validText(data.lastname,2,32) then return nil,'invalid_name' end;if type(data.birthdate)~='string' or not data.birthdate:match('^%d%d%d%d%-%d%d%-%d%d$') then return nil,'invalid_birthdate' end;if data.gender~='male' and data.gender~='female' then return nil,'invalid_gender' end;local cid=citizen();local new=SzCore.DB.createCharacter(id,cid,{slot=slot,firstname=data.firstname,lastname=data.lastname,birthdate=data.birthdate,gender=data.gender,nationality=validText(data.nationality,2,16) and data.nationality or 'HU'});return new and cid or nil,new and nil or 'database_error'
end)
SzCore.CreateCallback('szcore:selectCharacter',function(source,id)if type(id)~='string' then return false,'invalid_citizenid' end;return SzCore.Login(source,id)end)
SzCore.CreateCallback('szcore:deleteCharacter',function(source,id)
    if SzCore.GetPlayer(source)then return false,'logout_first'end
    if type(id)~='string'or #id>24 then return false,'invalid_id'end
    return SzCore.WithLocks({'session:'..source,'money:player:'..id,'groups:'..id},function()
        if SzCore.GetPlayerByCitizenId(id)or SzCore.PendingSaves[id]then return false,'character_busy'end
        local licenses=getIdentifiers(source);return #licenses>0 and SzCore.DB.deleteCharacterAny(licenses,id)>0 or false
    end)
end)
CreateThread(function() while true do Wait(SzCoreConfig.AutoSaveInterval);SzCore.SaveAll(false) end end)
AddEventHandler('playerDropped',function()local src=source;if SzCore.GetPlayer(src) then SzCore.Logout(src,true) end end)
AddEventHandler('txAdmin:events:scheduledRestart',function(e)if type(e)=='table' and e.secondsRemaining==60 then SzCore.SaveAll(true) end end)
AddEventHandler('txAdmin:events:serverShuttingDown',function()SzCore.SaveAll(true)end)
AddEventHandler('onResourceStop',function(r)
    if r~=GetCurrentResourceName()then return end
    for _,p in pairs(SzCore.Registry.bySource)do SzCore.PendingSaves[p.PlayerData.citizenid]=p end
    checkpointSaves()
    if SzCore.SaveAll(true)then for _,p in pairs(SzCore.Registry.bySource)do SzCore.PendingSaves[p.PlayerData.citizenid]=nil end;checkpointSaves()end
end)
CreateThread(function() MySQL.ready.await();local ok,err=pcall(function()SzCore.Migrations.run();assert(MySQL.startTransaction(function(query)local rows=query('SELECT 1 AS ready');return rows and rows[1] and tonumber(rows[1].ready)==1 end)==true,'oxmysql startTransaction unavailable');local raw=LoadResourceFile(GetCurrentResourceName(),'character_recovery.json');if raw then local rows=json.decode(raw);for cid,p in pairs(rows or {})do SzCore.PendingSaves[cid]=p end;retrySaves()end end);SzCore.Ready=ok;if not ok then SzCore.Log('error','Migration failed: %s',tostring(err)) end end)
exports('GetPlayer',function(s)return SzCore.ToExportPlayer(SzCore.GetPlayer(s))end);exports('GetPlayerByCitizenId',function(id)return SzCore.ToExportPlayer(SzCore.GetPlayerByCitizenId(id))end)
exports('GetPlayerSourcesByJob',function(j,d)local p=SzCore.GetPlayersByJob(j,d);local o={};for i=1,#p do o[i]=p[i].PlayerData.source end;return o end);exports('GetJobCount',function(j,d)return SzCore.GetJobCount(j,d)end);exports('GetPlayerCount',SzCore.GetPlayerCount);exports('GetIdentifier',SzCore.GetIdentifier);exports('GetIdentifiers',SzCore.GetIdentifiers);exports('GetJob',SzCore.GetJob);exports('GetJobs',SzCore.GetJobs);exports('GetGang',SzCore.GetGang);exports('GetGangs',SzCore.GetGangs);exports('GetLocation',function(n)return SzCoreLocations[n] end);exports('GetLocations',function()return SzCoreLocations end)
exports('GetMoney',function(i,a)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:getMoney(a) end);exports('AddMoney',function(i,a,n,r)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:addMoney(a,n,r) or false end);exports('RemoveMoney',function(i,a,n,r)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:removeMoney(a,n,r) or false end);exports('SetMoney',function(i,a,n,r)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:setMoney(a,n,r) or false end)
exports('SetJob',function(i,j,g,d)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:setJob(j,g,d) or false end);exports('SetGang',function(i,g,gr)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:setGang(g,gr) or false end);exports('SetDuty',function(i,d)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:setDuty(d) or false end);exports('GetMetadata',function(i,k)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:getMetadata(k) end);exports('SetMetadata',function(i,k,v)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:setMetadata(k,v) or false end)
exports('GetConfig',function()return SzCoreConfig end);exports('Login',SzCore.Login);exports('Logout',SzCore.Logout);exports('Save',SzCore.Save);exports('SaveAll',SzCore.SaveAll);exports('GetMetrics',function()return SzCore.Metrics end);exports('Locale',SzCore.Locale)
exports('HasLicense',function(i,n)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:hasLicense(n) or false end);exports('AddLicense',function(i,n)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:addLicense(n) or false end);exports('RemoveLicense',function(i,n)local p=tonumber(i) and SzCore.GetPlayer(tonumber(i)) or SzCore.GetPlayerByCitizenId(i);return p and p:removeLicense(n) or false end)
exports('GetPlayersByGroup',function(kind,name)local list=SzCore.GetPlayersByGroup((kind=='job' or kind=='jobs') and 'jobs' or 'gangs',name);local o={};for i=1,#list do o[i]=list[i].PlayerData.source end;return o end)
local Core={Version=SzCoreConfig.Version,Shared={Jobs=SzCoreJobs,Gangs=SzCoreGangs,Items=SzCoreItems,Vehicles=SzCoreVehicles,Locations=SzCoreLocations},Functions={}}
Core.Functions.GetPlayer=function(s)return SzCore.ToExportPlayer(SzCore.GetPlayer(s))end;Core.Functions.GetPlayerByCitizenId=function(i)return SzCore.ToExportPlayer(SzCore.GetPlayerByCitizenId(i))end;Core.Functions.IsAdmin=SzCore.IsAdmin;Core.Functions.HasPermission=SzCore.HasPermission;exports('GetCoreObject',function()return Core end)
SzCore.Log('info','SzCore Core %s loaded.',SzCoreConfig.Version)

exports('GetItemDefinition',function(name)return SzCoreItems[name]end)

CreateThread(function()while true do Wait(10000);if SzCore.Ready and next(SzCore.PendingSaves)then retrySaves()end end end)

exports('IsReady',function()return SzCore.Ready==true end)
