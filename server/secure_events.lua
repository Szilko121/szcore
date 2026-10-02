SzCore.SecureEvents=SzCore.SecureEvents or {definitions={},rate={}}
local S=SzCore.SecureEvents
local function allowed(src,name,opt)
    local key=src..':'..name;local now=GetGameTimer();local r=S.rate[key];local win=(opt.rate and opt.rate.window) or SzCoreConfig.SecureEventRate.WindowMs;local max=(opt.rate and opt.rate.max) or SzCoreConfig.SecureEventRate.MaxRequests
    if not r or now-r.started>=win then r={started=now,count=0};S.rate[key]=r end;r.count=r.count+1;return r.count<=max
end
local function validateSchema(schema,data)
    if not schema then return true end;if type(data)~='table' then return false end
    for k,t in pairs(schema) do if type(data[k])~=t then return false end end;return true
end
function SzCore.RegisterSecureEvent(name,options,handler)
    assert(type(name)=='string' and name~='','secure event name required');assert(SzCore.IsCallable(handler),'secure event handler required');options=options or {};local prior=S.definitions[name];if prior and prior.token then RemoveEventHandler(prior.token) end;S.definitions[name]={options=options,handler=handler,resource=GetInvokingResource()}
    RegisterNetEvent(name)
    S.definitions[name].token=AddEventHandler(name,function(data,...)
        local src=source;local d=S.definitions[name];if not d then return end
        if not allowed(src,name,d.options) then SzCore.Metrics.rejectedEvents=SzCore.Metrics.rejectedEvents+1;return end
        if d.options.player~=false and not SzCore.GetPlayer(src) then return end
        if d.options.permission and not SzCore.HasPermission(src,d.options.permission) then SzCore.Metrics.rejectedEvents=SzCore.Metrics.rejectedEvents+1;return end
        if not validateSchema(d.options.schema,data) then SzCore.Metrics.rejectedEvents=SzCore.Metrics.rejectedEvents+1;return end
        if d.options.validate then local ok,res=pcall(d.options.validate,src,data,...);if not ok or res~=true then SzCore.Metrics.rejectedEvents=SzCore.Metrics.rejectedEvents+1;return end end
        SzCore.Metrics.secureEvents=SzCore.Metrics.secureEvents+1
        local ok,err=pcall(d.handler,src,data,...);if not ok then SzCore.Log('error','Secure event %s failed: %s',name,tostring(err)) end
    end)
end
function SzCore.ValidateDistance(source,target,maxDistance)
    if GetPlayerRoutingBucket(source)~=GetPlayerRoutingBucket(target) then return false end
    local a=GetPlayerPed(source);local b=GetPlayerPed(target);if a==0 or b==0 then return false end
    local ac=GetEntityCoords(a);local bc=GetEntityCoords(b);local dx,dy,dz=ac.x-bc.x,ac.y-bc.y,ac.z-bc.z;return dx*dx+dy*dy+dz*dz <= (maxDistance or 3.0)^2
end
exports('RegisterSecureEvent',SzCore.RegisterSecureEvent);exports('ValidateDistance',SzCore.ValidateDistance)
AddEventHandler('playerDropped',function() local prefix=tostring(source)..':' for k in pairs(S.rate) do if k:sub(1,#prefix)==prefix then S.rate[k]=nil end end end)
AddEventHandler('onResourceStop',function(resource)
    for name,d in pairs(S.definitions) do if d.resource==resource then if d.token then RemoveEventHandler(d.token) end;S.definitions[name]=nil end end
end)
