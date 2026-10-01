SzCore.ServerCallbacks=SzCore.ServerCallbacks or {};local rate={};local owners={};local inflight={};local sessions={}
local function allowed(src) local now=GetGameTimer();local w=SzCoreConfig.CallbackRate.WindowMs;local l=SzCoreConfig.CallbackRate.MaxRequests;local b=rate[src];if not b or now-b.started>=w then b={started=now,count=0};rate[src]=b end;b.count=b.count+1;return b.count<=l end
function SzCore.CreateCallback(name,fn) assert(type(name)=='string' and name~='');assert(type(fn)=='function');SzCore.ServerCallbacks[name]=fn;owners[name]=GetInvokingResource() end
RegisterNetEvent('szcore:server:callbackRequest',function(id,name,...)
    local src=source;if not SzCore.Integer(id,0,2147483647) or type(name)~='string' or #name>128 then return end;if (inflight[src] or 0)>=8 then return end;local session=sessions[src] or {};sessions[src]=session;if not allowed(src) then SzCore.Metrics.rejectedCallbacks=SzCore.Metrics.rejectedCallbacks+1;TriggerClientEvent('szcore:client:callbackResponse',src,id,false,'rate_limited');return end
    if not SzCore.Ready then TriggerClientEvent('szcore:client:callbackResponse',src,id,false,'core_not_ready');return end
    local fn=SzCore.ServerCallbacks[name];if not fn then TriggerClientEvent('szcore:client:callbackResponse',src,id,false,'callback_not_found');return end;SzCore.Metrics.callbacks=SzCore.Metrics.callbacks+1
    inflight[src]=(inflight[src] or 0)+1;local ok,a,b,c,d,e=pcall(fn,src,...);if sessions[src]~=session then return end;inflight[src]=math.max(0,(inflight[src] or 1)-1);if not ok then SzCore.Log('error','Callback %s failed: %s',name,tostring(a));TriggerClientEvent('szcore:client:callbackResponse',src,id,false,'callback_error');return end;TriggerClientEvent('szcore:client:callbackResponse',src,id,true,a,b,c,d,e)
end)
AddEventHandler('playerDropped',function()rate[source]=nil;inflight[source]=nil;sessions[source]=nil end)
exports('CreateCallback',SzCore.CreateCallback)
AddEventHandler('onResourceStop',function(resource)for name,owner in pairs(owners) do if owner==resource then SzCore.ServerCallbacks[name]=nil;owners[name]=nil end end end)
