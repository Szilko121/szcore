-- Durable money authority. Every mutation commits before runtime data changes.
-- Requires oxmysql startTransaction(query callback) and InnoDB tables.
SzCore.Money = {}
local M = SzCore.Money
local columns={cash=true,bank=true,crypto=true,dirty=true}
local MAX=9000000000000
local function endpoint(e)
    if type(e)~='table' or type(e.id)~='string' or #e.id<1 or #e.id>96 then return nil end
    if e.kind=='player' and columns[e.account] then return 'money:player:'..e.id end
    if e.kind=='account' then return 'money:account:'..e.id end
end
local function publish(leg, value, old, reason)
    if leg.kind~='player' then return end
    local p=SzCore.GetPlayerByCitizenId(leg.id)
    if not p then return end
    p.PlayerData.money[leg.account]=value
    SzCore.Metrics.moneyChanges=SzCore.Metrics.moneyChanges+1
    TriggerClientEvent('szcore:client:playerDataDelta',p.PlayerData.source,'money.'..leg.account,value)
    TriggerEvent('szcore:server:moneyChanged',p.PlayerData.source,leg.account,value,old,reason)
    SzCore.RunHooks('money:afterSet',{player=p,account=leg.account,old=old,amount=value,reason=reason})
end
function M.apply(legs, reason, actor, bill, vehicle)
    if type(legs)~='table' or (#legs<1 and not vehicle) or #legs>8 then return false,'invalid_transaction' end
    local keys, seen = {}, {}
    for _,leg in ipairs(legs) do
        local key=endpoint(leg)
        local field=key and (key..':'..(leg.account or 'balance'))
        if not key or seen[field] or not SzCore.Integer(leg.value,-MAX,MAX) or (leg.mode~='set' and leg.mode~='add') then return false,'invalid_transaction' end
        seen[field]=true; keys[#keys+1]=key
    end
    if vehicle then keys[#keys+1]='vehicle:'..vehicle.id end
    if bill then keys[#keys+1]='bill:'..bill.id end
    table.sort(legs,function(a,b)return endpoint(a)..':'..(a.account or '') < endpoint(b)..':'..(b.account or '')end)
    reason=tostring(reason or 'unknown'):sub(1,128);actor=tostring(actor or 'system'):sub(1,96)
    return SzCore.WithLocks(keys,function()
        local failure='database_error';local changes={}
        local success=MySQL.startTransaction(function(rawQuery)
            local function query(sql,params)local result=rawQuery(sql,params);if result==nil or result==false then error("transaction_query_failed")end;return result end
            if bill then
                local rows=query("SELECT * FROM szcore_bills WHERE id=? AND target_citizenid=? AND status='unpaid' FOR UPDATE",{bill.id,bill.citizenid})
                local b=rows and rows[1]
                if not b or tonumber(b.amount)~=bill.amount or b.society~=bill.society then failure='bill_changed';return false end
            end
            if vehicle then
                local rows=query('SELECT citizenid,garage,state,impound_fee FROM szcore_vehicles WHERE id=? FOR UPDATE',{vehicle.id})
                local v=rows and rows[1]
                if not v or v.state~=vehicle.state or v.garage~=vehicle.oldGarage or v.citizenid~=vehicle.owner or (tonumber(v.impound_fee)or 0)~=vehicle.fee then failure='vehicle_changed';return false end
            end
            for _,leg in ipairs(legs) do
                local rows,old,allow
                if leg.kind=='player' then
                    rows=query('SELECT '..leg.account..' AS balance FROM szcore_characters WHERE citizenid=? FOR UPDATE',{leg.id})
                    allow=SzCoreConfig.Money.AllowNegative[leg.account]==true
                else
                    rows=query('SELECT balance,allow_negative FROM szcore_financial_accounts WHERE account_id=? FOR UPDATE',{leg.id})
                    allow=rows and rows[1] and (rows[1].allow_negative==1 or rows[1].allow_negative==true)
                end
                if not rows or not rows[1] then failure='account_not_found';return false end
                old=tonumber(rows[1].balance)
                local value=leg.mode=='set' and leg.value or old+leg.value
                local minimum=allow and -MAX or 0
                if leg.kind=='player' and leg.account=='bank' then minimum=math.max(minimum,SzCoreConfig.Money.MinimumBank or 0) end
                if not SzCore.Integer(value,minimum,MAX) then failure='insufficient_funds_or_limit';return false end
                local p=leg.kind=='player' and SzCore.GetPlayerByCitizenId(leg.id)
                if p then
                    local ok,ctx=SzCore.RunHooks('money:beforeSet',{player=p,account=leg.account,old=old,amount=value,reason=reason})
                    if not ok or ctx.amount~=value then failure='hook_cancelled';return false end
                end
                if leg.kind=='player' then
                    query('UPDATE szcore_characters SET '..leg.account..'=? WHERE citizenid=?',{value,leg.id})
                    if SzCoreConfig.Money.AuditLedger then query('INSERT INTO szcore_money_ledger (citizenid,account,amount,balance,reason) VALUES (?,?,?,?,?)',{leg.id,leg.account,value-old,value,reason}) end
                else
                    query('UPDATE szcore_financial_accounts SET balance=? WHERE account_id=?',{value,leg.id})
                    query('INSERT INTO szcore_account_transactions (account_id,amount,reason,actor) VALUES (?,?,?,?)',{leg.id,value-old,reason,actor})
                end
                changes[#changes+1]={leg=leg,value=value,old=old}
            end
            if bill then
                local result=query("UPDATE szcore_bills SET status='paid',paid_at=CURRENT_TIMESTAMP WHERE id=? AND status='unpaid'",{bill.id})
                if not result or result.affectedRows~=1 then failure='bill_changed';return false end
            end
            if vehicle then
                query("UPDATE szcore_vehicles SET state='out',garage=?,last_position=?,impound_fee=0,impound_reason=NULL,impounded_at=NULL WHERE id=?",{vehicle.garage,json.encode(vehicle.position),vehicle.id})
            end
            return true
        end)
        if success~=true then return false,failure end
        for _,c in ipairs(changes) do
            local ok,err=pcall(publish,c.leg,c.value,c.old,reason)
            if not ok then SzCore.Log('error','Money committed; notification failed: %s',tostring(err)) end
        end
        return true
    end)
end
function M.player(cid,account,mode,value,reason)
    return M.apply({{kind='player',id=cid,account=account,mode=mode,value=value}},reason,cid)
end
function M.transfer(from,to,amount,reason,actor)
    amount=SzCore.Integer(amount,1,MAX)
    if not amount or not endpoint(from) or not endpoint(to) or (endpoint(from)==endpoint(to) and from.account==to.account) then return false,'invalid_transfer' end
    return M.apply({{kind=from.kind,id=from.id,account=from.account,mode='add',value=-amount},
        {kind=to.kind,id=to.id,account=to.account,mode='add',value=amount}},reason,actor)
end
exports('TransferMoney',M.transfer)
exports('PayInvoiceAtomic',function(source,id)
    local p=SzCore.GetPlayer(source);id=SzCore.Integer(id,1)
    if not p or not id then return false,'invalid_request' end
    local b=MySQL.single.await("SELECT * FROM szcore_bills WHERE id=? AND target_citizenid=? AND status='unpaid'",{id,p.PlayerData.citizenid})
    if not b then return false,'bill_not_found' end
    local amount=SzCore.Integer(b.amount,1,MAX);if not amount then return false,'invalid_amount' end
    local destination=b.society and {kind='account',id='society:'..b.society} or {kind='player',id=b.issuer_citizenid,account='bank'}
    if not endpoint(destination) then return false,'recipient_not_found' end
    return M.apply({{kind='player',id=p.PlayerData.citizenid,account='bank',mode='add',value=-amount},
        {kind=destination.kind,id=destination.id,account=destination.account,mode='add',value=amount}},'bill:'..id,p.PlayerData.citizenid,
        {id=id,citizenid=p.PlayerData.citizenid,amount=amount,society=b.society})
end)

exports('ReleaseVehicleAtomic',function(source,v,garage,position)
    local p=SzCore.GetPlayer(source);if not p or type(v)~='table' or not SzCore.Integer(v.id,1)then return false,'invalid_request'end
    local fee=v.state=='impounded' and SzCore.Integer(v.impound_fee or 0,0,MAX) or 0
    if not fee then return false,'invalid_fee'end
    local legs={};if fee>0 then legs[1]={kind='player',id=p.PlayerData.citizenid,account='bank',mode='add',value=-fee}end
    return M.apply(legs,'impound_release:'..v.id,p.PlayerData.citizenid,nil,{id=v.id,state=v.state,oldGarage=v.garage,owner=v.citizenid,fee=tonumber(v.impound_fee)or 0,garage=garage,position=position})
end)
