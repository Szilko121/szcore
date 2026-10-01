SzCore.Hooks = SzCore.Hooks or { entries = {}, nextId = 0 }
function SzCore.RegisterHook(name, callback, options)
    assert(type(name) == 'string' and name ~= '', 'hook name required')
    assert(type(callback) == 'function', 'hook callback required')
    SzCore.Hooks.nextId = SzCore.Hooks.nextId + 1
    local id = SzCore.Hooks.nextId
    local list = SzCore.Hooks.entries[name] or {}
    SzCore.Hooks.entries[name] = list
    list[#list + 1] = { id = id, callback = callback, priority = (options and options.priority) or 0, once = options and options.once == true, resource = GetInvokingResource() }
    table.sort(list, function(a, b) return a.priority > b.priority end)
    return id
end
function SzCore.RemoveHook(id)
    for name, list in pairs(SzCore.Hooks.entries) do
        for i = #list, 1, -1 do if list[i].id == id then table.remove(list, i); if #list == 0 then SzCore.Hooks.entries[name] = nil end; return true end end
    end
    return false
end
function SzCore.RunHooks(name, context)
    local list = SzCore.Hooks.entries[name]
    if not list then return true, context end
    local snapshot={};for i=1,#list do snapshot[i]=list[i]end
    for _,entry in ipairs(snapshot) do
        if entry.once then SzCore.RemoveHook(entry.id)end
        local ok,result=pcall(entry.callback,context);SzCore.Metrics.hooks=SzCore.Metrics.hooks+1
        if not ok then SzCore.Log('error','Hook %s failed: %s',name,tostring(result));return false,context
        elseif result==false then return false,context
        elseif type(result)=='table' then context=result end
    end
    return true, context
end
AddEventHandler('onResourceStop', function(resource)
    for name, list in pairs(SzCore.Hooks.entries) do
        for i = #list, 1, -1 do if list[i].resource == resource then table.remove(list, i) end end
        if #list == 0 then SzCore.Hooks.entries[name] = nil end
    end
end)
exports('RegisterHook', SzCore.RegisterHook)
exports('RemoveHook', SzCore.RemoveHook)
