SzCore.Entities=SzCore.Entities or {nextId=0,byEntity={},bySession={}}
local E=SzCore.Entities
function E.createSessionId(entity)
    if not entity or entity==0 or not DoesEntityExist(entity) then return nil end
    if E.byEntity[entity] then return E.byEntity[entity] end
    E.nextId=E.nextId+1;local id=('NXE-%08X'):format(E.nextId);E.byEntity[entity]=id;E.bySession[id]=entity
    Entity(entity).state:set('szcoreSessionId',id,true);return id
end
function E.get(id) local e=E.bySession[id];return e and DoesEntityExist(e) and e or nil end
function E.resolve(entity) if entity and DoesEntityExist(entity) then return E.byEntity[entity] or E.createSessionId(entity) end end
exports('CreateSessionId',E.createSessionId);exports('GetEntityBySessionId',E.get);exports('ResolveSessionId',E.resolve)
AddEventHandler('entityRemoved',function(entity)local id=E.byEntity[entity];E.byEntity[entity]=nil;if id then E.bySession[id]=nil end end)
