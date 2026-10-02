SzCore.Commands=SzCore.Commands or {}
local C=SzCore.Commands
local function parseArg(src,spec,value)
    if spec.type=='number' then local n=tonumber(value);if not n then return nil,'invalid_number' end;return n end
    if spec.type=='player' then local n=tonumber(value);if not n or not GetPlayerName(n) then return nil,'invalid_player' end;return n end
    if spec.type=='job' then if not SzCoreJobs[value] then return nil,'invalid_job' end;return value end
    if spec.type=='gang' then if not SzCoreGangs[value] then return nil,'invalid_gang' end;return value end
    if spec.type=='boolean' then return value=='true' or value=='1' or value=='yes' end
    return value
end
function C.register(def,handler)
    assert(type(def)=='table' and type(def.name)=='string','command definition required');assert(SzCore.IsCallable(handler),'command handler required')
    C[def.name]={def=def,handler=handler,resource=GetInvokingResource()}
    RegisterCommand(def.name,function(source,args,raw)
        if def.permission and not SzCore.HasPermission(source,def.permission) then TriggerClientEvent('szcore_ui:notify',source,{type='error',description=SzCore.Locale('no_permission')});return end
        local parsed={};for i,spec in ipairs(def.arguments or {}) do local rawValue=spec.rest and table.concat(args,' ',i) or args[i];local v,err=parseArg(source,spec,rawValue);if v==nil and spec.required~=false then TriggerClientEvent('szcore_ui:notify',source,{type='error',description=err or ('Missing '..spec.name)});return end;parsed[spec.name]=v end
        SzCore.Metrics.commands=SzCore.Metrics.commands+1;local ok,err=pcall(handler,source,parsed,raw);if not ok then SzCore.Log('error','Command /%s failed: %s',def.name,tostring(err)) end
    end,def.restricted==true)
end
exports('RegisterCommand',C.register)
