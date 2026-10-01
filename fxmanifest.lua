fx_version 'cerulean'
game 'gta5'
author 'SzCode / SzCore'
description 'SzCore Framework Core - modular event-driven RP framework'
version '1.4.0-rc1'
shared_scripts {'shared/config.lua','shared/jobs.lua','shared/gangs.lua','shared/items.lua','shared/vehicles.lua','shared/locations.lua','shared/locales.lua'}
server_scripts {
 '@oxmysql/lib/MySQL.lua','server/logger.lua','server/safety.lua','server/dependencies.lua','server/database.lua','server/migrations.lua','server/registry.lua','server/hooks.lua','server/permissions.lua','server/groups.lua','server/accounts.lua','server/money.lua','server/storage.lua','server/buckets.lua','server/entities.lua','server/secure_events.lua','server/commands.lua','server/player.lua','server/offline.lua','server/callbacks.lua','server/main.lua'
}
client_scripts {'client/callbacks.lua','client/main.lua'}
dependency 'oxmysql'
