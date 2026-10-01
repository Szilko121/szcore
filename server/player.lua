local PlayerMethods={};PlayerMethods.__index=PlayerMethods
local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
local function defaults(t,d) t=type(t)=='table' and t or {};for k,v in pairs(d) do if t[k]==nil then t[k]=copy(v) end end;return t end
local function resolveJob(name,grade,duty)
    local job=SzCoreJobs[name];if not job then name=SzCoreConfig.DefaultJob.name;job=SzCoreJobs[name];grade=SzCoreConfig.DefaultJob.grade;duty=SzCoreConfig.DefaultJob.duty end
    grade=tonumber(grade) or 0;local gd=job.grades[grade] or job.grades[0];if not job.grades[grade] then grade=0 end
    return {name=name,label=job.label,type=job.type or 'civilian',grade=grade,gradeName=gd.name,salary=gd.salary or 0,boss=gd.boss==true,onduty=duty==nil and job.defaultDuty==true or duty==true}
end
local function resolveGang(name,grade)
    name=SzCoreGangs[name] and name or SzCoreConfig.DefaultGang.name;local gang=SzCoreGangs[name];grade=tonumber(grade) or 0;local gd=gang.grades[grade] or gang.grades[0];if not gang.grades[grade] then grade=0 end
    return {name=name,label=gang.label,grade=grade,gradeName=gd.name,boss=gd.boss==true}
end
local function position(p) if SzCore.GetPlayer(p.PlayerData.source)~=p then return end;local ped=GetPlayerPed(p.PlayerData.source);if ped~=0 and DoesEntityExist(ped) then local c=GetEntityCoords(ped);p.PlayerData.position={x=c.x,y=c.y,z=c.z,w=GetEntityHeading(ped)} end end
local function delta(p,path,value) TriggerClientEvent('szcore:client:playerDataDelta',p.PlayerData.source,path,value) end
function PlayerMethods:markDirty(section) self._dirty=true;self._dirtyVersion=(self._dirtyVersion or 0)+1;if section then self._dirtySections[section]=true end end
function PlayerMethods:isDirty() return self._dirty==true end
function PlayerMethods:getData() return self.PlayerData end
function PlayerMethods:getMoney(a) return self.PlayerData.money[a] end
function PlayerMethods:setMoney(account,amount,reason)
    if (SzCore.GetPlayer(self.PlayerData.source)~=self or self._unloading) then return false,'stale_player' end
    return SzCore.Money.player(self.PlayerData.citizenid,account,'set',amount,reason)
end
function PlayerMethods:addMoney(account,amount,reason)
    amount=SzCore.Integer(amount,1);if not amount then return false,'invalid_amount' end
    if (SzCore.GetPlayer(self.PlayerData.source)~=self or self._unloading) then return false,'stale_player' end
    return SzCore.Money.player(self.PlayerData.citizenid,account,'add',amount,reason)
end
function PlayerMethods:removeMoney(account,amount,reason)
    amount=SzCore.Integer(amount,1);if not amount then return false,'invalid_amount' end
    if (SzCore.GetPlayer(self.PlayerData.source)~=self or self._unloading) then return false,'stale_player' end
    return SzCore.Money.player(self.PlayerData.citizenid,account,'add',-amount,reason)
end
function PlayerMethods:setJob(name,grade,duty,replace)
    grade=SzCore.Integer(grade or 0,0);local def=SzCoreJobs[name]
    if not def or not grade or not def.grades[grade] then return false,'invalid_job_or_grade'end
    local cid=self.PlayerData.citizenid
    return SzCore.WithLocks({'groups:'..cid},function()
        if (SzCore.GetPlayer(self.PlayerData.source)~=self or self._unloading) then return false,'stale_player'end
        local old=self.PlayerData.job;local new=resolveJob(name,grade,duty)
        if not SzCore.DB.primaryGroup(cid,'job',name,grade,new.onduty,replace and old.name)then return false,'database_error'end
        if SzCore.GetPlayer(self.PlayerData.source)~=self then return true end
        self.PlayerData.job=new
        for _,g in pairs(self.PlayerData.groups.jobs)do g.primary=false end
        if replace and old.name~=name then self.PlayerData.groups.jobs[old.name]=nil;SzCore.ReindexGroup(self.PlayerData.source,'jobs',old.name,nil)end
        self.PlayerData.groups.jobs[name]={grade=grade,duty=new.onduty,primary=true}
        SzCore.ReindexGroup(self.PlayerData.source,'jobs',nil,name)
        SzCore.ReindexJob(self.PlayerData.source,old.name,old.onduty,name,new.onduty)
        local state=Player(self.PlayerData.source).state;state:set('szcoreJob',name,true);state:set('szcoreDuty',new.onduty,true)
        delta(self,'job',new);delta(self,'groups',self.PlayerData.groups)
        TriggerEvent('szcore:server:jobChanged',self.PlayerData.source,new,old)
        if old.onduty~=new.onduty then TriggerEvent('szcore:server:dutyChanged',self.PlayerData.source,new.onduty)end
        SzCore.RunHooks('player:jobChanged',{player=self,new=new,old=old})
        return true
    end)
end
function PlayerMethods:setGang(name,grade,replace)
    grade=SzCore.Integer(grade or 0,0);local def=SzCoreGangs[name]
    if not def or not grade or not def.grades[grade]then return false,'invalid_gang_or_grade'end
    local cid=self.PlayerData.citizenid
    return SzCore.WithLocks({'groups:'..cid},function()
        if (SzCore.GetPlayer(self.PlayerData.source)~=self or self._unloading) then return false,'stale_player'end
        local old=self.PlayerData.gang;local new=resolveGang(name,grade)
        if not SzCore.DB.primaryGroup(cid,'gang',name,grade,false,replace and old.name)then return false,'database_error'end
        if SzCore.GetPlayer(self.PlayerData.source)~=self then return true end
        self.PlayerData.gang=new
        for _,g in pairs(self.PlayerData.groups.gangs)do g.primary=false end
        if replace and old.name~=name then self.PlayerData.groups.gangs[old.name]=nil;SzCore.ReindexGroup(self.PlayerData.source,'gangs',old.name,nil)end
        self.PlayerData.groups.gangs[name]={grade=grade,duty=false,primary=true}
        SzCore.ReindexGroup(self.PlayerData.source,'gangs',nil,name);SzCore.ReindexGang(self.PlayerData.source,old.name,name)
        delta(self,'gang',new);delta(self,'groups',self.PlayerData.groups);TriggerEvent('szcore:server:gangChanged',self.PlayerData.source,new,old)
        return true
    end)
end
function PlayerMethods:setDuty(duty)return self:setJob(self.PlayerData.job.name,self.PlayerData.job.grade,duty==true)end
function PlayerMethods:getMetadata(k) return self.PlayerData.metadata[k] end
function PlayerMethods:setMetadata(k,v) if type(k)~='string' or k=='' then return false end;self.PlayerData.metadata[k]=v;self:markDirty('metadata');delta(self,'metadata.'..k,v);if k=='dead' then Player(self.PlayerData.source).state:set('szcoreDead',v==true,true) end;return true end
function PlayerMethods:hasGroup(kind,name,grade) return SzCore.Groups.has(self,kind,name,grade) end
function PlayerMethods:addGroup(kind,name,grade,duty,primary) return SzCore.Groups.add(self,kind,name,grade,duty,primary) end
function PlayerMethods:removeGroup(kind,name) return SzCore.Groups.remove(self,kind,name) end
function PlayerMethods:hasPermission(permission) return SzCore.HasPermission(self.PlayerData.source,permission) end

function PlayerMethods:hasLicense(name) local l=self.PlayerData.metadata.licenses or {};return l[name]==true end
function PlayerMethods:addLicense(name) local l=self.PlayerData.metadata.licenses or {};l[name]=true;self:setMetadata('licenses',l);return true end
function PlayerMethods:removeLicense(name) local l=self.PlayerData.metadata.licenses or {};l[name]=nil;self:setMetadata('licenses',l);return true end

function PlayerMethods:save(force)
    local deadline=GetGameTimer()+10000;while self._saving do if GetGameTimer()>deadline then return false,'save_busy' end;Wait(5) end;if not force and not self._dirty then return true end;self._saving=true;position(self);local ver=self._dirtyVersion or 0;local ok,res=pcall(SzCore.DB.saveCharacter,self);if not ok or res==false or res==nil then self._saving=false;SzCore.Log('error','Save failed %s: %s',self.PlayerData.citizenid,tostring(res));return false end;if (self._dirtyVersion or 0)==ver then self._dirty=false;self._dirtySections={} end;self._persistedPosition=copy(self.PlayerData.position);self._lastSave=os.time();self._saving=false;SzCore.Metrics.saves=SzCore.Metrics.saves+1;return true
end
function SzCore.CreateRuntimePlayer(source,row)
    local p=setmetatable({PlayerData={source=source,license=row.license,citizenid=row.citizenid,slot=tonumber(row.slot) or 1,name=((row.firstname or '')..' '..(row.lastname or '')),
      charinfo={firstname=row.firstname or 'Unknown',lastname=row.lastname or 'Unknown',birthdate=row.birthdate or '2000-01-01',gender=row.gender or 'male',nationality=row.nationality or 'HU'},
      money={cash=tonumber(row.cash) or 0,bank=tonumber(row.bank) or 0,crypto=tonumber(row.crypto) or 0,dirty=tonumber(row.dirty) or 0},job=resolveJob(row.job,row.job_grade,row.job_duty),gang=resolveGang(row.gang,row.gang_grade),
      groups={jobs={},gangs={}},permissions=type(row.permissions)=='table' and row.permissions or {},metadata=defaults(row.metadata,SzCoreConfig.DefaultMetadata),position=defaults(row.position,SzCoreConfig.DefaultPosition)},
      _dirty=false,_dirtyVersion=0,_saving=false,_dirtySections={},_persistedPosition=copy(row.position or SzCoreConfig.DefaultPosition),_lastSave=os.time()},PlayerMethods)
    SzCore.Groups.load(p);return p
end
function SzCore.GetClientPlayerData(p) if not p then return nil end;local d=p.PlayerData;return {source=d.source,citizenid=d.citizenid,slot=d.slot,name=d.name,charinfo=copy(d.charinfo),money=copy(d.money),job=copy(d.job),gang=copy(d.gang),groups=copy(d.groups),metadata=copy(d.metadata),position=copy(d.position)} end
function SzCore.UpdatePlayerPosition(p) position(p) end
function SzCore.GetJob(n) return SzCoreJobs[n] end;function SzCore.GetJobs() return SzCoreJobs end;function SzCore.GetGang(n)return SzCoreGangs[n] end;function SzCore.GetGangs()return SzCoreGangs end

SzCore.ExportPlayers=SzCore.ExportPlayers or {}
function SzCore.ToExportPlayer(p)
    if not p then return nil end;local src=p.PlayerData.source;if SzCore.ExportPlayers[src] then return SzCore.ExportPlayers[src] end
    local x={PlayerData=p.PlayerData}
    x.getData=function()return p:getData()end;x.getMoney=function(a)return p:getMoney(a)end;x.setMoney=function(a,n,r)return p:setMoney(a,n,r)end;x.addMoney=function(a,n,r)return p:addMoney(a,n,r)end;x.removeMoney=function(a,n,r)return p:removeMoney(a,n,r)end;x.setJob=function(n,g,d)return p:setJob(n,g,d)end;x.setGang=function(n,g)return p:setGang(n,g)end;x.setDuty=function(d)return p:setDuty(d)end;x.getMetadata=function(k)return p:getMetadata(k)end;x.setMetadata=function(k,v)return p:setMetadata(k,v)end;x.hasGroup=function(k,n,g)return p:hasGroup(k,n,g)end;x.addGroup=function(k,n,g,d,pr)return p:addGroup(k,n,g,d,pr)end;x.removeGroup=function(k,n)return p:removeGroup(k,n)end;x.hasPermission=function(per)return p:hasPermission(per)end;x.hasLicense=function(n)return p:hasLicense(n)end;x.addLicense=function(n)return p:addLicense(n)end;x.removeLicense=function(n)return p:removeLicense(n)end;x.save=function(f)return p:save(f)end
    SzCore.ExportPlayers[src]=x;return x
end
