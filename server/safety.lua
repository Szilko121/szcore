SzCore.Locks = {}
function SzCore.Integer(value, minimum, maximum)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge or n % 1 ~= 0 then return nil end
    if n < (minimum or -9007199254740991) or n > (maximum or 9007199254740991) then return nil end
    return n
end
function SzCore.WithLocks(keys, fn)
    local seen, ordered = {}, {}
    for _, key in ipairs(keys) do if not seen[key] then seen[key]=true; ordered[#ordered+1]=key end end
    table.sort(ordered)
    for _, key in ipairs(ordered) do if SzCore.Locks[key] then return false, 'operation_busy' end end
    for _, key in ipairs(ordered) do SzCore.Locks[key]=true end
    local result=table.pack(pcall(fn))
    for _, key in ipairs(ordered) do SzCore.Locks[key]=nil end
    if not result[1] then SzCore.Log('error','Operation failed: %s',tostring(result[2]));return false,'operation_failed' end
    return table.unpack(result,2,result.n)
end
exports('ValidateInteger', SzCore.Integer)
