SzCore.ServerCallbacks = SzCore.ServerCallbacks or {}

local rate = {}
local owners = {}
local inflight = {}
local sessions = {}

local function allowed(src)
    local now = GetGameTimer()
    local window = SzCoreConfig.CallbackRate.WindowMs
    local limit = SzCoreConfig.CallbackRate.MaxRequests
    local bucket = rate[src]

    if not bucket or now - bucket.started >= window then
        bucket = { started = now, count = 0 }
        rate[src] = bucket
    end

    bucket.count = bucket.count + 1
    return bucket.count <= limit
end

function SzCore.CreateCallback(name, fn, owner)
    if type(name) ~= 'string' or name == '' or #name > 128 then
        return false, 'invalid_callback_name'
    end

    if not SzCore.IsCallable(fn) then
        return false, ('invalid_callback_handler:%s'):format(type(fn))
    end

    owner = owner or GetInvokingResource() or GetCurrentResourceName()

    SzCore.ServerCallbacks[name] = fn
    owners[name] = owner

    SzCore.Debug('Registered callback %s from %s', name, owner)
    return true
end

RegisterNetEvent('szcore:server:callbackRequest', function(id, name, ...)
    local src = source

    if not SzCore.Integer(id, 0, 2147483647) or type(name) ~= 'string' or #name > 128 then
        return
    end

    if (inflight[src] or 0) >= 8 then
        SzCore.Metrics.rejectedCallbacks = SzCore.Metrics.rejectedCallbacks + 1
        TriggerClientEvent('szcore:client:callbackResponse', src, id, false, 'too_many_inflight')
        return
    end

    local session = sessions[src]
    if not session then
        session = {}
        sessions[src] = session
    end

    if not allowed(src) then
        SzCore.Metrics.rejectedCallbacks = SzCore.Metrics.rejectedCallbacks + 1
        TriggerClientEvent('szcore:client:callbackResponse', src, id, false, 'rate_limited')
        return
    end

    if not SzCore.Ready then
        TriggerClientEvent('szcore:client:callbackResponse', src, id, false, 'core_not_ready')
        return
    end

    local fn = SzCore.ServerCallbacks[name]
    if not fn then
        TriggerClientEvent('szcore:client:callbackResponse', src, id, false, 'callback_not_found')
        return
    end

    SzCore.Metrics.callbacks = SzCore.Metrics.callbacks + 1
    inflight[src] = (inflight[src] or 0) + 1

    local result = table.pack(pcall(fn, src, ...))

    if sessions[src] ~= session then
        return
    end

    inflight[src] = math.max(0, (inflight[src] or 1) - 1)

    if not result[1] then
        SzCore.Log('error', 'Callback %s failed: %s', name, tostring(result[2]))
        TriggerClientEvent('szcore:client:callbackResponse', src, id, false, 'callback_error')
        return
    end

    TriggerClientEvent(
        'szcore:client:callbackResponse',
        src,
        id,
        true,
        table.unpack(result, 2, result.n)
    )
end)

AddEventHandler('playerDropped', function()
    rate[source] = nil
    inflight[source] = nil
    sessions[source] = nil
end)

exports('CreateCallback', function(name, fn)
    local owner = GetInvokingResource() or 'unknown'
    local ok, err = SzCore.CreateCallback(name, fn, owner)

    if not ok then
        SzCore.Log(
            'error',
            'CreateCallback rejected registration from %s: name=%s handler=%s error=%s',
            owner,
            tostring(name),
            type(fn),
            tostring(err)
        )
        return false, err
    end

    return true
end)

AddEventHandler('onResourceStop', function(resource)
    for name, owner in pairs(owners) do
        if owner == resource then
            SzCore.ServerCallbacks[name] = nil
            owners[name] = nil
        end
    end
end)
