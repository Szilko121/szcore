SzCoreClient = SzCoreClient or {}
local pending = {}
local nextId = 0

RegisterNetEvent('szcore:client:callbackResponse', function(requestId, ok, ...)
    local entry = pending[requestId]
    if not entry then return end
    pending[requestId] = nil
    if entry.promise then entry.promise:resolve({ ok = ok, values = table.pack(...) })
    elseif entry.callback then entry.callback(ok, ...) end
end)

local function request(name, args, callback, promiseObject)
    nextId = nextId + 1
    if nextId > 2147483000 then nextId = 1 end
    local id = nextId
    pending[id] = { callback = callback, promise = promiseObject, created = GetGameTimer() }
    TriggerServerEvent('szcore:server:callbackRequest', id, name, table.unpack(args or {},1,args and (args.n or #args) or 0))
    return id
end

function SzCoreClient.TriggerCallback(name, callback, ...) return request(name, table.pack(...), callback, nil) end
function SzCoreClient.AwaitCallback(name, ...)
    local p = promise.new()
    request(name, table.pack(...), nil, p)
    local response = Citizen.Await(p)
    if not response.ok then return nil, response.values[1] end
    return table.unpack(response.values,1,response.values.n or #response.values)
end

CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for id, entry in pairs(pending) do
            if now - entry.created > SzCoreConfig.CallbackTimeout then
                pending[id] = nil
                if entry.promise then entry.promise:resolve({ ok = false, values = { 'timeout' } }) end
                if entry.callback then entry.callback(false, 'timeout') end
            end
        end
    end
end)

exports('TriggerCallback', SzCoreClient.TriggerCallback)
exports('AwaitCallback', SzCoreClient.AwaitCallback)
