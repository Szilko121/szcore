SzCore.Permissions = SzCore.Permissions or {}
local function listHas(list, wanted)
    if type(list) ~= 'table' then return false end
    for i = 1, #list do if list[i] == '*' or list[i] == wanted then return true end end
    return false
end
function SzCore.IsAdmin(source)
    return source == 0 or IsPlayerAceAllowed(tostring(source), 'szcore.admin') or IsPlayerAceAllowed(tostring(source), 'command')
end
function SzCore.HasPermission(source, permission)
    if source == 0 or SzCore.IsAdmin(source) then return true end
    if IsPlayerAceAllowed(tostring(source), 'szcore.' .. permission) then return true end
    local player = SzCore.GetPlayer and SzCore.GetPlayer(source)
    if not player then return false end
    if listHas(player.PlayerData.permissions, permission) then return true end
    local job = player.PlayerData.job
    if job then
        local def = SzCoreJobs[job.name]
        local grade = def and def.grades[job.grade]
        if grade and listHas(grade.permissions, permission) then return true end
    end
    return false
end
function SzCore.RequirePermission(source, permission)
    if SzCore.HasPermission(source, permission) then return true end
    return false, 'no_permission'
end
exports('IsAdmin', SzCore.IsAdmin)
exports('HasPermission', SzCore.HasPermission)
