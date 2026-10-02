SzCore.DB = SzCore.DB or {}
local DB = SzCore.DB
local SAVE_SQL = [[
UPDATE szcore_characters SET
 firstname=?, lastname=?, birthdate=?, gender=?, nationality=?,
 metadata=?, position=?, permissions=?, last_seen=CURRENT_TIMESTAMP
WHERE citizenid=? AND license=?
]]
local function decode(v, fallback)
    if not v or v == '' then return fallback end
    local ok, x = pcall(json.decode, v)
    return ok and x ~= nil and x or fallback
end
function DB.ensureAccount(identifier, name)
    return MySQL.prepare.await([[INSERT INTO szcore_accounts (license,display_name) VALUES (?,?)
      ON DUPLICATE KEY UPDATE display_name=VALUES(display_name),last_seen=CURRENT_TIMESTAMP]], {identifier,name or 'Unknown'})
end

local function identifierPlaceholders(identifiers)
    if type(identifiers) ~= 'table' or #identifiers == 0 then
        return nil
    end

    local placeholders = {}
    for i = 1, #identifiers do
        placeholders[i] = '?'
    end

    return table.concat(placeholders, ',')
end

function DB.listCharactersAny(identifiers)
    local placeholders = identifierPlaceholders(identifiers)
    if not placeholders then return {} end

    return MySQL.query.await(
        ('SELECT citizenid,slot,firstname,lastname,birthdate,gender,nationality,cash,bank,job,job_grade,last_seen,license FROM szcore_characters WHERE license IN (%s) ORDER BY slot ASC'):format(placeholders),
        identifiers
    ) or {}
end

function DB.loadCharacterAny(identifiers, citizenid)
    local placeholders = identifierPlaceholders(identifiers)
    if not placeholders then return nil end

    local params = {}
    for i = 1, #identifiers do params[#params + 1] = identifiers[i] end
    params[#params + 1] = citizenid

    local row = MySQL.single.await(
        ('SELECT * FROM szcore_characters WHERE license IN (%s) AND citizenid=? LIMIT 1'):format(placeholders),
        params
    )

    if not row then return nil end

    row.metadata = decode(row.metadata, {})
    row.position = decode(row.position, SzCoreConfig.DefaultPosition)
    row.permissions = decode(row.permissions, {})
    row.job_duty = row.job_duty == 1 or row.job_duty == true

    return row
end

function DB.slotTakenAny(identifiers, slot)
    local placeholders = identifierPlaceholders(identifiers)
    if not placeholders then return false end

    local params = {}
    for i = 1, #identifiers do params[#params + 1] = identifiers[i] end
    params[#params + 1] = slot

    return MySQL.scalar.await(
        ('SELECT 1 FROM szcore_characters WHERE license IN (%s) AND slot=? LIMIT 1'):format(placeholders),
        params
    ) ~= nil
end

function DB.deleteCharacterAny(identifiers, citizenid)
    local placeholders = identifierPlaceholders(identifiers)
    if not placeholders then return 0 end

    local params = {}
    for i = 1, #identifiers do params[#params + 1] = identifiers[i] end
    params[#params + 1] = citizenid

    return MySQL.update.await(
        ('DELETE FROM szcore_characters WHERE license IN (%s) AND citizenid=?'):format(placeholders),
        params
    )
end

function DB.listCharacters(identifier)
    return MySQL.query.await([[SELECT citizenid,slot,firstname,lastname,birthdate,gender,nationality,cash,bank,job,job_grade,last_seen
      FROM szcore_characters WHERE license=? ORDER BY slot ASC]], {identifier}) or {}
end
function DB.loadCharacter(identifier, citizenid)
    local row = MySQL.single.await('SELECT * FROM szcore_characters WHERE license=? AND citizenid=? LIMIT 1',{identifier,citizenid})
    if not row then return nil end
    row.metadata=decode(row.metadata,{}) ; row.position=decode(row.position,SzCoreConfig.DefaultPosition)
    row.permissions=decode(row.permissions,{}) ; row.job_duty=row.job_duty==1 or row.job_duty==true
    return row
end
function DB.loadCharacterByCitizen(citizenid)
    local row = MySQL.single.await('SELECT * FROM szcore_characters WHERE citizenid=? LIMIT 1',{citizenid})
    if not row then return nil end
    row.metadata=decode(row.metadata,{}) ; row.position=decode(row.position,SzCoreConfig.DefaultPosition)
    row.permissions=decode(row.permissions,{}) ; row.job_duty=row.job_duty==1 or row.job_duty==true
    return row
end
function DB.slotTaken(identifier, slot) return MySQL.scalar.await('SELECT 1 FROM szcore_characters WHERE license=? AND slot=? LIMIT 1',{identifier,slot})~=nil end
function DB.citizenIdTaken(id) return MySQL.scalar.await('SELECT 1 FROM szcore_characters WHERE citizenid=? LIMIT 1',{id})~=nil end
function DB.createCharacter(identifier,citizenid,data)
    return MySQL.insert.await([[INSERT INTO szcore_characters
    (license,citizenid,slot,firstname,lastname,birthdate,gender,nationality,cash,bank,crypto,dirty,job,job_grade,job_duty,gang,gang_grade,metadata,position,permissions)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)]],{
      identifier,citizenid,data.slot,data.firstname,data.lastname,data.birthdate,data.gender,data.nationality,
      SzCoreConfig.StartingMoney.cash,SzCoreConfig.StartingMoney.bank,SzCoreConfig.StartingMoney.crypto,SzCoreConfig.StartingMoney.dirty or 0,
      SzCoreConfig.DefaultJob.name,SzCoreConfig.DefaultJob.grade,SzCoreConfig.DefaultJob.duty and 1 or 0,
      SzCoreConfig.DefaultGang.name,SzCoreConfig.DefaultGang.grade,json.encode(SzCoreConfig.DefaultMetadata),json.encode(SzCoreConfig.DefaultPosition),json.encode({})
    })
end
function DB.deleteCharacter(identifier,citizenid) return MySQL.update.await('DELETE FROM szcore_characters WHERE license=? AND citizenid=?',{identifier,citizenid}) end
local function params(p)
    local d=p.PlayerData
    return {d.charinfo.firstname,d.charinfo.lastname,d.charinfo.birthdate,d.charinfo.gender,d.charinfo.nationality,
      json.encode(d.metadata),json.encode(d.position),json.encode(d.permissions or {}),d.citizenid,d.license}
end
function DB.saveCharacter(p) SzCore.Metrics.dbWrites=SzCore.Metrics.dbWrites+1; return MySQL.prepare.await(SAVE_SQL,params(p)) end
function DB.saveCharacters(players)
    if #players==0 then return true end
    local batches={} for i=1,#players do batches[i]=params(players[i]) end
    SzCore.Metrics.dbWrites=SzCore.Metrics.dbWrites+#players
    local result=MySQL.prepare.await(SAVE_SQL,batches);return result~=nil and result~=false
end
function DB.addMoneyLedger(citizenid,account,amount,balance,reason)
    if not SzCoreConfig.Money.AuditLedger then return end
    MySQL.prepare('INSERT INTO szcore_money_ledger (citizenid,account,amount,balance,reason) VALUES (?,?,?,?,?)',{citizenid,account,amount,balance,reason or 'unknown'})
end
function DB.audit(action,actor,target,data)
    return MySQL.insert.await('INSERT INTO szcore_audit_log (action,actor,target,data) VALUES (?,?,?,?)',{action,actor,target,json.encode(data or {})})
end
function DB.getGroups(citizenid)
    return MySQL.query.await('SELECT group_type,name,grade,duty,is_primary FROM szcore_character_groups WHERE citizenid=?',{citizenid}) or {}
end
function DB.upsertGroup(citizenid,kind,name,grade,duty,primary)
    if primary then MySQL.update.await('UPDATE szcore_character_groups SET is_primary=0 WHERE citizenid=? AND group_type=?',{citizenid,kind}) end
    return MySQL.prepare.await([[INSERT INTO szcore_character_groups (citizenid,group_type,name,grade,duty,is_primary)
      VALUES (?,?,?,?,?,?) ON DUPLICATE KEY UPDATE grade=VALUES(grade),duty=VALUES(duty),is_primary=VALUES(is_primary)]],
      {citizenid,kind,name,grade,duty and 1 or 0,primary and 1 or 0})
end
function DB.removeGroup(citizenid,kind,name) return MySQL.update.await('DELETE FROM szcore_character_groups WHERE citizenid=? AND group_type=? AND name=?',{citizenid,kind,name}) end
function DB.searchCharacters(filters)
    filters=filters or {}; local where={'1=1'}; local p={}
    if filters.job then where[#where+1]='job=?';p[#p+1]=filters.job end
    if filters.gang then where[#where+1]='gang=?';p[#p+1]=filters.gang end
    if filters.license then where[#where+1]='license=?';p[#p+1]=filters.license end
    if filters.citizenid then where[#where+1]='citizenid=?';p[#p+1]=filters.citizenid end
    if filters.metadataKey and tostring(filters.metadataKey):match('^[%w_]+$') then where[#where+1]='JSON_UNQUOTE(JSON_EXTRACT(metadata, ?)) = ?';p[#p+1]='$.'..filters.metadataKey;p[#p+1]=tostring(filters.metadataValue) end
    local limit=math.min(tonumber(filters.limit) or 100,500)
    return MySQL.query.await('SELECT * FROM szcore_characters WHERE '..table.concat(where,' AND ')..' LIMIT '..limit,p) or {}
end
function DB.primaryGroup(cid,kind,name,grade,duty,removeOld)
    local queries={
        {query='UPDATE szcore_character_groups SET is_primary=0 WHERE citizenid=? AND group_type=?',values={cid,kind}},
        {query=[[INSERT INTO szcore_character_groups (citizenid,group_type,name,grade,duty,is_primary) VALUES (?,?,?,?,?,1)
          ON DUPLICATE KEY UPDATE grade=VALUES(grade),duty=VALUES(duty),is_primary=1]],values={cid,kind,name,grade,duty and 1 or 0}}
    }
    if kind=='job' then queries[#queries+1]={query='UPDATE szcore_characters SET job=?,job_grade=?,job_duty=? WHERE citizenid=?',values={name,grade,duty and 1 or 0,cid}}
    else queries[#queries+1]={query='UPDATE szcore_characters SET gang=?,gang_grade=? WHERE citizenid=?',values={name,grade,cid}}end
    if removeOld and removeOld~=name then queries[#queries+1]={query='DELETE FROM szcore_character_groups WHERE citizenid=? AND group_type=? AND name=?',values={cid,kind,removeOld}}end
    return MySQL.transaction.await(queries)==true
end
