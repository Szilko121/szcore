SzCore.Groups = SzCore.Groups or {}
local G=SzCore.Groups
local function def(kind,name)
    if kind=='jobs' or kind=='job' then return SzCoreJobs[name] end
    if kind=='gangs' or kind=='gang' then return SzCoreGangs[name] end
end
local function normalizeKind(kind) return (kind=='job' or kind=='jobs') and 'jobs' or 'gangs' end
function G.load(player)
    player.PlayerData.groups={jobs={},gangs={}}
    local rows=SzCore.DB.getGroups(player.PlayerData.citizenid)
    if #rows==0 then
        SzCore.DB.upsertGroup(player.PlayerData.citizenid,'job',player.PlayerData.job.name,player.PlayerData.job.grade,player.PlayerData.job.onduty,true)
        SzCore.DB.upsertGroup(player.PlayerData.citizenid,'gang',player.PlayerData.gang.name,player.PlayerData.gang.grade,false,true)
        rows=SzCore.DB.getGroups(player.PlayerData.citizenid)
    end
    for i=1,#rows do local r=rows[i];local k=r.group_type=='job' and 'jobs' or 'gangs';player.PlayerData.groups[k][r.name]={grade=tonumber(r.grade) or 0,duty=r.duty==1 or r.duty==true,primary=r.is_primary==1 or r.is_primary==true} end
end
function G.has(player,kind,name,minGrade)
    kind=normalizeKind(kind);local e=player and player.PlayerData.groups and player.PlayerData.groups[kind] and player.PlayerData.groups[kind][name]
    return e~=nil and (tonumber(e.grade) or 0)>=(tonumber(minGrade) or 0)
end
function G.add(player,kind,name,grade,duty,primary)
    kind=normalizeKind(kind);grade=SzCore.Integer(grade or 0,0);local d=def(kind,name)
    if not d or not grade or not d.grades[grade]then return false,'invalid_group'end
    local old=player.PlayerData.groups[kind][name]
    if primary or (old and old.primary) then if kind=='jobs' then return player:setJob(name,grade,duty)end;return player:setGang(name,grade) end
    return SzCore.WithLocks({'groups:'..player.PlayerData.citizenid},function()
        local ok=SzCore.DB.upsertGroup(player.PlayerData.citizenid,kind=='jobs' and 'job' or 'gang',name,grade,duty,false)
        if ok==nil or ok==false then return false,'database_error'end
        player.PlayerData.groups[kind][name]={grade=grade,duty=duty==true,primary=false}
        SzCore.ReindexGroup(player.PlayerData.source,kind,nil,name)
        TriggerClientEvent('szcore:client:playerDataDelta',player.PlayerData.source,'groups',player.PlayerData.groups)
        return true
    end)
end
function G.remove(player,kind,name)
    kind=normalizeKind(kind)
    return SzCore.WithLocks({'groups:'..player.PlayerData.citizenid},function()
        local e=player.PlayerData.groups[kind][name];if not e then return false,'not_member'end
        if e.primary then return false,'primary_group'end
        if SzCore.DB.removeGroup(player.PlayerData.citizenid,kind=='jobs' and 'job' or 'gang',name)<1 then return false,'database_error'end
        player.PlayerData.groups[kind][name]=nil;SzCore.ReindexGroup(player.PlayerData.source,kind,name,nil)
        TriggerClientEvent('szcore:client:playerDataDelta',player.PlayerData.source,'groups',player.PlayerData.groups);return true
    end)
end
function G.setPrimary(player,kind,name,grade,duty)
    kind=normalizeKind(kind);local e=player.PlayerData.groups[kind][name];if not e then return false,'not_member'end
    if duty==nil then duty=e.duty end
    if kind=='jobs' then return player:setJob(name,grade or e.grade,duty)end
    return player:setGang(name,grade or e.grade)
end
exports('HasGroup',function(source,kind,name,minGrade)local p=SzCore.GetPlayer(source);return p and G.has(p,kind,name,minGrade) or false end)
exports('GetPlayersByGroup',function(kind,name)local list=SzCore.GetPlayersByGroup(normalizeKind(kind),name);local out={};for i=1,#list do out[i]=list[i].PlayerData.source end;return out end)
function G.addDefinition(kind,name,data)
    if type(name)~='string' or type(data)~='table' or type(data.grades)~='table' then return false end
    if kind=='job' or kind=='jobs' then SzCoreJobs[name]=data else SzCoreGangs[name]=data end
    TriggerEvent('szcore:server:definitionsChanged',kind,name,data);return true
end
function G.removeDefinition(kind,name)
    if name=='unemployed' or name=='none' then return false end
    if kind=='job' or kind=='jobs' then SzCoreJobs[name]=nil else SzCoreGangs[name]=nil end
    TriggerEvent('szcore:server:definitionsChanged',kind,name,nil);return true
end
exports('AddGroupDefinition',G.addDefinition);exports('RemoveGroupDefinition',G.removeDefinition)
exports('AddGroup',function(source,kind,name,grade,duty,primary)local p=SzCore.GetPlayer(source);return p and G.add(p,kind,name,grade,duty,primary) or false end)
exports('RemoveGroup',function(source,kind,name)local p=SzCore.GetPlayer(source);return p and G.remove(p,kind,name) or false end)
exports('SetPrimaryGroup',function(source,kind,name)local p=SzCore.GetPlayer(source);return p and G.setPrimary(p,kind,name) or false end)
exports('ReplacePrimaryGroup',function(src,kind,name,grade)
    local p=SzCore.GetPlayer(src);if not p then return false,'player_not_found'end
    if normalizeKind(kind)=='jobs' then return p:setJob(name,grade,nil,true)end
    return p:setGang(name,grade,true)
end)
