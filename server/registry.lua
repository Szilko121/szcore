SzCore.Registry = SzCore.Registry or {bySource={},byCitizenId={},byLicense={},byJob={},byDutyJob={},byGang={},byGroup={}}
local R=SzCore.Registry
local counts=setmetatable({},{__mode="k"});local total=0
local function add(index,key,src) if not key then return end; index[key]=index[key] or {}; if not index[key][src] then index[key][src]=true;counts[index]=counts[index] or {};counts[index][key]=(counts[index][key] or 0)+1 end end
local function rem(index,key,src) local b=key and index[key]; if not b then return end; if b[src] then b[src]=nil;counts[index][key]=math.max(0,(counts[index][key] or 1)-1) end; if not next(b) then index[key]=nil end end
function SzCore.RegisterPlayer(p)
    local d=p.PlayerData;if R.bySource[d.source] then SzCore.UnregisterPlayer(d.source) end;total=total+1; R.bySource[d.source]=p; R.byCitizenId[d.citizenid]=d.source; add(R.byLicense,d.license,d.source)
    add(R.byJob,d.job.name,d.source); if d.job.onduty then add(R.byDutyJob,d.job.name,d.source) end; add(R.byGang,d.gang.name,d.source)
    for kind,groups in pairs(d.groups or {}) do for name in pairs(groups) do add(R.byGroup,kind..':'..name,d.source) end end
end
function SzCore.UnregisterPlayer(src)
    local p=R.bySource[src]; if not p then return end; local d=p.PlayerData
    total=math.max(0,total-1);R.bySource[src]=nil; if SzCore.ExportPlayers then SzCore.ExportPlayers[src]=nil end
    if R.byCitizenId[d.citizenid]==src then R.byCitizenId[d.citizenid]=nil end
    rem(R.byLicense,d.license,src); rem(R.byJob,d.job.name,src); rem(R.byDutyJob,d.job.name,src); rem(R.byGang,d.gang.name,src)
    for kind,groups in pairs(d.groups or {}) do for name in pairs(groups) do rem(R.byGroup,kind..':'..name,src) end end
end
function SzCore.ReindexJob(src,oldName,oldDuty,newName,newDuty) rem(R.byJob,oldName,src);if oldDuty then rem(R.byDutyJob,oldName,src) end;add(R.byJob,newName,src);if newDuty then add(R.byDutyJob,newName,src) end end
function SzCore.ReindexGang(src,oldName,newName) rem(R.byGang,oldName,src);add(R.byGang,newName,src) end
function SzCore.ReindexGroup(src,kind,oldName,newName) if oldName then rem(R.byGroup,kind..':'..oldName,src) end;if newName then add(R.byGroup,kind..':'..newName,src) end end
function SzCore.GetPlayer(src) return R.bySource[tonumber(src)] end
function SzCore.GetPlayerByCitizenId(id) local src=R.byCitizenId[id];return src and R.bySource[src] or nil end
function SzCore.GetPlayersByJob(name,duty) local idx=duty and R.byDutyJob or R.byJob;local b=idx[name];local out={};if not b then return out end;for src in pairs(b) do if R.bySource[src] then out[#out+1]=R.bySource[src] end end;return out end
function SzCore.GetPlayersByGroup(kind,name) local b=R.byGroup[kind..':'..name];local out={};if not b then return out end;for src in pairs(b) do if R.bySource[src] then out[#out+1]=R.bySource[src] end end;return out end
function SzCore.GetPlayerCount()return total end
function SzCore.GetJobCount(name,duty)local idx=duty and R.byDutyJob or R.byJob;return counts[idx] and counts[idx][name] or 0 end
function SzCore.GetPlayerByLicense(license)local bucket=R.byLicense[license];if not bucket then return nil end;for src in pairs(bucket) do return R.bySource[src] end end
function SzCore.GetPlayerSources()local out={};for src in pairs(R.bySource) do out[#out+1]=src end;table.sort(out);return out end
exports('GetPlayerByLicense',function(license)return SzCore.ToExportPlayer(SzCore.GetPlayerByLicense(license))end)
exports('GetPlayerSources',SzCore.GetPlayerSources)
