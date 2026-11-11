fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bakery_multicharacter'
author 'Bakery'
description 'Multicharacter and spawn selector for QBX, QBCore and ESX'
version '1.0.0'

-- ESX turns its multicharacter mode on when a resource called esx_multicharacter exists.
-- This makes es_extended see us as that resource, so no ESX file needs editing.
provide 'esx_multicharacter'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/dui.html',
    'web/dist/assets/*',
    'logo/*',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua',
    'bridge/housing.lua',
}

client_scripts {
    'bridge/appearance.lua',
    'bridge/clothing.lua',
    'bridge/client.lua',
    'client/nui.lua',
    'client/backdrop.lua',
    'client/scene.lua',
    'client/intro.lua',
    'client/spawn.lua',
    'client/wake.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'bridge/qb.lua',
    'bridge/qbx.lua',
    'bridge/esx.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
