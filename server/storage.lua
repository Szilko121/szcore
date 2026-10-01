SzCore.Storage=SzCore.Storage or {}
local S=SzCore.Storage
function S.set(namespace,key,value,scope,owner,ttlSeconds)
    local expires=ttlSeconds and os.date('!%Y-%m-%d %H:%M:%S',os.time()+ttlSeconds) or nil
    return MySQL.prepare.await([[INSERT INTO szcore_storage (namespace,storage_key,scope,owner_id,value,expires_at)
      VALUES (?,?,?,?,?,?) ON DUPLICATE KEY UPDATE value=VALUES(value),expires_at=VALUES(expires_at),updated_at=CURRENT_TIMESTAMP]],
      {namespace,key,scope or 'global',owner or '',json.encode(value),expires})
end
function S.get(namespace,key,scope,owner,default)
    local row=MySQL.single.await([[SELECT value FROM szcore_storage WHERE namespace=? AND storage_key=? AND scope=? AND owner_id=?
      AND (expires_at IS NULL OR expires_at>CURRENT_TIMESTAMP) LIMIT 1]],{namespace,key,scope or 'global',owner or ''})
    if not row then return default end;local ok,v=pcall(json.decode,row.value);return ok and v or default
end
function S.delete(namespace,key,scope,owner) return MySQL.update.await('DELETE FROM szcore_storage WHERE namespace=? AND storage_key=? AND scope=? AND owner_id=?',{namespace,key,scope or 'global',owner or ''}) end
exports('StorageSet',S.set);exports('StorageGet',S.get);exports('StorageDelete',S.delete)
