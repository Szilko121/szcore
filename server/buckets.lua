SzCore.Buckets=SzCore.Buckets or {nextId=1000,entries={}}
local B=SzCore.Buckets
local function configure(id,opt)
    opt=opt or {}
    if SetRoutingBucketPopulationEnabled then pcall(SetRoutingBucketPopulationEnabled,id,opt.population~=false) end
    if SetRoutingBucketEntityLockdownMode then pcall(SetRoutingBucketEntityLockdownMode,id,opt.lockdown or 'relaxed') end
end
function B.create(options)B.nextId=B.nextId+1;local id=B.nextId;B.entries[id]={options=options or {},players={},entities={}};configure(id,options);return id end
function B.addPlayer(id,source)source=tonumber(source);if not B.entries[id] or not source then return false end;B.removePlayer(source);SetPlayerRoutingBucket(source,id);B.entries[id].players[source]=true;return true end
function B.addEntity(id,entity)if not B.entries[id] or not entity or entity==0 or not DoesEntityExist(entity) then return false end;SetEntityRoutingBucket(entity,id);B.entries[id].entities[entity]=true;return true end
function B.removeEntity(entity)if not entity or entity==0 or not DoesEntityExist(entity) then return false end;local old=GetEntityRoutingBucket and GetEntityRoutingBucket(entity) or 0;SetEntityRoutingBucket(entity,0);if B.entries[old] then B.entries[old].entities[entity]=nil end;return true end
function B.removePlayer(source)source=tonumber(source);if not source then return false end;local old=GetPlayerRoutingBucket(source);SetPlayerRoutingBucket(source,0);if B.entries[old] then B.entries[old].players[source]=nil end;return true end
function B.destroy(id)
    local e=B.entries[id];if not e then return false end
    for src in pairs(e.players) do if GetPlayerName(src) then SetPlayerRoutingBucket(src,0) end end
    for entity in pairs(e.entities) do if DoesEntityExist(entity) then SetEntityRoutingBucket(entity,0) end end
    B.entries[id]=nil;return true
end
function B.get(id)return B.entries[id] end
function B.getPlayerBucket(source)return GetPlayerRoutingBucket(tonumber(source) or 0) end
exports('CreateBucket',B.create);exports('AddPlayerToBucket',B.addPlayer);exports('RemovePlayerFromBucket',B.removePlayer);exports('AddEntityToBucket',B.addEntity);exports('RemoveEntityFromBucket',B.removeEntity);exports('DestroyBucket',B.destroy);exports('GetBucket',B.get);exports('GetPlayerBucket',B.getPlayerBucket)
AddEventHandler('playerDropped',function()local src=source;for _,e in pairs(B.entries) do e.players[src]=nil end end)
