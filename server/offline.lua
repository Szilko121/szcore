SzCore.Offline=SzCore.Offline or {}
local O=SzCore.Offline
local moneyCols={cash='cash',bank='bank',crypto='crypto',dirty='dirty'}
local function column(account)return moneyCols[account] end
local function ledger(cid,account,delta,reason)local bal=MySQL.scalar.await('SELECT '..column(account)..' FROM szcore_characters WHERE citizenid=?',{cid});SzCore.DB.addMoneyLedger(cid,account,delta,tonumber(bal) or 0,reason or 'offline')end
function O.getData(citizenid)
    local row=SzCore.DB.loadCharacterByCitizen(citizenid);if not row then return nil end
    row.money={cash=tonumber(row.cash) or 0,bank=tonumber(row.bank) or 0,crypto=tonumber(row.crypto) or 0,dirty=tonumber(row.dirty) or 0};return row
end
function O.addMoney(cid,account,value,reason)
    value=SzCore.Integer(value,1);if not value then return false,'invalid_amount' end
    return SzCore.Money.player(cid,account,'add',value,reason)
end
function O.removeMoney(cid,account,value,reason)
    value=SzCore.Integer(value,1);if not value then return false,'invalid_amount' end
    return SzCore.Money.player(cid,account,'add',-value,reason)
end
function O.setMoney(cid,account,value,reason)return SzCore.Money.player(cid,account,'set',value,reason)end
function O.setJob(cid,name,grade,duty)
    local live=SzCore.GetPlayerByCitizenId(cid);if live then return live:setJob(name,grade,duty)end
    grade=SzCore.Integer(grade or 0,0);if not SzCoreJobs[name] or not grade or not SzCoreJobs[name].grades[grade] then return false,'invalid_job'end
    return SzCore.WithLocks({'groups:'..cid},function()return SzCore.DB.primaryGroup(cid,'job',name,grade,duty)end)
end
function O.setGang(cid,name,grade)
    local live=SzCore.GetPlayerByCitizenId(cid);if live then return live:setGang(name,grade)end
    grade=SzCore.Integer(grade or 0,0);if not SzCoreGangs[name] or not grade or not SzCoreGangs[name].grades[grade] then return false,'invalid_gang'end
    return SzCore.WithLocks({'groups:'..cid},function()return SzCore.DB.primaryGroup(cid,'gang',name,grade,false)end)
end
function O.setMetadata(citizenid,key,value)
    local live=SzCore.GetPlayerByCitizenId(citizenid);if live then return live:setMetadata(key,value)end
    if type(key)~='string' or key=='' then return false end;local row=SzCore.DB.loadCharacterByCitizen(citizenid);if not row then return false end;row.metadata[key]=value;return MySQL.update.await('UPDATE szcore_characters SET metadata=? WHERE citizenid=?',{json.encode(row.metadata),citizenid})>0
end
function O.addGroup(citizenid,kind,name,grade,duty,primary)
    local live=SzCore.GetPlayerByCitizenId(citizenid);if live then return live:addGroup(kind,name,grade,duty,primary)end
    kind=(kind=='job' or kind=='jobs') and 'job' or 'gang';grade=tonumber(grade) or 0;local defs=kind=='job' and SzCoreJobs or SzCoreGangs;if not defs[name] or not defs[name].grades[grade] then return false end
    if primary then if kind=='job' then return O.setJob(citizenid,name,grade,duty)end;return O.setGang(citizenid,name,grade)end
    SzCore.DB.upsertGroup(citizenid,kind,name,grade,duty,false);return true
end
function O.removeGroup(citizenid,kind,name)
    local live=SzCore.GetPlayerByCitizenId(citizenid);if live then return live:removeGroup(kind,name)end
    kind=(kind=='job' or kind=='jobs') and 'job' or 'gang';local row=MySQL.single.await('SELECT is_primary FROM szcore_character_groups WHERE citizenid=? AND group_type=? AND name=?',{citizenid,kind,name});if not row then return false,'not_member' end;if row.is_primary==1 or row.is_primary==true then return false,'primary_group' end;return SzCore.DB.removeGroup(citizenid,kind,name)>0
end
function O.search(filters) return SzCore.DB.searchCharacters(filters) end
function O.proxy(citizenid)
    local d=O.getData(citizenid);if not d then return nil end
    return {PlayerData=d,addMoney=function(a,n,r)return O.addMoney(citizenid,a,n,r)end,removeMoney=function(a,n,r)return O.removeMoney(citizenid,a,n,r)end,setMoney=function(a,n,r)return O.setMoney(citizenid,a,n,r)end,setJob=function(j,g,du)return O.setJob(citizenid,j,g,du)end,setGang=function(j,g)return O.setGang(citizenid,j,g)end,setMetadata=function(k,v)return O.setMetadata(citizenid,k,v)end,addGroup=function(k,n,g,du,p)return O.addGroup(citizenid,k,n,g,du,p)end,removeGroup=function(k,n)return O.removeGroup(citizenid,k,n)end}
end
local rawSearch=O.search
function O.search(filters)
    local rows=rawSearch(filters);for i=1,#rows do local live=SzCore.GetPlayerByCitizenId(rows[i].citizenid);rows[i].online=live~=nil;rows[i].source=live and live.PlayerData.source or nil end;return rows
end
exports('GetOfflinePlayerData',O.getData);exports('GetOfflinePlayer',O.proxy);exports('AddOfflineMoney',O.addMoney);exports('RemoveOfflineMoney',O.removeMoney);exports('SetOfflineMoney',O.setMoney);exports('SetOfflineJob',O.setJob);exports('SetOfflineGang',O.setGang);exports('SetOfflineMetadata',O.setMetadata);exports('AddOfflineGroup',O.addGroup);exports('RemoveOfflineGroup',O.removeGroup);exports('SearchPlayers',O.search)

exports('SetOfflinePrimaryGroup',function(cid,kind,name)
    local row=MySQL.single.await('SELECT grade,duty FROM szcore_character_groups WHERE citizenid=? AND group_type=? AND name=?',{cid,kind,name})
    if not row then return false,'not_member'end
    if kind=='job' then return O.setJob(cid,name,row.grade,row.duty==true or row.duty==1)end
    return O.setGang(cid,name,row.grade)
end)
