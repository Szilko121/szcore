SzCore.Accounts=SzCore.Accounts or {}
local A=SzCore.Accounts
local locks={}
local function acquire(ids)
    table.sort(ids)
    local deadline=GetGameTimer()+5000
    for i=1,#ids do
        local id=ids[i]
        while locks[id] do if GetGameTimer()>deadline then for j=1,i-1 do locks[ids[j]]=nil end;return false end;Wait(0) end
        locks[id]=true
    end
    return true
end
local function release(ids)for i=1,#ids do locks[ids[i]]=nil end end
function A.ensure(id,kind,owner,label,balance,allowNegative)
    MySQL.prepare.await([[INSERT INTO szcore_financial_accounts (account_id,account_type,owner_id,label,balance,allow_negative)
      VALUES (?,?,?,?,?,?) ON DUPLICATE KEY UPDATE label=VALUES(label)]],{id,kind,owner,label or id,balance or 0,allowNegative and 1 or 0})
    return A.get(id)
end
function A.get(id) return MySQL.single.await('SELECT * FROM szcore_financial_accounts WHERE account_id=?',{id}) end
function A.balance(id) return tonumber(MySQL.scalar.await('SELECT balance FROM szcore_financial_accounts WHERE account_id=?',{id})) end
function A.change(id,amount,reason,actor)return SzCore.Money.apply({{kind='account',id=id,mode='add',value=amount}},reason,actor)end
function A.transfer(from,to,amount,reason,actor)return SzCore.Money.transfer({kind='account',id=from},{kind='account',id=to},amount,reason,actor)end
function A.transactions(id,limit)
    limit=math.max(1,math.min(tonumber(limit) or 50,200))
    return MySQL.query.await('SELECT * FROM szcore_account_transactions WHERE account_id=? ORDER BY id DESC LIMIT '..limit,{id}) or {}
end
exports('EnsureAccount',A.ensure);exports('GetAccount',A.get);exports('GetAccountBalance',A.balance);exports('ChangeAccountBalance',A.change);exports('TransferAccounts',A.transfer);exports('GetAccountTransactions',A.transactions)
