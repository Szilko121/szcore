SzCoreClient=SzCoreClient or {};SzCoreClient.PlayerData=SzCoreClient.PlayerData or {};SzCoreClient.Loaded=false
local function apply(root,path,value)local keys={};for k in string.gmatch(path,'[^.]+') do keys[#keys+1]=k end;if #keys==0 then return end;local c=root;for i=1,#keys-1 do local k=keys[i];if type(c[k])~='table' then c[k]={} end;c=c[k] end;c[keys[#keys]]=value end
RegisterNetEvent('szcore:client:playerLoaded',function(data)SzCoreClient.PlayerData=data or {};SzCoreClient.Loaded=true;TriggerEvent('szcore:client:onPlayerLoaded',SzCoreClient.PlayerData)end)
RegisterNetEvent('szcore:client:playerUnloaded',function()SzCoreClient.PlayerData={};SzCoreClient.Loaded=false;TriggerEvent('szcore:client:onPlayerUnloaded')end)
RegisterNetEvent('szcore:client:playerDataDelta',function(path,value)if type(path)~='string' then return end;apply(SzCoreClient.PlayerData,path,value);TriggerEvent('szcore:client:onPlayerData',path,value)end)
exports('GetPlayerData',function()return SzCoreClient.PlayerData end);exports('IsPlayerLoaded',function()return SzCoreClient.Loaded end);exports('Locale',function(key,...)return SzCoreLocale(key,...)end);exports('GetCoreObject',function()return SzCoreClient end)
CreateThread(function()
    for _=1,20 do
        Wait(750);if SzCoreClient.Loaded then return end
        local data=SzCoreClient.AwaitCallback('szcore:restoreSession')
        if data and type(data)=='table' and data.citizenid then
            if not SzCoreClient.Loaded then SzCoreClient.PlayerData=data;SzCoreClient.Loaded=true;TriggerEvent('szcore:client:onPlayerLoaded',data)end
            return
        end
    end
end)
