SzCore = SzCore or {}
SzCore.Metrics = SzCore.Metrics or {
    logins = 0, logouts = 0, saves = 0, batchSaves = 0, callbacks = 0,
    rejectedCallbacks = 0, secureEvents = 0, rejectedEvents = 0, moneyChanges = 0,
    dbWrites = 0, inventoryWrites = 0, hooks = 0, commands = 0
}
function SzCore.Log(level, message, ...)
    local txt = select('#', ...) > 0 and string.format(message, ...) or tostring(message)
    print(('[SzCore:%s] %s'):format(string.upper(level or 'INFO'), txt));local webhook=GetConvar('szcore_log_webhook','');if webhook~='' and (level=='error' or level=='warn') then PerformHttpRequest(webhook,function()end,'POST',json.encode({username='SzCore',content=('**%s** %s'):format(string.upper(level or 'INFO'),txt)}),{['Content-Type']='application/json'}) end
end
function SzCore.Debug(message, ...) if SzCoreConfig.Debug then SzCore.Log('debug', message, ...) end end
function SzCore.Locale(key, ...) return SzCoreLocale(key, ...) end
function SzCore.Audit(action, source, target, data)
    if not SzCoreConfig.Audit.Enabled or not SzCore.DB or not SzCore.DB.audit then return end
    local srcPlayer = source and SzCore.GetPlayer and SzCore.GetPlayer(source) or nil
    local actor = srcPlayer and srcPlayer.PlayerData.citizenid or (source and tostring(source) or 'system')
    CreateThread(function()
        local ok, err = pcall(SzCore.DB.audit, action, actor, target and tostring(target) or nil, data or {})
        if not ok then SzCore.Debug('Audit failed: %s', tostring(err)) end
    end)
end
exports('Audit',SzCore.Audit)
exports('GetMetrics',function()return SzCore.Metrics end)
