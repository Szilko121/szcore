SzCore.Dependencies=SzCore.Dependencies or {}
local D=SzCore.Dependencies
local function parts(v)local out={};for n in tostring(v or '0'):gmatch('%d+') do out[#out+1]=tonumber(n) or 0 end;return out end
local function atLeast(actual,required)local a,b=parts(actual),parts(required);for i=1,math.max(#a,#b) do local x,y=a[i] or 0,b[i] or 0;if x>y then return true elseif x<y then return false end end;return true end
function D.check(resource,minVersion)
    local state=GetResourceState(resource);if state=='missing' or state=='unknown' then return false,'missing' end
    local version=GetResourceMetadata(resource,'version',0) or '0.0.0';if minVersion and not atLeast(version,minVersion) then return false,'version_too_old',version end;return true,nil,version
end
function D.require(resource,minVersion)
    local ok,err,version=D.check(resource,minVersion);if not ok then error(('Required resource %s failed dependency check (%s, found %s)'):format(resource,tostring(err),tostring(version or 'none'))) end;return true
end
exports('CheckDependency',D.check);exports('RequireDependency',D.require)
CreateThread(function()Wait(0);local ok,err,version=D.check('oxmysql');if not ok then SzCore.Log('error','oxmysql dependency check failed: %s',tostring(err)) else SzCore.Log('debug','oxmysql detected (%s)',tostring(version)) end end)
